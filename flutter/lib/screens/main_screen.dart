// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/navigation_provider.dart';
import '../services/api_service.dart';

import 'home_screen.dart';
import 'map_screen.dart';
import 'deals_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  static const Color accentColor = Color(0xFFD1BC00);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _unreadCount = 0;

  // Порядок нижней панели:
  // Home, Map, Deals, Notifications, Profile
  static const List<Widget> _screens = [
    HomeScreen(),
    MapScreen(),
    DealsScreen(),
    NotificationsScreen(audience: NotificationAudience.buyer),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
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
        NotificationAudience.buyer,
      );

      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {}
  }

  void _onDestinationSelected(int index) {
    context.read<NavigationProvider>().setIndex(index);

    // Notifications теперь на индексе 3.
    if (index == 3) {
      ApiService.notificationsVersion.value++;
    }

    _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navigation, _) {
        final selectedIndex = navigation.currentIndex.clamp(0, _screens.length - 1);

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          extendBody: false,
          body: IndexedStack(
            index: selectedIndex,
            children: List<Widget>.generate(
              _screens.length,
                  (index) => HeroMode(
                enabled: index == selectedIndex,
                child: _screens[index],
              ),
            ),
          ),
          bottomNavigationBar: _SquareBottomNavigationBar(
            selectedIndex: selectedIndex,
            unreadCount: _unreadCount,
            onSelected: _onDestinationSelected,
          ),
        );
      },
    );
  }
}

class _SquareBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final int unreadCount;
  final ValueChanged<int> onSelected;

  const _SquareBottomNavigationBar({
    required this.selectedIndex,
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
              color: Colors.black.withOpacity(0.08),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Home - размер 24
            Expanded(
              child: _BottomSvgItem(
                asset: 'assets/icons/home.svg',
                activeAsset: 'assets/icons/home_active.svg',
                selected: selectedIndex == 0,
                iconSize: 24, // Оставляем 24
                onTap: () => onSelected(0),
              ),
            ),
            // Map - размер 21
            Expanded(
              child: _BottomSvgItem(
                asset: 'assets/icons/map.svg',
                activeAsset: 'assets/icons/map_active.svg',
                selected: selectedIndex == 1,
                iconSize: 21, // Было 24
                onTap: () => onSelected(1),
              ),
            ),
            // Deals - размер 18
            Expanded(
              child: _BottomSvgItem(
                asset: 'assets/icons/deals.svg',
                activeAsset: 'assets/icons/deals_active.svg',
                selected: selectedIndex == 2,
                iconSize: 18, // Было 24
                onTap: () => onSelected(2),
              ),
            ),
            // Notification - размер 24
            Expanded(
              child: _BottomSvgNotificationItem(
                asset: 'assets/icons/notification.svg',
                activeAsset: 'assets/icons/notification_active.svg',
                selected: selectedIndex == 3,
                count: unreadCount,
                iconSize: 24, // Добавлен параметр
                onTap: () => onSelected(3),
              ),
            ),
            // Profile - размер 18
            Expanded(
              child: _BottomSvgItem(
                asset: 'assets/icons/profile.svg',
                activeAsset: 'assets/icons/profile_active.svg',
                selected: selectedIndex == 4,
                showCircle: true,
                iconSize: 18, // Добавлен параметр (внутри круга)
                onTap: () => onSelected(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSvgItem extends StatelessWidget {
  final String asset;
  final String activeAsset;
  final bool selected;
  final bool showCircle;
  final double iconSize; // Добавлено поле
  final VoidCallback onTap;

  const _BottomSvgItem({
    required this.asset,
    required this.activeAsset,
    required this.selected,
    required this.onTap,
    this.showCircle = false,
    this.iconSize = 24, // Значение по умолчанию
  });

  @override
  Widget build(BuildContext context) {
    Widget icon = SvgPicture.asset(
      selected ? activeAsset : asset,
      width: iconSize, // Было 24
      height: iconSize, // Было 24
      fit: BoxFit.contain,
    );

    if (showCircle) {
      icon = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? MainScreen.accentColor
                : Colors.grey.shade300,
            width: 1.3,
          ),
        ),
        child: Center(
          child: SvgPicture.asset(
            selected ? activeAsset : asset,
            width: 18, // Размер внутри круга остается 18
            height: 18,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Center(child: icon),
    );
  }
}

class _BottomSvgNotificationItem extends StatelessWidget {
  final String asset;
  final String activeAsset;
  final bool selected;
  final int count;
  final double iconSize; // Добавлено поле
  final VoidCallback onTap;

  const _BottomSvgNotificationItem({
    required this.asset,
    required this.activeAsset,
    required this.selected,
    required this.onTap,
    this.count = 0,
    this.iconSize = 24, // Значение по умолчанию
  });

  @override
  Widget build(BuildContext context) {
    final icon = SvgPicture.asset(
      selected ? activeAsset : asset,
      width: iconSize, // Было 24
      height: iconSize, // Было 24
      fit: BoxFit.contain,
    );

    return InkWell(
      onTap: onTap,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
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
    );
  }
}