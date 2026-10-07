// lib/screens/seller_main_screen.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import 'notifications_screen.dart';
import 'seller_dashboard_screen.dart';
import 'seller_registration/seller_registration_service.dart';

class SellerMainScreen extends StatefulWidget {
  final Widget profileScreen;

  const SellerMainScreen({
    super.key,
    required this.profileScreen,
  });

  static const Color accentColor = Color(0xFFD1BC00);

  @override
  State<SellerMainScreen> createState() => _SellerMainScreenState();
}

class _SellerMainScreenState extends State<SellerMainScreen> {
  bool _loading = true;
  String? _loadError;

  bool _hasHot = false;
  bool _hasDeals = false;

  int _selectedIndex = 0;
  int _unreadCount = 0;

  SellerRegistrationService _registrationService() {
    return SellerRegistrationService(
      dio: Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ),
      baseUrl: ApiService.apiUrl,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSellerMode();
    _loadUnreadCount();
    ApiService.notificationsVersion.addListener(_loadUnreadCount);
  }

  @override
  void dispose() {
    ApiService.notificationsVersion.removeListener(_loadUnreadCount);
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final items = await ApiService.getNotifications();
      final count = unreadNotificationsForAudience(
        items,
        NotificationAudience.seller,
      );

      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _loadSellerMode() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final service = _registrationService();
      final application = await service.getMyApplication();

      final resolved = <String>{};

      if (application != null) {
        final codes =
        await service.resolveApplicationChannelCodes(application);

        for (final raw in codes) {
          final code = raw.trim().toLowerCase();
          if (code == 'hot') {
            resolved.add('hot');
          } else if (code == 'deals' || code == 'long') {
            resolved.add('deals');
          }
        }
      }

      if (resolved.isEmpty) {
        try {
          final products = await ApiService.getMySellerProducts();
          _inferChannelsFromProducts(products, resolved);
        } catch (_) {}
      }

      if (resolved.isEmpty) {
        throw StateError('Seller channels are not available.');
      }

      final hasHot = resolved.contains('hot');
      final hasDeals = resolved.contains('deals');

      if (!mounted) return;

      setState(() {
        _hasHot = hasHot;
        _hasDeals = hasDeals;
        _selectedIndex = hasHot ? 0 : 1;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  void _inferChannelsFromProducts(
      List<Product> products,
      Set<String> result,
      ) {
    for (final product in products) {
      final type = product.type.trim().toLowerCase();

      if (type == 'hot') {
        result.add('hot');
      } else if (type == 'deals' || type == 'long') {
        result.add('deals');
      }
    }
  }

  void _selectTab(int index) {
    if (index == 0 && !_hasHot) return;
    if (index == 1 && !_hasDeals) return;

    setState(() => _selectedIndex = index);

    if (index == 2) {
      ApiService.notificationsVersion.value++;
      _loadUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(
              color: SellerMainScreen.accentColor,
            ),
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 48,
                  color: SellerMainScreen.accentColor,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Seller mode could not be loaded',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _loadSellerMode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SellerMainScreen.accentColor,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screens = <Widget>[
      _hasHot
          ? const SellerDashboardScreen(
        key: ValueKey('seller-hot-dashboard'),
        productType: 'hot',
      )
          : const SizedBox.shrink(),
      _hasDeals
          ? const SellerDashboardScreen(
        key: ValueKey('seller-deals-dashboard'),
        productType: 'long',
      )
          : const SizedBox.shrink(),
      const NotificationsScreen(
        key: ValueKey('seller-notifications'),
        audience: NotificationAudience.seller,
      ),
      KeyedSubtree(
        key: const ValueKey('seller-profile'),
        child: widget.profileScreen,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      extendBody: false,
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: _SellerBottomNavigationBar(
        selectedIndex: _selectedIndex,
        hasHot: _hasHot,
        hasDeals: _hasDeals,
        unreadCount: _unreadCount,
        onSelected: _selectTab,
      ),
    );
  }
}

class _SellerBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final bool hasHot;
  final bool hasDeals;
  final int unreadCount;
  final ValueChanged<int> onSelected;

  const _SellerBottomNavigationBar({
    required this.selectedIndex,
    required this.hasHot,
    required this.hasDeals,
    required this.unreadCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _SellerSvgNavItem(
                asset: 'assets/icons/seller_hot.svg',
                selected: selectedIndex == 0,
                enabled: hasHot,
                iconSize: 20,
                onTap: () => onSelected(0),
              ),
            ),
            Expanded(
              child: _SellerSvgNavItem(
                asset: 'assets/icons/deals.svg',
                activeAsset: 'assets/icons/deals_active.svg',
                selected: selectedIndex == 1,
                enabled: hasDeals,
                iconSize: 18,
                onTap: () => onSelected(1),
              ),
            ),
            Expanded(
              child: _SellerNotificationNavItem(
                selected: selectedIndex == 2,
                count: unreadCount,
                onTap: () => onSelected(2),
              ),
            ),
            Expanded(
              child: _SellerSvgNavItem(
                asset: 'assets/icons/profile.svg',
                activeAsset: 'assets/icons/profile_active.svg',
                selected: selectedIndex == 3,
                enabled: true,
                showCircle: true,
                iconSize: 18,
                onTap: () => onSelected(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerSvgNavItem extends StatelessWidget {
  final String asset;
  final String? activeAsset;
  final bool selected;
  final bool enabled;
  final bool showCircle;
  final double iconSize;
  final VoidCallback onTap;

  const _SellerSvgNavItem({
    required this.asset,
    this.activeAsset,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.showCircle = false,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final iconAsset = selected && activeAsset != null
        ? activeAsset!
        : asset;

    Widget icon = SvgPicture.asset(
      iconAsset,
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
      colorFilter: !enabled
          ? const ColorFilter.mode(
        Color(0xFFD7D7D7),
        BlendMode.srcIn,
      )
          : activeAsset == null
          ? ColorFilter.mode(
        selected
            ? SellerMainScreen.accentColor
            : const Color(0xFF787878),
        BlendMode.srcIn,
      )
          : null,
    );

    if (showCircle) {
      icon = Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? SellerMainScreen.accentColor
                : const Color(0xFFD7D7D7),
            width: 1.2,
          ),
        ),
        child: icon,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: enabled ? 1 : 0.42,
            child: icon,
          ),
        ),
      ),
    );
  }
}

class _SellerNotificationNavItem extends StatelessWidget {
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _SellerNotificationNavItem({
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SvgPicture.asset(
                selected
                    ? 'assets/icons/notification_active.svg'
                    : 'assets/icons/notification.svg',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
              if (count > 0)
                Positioned(
                  top: -7,
                  right: -9,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 17,
                      minHeight: 17,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE30620),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
