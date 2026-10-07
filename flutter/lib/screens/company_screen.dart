// lib/screens/company_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // 👈 ДОБАВЛЕН ИМПОРТ

import '../utils/phone_launcher.dart';
import '../models/product.dart';
import '../providers/navigation_provider.dart';
import '../services/api_service.dart';
import '../utils/app_feedback.dart';
import '../widgets/product_card.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/app_error_state.dart';

class CompanyScreen extends StatefulWidget {
  final Company company;

  const CompanyScreen({Key? key, required this.company}) : super(key: key);

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  static const Color accentColor = Color(0xFFD1BC00);
  static const Color darkColor = Color(0xFF1A1A1A);
  static const Color bgColor = Color(0xFFF8F8F8);
  static const Color cardColor = Color(0xFFFFFFFF);

  late Company _company;
  List<Product> _products = [];
  bool _isLoadingProducts = true;
  bool _hasMore = true;
  int _currentPage = 1;
  Object? _loadError;
  Object? _loadMoreError;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _company = widget.company;
    _loadCompanyDetails();
    _loadProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 220) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadCompanyDetails() async {
    try {
      final companyDetails = await ApiService.getCompanyBySlug(_company.slug);
      if (!mounted) return;
      setState(() => _company = companyDetails);
    } catch (e) {
      debugPrint('Error loading company details: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        _isLoadingProducts = true;
        _loadError = null;
        _loadMoreError = null;
        _currentPage = 1;
        _hasMore = true;
      });

      final products = await ApiService.getProductsByCompany(
        _company.slug,
        page: 1,
      );

      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoadingProducts = false;
        _loadError = null;
        _loadMoreError = null;
        _hasMore = products.length == ApiService.pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingProducts || !_hasMore) return;

    setState(() {
      _isLoadingProducts = true;
      _loadMoreError = null;
    });

    try {
      final nextPage = _currentPage + 1;
      final newProducts = await ApiService.getProductsByCompany(
        _company.slug,
        page: nextPage,
      );

      if (!mounted) return;
      setState(() {
        _products.addAll(newProducts);
        _currentPage = nextPage;
        _hasMore = newProducts.length == ApiService.pageSize;
      });
    } catch (e) {
      debugPrint('Error loading more products: $e');
      if (mounted) {
        setState(() => _loadMoreError = e);
      }
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  bool get _hasDescription {
    final text = _company.description;
    return text != null && text.trim().isNotEmpty;
  }

  String get _companyName {
    return _company.name?.trim().isNotEmpty == true
        ? _company.name!.trim()
        : 'Магазин';
  }

  String get _address {
    return _company.address.trim().isNotEmpty ? _company.address.trim() : 'Адрес не указан';
  }

  String get _phone {
    return (_company.phone ?? '').trim();
  }

  // 👇 ДОБАВЛЕНЫ ГЕТТЕРЫ ДЛЯ СОЦСЕТЕЙ
  String get _instagram {
    return (_company.instagram ?? '').trim();
  }

  String get _facebook {
    return (_company.facebook ?? '').trim();
  }

  LatLng? get _companyPoint {
    final lat = double.tryParse((_company.latitude ?? '').replaceAll(',', '.'));
    final lng = double.tryParse((_company.longitude ?? '').replaceAll(',', '.'));

    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

    return LatLng(lat, lng);
  }

  Future<void> _refresh() async {
    await _loadCompanyDetails();
    await _loadProducts();
  }

  void _openOnMap() {
    context.read<NavigationProvider>().openMapForCompany(_company.slug);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _callCompany() async {
    const actionKey = 'company.phone-call';
    if (!AppActionGuard.tryLock(actionKey)) return;

    try {
      await launchPhoneCall(context, _phone);
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  // 👇 ДОБАВЛЕН МЕТОД ДЛЯ ОТКРЫТИЯ ССЫЛОК
  Future<void> _openUrl(String url) async {
    final actionKey = 'company.external-url:$url';
    if (!AppActionGuard.tryLock(actionKey)) return;

    try {
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }


  Future<void> _openNavigator(LatLng point) async {
    const actionKey = 'company.open-navigator';
    if (!AppActionGuard.tryLock(actionKey)) return;

    try {
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}&travelmode=walking',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        color: accentColor,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    _buildCompanyHeader(),
                    _buildPhoneBlock(),
                    _buildMapBlock(),
                    _buildAboutAndRatingBlock(),
                    _buildProductsHeader(),
                  ],
                ),
              ),
            ),
            _buildProductsSliver(),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left_rounded),
            color: accentColor,
            iconSize: 32,
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.share_rounded),
            color: darkColor,
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: accentColor, width: 1.7),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _company.imageUrl.isNotEmpty
                          ? Image.network(
                        ApiService.fixImageUrl(_company.imageUrl),
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return const ImageLoadingShimmer();
                        },
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.store_rounded,
                          color: accentColor,
                          size: 34,
                        ),
                      )
                          : const Icon(
                        Icons.store_rounded,
                        color: accentColor,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _companyName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: darkColor,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.withOpacity(0.16)),
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'КАК НАС НАЙТИ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  // 👇 ИЗМЕНЕНО: соцсети показываются только если есть ссылки
                  if (_facebook.isNotEmpty || _instagram.isNotEmpty) ...[
                    Container(
                      width: 1.5,
                      height: 24,
                      color: accentColor,
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_facebook.isNotEmpty)
                            _SocialIconButton(
                              label: 'f',
                              onTap: () => _openUrl(_facebook),
                            ),
                          if (_facebook.isNotEmpty && _instagram.isNotEmpty)
                            const SizedBox(width: 22),
                          if (_instagram.isNotEmpty)
                            _SocialIconButton(
                              label: '◎',
                              onTap: () => _openUrl(_instagram),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(height: 4, color: accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneBlock() {
    if (_phone.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _callCompany,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.13),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.phone_rounded,
                color: accentColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _phone,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: darkColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Позвонить',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: accentColor,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBlock() {
    final point = _companyPoint;

    return Container(
      height: 190,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: point == null
          ? Center(
        child: Text(
          'Координаты магазина не указаны',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w800,
          ),
        ),
      )
          : Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 16,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'am.apsosa.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openOnMap,
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: accentColor,
              shape: const CircleBorder(),
              elevation: 8,
              shadowColor: Colors.black26,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _openNavigator(point),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutAndRatingBlock() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: accentColor, size: 27),
              const SizedBox(width: 10),
              const Text(
                'О МАГАЗИНЕ',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: darkColor,
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(left: 37, top: 7, bottom: 14),
            width: 58,
            height: 2,
            color: accentColor,
          ),
          Text(
            _hasDescription
                ? _company.description!.trim()
                : 'Описание магазина пока не добавлено.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Color(0xFF202020),
            ),
          ),
          if (_company.hasHotProducts) ...[
            const SizedBox(height: 24),
            _buildRatingBlock(),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingBlock() {
    final rating = _company.rating;

    final reviewsCount = _company.reviewsCount;

    String ratingText;

    if (rating <= 0) {
      ratingText = 'Новый';
    } else {
      ratingText = rating.toStringAsFixed(1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.star_rounded,
              color: accentColor,
              size: 38,
            ),

            const SizedBox(width: 8),

            Text(
              ratingText,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: darkColor,
              ),
            ),

            const SizedBox(width: 8),

            Text(
              '($reviewsCount)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        _RatingLine(
          title: 'Качество',
          value: (_company.avgQuality / 5).clamp(0, 1),
          score: _company.avgQuality.toStringAsFixed(1),
        ),

        _RatingLine(
          title: 'Выгодность',
          value: (_company.avgValue / 5).clamp(0, 1),
          score: _company.avgValue.toStringAsFixed(1),
        ),

        _RatingLine(
          title: 'Соответствие',
          value: (_company.avgDescriptionMatch / 5).clamp(0, 1),
          score: _company.avgDescriptionMatch.toStringAsFixed(1),
        ),

        _RatingLine(
          title: 'Сервис',
          value: (_company.avgService / 5).clamp(0, 1),
          score: _company.avgService.toStringAsFixed(1),
        ),
      ],
    );
  }

  Widget _buildProductsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Товары магазина',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          if (!_isLoadingProducts && _products.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_products.length}',
                style: const TextStyle(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductsSliver() {
    if (_isLoadingProducts && _products.isEmpty) {
      return const CompanyProductsSkeletonSliver(count: 3);
    }

    if (_loadError != null && _products.isEmpty) {
      return SliverToBoxAdapter(
        child: AppErrorState(
          error: _loadError,
          onRetry: _loadProducts,
        ),
      );
    }

    if (_products.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: _EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'Товаров пока нет',
            subtitle: 'Когда магазин добавит предложения, они появятся здесь',
          ),
        ),
      );
    }

    final showTail = (_isLoadingProducts && _hasMore) ||
        _loadMoreError != null;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index == _products.length) {
            if (_loadMoreError != null) {
              return AppInlineError(
                error: _loadMoreError,
                loadMore: true,
                onRetry: _loadMoreProducts,
              );
            }

            return const ProductCardSkeleton(showCompanyLogo: false);
          }

          return ProductCard(
            product: _products[index],
            showCompanyLogo: false,
          );
        },
        childCount: _products.length + (showTail ? 1 : 0),
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SocialIconButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingLine extends StatelessWidget {
  final String title;
  final double value;
  final String score;

  const _RatingLine({
    required this.title,
    required this.value,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF202020),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD1BC00)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            score,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onPressed;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFD1BC00).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38, color: const Color(0xFFD1BC00)),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              height: 1.35,
            ),
          ),
          if (buttonText != null && onPressed != null) ...[
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD1BC00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonText!,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }
}