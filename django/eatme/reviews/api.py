from decimal import Decimal

from django.db import transaction
from django.db.models import Avg, Exists, OuterRef, Q
from django.utils import timezone
from rest_framework import status
from rest_framework.generics import CreateAPIView, ListAPIView, RetrieveUpdateDestroyAPIView
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import ValidationError, PermissionDenied

from company.models import Company
from card.models import Card, Card_item
from card.review_eligibility import (
    company_ids_for_card,
    hot_company_ids_for_card,
    get_company_review_availability,
)
from profiles.models import OrgProf
from .models import Review, ReviewEditRequest
from .serializers import ReviewSerializer



def hot_reviews_queryset():
    """Reviews backed by a HOT purchase from the same company.

    Historical Deals reviews are kept in the database for audit/history, but
    they are excluded from customer/seller review APIs and rating calculation.
    """
    matching_hot_item = (
        Card_item.objects
        .filter(card_id=OuterRef('card_id'))
        .filter(
            Q(company_id_snapshot=OuterRef('company_id'))
            | Q(
                company_id_snapshot__isnull=True,
                product__company_id=OuterRef('company_id'),
            )
        )
        .filter(
            Q(product_type_snapshot__iexact='hot')
            | Q(
                product_type_snapshot='',
                product__type__iexact='hot',
            )
        )
    )

    return (
        Review.objects
        .annotate(_has_hot_purchase=Exists(matching_hot_item))
        .filter(_has_hot_purchase=True)
    )


def recalculate_company_rating(company):
    reviews = hot_reviews_queryset().filter(company=company)

    reviews_count = reviews.count()
    average_rating = reviews.aggregate(avg=Avg('rating'))['avg'] or Decimal('0')
    all_average = hot_reviews_queryset().aggregate(avg=Avg('rating'))['avg'] or Decimal('4.30')

    m = Decimal('20')
    v = Decimal(reviews_count)

    if reviews_count == 0:
        bayesian_rating = Decimal('0')
    else:
        bayesian_rating = (
            (v / (v + m)) * Decimal(average_rating) +
            (m / (v + m)) * Decimal(all_average)
        )

    user_rating_score = bayesian_rating * Decimal('20')

    total_orders = company.successful_orders or 0
    fulfillment_rate = Decimal('100') if total_orders > 0 else Decimal('0')

    if total_orders > 0:
        complaint_score = Decimal('100') - (
            Decimal(company.complaints_count) / Decimal(total_orders)
        ) * Decimal('100')
    else:
        complaint_score = Decimal('100')

    company_score = (
        Decimal('0.55') * user_rating_score +
        Decimal('0.30') * fulfillment_rate +
        Decimal('0.15') * complaint_score
    )

    company.rating = round(bayesian_rating, 2)
    company.reviews_count = reviews_count
    company.company_score = max(0, min(100, int(round(company_score))))

    company.save(
        update_fields=[
            'rating',
            'reviews_count',
            'company_score',
        ]
    )


