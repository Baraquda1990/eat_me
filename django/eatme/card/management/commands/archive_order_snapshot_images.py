from collections import Counter

from django.core.management.base import BaseCommand

from card.models import Card_item
from card.snapshots import archive_existing_item_snapshot_image


class Command(BaseCommand):
    help = (
        'Archive product images referenced by existing paid-order snapshots. '
        'The command preserves the historical snapshot URL when its original '
        'file can no longer be found; it never silently substitutes a newer '
        'live product image.'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--limit',
            type=int,
            default=0,
            help='Process at most N paid items (0 = all).',
        )

    def handle(self, *args, **options):
        limit = max(int(options.get('limit') or 0), 0)

        queryset = (
            Card_item.objects
            .filter(card__status='paided')
            .select_related('product')
            .order_by('id')
        )

        if limit:
            queryset = queryset[:limit]

        counts = Counter()

        for item in queryset.iterator(chunk_size=100):
            result = archive_existing_item_snapshot_image(item)
            counts[result] += 1

        checked = sum(counts.values())

        self.stdout.write(
            self.style.SUCCESS(
                'Done. '
                f'Checked: {checked}; '
                f'archived: {counts["archived"]}; '
                f'already archived: {counts["already_archived"]}; '
                f'no image: {counts["no_image"]}; '
                f'source missing: {counts["source_missing"]}; '
                f'no snapshot: {counts["no_snapshot"]}; '
                f'failed: {counts["failed"]}.'
            )
        )

        if counts['source_missing']:
            self.stdout.write(
                self.style.WARNING(
                    'Some old snapshot image URLs no longer exist in storage. '
                    'Those historical URLs were left unchanged intentionally.'
                )
            )
