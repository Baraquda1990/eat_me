from rest_framework.generics import (
    ListAPIView,
    RetrieveAPIView,
    CreateAPIView,
    RetrieveUpdateAPIView,
    DestroyAPIView,
)
from rest_framework.permissions import AllowAny, BasePermission
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.exceptions import PermissionDenied
from rest_framework.pagination import LimitOffsetPagination
from rest_framework import filters
from drf_spectacular.utils import extend_schema
from django.db.models import (
    F, Sum, Value, IntegerField, DecimalField, FloatField,
    ExpressionWrapper, Count, OuterRef, Subquery, Func,
)
from django.db.models.functions import Coalesce
from django.utils import timezone
from notifications.tasks import check_product_alarm_matches
from products.tasks import publish_scheduled_product, schedule_deals_expiration
from .models import Products
from .serializers import ProductsDetailSerializer, ProductsListSerializer, ProductsSerializer
from .services import activate_product, pause_product, ensure_product_expiration_schedule
from profiles.models import OrgProf
from django.db.models import Q
from card.models import Card_item



def public_available_products(queryset):
    now = timezone.now()

    today = timezone.localdate()

    return queryset.filter(
        publication_status=Products.PublicationStatus.PUBLISHED,
        is_active=True,
        count__gt=0,
    ).filter(
        Q(publish_at__isnull=True) | Q(publish_at__lte=now)
    ).filter(
        Q(
            type=Products.Type.LONG,
            expiration_date__isnull=True,
        )
        | Q(
            type=Products.Type.LONG,
            expiration_date__gte=today,
        )
        | Q(
            type=Products.Type.HOT,
            pickup_until__gt=now,
        )
        # Temporary compatibility for HOT rows backfilled from the old logic.
        | Q(
            type=Products.Type.HOT,
            pickup_until__isnull=True,
            active_until__gt=now,
        )
    )



class _DoublePrecision(Func):
    template = '(%(expressions)s)::double precision'
    output_field = FloatField()


class _Radians(Func):
    function = 'RADIANS'
    arity = 1
    output_field = FloatField()


class _Sin(Func):
    function = 'SIN'
    arity = 1
    output_field = FloatField()


class _Cos(Func):
    function = 'COS'
    arity = 1
    output_field = FloatField()


class _ACos(Func):
    function = 'ACOS'
    arity = 1
    output_field = FloatField()


class _Least(Func):
    function = 'LEAST'
    output_field = FloatField()


class _Greatest(Func):
    function = 'GREATEST'
    output_field = FloatField()


def _parse_client_coordinate(value, minimum, maximum):
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return None

    if parsed < minimum or parsed > maximum:
        return None

    return parsed


def with_distance_from(queryset, latitude, longitude):
    """
    Annotate products with great-circle distance in kilometres.

    PostgreSQL evaluates this before LIMIT/OFFSET, therefore
    ?ordering=distance_km,-id is a true global nearest sort and not a
    client-side reordering of only the currently downloaded page.
    """
    # Prefer the product-specific point selected by the seller. Existing
    # products without one keep the previous behaviour and fall back to the
    # company's coordinates.
    company_lat = _DoublePrecision(F('company__latitude'))
    company_lng = _DoublePrecision(F('company__longitude'))
    product_lat = Coalesce(
        _DoublePrecision(F('location_latitude')),
        company_lat,
        output_field=FloatField(),
    )
    product_lng = Coalesce(
        _DoublePrecision(F('location_longitude')),
        company_lng,
        output_field=FloatField(),
    )

    user_lat = Value(float(latitude), output_field=FloatField())
    user_lng = Value(float(longitude), output_field=FloatField())

    cosine = (
        _Cos(_Radians(user_lat))
        * _Cos(_Radians(product_lat))
        * _Cos(_Radians(product_lng) - _Radians(user_lng))
        + _Sin(_Radians(user_lat))
        * _Sin(_Radians(product_lat))
    )

    # Floating-point rounding can occasionally produce 1.0000000001 or
    # -1.0000000001, which would make ACOS fail. Clamp to [-1, 1].
    clamped_cosine = _Greatest(
        Value(-1.0, output_field=FloatField()),
        _Least(
            Value(1.0, output_field=FloatField()),
            cosine,
        ),
    )

    distance_km = ExpressionWrapper(
        Value(6371.0088, output_field=FloatField())
        * _ACos(clamped_cosine),
        output_field=FloatField(),
    )

    return queryset.annotate(distance_km=distance_km)


