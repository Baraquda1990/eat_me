from django.core.management.base import BaseCommand

from card.models import Card
from card.snapshots import capture_card_snapshot


class Command(BaseCommand):
    help = (
        'Backfill snapshots for existing paid orders. '
        'Existing historical data is best-effort because the original '
        'purchase-time product values were not stored before this feature.'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--force',
            action='store_true',
            help='Overwrite existing snapshots with current live values.',
        )

    def handle(self, *args, **options):
        force = bool(options['force'])

        cards = (
            Card.objects
            .filter(status='paided')
            .select_related('user', 'user__profile')
            .order_by('id')
        )

        cards_count = 0
        items_count = 0

        for card in cards.iterator(chunk_size=200):
            changed = capture_card_snapshot(
                card,
                user=card.user,
                force=force,
            )
            cards_count += 1
            items_count += changed

        self.stdout.write(
            self.style.SUCCESS(
                f'Done. Paid orders checked: {cards_count}; '
                f'item snapshots created/updated: {items_count}.'
            )
        )
        self.stdout.write(
            self.style.WARNING(
                'Note: old orders are best-effort snapshots of the product '
                'as it exists now. Only new orders will contain exact '
                'purchase-time values.'
            )
        )
