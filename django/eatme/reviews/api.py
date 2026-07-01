from decimal import Decimal

from django.db.models import Avg
from rest_framework import status
from rest_framework.generics import CreateAPIView, ListAPIView, RetrieveUpdateDestroyAPIView
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError, PermissionDenied

from company.models import Company
from card.models import Card
from profiles.models import OrgProf
from .models import Review
from .serializers import ReviewSerializer


def recalculate_company_rating(company):
    reviews = Review.objects.filter(company=company)

    reviews_count = reviews.count()
    average_rating = reviews.aggregate(avg=Avg('rating'))['avg'] or Decimal('0')
    all_average = Review.objects.aggregate(avg=Avg('rating'))['avg'] or Decimal('4.30')

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

        if not card.card_item.filter(product__company=company).exists():
            raise ValidationError(
                'В этом заказе нет товаров этой компании'
            )

        if Review.objects.filter(
            user=user,
            card=card,
            company=company
        ).exists():
            raise ValidationError(
                'Вы уже оставили отзыв этой компании по этому заказу'
            )

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
        return Review.objects.filter(
            company__slug=self.kwargs['slug']
        )


class MyReviewsApi(ListAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Review.objects.filter(
            user=self.request.user
        )


class SellerReviewsApi(ListAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user

        company_ids = OrgProf.objects.filter(
            user=user
        ).values_list('company_id', flat=True)

        return Review.objects.filter(
            company_id__in=company_ids
        ).select_related(
            'user',
            'company',
            'card',
        )


class MyReviewDetailApi(RetrieveUpdateDestroyAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Review.objects.filter(
            user=self.request.user
        ).select_related(
            'user',
            'company',
            'card',
        )

    def perform_update(self, serializer):
        review = serializer.save()
        recalculate_company_rating(review.company)

    def perform_destroy(self, instance):
        company = instance.company
        instance.delete()
        recalculate_company_rating(company)