def with_product_list_stats(queryset):
    """
    Adds fields used both by the list serializer and server-side ordering.

    sold_count is calculated through a correlated subquery instead of a JOIN.
    That keeps it correct when the product queryset is also filtered by M2M tags.
    """
    paid_quantity = (
        Card_item.objects
        .filter(
            product_id=OuterRef('pk'),
            card__status='paided',
        )
        .values('product_id')
        .annotate(total=Sum('quantity'))
        .values('total')[:1]
    )

    return queryset.annotate(
        discount_price=ExpressionWrapper(
            F('price') - (F('price') * F('discount') / 100.0),
            output_field=DecimalField(max_digits=10, decimal_places=2),
        ),
        sold_count=Coalesce(
            Subquery(paid_quantity, output_field=IntegerField()),
            Value(0),
            output_field=IntegerField(),
        ),
    )


class ProductsPagination(LimitOffsetPagination):
    default_limit = 10
    max_limit = 100

    def paginate_queryset(self, queryset, request, view=None):
        # Keep the already-filtered queryset so first-page responses can expose
        # real catalogue metadata without asking Flutter to download every item.
        self._filtered_queryset = queryset
        return super().paginate_queryset(queryset, request, view=view)

    def get_paginated_response(self, data):
        payload = {
            'count': self.count,
            'next': self.get_next_link(),
            'previous': self.get_previous_link(),
            'results': data,
        }

        include_meta = str(
            self.request.query_params.get('include_meta', '')
        ).lower() in {'1', 'true', 'yes'}

        if include_meta:
            queryset = getattr(self, '_filtered_queryset', None)

            tag_counts = {}
            untagged_count = 0

            if queryset is not None:
                rows = (
                    queryset
                    .values('tag__slug')
                    .annotate(total=Count('id', distinct=True))
                )

                for row in rows:
                    slug = row.get('tag__slug')
                    total = int(row.get('total') or 0)

                    if slug:
                        tag_counts[slug] = total
                    else:
                        untagged_count = total

            payload['tag_counts'] = tag_counts
            payload['untagged_count'] = untagged_count

        return Response(payload)


