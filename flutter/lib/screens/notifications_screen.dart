// lib/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import '../providers/auth_provider.dart';

import '../models/product.dart';
import '../services/api_service.dart';

import 'my_reviews_screen.dart';
import 'product_detail_screen.dart';
import 'deal_detail_screen.dart';
import 'seller_order_detail_screen.dart';
import 'seller_product_form_screen.dart';
import 'seller_deals_product_form_screen.dart';


enum NotificationAudience {
  buyer,
  seller,
}

Map<String, dynamic> notificationPayload(Map<String, dynamic> item) {
  final raw = item['data'];
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

bool notificationBelongsToAudience(
    Map<String, dynamic> item,
    NotificationAudience audience,
    ) {
  final type = item['type']?.toString().trim().toLowerCase() ?? '';
  final data = notificationPayload(item);

  // Future-proofing: when backend explicitly sends audience, prefer it.
  final explicitAudience =
      data['audience']?.toString().trim().toLowerCase() ?? '';

  if (explicitAudience == 'seller') {
    return audience == NotificationAudience.seller;
  }

  if (explicitAudience == 'buyer') {
    return audience == NotificationAudience.buyer;
  }

  // Administration announcements are useful in both modes.
  if (type == 'admin_news') return true;

  // Current backend seller-only notification types.
  const sellerTypes = <String>{
    'order_created',
    'low_stock',
    'product_expired',
  };

  final sellerNotification = sellerTypes.contains(type);

  return audience == NotificationAudience.seller
      ? sellerNotification
      : !sellerNotification;
}

int unreadNotificationsForAudience(
    List<Map<String, dynamic>> items,
    NotificationAudience audience,
    ) {
  return items.where((item) {
    return item['is_read'] != true &&
        notificationBelongsToAudience(item, audience);
  }).length;
}

class NotificationsScreen extends StatefulWidget {
  final NotificationAudience audience;

  const NotificationsScreen({
    Key? key,
    this.audience = NotificationAudience.buyer,
  }) : super(key: key);

  static const Color accentColor = Color(0xFFD1BC00);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  bool? _lastLoggedInState;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    ApiService.notificationsVersion.addListener(_loadNotifications);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = context.watch<AuthProvider>();

    if (!auth.initialized) return;

    final loggedIn = auth.isLoggedIn;
    if (_lastLoggedInState == loggedIn) return;

    _lastLoggedInState = loggedIn;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (loggedIn) {
        _loadNotifications();
      } else {
        setState(() {
          _items = <Map<String, dynamic>>[];
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    ApiService.notificationsVersion.removeListener(_loadNotifications);
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (!auth.initialized || !auth.isLoggedIn) {
      setState(() {
        _items = <Map<String, dynamic>>[];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final items = await ApiService.getNotifications();

      if (!mounted) return;

      setState(() {
        _items = items
            .where(
              (item) => notificationBelongsToAudience(
            item,
            widget.audience,
          ),
        )
            .toList();
        _isLoading = false;
      });
    } catch (e) {


      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final id = int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return;

    await ApiService.markNotificationRead(id);
    await _loadNotifications();
  }

  Map<String, dynamic> _notificationData(Map<String, dynamic> item) {
    return notificationPayload(item);
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> item) async {
    await _markRead(item);

    if (!mounted) return;

    final data = _notificationData(item);
    final productSlug =
        (data['product_slug'] ?? item['product_slug'])?.toString().trim() ?? '';
    final cardId = int.tryParse(
      (data['card_id'] ?? item['card_id'] ?? '').toString(),
    );
    final companyId = int.tryParse(
      (data['company_id'] ?? item['company_id'] ?? '').toString(),
    );

    if (widget.audience == NotificationAudience.seller &&
        item['type']?.toString() == 'order_created' &&
        cardId != null &&
        companyId != null) {
      _openOrderDetail(
        cardId: cardId,
        companyId: companyId,
      );
      return;
    }

    if (productSlug.isNotEmpty) {
      if (widget.audience == NotificationAudience.seller) {
        await _openSellerProductBySlug(productSlug);
      } else {
        await _openProductBySlug(productSlug);
      }
      return;
    }

    if (cardId != null || item['type']?.toString() == 'review_reminder') {
      _openMyReviews();
      return;
    }
  }

  Future<void> _openProductBySlug(String slug) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.openingProduct,
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );

    final product = await _findProductBySlug(slug);

    if (!mounted) return;

    messenger.clearSnackBars();

    if (product == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.productNotFound,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.50),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: (product.type.trim().toLowerCase() == 'long' ||
                product.type.trim().toLowerCase() == 'deals')
                ? DealDetailScreen(product: product)
                : ProductDetailScreen(product: product),
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSellerProductBySlug(String slug) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final products = await ApiService.getMySellerProducts();

      Product? product;
      for (final item in products) {
        if (item.slug == slug) {
          product = item;
          break;
        }
      }

      if (!mounted) return;

      if (product == null) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.productNotFound,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final type = product.type.trim().toLowerCase();

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => (type == 'long' || type == 'deals')
              ? SellerDealsProductFormScreen(product: product)
              : SellerProductFormScreen(product: product),
        ),
      );

      if (!mounted) return;
      await _loadNotifications();
    } catch (_) {
      if (!mounted) return;

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.productNotFound,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<Product?> _findProductBySlug(String slug) async {
    return ApiService.getProductBySlug(slug);
  }

  void _openMyReviews() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MyReviewsScreen(),
      ),
    );
  }

  void _openOrderDetail({
    required int cardId,
    required int companyId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerOrderDetailScreen(
          cardId: cardId,
          companyId: companyId,
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupNotifications() {
    final l10n = AppLocalizations.of(context)!;
    final groups = <String, List<Map<String, dynamic>>>{
      l10n.notificationsToday: <Map<String, dynamic>>[],
      l10n.notificationsYesterday: <Map<String, dynamic>>[],
      l10n.notificationsEarlier: <Map<String, dynamic>>[],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final item in _items) {
      try {
        final created = DateTime.parse(
          item['created'].toString(),
        ).toLocal();

        final createdDay = DateTime(
          created.year,
          created.month,
          created.day,
        );

        final difference = today.difference(createdDay).inDays;

        if (difference == 0) {
          groups[l10n.notificationsToday]!.add(item);
        } else if (difference == 1) {
          groups[l10n.notificationsYesterday]!.add(item);
        } else {
          groups[l10n.notificationsEarlier]!.add(item);
        }
      } catch (_) {
        groups[l10n.notificationsEarlier]!.add(item);
      }
    }

    groups.removeWhere((_, value) => value.isEmpty);
    return groups;
  }

  String _screenTitle(BuildContext context) {
    final seller = widget.audience == NotificationAudience.seller;

    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => seller ? 'Уведомления продавца' : 'Уведомления',
      'hy' => seller ? 'Վաճառողի ծանուցումներ' : 'Ծանուցումներ',
      _ => seller ? 'Seller notifications' : 'Notifications',
    };
  }

  String _emptyText(BuildContext context) {
    final seller = widget.audience == NotificationAudience.seller;

    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => seller
          ? 'Новых уведомлений для продавца пока нет'
          : 'Новых уведомлений пока нет',
      'hy' => seller
          ? 'Վաճառողի համար նոր ծանուցումներ դեռ չկան'
          : 'Նոր ծանուցումներ դեռ չկան',
      _ => seller
          ? 'No seller notifications yet'
          : 'No notifications yet',
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final groups = _groupNotifications();
    final entries = groups.entries.toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: !auth.initialized
            ? const Center(child: CircularProgressIndicator())
            : !auth.isLoggedIn
            ? _buildGuestState()
            : _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? _buildEmpty()
            : RefreshIndicator(
          onRefresh: _loadNotifications,
          color: NotificationsScreen.accentColor,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  _screenTitle(context),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    color: Color(0xFF242424),
                  ),
                ),
              ),
              ...entries.map(
                    (entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 10,
                        bottom: 10,
                      ),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF242424),
                        ),
                      ),
                    ),
                    ...entry.value.map(
                          (item) => _NotificationTile(
                        item: item,
                        onTap: () => _handleNotificationTap(item),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestState() {
    final languageCode = Localizations.localeOf(context).languageCode;

    final title = switch (languageCode) {
      'ru' => 'Войдите или зарегистрируйтесь',
      'hy' => 'Մուտք գործեք կամ գրանցվեք',
      _ => 'Sign in or create an account',
    };

    final message = switch (languageCode) {
      'ru' =>
      'Чтобы покупать товары и получать уведомления, войдите в аккаунт или зарегистрируйтесь.',
      'hy' =>
      'Ապրանքներ գնելու և ծանուցումներ ստանալու համար մուտք գործեք հաշիվ կամ գրանցվեք։',
      _ =>
      'Sign in or create an account to purchase products and receive notifications.',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 120),
      children: [
        Text(
          _screenTitle(context),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: Color(0xFF242424),
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.10,
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBDF),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: NotificationsScreen.accentColor.withOpacity(0.35),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: NotificationsScreen.accentColor.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 38,
                      color: Color(0xFF9B8A00),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF242424),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text(
        _emptyText(context),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Colors.black54,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  static const Color accentColor = NotificationsScreen.accentColor;

  String get _type => item['type']?.toString() ?? '';
  bool get _isRead => item['is_read'] == true;
  bool get _isAdmin => _type == 'admin_news';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isAdmin
                    ? accentColor.withOpacity(0.55)
                    : Colors.transparent,
                width: _isAdmin ? 1.2 : 0,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NotificationAvatar(type: _type, isRead: _isRead),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderBadges(type: _type),
                      Text(
                        item['title']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.15,
                          fontWeight: _isRead ? FontWeight.w700 : FontWeight.w900,
                          color: const Color(0xFF242424),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item['body']?.toString() ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.25,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDate(item['created']?.toString()),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color get _cardColor {
    if (_isAdmin) return const Color(0xFFFFF7D6);
    if (_type == 'welcome') return const Color(0xFFFFFBDF);
    if (_isRead) return const Color(0xFFF7F7F7);
    return const Color(0xFFFFFBDF);
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '';

    try {
      final date = DateTime.parse(value).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day.$month $hour:$minute';
    } catch (_) {
      return value;
    }
  }
}

class _HeaderBadges extends StatelessWidget {
  final String type;

  const _HeaderBadges({required this.type});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = type == 'product_expired'
        ? switch (Localizations.localeOf(context).languageCode) {
      'hy' => 'ԱՊՐԱՆՔԸ ՀԱՆՎԱԾ Է',
      'ru' => 'ТОВАР СНЯТ',
      _ => 'PRODUCT PAUSED',
    }
        : _labelForType(type, l10n);
    final color = _colorForType(type);

    if (label.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  String _labelForType(
      String type,
      AppLocalizations l10n,
      ) {
    switch (type) {
      case 'admin_news':
        return l10n.adminBadge;
      case 'welcome':
        return 'APPSOSA';
      case 'alarm_match':
        return l10n.offerBadge;
      case 'new_product':
        return l10n.storeBadge;
      case 'order_reserved':
        return l10n.reserveBadge;
      case 'order_created':
        return l10n.orderBadge;
      case 'low_stock':
        return l10n.stockBadge;
      case 'favorite_store':
        return l10n.favoriteStoreBadge;
      case 'review_reminder':
        return l10n.reviewBadge;
      case 'new_nearby_product':
        return l10n.nearbyBadge;
      case 'recommendation':
        return l10n.forYouBadge;
      default:
        return '';
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'admin_news':
        return const Color(0xFFD1BC00);
      case 'welcome':
        return const Color(0xFFD1BC00);
      case 'alarm_match':
        return const Color(0xFF5E6AD2);
      case 'new_product':
        return const Color(0xFF20A85A);
      case 'order_reserved':
      case 'order_created':
        return const Color(0xFF242424);
      case 'low_stock':
        return Colors.redAccent;
      case 'favorite_store':
        return const Color(0xFFD1BC00);
      case 'review_reminder':
        return const Color(0xFFFF9800);
      case 'new_nearby_product':
        return const Color(0xFF00A6A6);
      case 'recommendation':
        return const Color(0xFF8B5CF6);
      case 'product_expired':
        return const Color(0xFFE30620);
      default:
        return Colors.grey;
    }
  }
}

class _NotificationAvatar extends StatelessWidget {
  final String type;
  final bool isRead;

  const _NotificationAvatar({
    required this.type,
    required this.isRead,
  });

  static const Color accentColor = NotificationsScreen.accentColor;

  @override
  Widget build(BuildContext context) {
    final isAdmin = type == 'admin_news';
    final isWelcome = type == 'welcome';
    final isNearby = type == 'new_nearby_product';
    final isFavorite = type == 'favorite_store';
    final isRecommendation = type == 'recommendation';

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _backgroundColor,
        shape: BoxShape.circle,
        border: isAdmin
            ? Border.all(color: accentColor, width: 1.4)
            : null,
      ),
      child: Center(
        child: isAdmin
            ? _AdminLogo()
            : isWelcome
            ? ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/icons/app_icon.png',
            width: 34,
            height: 34,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.waving_hand_rounded,
              size: 25,
              color: accentColor,
            ),
          ),
        )
            : isNearby || isFavorite || isRecommendation
            ? Image.asset(
          'assets/icons/notifications.png',
          width: 26,
          height: 26,
          color: _iconColor,
          errorBuilder: (_, __, ___) => Icon(
            isFavorite ? Icons.favorite_rounded : Icons.notifications_rounded,
            size: 25,
            color: _iconColor,
          ),
        )
            : Icon(
          _iconForType(type),
          size: 25,
          color: _iconColor,
        ),
      ),
    );
  }

  Color get _backgroundColor {
    switch (type) {
      case 'admin_news':
        return Colors.white;
      case 'welcome':
        return const Color(0xFFFFFBDF);
      case 'alarm_match':
        return const Color(0xFFECEEFF);
      case 'new_product':
        return const Color(0xFFEAF8EF);
      case 'low_stock':
        return const Color(0xFFFFECEF);
      case 'favorite_store':
        return const Color(0xFFFFF7D6);
      case 'review_reminder':
        return const Color(0xFFFFF1DD);
      case 'new_nearby_product':
        return const Color(0xFFE3FAFA);
      case 'recommendation':
        return const Color(0xFFF1EAFF);
      case 'product_expired':
        return const Color(0xFFFFECEF);
      default:
        return isRead ? Colors.white : accentColor.withOpacity(0.18);
    }
  }

  Color get _iconColor {
    switch (type) {
      case 'welcome':
        return const Color(0xFFD1BC00);
      case 'alarm_match':
        return const Color(0xFF5E6AD2);
      case 'new_product':
        return const Color(0xFF20A85A);
      case 'low_stock':
        return Colors.redAccent;
      case 'favorite_store':
        return const Color(0xFFD1BC00);
      case 'review_reminder':
        return const Color(0xFFFF9800);
      case 'new_nearby_product':
        return const Color(0xFFD1BC00);
      case 'recommendation':
        return const Color(0xFF8B5CF6);
      case 'product_expired':
        return const Color(0xFFE30620);
      default:
        return accentColor;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'welcome':
        return Icons.waving_hand_rounded;
      case 'alarm_match':
        return Icons.notifications_active_rounded;
      case 'new_product':
        return Icons.storefront_rounded;
      case 'order_reserved':
        return Icons.inventory_2_rounded;
      case 'order_created':
        return Icons.shopping_bag_rounded;
      case 'order_cancelled':
        return Icons.cancel_rounded;
      case 'low_stock':
        return Icons.warning_amber_rounded;
      case 'favorite_store':
        return Icons.favorite_rounded;
      case 'review_reminder':
        return Icons.star_rounded;
      case 'new_nearby_product':
        return Icons.notifications_rounded;
      case 'recommendation':
        return Icons.auto_awesome_rounded;
      case 'product_expired':
        return Icons.timer_off_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}

class _AdminLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: 27,
      height: 27,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Text(
        'A',
        style: TextStyle(
          color: Color(0xFFD1BC00),
          fontSize: 23,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}