class ReviewCreateApi(CreateAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
        user = request.user
        card_id = request.data.get('card')
        company_id = request.data.get('company')

        try:
            card = Card.objects.get(
                id=card_id,
                user=user,
                status='paided'
            )
        except Card.DoesNotExist:
            raise PermissionDenied(
                'Можно оценивать только свой оплаченный заказ'
            )

        try:
            company = Company.objects.get(id=company_id)
        except Company.DoesNotExist:
            raise ValidationError('Компания не найдена')

        if company.id not in company_ids_for_card(card):
            raise ValidationError(
                'В этом заказе нет товаров этой компании'
            )

        if company.id not in hot_company_ids_for_card(card):
            raise ValidationError(
                {
                    'detail': 'Отзывы доступны только для покупок HOT-товаров',
                    'code': 'reviews_hot_only',
                }
            )

        if Review.objects.filter(
            user=user,
            card=card,
            company=company
        ).exists():
            raise ValidationError(
                'Вы уже оставили отзыв этой компании по этому заказу'
            )

        review_state = get_company_review_availability(card, company.id)
        if not review_state.get('can_review'):
            reason = review_state.get('reason')
            available_at = review_state.get('available_at')

            if reason == 'waiting_delivery':
                message = 'Отзыв можно оставить после получения товара'
            elif reason == 'waiting_pickup':
                message = 'Отзыв можно оставить после времени самовывоза'
            else:
                message = 'Отзыв пока недоступен. Попробуйте немного позже'

            error = {
                'detail': message,
                'code': 'review_not_available_yet',
            }
            if available_at is not None:
                error['available_at'] = available_at.isoformat()

            raise ValidationError(error)

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        review = serializer.save(
            user=user,
            card=card,
            company=company
        )

        recalculate_company_rating(company)

        return Response(
            ReviewSerializer(review).data,
            status=status.HTTP_201_CREATED
        )


class CompanyReviewsApi(ListAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        return hot_reviews_queryset().filter(
            company__slug=self.kwargs['slug']
        ).select_related(
            'user',
            'company',
            'card',
        )


class MyReviewsApi(ListAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return hot_reviews_queryset().filter(
            user=self.request.user
        ).select_related(
            'company',
            'card',
        ).prefetch_related(
            'edit_requests',
        )


class SellerReviewsApi(ListAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user

        company_ids = OrgProf.objects.filter(
            user=user
        ).values_list('company_id', flat=True)

        return hot_reviews_queryset().filter(
            company_id__in=company_ids
        ).select_related(
            'user',
            'company',
            'card',
        ).prefetch_related(
            'edit_requests',
        )


class ReviewEditRequestApi(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, pk):
        try:
            review = hot_reviews_queryset().select_for_update().get(
                pk=pk,
                user=request.user,
            )
        except Review.DoesNotExist:
            return Response(
                {'detail': 'Отзыв не найден.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        current = review.edit_requests.order_by(
            '-created',
            '-id',
        ).first()

        if current is not None and current.status in {
            ReviewEditRequest.Status.PENDING,
            ReviewEditRequest.Status.APPROVED,
        }:
            return Response(
                {
                    'id': current.id,
                    'status': current.status,
                    'can_edit': (
                        current.status == ReviewEditRequest.Status.APPROVED
                    ),
                    'detail': (
                        'Редактирование уже разрешено.'
                        if current.status == ReviewEditRequest.Status.APPROVED
                        else 'Запрос уже ожидает решения администратора.'
                    ),
                },
                status=status.HTTP_200_OK,
            )

        edit_request = ReviewEditRequest.objects.create(
            review=review,
            user=request.user,
        )

        return Response(
            {
                'id': edit_request.id,
                'status': edit_request.status,
                'can_edit': False,
                'detail': 'Запрос на редактирование отправлен администратору.',
            },
            status=status.HTTP_201_CREATED,
        )


class MyReviewDetailApi(RetrieveUpdateDestroyAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return hot_reviews_queryset().filter(
            user=self.request.user
        ).select_related(
            'user',
            'company',
            'card',
        ).prefetch_related(
            'edit_requests',
        )

    @transaction.atomic
    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)

        try:
            instance = hot_reviews_queryset().select_for_update().select_related(
                'company',
                'card',
            ).get(
                pk=kwargs['pk'],
                user=request.user,
            )
        except Review.DoesNotExist:
            return Response(
                {'detail': 'Отзыв не найден.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        permission = instance.edit_requests.order_by(
            '-created',
            '-id',
        ).first()

        if (
            permission is None
            or permission.status != ReviewEditRequest.Status.APPROVED
        ):
            return Response(
                {
                    'detail': (
                        'Редактирование отзыва не разрешено. '
                        'Сначала отправьте запрос администратору.'
                    ),
                    'code': 'review_edit_not_approved',
                    'can_edit': False,
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = self.get_serializer(
            instance,
            data=request.data,
            partial=partial,
        )
        serializer.is_valid(raise_exception=True)
        review = serializer.save()

        recalculate_company_rating(review.company)

        permission.status = ReviewEditRequest.Status.USED
        permission.used_at = timezone.now()
        permission.save(
            update_fields=[
                'status',
                'used_at',
            ]
        )

        refreshed = self.get_serializer(review)
        return Response(refreshed.data, status=status.HTTP_200_OK)

    def perform_destroy(self, instance):
        company = instance.company
        instance.delete()
        recalculate_company_rating(company)