@extend_schema(
    description=(
        "Получить список товаров. Можно использовать: limit=1&offset=0 — для догрузки содержимого "
        "с помощью LimitOffsetPagination. Также можно добавить: &tag=НазваниеТега — фильтрация товаров "
        "по тегам, &company=НазваниеКомпании — фильтрация товаров по компании, &type=hot/long — фильтрация "
        "по типу товара (горячие/акции), &search=СловаДляПоиска - поиск продуктов по названию и описанию, "
        "&ordering=price - сортировка по возрастанию цены, &ordering=-price - сортировка по убыванию цены, "
        "&ordering=-created - сортировка от новых к старым, "
        "&ordering=discount_price - сортировка по возрастанию цены со скидкой, "
        "&ordering=-discount_price - сортировка по убыванию цены со скидкой"
    )
)
class ProductsList(ListAPIView):
    serializer_class = ProductsListSerializer
    permission_classes = [AllowAny]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]

    # Search must stay correct after Flutter stops downloading the full catalogue.
    search_fields = [
        'name',
        'description',
        'company__name',
        'company__address',
    ]

    ordering_fields = [
        'price',
        'discount_price',
        'created',
        'id',
        'count',
        'sold_count',
        'views_count',
        'shares_count',
        'company__rating',
        'company__reviews_count',
        'company__company_score',
        'distance_km',
    ]

    # A deterministic tie-breaker is important for offset pagination:
    # equal-price products must not randomly jump between pages.
    ordering = ['discount_price', '-created', '-id']
    pagination_class = ProductsPagination

    def get_queryset(self):
        queryset = (
            Products.objects
            .all()
            .select_related('company')
            .prefetch_related('tag')
        )

        queryset = public_available_products(queryset)

        company = self.request.GET.get('company')
        if company:
            queryset = queryset.filter(company__slug=company)

        product_type = self.request.GET.get('type')
        if product_type:
            queryset = queryset.filter(type__iexact=product_type)

        promoted = str(self.request.GET.get('promoted', '')).lower()
        if promoted in {'1', 'true', 'yes'}:
            now = timezone.now()
            queryset = queryset.filter(is_promoted=True).filter(
                Q(promotion_until__isnull=True)
                | Q(promotion_until__gt=now)
            )

        untagged = str(self.request.GET.get('untagged', '')).lower()
        if untagged in {'1', 'true', 'yes'}:
            queryset = queryset.filter(tag__isnull=True)
        else:
            tags_raw = self.request.GET.get('tags')
            tag = self.request.GET.get('tag')

            if tags_raw:
                tag_slugs = [
                    item.strip()
                    for item in tags_raw.split(',')
                    if item.strip()
                ]
                if tag_slugs:
                    queryset = queryset.filter(
                        tag__slug__in=tag_slugs
                    ).distinct()
            elif tag:
                queryset = queryset.filter(tag__slug=tag)

        queryset = with_product_list_stats(queryset)

        requested_ordering = self.request.GET.get('ordering', '')
        wants_distance = any(
            item.lstrip('-') == 'distance_km'
            for item in requested_ordering.split(',')
            if item
        )

        if wants_distance:
            latitude = _parse_client_coordinate(
                self.request.GET.get('lat'),
                -90.0,
                90.0,
            )
            longitude = _parse_client_coordinate(
                self.request.GET.get('lng'),
                -180.0,
                180.0,
            )

            if latitude is not None and longitude is not None:
                queryset = with_distance_from(
                    queryset,
                    latitude,
                    longitude,
                )
            else:
                # Keep OrderingFilter valid even for malformed/manual requests.
                # Flutter sends distance ordering only when a real location is
                # available, so normal app traffic uses the real annotation.
                queryset = queryset.annotate(
                    distance_km=Value(
                        None,
                        output_field=FloatField(),
                    )
                )

        return queryset


@extend_schema(description="Рекомендованные товары для пользователя")
class RecommendedProductsList(ListAPIView):
    serializer_class = ProductsListSerializer
    permission_classes = [AllowAny]
    pagination_class = ProductsPagination

    def get_queryset(self):
        queryset = (
            Products.objects
            .all()
            .select_related('company')
            .prefetch_related('tag')
        )

        queryset = with_product_list_stats(
            public_available_products(queryset).filter(
                type__iexact='hot'
            )
        )

        user = self.request.user
        mode = self.request.GET.get('mode', '').strip().lower()

        if mode == 'favorite_stores':
            if not user.is_authenticated:
                return queryset.none()

            purchased_company_ids = (
                Card_item.objects
                .filter(
                    card__user=user,
                    card__status='paided',
                    product__isnull=False,
                )
                .values_list('product__company_id', flat=True)
                .distinct()
            )

            return queryset.filter(
                company_id__in=purchased_company_ids
            ).order_by(
                '-company__company_score',
                '-company__rating',
                '-sold_count',
                '-id',
            )

        if user.is_authenticated:
            purchased_items = (
                Card_item.objects
                .filter(
                    card__user=user,
                    card__status='paided',
                    product__isnull=False,
                )
                .select_related('product')
                .prefetch_related('product__tag')
            )

            tag_slugs = set()

            for item in purchased_items[:50]:
                if not item.product:
                    continue

                for tag in item.product.tag.all():
                    tag_slugs.add(tag.slug)

            if tag_slugs:
                recommended = queryset.filter(
                    tag__slug__in=tag_slugs
                ).distinct().order_by(
                    '-company__company_score',
                    '-company__rating',
                    '-sold_count',
                    'discount_price',
                    '-id',
                )

                if recommended.exists():
                    return recommended

        return queryset.order_by(
            '-company__company_score',
            '-company__rating',
            '-sold_count',
            'discount_price',
            '-id',
        )


