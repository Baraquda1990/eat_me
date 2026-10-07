# card/stock_out_notifications.py

from notifications.models import Notification
from notifications.services import send_push_to_user
from products.models import Products
from profiles.models import OrgProf


def notify_product_out_of_stock(product_id):
    """
    Notify every seller attached to the product's company when stock reaches 0.

    Uses the existing LOW_STOCK notification type, so no migration is needed.
    The helper is safe to call after the stock decrement that transitions the
    product to zero.
    """
    product = (
        Products.objects
        .select_related('company')
        .filter(pk=product_id)
        .first()
    )

    if product is None or int(product.count or 0) > 0:
        return

    company = product.company
    sellers = list(
        OrgProf.objects
        .filter(company=company)
        .select_related('user')
    )

    title = 'Товар закончился'
    body = f'Товар «{product.name}» полностью распродан. Остаток: 0.'

    for seller in sellers:
        # This helper is called only on the positive-stock -> zero transition.
        # Do not permanently deduplicate by product slug: a Deals product can
        # be replenished and legitimately sell out again later.
        Notification.objects.create(
            user=seller.user,
            type=Notification.Type.LOW_STOCK,
            title=title,
            body=body,
            data={
                'reason': 'out_of_stock',
                'company_id': company.id,
                'company_name': company.name,
                'product_slug': product.slug,
                'product_name': product.name,
                'product_type': product.type,
                'remaining': 0,
            },
        )

        send_push_to_user(
            user=seller.user,
            title=title,
            body=body,
            data={
                'type': 'low_stock',
                'reason': 'out_of_stock',
                'company_id': str(company.id),
                'company_name': company.name,
                'product_slug': product.slug,
                'product_name': product.name,
                'product_type': str(product.type),
                'remaining': '0',
            },
        )