@extend_schema(description="Детальная информация о продукте.")
class ProductsDetail(RetrieveAPIView):
    queryset = Products.objects.all().select_related('company')
    permission_classes = [AllowAny]
    serializer_class = ProductsDetailSerializer
    lookup_field = 'slug'

    def get_queryset(self):
        return public_available_products(super().get_queryset())


@extend_schema(description="Увеличить счётчик просмотров продукта")
class ProductViewEvent(APIView):
    permission_classes = [AllowAny]

    def post(self, request, slug):
        available = public_available_products(Products.objects.all()).filter(slug=slug)
        updated = available.update(
            views_count=F('views_count') + 1
        )
        if not updated:
            return Response({'detail': 'Продукт не найден.'}, status=status.HTTP_404_NOT_FOUND)

        product = Products.objects.only('views_count').get(slug=slug)
        return Response({'views_count': product.views_count}, status=status.HTTP_200_OK)


@extend_schema(description="Увеличить счётчик поделившихся продуктом")
class ProductShareEvent(APIView):
    permission_classes = [AllowAny]

    def post(self, request, slug):
        available = public_available_products(Products.objects.all()).filter(slug=slug)
        updated = available.update(
            shares_count=F('shares_count') + 1
        )
        if not updated:
            return Response({'detail': 'Продукт не найден.'}, status=status.HTTP_404_NOT_FOUND)

        product = Products.objects.only('shares_count').get(slug=slug)
        return Response({'shares_count': product.shares_count}, status=status.HTTP_200_OK)


class IsSeller(BasePermission):
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated
            and hasattr(request.user, 'profile')
            and request.user.profile.type_user == 'seller'
        )


@extend_schema(description="Создание продукта")
class ProductsCreate(CreateAPIView):
    serializer_class = ProductsSerializer
    permission_classes = [IsSeller]

    def perform_create(self, serializer):
        user = self.request.user
        company = serializer.validated_data['company']

        if not OrgProf.objects.filter(user=user, company=company).exists():
            raise PermissionDenied("Вы не владелец этой компании")

        now = timezone.now()
        requested_publish_at = serializer.validated_data.get('publish_at')

        if requested_publish_at is not None and requested_publish_at > now:
            product = serializer.save(
                publication_status=Products.PublicationStatus.SCHEDULED,
                is_active=False,
                inactive_reason=Products.InactiveReason.SCHEDULED,
                published_at=None,
            )
            schedule_deals_expiration(product)

            return

        product = serializer.save(
            publication_status=Products.PublicationStatus.PUBLISHED,
            publish_at=now,
            published_at=now,
            inactive_reason='',
        )
        activate_product(product)
        schedule_deals_expiration(product)
        check_product_alarm_matches.delay(product.id)


@extend_schema(description="Список продуктов созданных компанией")
class MyProductsList(ListAPIView):
    serializer_class = ProductsListSerializer
    permission_classes = [IsSeller]

    def get_queryset(self):
        return Products.objects.filter(
            company__orgprof__user=self.request.user
        ).select_related('company').prefetch_related('tag').annotate(
            sold_count=Coalesce(
                Sum(
                    'card_item__quantity',
                    filter=Q(card_item__card__status='paided'),
                ),
                Value(0),
                output_field=IntegerField(),
            )
        ).order_by('-created')


@extend_schema(description="Изменение продукта")
class MyProductUpdate(RetrieveUpdateAPIView):
    serializer_class = ProductsSerializer
    permission_classes = [IsSeller]
    lookup_field = 'slug'

    def get_queryset(self):
        # Важно: здесь уже проверяется владелец товара.
        # Если товар не принадлежит продавцу, Django просто не найдёт объект.
        return Products.objects.filter(
            company__orgprof__user=self.request.user
        )

    def perform_update(self, serializer):
        company = serializer.validated_data.get('company')

        # Если при редактировании продавец меняет компанию,
        # проверяем, что новая компания тоже принадлежит ему.
        if company and not OrgProf.objects.filter(
            user=self.request.user,
            company=company,
        ).exists():
            raise PermissionDenied("Вы не владелец этой компании")

        now = timezone.now()
        schedule_was_changed = 'publish_at' in serializer.validated_data
        requested_publish_at = serializer.validated_data.get('publish_at')

        # Если продавец в режиме редактирования выбрал новое будущее время,
        # переносим публикацию и оставляем товар скрытым до нового момента.
        if (
            schedule_was_changed
            and requested_publish_at is not None
            and requested_publish_at > now
        ):
            product = serializer.save(
                publication_status=Products.PublicationStatus.SCHEDULED,
                is_active=False,
                inactive_reason=Products.InactiveReason.SCHEDULED,
                published_at=None,
                active_until=None,
            )
            schedule_deals_expiration(product)
            return

        # Защита API: если клиент явно передал время "сейчас/в прошлом",
        # считаем это немедленной публикацией.
        if schedule_was_changed and (
            requested_publish_at is None
            or requested_publish_at <= now
        ):
            product = serializer.save(
                publication_status=Products.PublicationStatus.PUBLISHED,
                publish_at=now,
                published_at=now,
                inactive_reason='',
            )

            try:
                activate_product(product)
                schedule_deals_expiration(product)
            except ValueError as exc:
                raise PermissionDenied(str(exc))

            check_product_alarm_matches.delay(product.id)
            return

        # В обычном редактировании publish_at_local не передаётся.
        # Поэтому существующее расписание scheduled-товара сохраняется как есть.
        #
        # Для просроченного Deals разрешаем использовать существующую карточку
        # как шаблон новой партии: продавец меняет срок годности (и при желании
        # остаток/цену), сохраняет форму — товар снова возвращается в продажу.
        was_expired_deal = (
            serializer.instance.type == Products.Type.LONG
            and serializer.instance.inactive_reason
            == Products.InactiveReason.EXPIRATION_EXPIRED
        )
        previous_expiration_date = serializer.instance.expiration_date
        expiration_was_submitted = 'expiration_date' in serializer.validated_data
        requested_expiration_date = serializer.validated_data.get(
            'expiration_date',
            previous_expiration_date,
        )
        effective_count = serializer.validated_data.get(
            'count',
            serializer.instance.count,
        )

        reactivate_expired_deal = (
            was_expired_deal
            and expiration_was_submitted
            and requested_expiration_date is not None
            and requested_expiration_date >= timezone.localdate()
            and requested_expiration_date != previous_expiration_date
        )

        if reactivate_expired_deal and effective_count <= 0:
            raise PermissionDenied(
                'Чтобы вернуть товар в продажу, укажите остаток больше нуля.'
            )

        if reactivate_expired_deal:
            product = serializer.save(
                publication_status=Products.PublicationStatus.PUBLISHED,
                publish_at=now,
                published_at=now,
                inactive_reason='',
            )

            try:
                activate_product(product)
                schedule_deals_expiration(product)
            except ValueError as exc:
                raise PermissionDenied(str(exc))

            # Для покупателя это снова актуальная партия товара.
            check_product_alarm_matches.delay(product.id)
            return

        product = serializer.save()
        schedule_deals_expiration(product)

        if product.is_active:
            ensure_product_expiration_schedule(product)
        elif (
            product.type == Products.Type.LONG
            and product.inactive_reason == Products.InactiveReason.EXPIRATION_EXPIRED
            and (
                product.expiration_date is None
                or product.expiration_date >= timezone.localdate()
            )
        ):
            # Если срок просто удалили/не заменили на новый, не включаем товар
            # автоматически. Для возврата в продажу нужен именно новый срок.
            product.inactive_reason = Products.InactiveReason.MANUAL
            product.save(update_fields=['inactive_reason'])
        elif (
            product.type == Products.Type.HOT
            and product.inactive_reason == Products.InactiveReason.PICKUP_EXPIRED
            and product.pickup_until is not None
            and product.pickup_until > timezone.now()
        ):
            # The seller supplied a new future pickup window.
            # Keep the item inactive until they explicitly press Play.
            product.inactive_reason = Products.InactiveReason.MANUAL
            product.active_until = product.pickup_until
            product.save(
                update_fields=[
                    'inactive_reason',
                    'active_until',
                ]
            )


@extend_schema(description="Пауза / возврат товара в продажу")
class MyProductStatus(APIView):
    permission_classes = [IsSeller]

    def patch(self, request, slug):
        product = Products.objects.filter(
            slug=slug,
            company__orgprof__user=request.user,
        ).select_related('company').first()

        if product is None:
            return Response(
                {'detail': 'Продукт не найден.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        requested = request.data.get('is_active')
        if not isinstance(requested, bool):
            return Response(
                {'detail': 'Передайте is_active: true или false.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if requested:
            publishing_scheduled_now = (
                product.publication_status == Products.PublicationStatus.SCHEDULED
            )

            if product.count <= 0:
                detail = (
                    'Нельзя вернуть в продажу предложение с нулевым остатком '
                    'доступных мест.'
                    if product.dine_in_only
                    else 'Нельзя вернуть в продажу товар с нулевым остатком.'
                )
                return Response(
                    {'detail': detail},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if (
                product.type == Products.Type.LONG
                and product.expiration_date is not None
                and product.expiration_date < timezone.localdate()
            ):
                return Response(
                    {'detail': 'Срок годности товара уже истёк.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if product.type == Products.Type.HOT:
                if product.pickup_from is None or product.pickup_until is None:
                    return Response(
                        {'detail': 'Укажите время получения Hot-товара.'},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if product.pickup_until <= timezone.now():
                    return Response(
                        {
                            'detail': (
                                'Время получения истекло. '
                                'Укажите новое время получения товара.'
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

            if publishing_scheduled_now:
                now = timezone.now()
                product.publication_status = Products.PublicationStatus.PUBLISHED
                product.publish_at = now
                product.published_at = now
                product.inactive_reason = ''
                product.save(
                    update_fields=[
                        'publication_status',
                        'publish_at',
                        'published_at',
                        'inactive_reason',
                    ]
                )

            try:
                activate_product(product)
                schedule_deals_expiration(product)
            except ValueError as exc:
                return Response(
                    {'detail': str(exc)},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if publishing_scheduled_now:
                # Старое scheduled-задание безопасно ничего не сделает,
                # потому что publication_status уже больше не scheduled.
                check_product_alarm_matches.delay(product.id)
        else:
            pause_product(product)

        product.refresh_from_db()

        return Response(
            ProductsListSerializer(
                product,
                context={'request': request},
            ).data,
            status=status.HTTP_200_OK,
        )


@extend_schema(description="Удаление продукта")
class MyProductDelete(DestroyAPIView):
    serializer_class = ProductsSerializer
    permission_classes = [IsSeller]
    lookup_field = 'slug'

    def get_queryset(self):
        return Products.objects.filter(
            company__orgprof__user=self.request.user
        )
