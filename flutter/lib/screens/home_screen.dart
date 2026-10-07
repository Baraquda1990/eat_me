// lib/screens/home_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/tag.dart';
import '../providers/company_provider.dart';
import '../providers/favorite_provider.dart';
import '../services/api_service.dart';
import '../utils/app_feedback.dart';
import '../widgets/product_card.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/app_error_state.dart';
import 'company_screen.dart';
import '../widgets/alarm_floating_button.dart';
import '../providers/products_refresh_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  List<Product> _allHotProducts = [];
  List<Product> _products = [];
  List<Product> _recommendedProducts = [];
  List<Product> _promotedProducts = [];
  List<Product> _favoriteStoreRecommendations = [];
  List<Product> _timeProducts = [];
  List<Tag> _allTags = [];

  final Map<String, int> _hotTagCounts = {};
  final Set<String> _selectedTagSlugs = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreCatalog = true;
  bool _hasTimeTagProducts = false;

  Object? _loadError;
  Object? _catalogError;
  Object? _paginationError;

  int _allHotCount = 0;
  int _catalogTotalCount = 0;
  int _catalogPage = 1;
  int _catalogGeneration = 0;

  String _searchQuery = '';
  String _currentSortType = 'none';

  Timer? _searchDebounce;
  int _lastRefreshVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String _catalogOrdering() {
    switch (_currentSortType) {
      case 'price_asc':
        return 'discount_price,-created,-id';
      case 'price_desc':
        return '-discount_price,-created,-id';
      case 'rating':
        return '-company__rating,-company__reviews_count,'
            '-company__company_score,-id';
      case 'distance':
        return 'distance_km,-id';
      default:
        return 'discount_price,-created,-id';
    }
  }

  String _currentTimeTagSlug() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) return 'zavtrak';
    if (hour >= 11 && hour < 16) return 'obed';
    return 'uzhin';
  }

  Future<ProductPageResult> _fetchCatalogPage(
      int page, {
        bool includeMeta = false,
      }) {
    final companyProvider = context.read<CompanyProvider>();
    final userLocation = companyProvider.userLocation;

    return ApiService.getProductsPage(
      page: page,
      search: _searchQuery.isEmpty ? null : _searchQuery,
      ordering: _catalogOrdering(),
      tagSlugs: _selectedTagSlugs.toList(),
      type: 'hot',
      includeMeta: includeMeta,
      latitude: _currentSortType == 'distance'
          ? userLocation?.latitude
          : null,
      longitude: _currentSortType == 'distance'
          ? userLocation?.longitude
          : null,
    );
  }

  Future<void> _loadData({bool showInitialSkeleton = true}) async {
    final hadProducts = _allHotProducts.isNotEmpty;
    final companyProvider = context.read<CompanyProvider>();
    final favoriteProvider = context.read<FavoriteProvider>();
    final generation = ++_catalogGeneration;

    if (showInitialSkeleton) {
      setState(() {
        _isLoading = true;
        _loadError = null;
        _catalogError = null;
        _paginationError = null;
      });
    } else if (mounted) {
      setState(() {
        _loadError = null;
        _catalogError = null;
        _paginationError = null;
      });
    }

    try {
      final timeTag = _currentTimeTagSlug();

      // Every request is bounded. No 30/50-page loops are started here.
      final results = await Future.wait<dynamic>([
        companyProvider.loadCompanies(),
        ApiService.getTags(),
        _fetchCatalogPage(1, includeMeta: true),
        ApiService.getProducts(
          page: 1,
          type: 'hot',
          promoted: true,
          ordering: '-sold_count,-views_count,-shares_count,-created,-id',
        ).catchError((_) => <Product>[]),
        ApiService.getRecommendedProducts()
            .catchError((_) => <Product>[]),
        ApiService.getRecommendedProducts(mode: 'favorite_stores')
            .catchError((_) => <Product>[]),
        ApiService.getProducts(
          page: 1,
          type: 'hot',
          tagSlug: timeTag,
          ordering: '-company__company_score,-company__rating,-id',
        ).catchError((_) => <Product>[]),
        favoriteProvider.loadFavorites(),
      ]);

      if (!mounted || generation != _catalogGeneration) return;

      final tags = results[1] as List<Tag>;
      final page = results[2] as ProductPageResult;
      final promoted = results[3] as List<Product>;
      final recommended = results[4] as List<Product>;
      final favoriteStores = results[5] as List<Product>;
      final timeTagged = results[6] as List<Product>;

      final tagCounts = page.tagCounts;
      tags.sort((a, b) {
        final aCount = tagCounts[a.slug] ?? 0;
        final bCount = tagCounts[b.slug] ?? 0;
        return bCount.compareTo(aCount);
      });

      final hotProducts = page.products
          .where((product) =>
      product.type.toLowerCase() == 'hot' &&
          product.isAvailableForSale)
          .toList();

      final timeProducts = timeTagged
          .where((product) =>
      product.type.toLowerCase() == 'hot' &&
          product.isAvailableForSale)
          .toList();

      setState(() {
        _allTags = tags;
        _allHotProducts = hotProducts;
        _products = _applyFilters(hotProducts);

        _recommendedProducts = recommended
            .where((product) =>
        product.type.toLowerCase() == 'hot' &&
            product.isAvailableForSale)
            .take(ApiService.pageSize)
            .toList();

        _promotedProducts = promoted
            .where((product) =>
        product.type.toLowerCase() == 'hot' &&
            product.isAvailableForSale)
            .take(ApiService.pageSize)
            .toList();

        _favoriteStoreRecommendations = favoriteStores
            .where((product) =>
        product.type.toLowerCase() == 'hot' &&
            product.isAvailableForSale)
            .take(ApiService.pageSize)
            .toList();

        _hasTimeTagProducts = timeProducts.isNotEmpty;
        _timeProducts = (timeProducts.isNotEmpty ? timeProducts : hotProducts)
            .take(ApiService.pageSize)
            .toList();

        _catalogPage = 1;
        _catalogTotalCount = page.count;
        _hasMoreCatalog = page.hasMore;
        _isLoadingMore = false;

        // The initial unfiltered response carries real totals for the whole HOT
        // catalogue. These numbers no longer depend on how many pages Flutter
        // has already downloaded.
        if (_searchQuery.isEmpty && _selectedTagSlugs.isEmpty) {
          _allHotCount = page.count;
          _hotTagCounts
            ..clear()
            ..addAll(page.tagCounts);
        }

        _loadError = null;
        _catalogError = null;
        _paginationError = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _catalogGeneration) return;

      if (showInitialSkeleton || !hadProducts) {
        setState(() {
          _loadError = e;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() => _catalogError = e);
        debugPrint('Home refresh failed: $e');
      }
    }
  }

  Future<void> _reloadCatalog() async {
    final generation = ++_catalogGeneration;

    if (mounted) {
      setState(() {
        _isLoadingMore = true;
        _catalogError = null;
        _paginationError = null;
      });
    }

    try {
      final page = await _fetchCatalogPage(
        1,
        includeMeta: _searchQuery.isEmpty && _selectedTagSlugs.isEmpty,
      );

      if (!mounted || generation != _catalogGeneration) return;

      final hotProducts = page.products
          .where((product) =>
      product.type.toLowerCase() == 'hot' &&
          product.isAvailableForSale)
          .toList();

      setState(() {
        _allHotProducts = hotProducts;
        _products = _applyFilters(hotProducts);
        _catalogPage = 1;
        _catalogTotalCount = page.count;
        _hasMoreCatalog = page.hasMore;
        _isLoadingMore = false;
        _catalogError = null;
        _paginationError = null;

        if (_searchQuery.isEmpty && _selectedTagSlugs.isEmpty) {
          _allHotCount = page.count;
          _hotTagCounts
            ..clear()
            ..addAll(page.tagCounts);
        }
      });
    } catch (e) {
      if (!mounted || generation != _catalogGeneration) return;
      setState(() {
        _isLoadingMore = false;
        _catalogError = e;
      });
      debugPrint('Home catalogue reload failed: $e');
    }
  }

  Future<void> _loadMoreCatalog() async {
    if (_isLoading ||
        _isLoadingMore ||
        !_hasMoreCatalog ||
        _paginationError != null) {
      return;
    }

    final generation = _catalogGeneration;
    final nextPage = _catalogPage + 1;

    setState(() {
      _isLoadingMore = true;
      _paginationError = null;
    });

    try {
      final page = await _fetchCatalogPage(nextPage);

      if (!mounted || generation != _catalogGeneration) return;

      final existingSlugs = _allHotProducts.map((p) => p.slug).toSet();
      final additions = page.products.where((product) {
        return product.type.toLowerCase() == 'hot' &&
            product.isAvailableForSale &&
            !existingSlugs.contains(product.slug);
      }).toList();

      setState(() {
        _allHotProducts.addAll(additions);
        _products = _applyFilters(_allHotProducts);
        _catalogPage = nextPage;
        _catalogTotalCount = page.count;
        _hasMoreCatalog = page.hasMore;
        _isLoadingMore = false;
        _paginationError = null;
      });
    } catch (e) {
      if (!mounted || generation != _catalogGeneration) return;
      setState(() {
        _isLoadingMore = false;
        _paginationError = e;
      });
      debugPrint('Home next page failed: $e');
    }
  }

  Future<void> _retryLoadMoreCatalog() async {
    if (!mounted) return;
    setState(() => _paginationError = null);
    await _loadMoreCatalog();
  }

  Map<String, int> _countHotTags(List<Product> hotProducts) {
    final counts = <String, int>{};

    for (final product in hotProducts) {
      final tags = product.tag ?? [];
      for (final tag in tags) {
        counts[tag.slug] = (counts[tag.slug] ?? 0) + 1;
      }
    }

    return counts;
  }

  List<Product> _applyFilters(List<Product> source) {
    final result = source.where((product) {
      if (!product.isAvailableForSale) return false;

      final query = _searchQuery.trim().toLowerCase();

      if (query.isNotEmpty) {
        final name = product.name.toLowerCase();
        final description = (product.description ?? '').toLowerCase();
        final companyName = (product.company.name ?? '').toLowerCase();
        final address = product.company.address.toLowerCase();

        final matchesSearch = name.contains(query) ||
            description.contains(query) ||
            companyName.contains(query) ||
            address.contains(query);

        if (!matchesSearch) return false;
      }

      if (_selectedTagSlugs.isNotEmpty) {
        final tags = product.tag ?? [];
        final hasSelectedTag = tags.any(
              (tag) => _selectedTagSlugs.contains(tag.slug),
        );
        if (!hasSelectedTag) return false;
      }

      return true;
    }).toList();

    switch (_currentSortType) {
      case 'price_asc':
        result.sort((a, b) => _actualPrice(a).compareTo(_actualPrice(b)));
        break;
      case 'price_desc':
        result.sort((a, b) => _actualPrice(b).compareTo(_actualPrice(a)));
        break;
      case 'distance':
      // Backend already sorted the complete queryset by distance before
      // pagination. Preserve that order locally.
        break;
      case 'rating':
        result.sort((a, b) {
          final ratingCompare = b.company.rating.compareTo(a.company.rating);
          if (ratingCompare != 0) return ratingCompare;

          final reviewsCompare =
          b.company.reviewsCount.compareTo(a.company.reviewsCount);
          if (reviewsCompare != 0) return reviewsCompare;

          return b.company.companyScore.compareTo(a.company.companyScore);
        });
        break;
    }

    return result;
  }

  double _actualPrice(Product product) {
    if (product.discountPrice > 0 && product.discountPrice < product.price) {
      return product.discountPrice;
    }
    return product.price;
  }

  double _discountPercent(Product product) {
    if (product.price <= 0) return 0;
    if (product.discountPrice <= 0 || product.discountPrice >= product.price) {
      return 0;
    }
    return ((product.price - product.discountPrice) / product.price) * 100;
  }

  int _productScore(Product product) {
    return product.company.companyScore +
        product.company.reviewsCount +
        product.count +
        _discountPercent(product).round();
  }

  List<Product> _popularProducts() {
    final products = [..._allHotProducts];

    products.sort((a, b) {
      final scoreCompare = _productScore(b).compareTo(_productScore(a));
      if (scoreCompare != 0) return scoreCompare;
      return b.company.rating.compareTo(a.company.rating);
    });

    return products.take(10).toList();
  }

  List<Product> _bestStoreProducts() {
    final products = [..._allHotProducts];

    products.sort((a, b) {
      final scoreCompare = b.company.companyScore.compareTo(a.company.companyScore);
      if (scoreCompare != 0) return scoreCompare;

      final ratingCompare = b.company.rating.compareTo(a.company.rating);
      if (ratingCompare != 0) return ratingCompare;

      return b.company.reviewsCount.compareTo(a.company.reviewsCount);
    });

    return products.take(10).toList();
  }

  List<Product> _newProducts() {
    final products = [..._allHotProducts];

    // РџРѕРєР° ProductsListSerializer РЅРµ РѕС‚РґР°С‘С‚ created, РёСЃРїРѕР»СЊР·СѓРµРј РїРѕСЂСЏРґРѕРє API.
    // РќРѕРІС‹Рµ С‚РѕРІР°СЂС‹ РѕР±С‹С‡РЅРѕ РїСЂРёС…РѕРґСЏС‚ Р±Р»РёР¶Рµ Рє РЅР°С‡Р°Р»Сѓ СЃРїРёСЃРєР° РїРѕСЃР»Рµ СЃРѕСЂС‚РёСЂРѕРІРєРё backend.
    return products.take(10).toList();
  }

  List<Product> _specialForYouProducts() {
    final result = _recommendedProducts.isNotEmpty
        ? [..._recommendedProducts]
        : [..._allHotProducts];

    result.sort((a, b) {
      final discountCompare = _discountPercent(b).compareTo(_discountPercent(a));
      if (discountCompare != 0) return discountCompare;
      return _productScore(b).compareTo(_productScore(a));
    });

    return result.take(10).toList();
  }

  List<Product> _favoriteStoreProducts() {
    return _favoriteStoreRecommendations
        .take(ApiService.pageSize)
        .toList();
  }

  List<Product> _timeBasedProducts() {
    return _timeProducts.take(ApiService.pageSize).toList();
  }

  String _timeBasedSectionTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 11) {
      return _hasTimeTagProducts ? l10n.breakfastNearby : l10n.morningOffers;
    }

    if (hour >= 11 && hour < 16) {
      return _hasTimeTagProducts ? l10n.lunchNearby : l10n.dayOffers;
    }

    return _hasTimeTagProducts ? l10n.dinnerNearby : l10n.eveningOffers;
  }

  List<Product> _topProducts(List<Product> source) {
    final promoted = source.where((product) => product.isPromoted).toList();

    promoted.sort((a, b) {
      final countCompare = b.count.compareTo(a.count);
      if (countCompare != 0) return countCompare;
      return _actualPrice(a).compareTo(_actualPrice(b));
    });

    return promoted.take(10).toList();
  }

  List<Product> _companiesForCarousel() {
    final Map<String, Product> result = {};

    for (final product in _allHotProducts) {
      final slug = product.company.slug;
      if (slug.isEmpty) continue;
      result.putIfAbsent(slug, () => product);
    }

    return result.values.toList();
  }

  Future<void> _refreshProducts() async {
    await _loadData(showInitialSkeleton: false);
  }

  void _filterProducts(String query) {
    final normalized = query.trim();

    setState(() {
      _searchQuery = normalized;
    });

    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      _reloadCatalog,
    );
  }

  void _selectAllTags() {
    if (_selectedTagSlugs.isEmpty) return;

    setState(() {
      _selectedTagSlugs.clear();
    });

    _reloadCatalog();
  }

  void _toggleTag(String slug) {
    setState(() {
      if (_selectedTagSlugs.contains(slug)) {
        _selectedTagSlugs.remove(slug);
      } else {
        _selectedTagSlugs.add(slug);
      }
    });

    _reloadCatalog();
  }

  Future<void> _setSortType(String type) async {
    Navigator.pop(context);

    if (type == 'distance') {
      final companyProvider = context.read<CompanyProvider>();

      // Usually location is already loaded together with companies on Home.
      // If not, make one explicit attempt before enabling a global distance
      // sort so we never send ?ordering=distance_km without coordinates.
      if (companyProvider.userLocation == null) {
        await companyProvider.loadUserLocation();
      }

      if (!mounted) return;

      if (companyProvider.userLocation == null) {
        AppFeedback.warning(
          context,
          AppLocalizations.of(context)!.locationSortError,
          key: 'home.sort.location-unavailable',
        );
        return;
      }
    }

    setState(() {
      _currentSortType = type;
    });

    await _reloadCatalog();
  }

  Future<void> _showSortMenu() async {
    const actionKey = 'home.sort-sheet';
    if (!AppActionGuard.tryLock(actionKey)) return;

    final l10n = AppLocalizations.of(context)!;

    try {
      await showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 8),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.sort,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sortOption(
                    icon: Icons.auto_awesome_rounded,
                    title: l10n.defaultSort,
                    selected: _currentSortType == 'none',
                    onTap: () => _setSortType('none'),
                  ),
                  _sortOption(
                    icon: Icons.arrow_upward_rounded,
                    title: l10n.cheaperFirst,
                    selected: _currentSortType == 'price_asc',
                    onTap: () => _setSortType('price_asc'),
                  ),
                  _sortOption(
                    icon: Icons.arrow_downward_rounded,
                    title: l10n.expensiveFirst,
                    selected: _currentSortType == 'price_desc',
                    onTap: () => _setSortType('price_desc'),
                  ),
                  _sortOption(
                    icon: Icons.near_me_rounded,
                    title: l10n.nearestFirst,
                    selected: _currentSortType == 'distance',
                    onTap: () => _setSortType('distance'),
                  ),
                  _sortOption(
                    icon: Icons.star_rounded,
                    title: l10n.byRating,
                    selected: _currentSortType == 'rating',
                    onTap: () => _setSortType('rating'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  Widget _sortOption({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: selected ? const Color(0xFFD1BC00) : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
          color: selected ? const Color(0xFFD1BC00) : Colors.black,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFFD1BC00))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final refreshVersion = context.watch<ProductsRefreshProvider>().version;

    if (refreshVersion != _lastRefreshVersion) {
      _lastRefreshVersion = refreshVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshProducts();
      });
    }

    final refreshProvider = context.watch<ProductsRefreshProvider>();

    if (refreshProvider.purchasedSlugs.isNotEmpty) {
      final purchased = refreshProvider.purchasedSlugs;

      final beforeRemoval = _allHotProducts.length;

      _allHotProducts.removeWhere((p) => purchased.contains(p.slug));
      _recommendedProducts.removeWhere((p) => purchased.contains(p.slug));
      _promotedProducts.removeWhere((p) => purchased.contains(p.slug));
      _favoriteStoreRecommendations
          .removeWhere((p) => purchased.contains(p.slug));
      _timeProducts.removeWhere((p) => purchased.contains(p.slug));
      _products = _applyFilters(_allHotProducts);

      final removedLoaded = beforeRemoval - _allHotProducts.length;
      if (removedLoaded > 0) {
        _catalogTotalCount -= removedLoaded;
        if (_catalogTotalCount < 0) _catalogTotalCount = 0;

        if (_searchQuery.isEmpty && _selectedTagSlugs.isEmpty) {
          _allHotCount -= removedLoaded;
          if (_allHotCount < 0) _allHotCount = 0;
        }
      }

      // Tag totals stay server-provided. A pull-to-refresh will reconcile
      // exact per-tag counts after a purchase.

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ProductsRefreshProvider>().clearPurchasedSlugs();
        }
      });
    }
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Consumer<FavoriteProvider>(
      builder: (context, favorites, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: _isLoading
                          ? const HomeProductsSkeleton()
                          : _loadError != null
                          ? AppErrorState(
                        error: _loadError,
                        onRetry: () => _loadData(),
                      )
                          : RefreshIndicator(
                        onRefresh: _refreshProducts,
                        color: Color(0xFFD1BC00),
                        child: _products.isEmpty
                            ? _buildEmptyHotList()
                            : _buildGroupedProducts(),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16 + safeBottom,
                child: AlarmFloatingButton(tags: _allTags),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupedProducts() {
    final sections = _buildProductSections();
    final hasCatalogError = _catalogError != null;
    final hasPaginationError = _paginationError != null;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 72),
      itemCount: sections.length +
          (hasCatalogError ? 1 : 0) +
          (hasPaginationError ? 1 : 0),
      itemBuilder: (_, index) {
        if (hasCatalogError && index == 0) {
          return AppInlineError(
            error: _catalogError,
            onRetry: _reloadCatalog,
          );
        }

        final sectionIndex = index - (hasCatalogError ? 1 : 0);

        if (sectionIndex >= sections.length) {
          return AppInlineError(
            error: _paginationError,
            loadMore: true,
            onRetry: _retryLoadMoreCatalog,
          );
        }

        final section = sections[sectionIndex];

        return _ProductSection(
          title: section.title,
          subtitle: section.subtitle,
          products: section.products,
          useBrandIcon: section.useBrandIcon,
          isTopSection: section.isTopSection,
          leadingIcon: section.leadingIcon,
          leadingIconColor: section.leadingIconColor,
          onEndReached: section.loadsCatalog ? _loadMoreCatalog : null,
          isLoadingMore: section.loadsCatalog && _isLoadingMore,
          hasMore: section.loadsCatalog && _hasMoreCatalog,
        );
      },
    );
  }

  List<Company> _buildCompanyCarouselItems() {
    final Map<String, Company> companies = {};

    for (final product in _allHotProducts) {
      final company = product.company;
      if (company.slug.isEmpty) continue;
      companies[company.slug] = company;
    }

    final result = companies.values.toList();
    result.sort((a, b) {
      final aName = (a.name ?? a.address).toLowerCase();
      final bName = (b.name ?? b.address).toLowerCase();
      return aName.compareTo(bName);
    });

    return result;
  }

  List<_HomeProductSection> _buildProductSections() {
    final l10n = AppLocalizations.of(context)!;
    final queryActive = _searchQuery.trim().isNotEmpty;
    final sortActive = _currentSortType != 'none';

    if (queryActive || sortActive) {
      return [
        _HomeProductSection(
          title: queryActive ? l10n.searchResults : l10n.hotNearby,
          subtitle: '$_catalogTotalCount ${l10n.offers}',
          products: _products,
          loadsCatalog: true,
        ),
      ];
    }

    if (_selectedTagSlugs.isNotEmpty) {
      final selectedSections = <_HomeProductSection>[];

      for (final tag in _allTags) {
        if (!_selectedTagSlugs.contains(tag.slug)) continue;

        final products = _products.where((product) {
          final tags = product.tag ?? [];
          return tags.any((item) => item.slug == tag.slug);
        }).toList();

        if (products.isEmpty) continue;

        selectedSections.add(
          _HomeProductSection(
            title: tag.name,
            subtitle: '${_hotTagCounts[tag.slug] ?? products.length} ${l10n.offers}',
            products: products,
            loadsCatalog: true,
          ),
        );
      }

      if (selectedSections.isNotEmpty) return selectedSections;
    }

    final promotedProducts = _promotedProducts;
    final timeProducts = _timeBasedProducts();
    final favoriteStoreProducts = _favoriteStoreProducts();

    final sections = <_HomeProductSection>[
      if (promotedProducts.isNotEmpty)
        _HomeProductSection(
          title: l10n.topOffers,
          subtitle: l10n.bestOffersNow,
          products: promotedProducts,
          useBrandIcon: true,
          isTopSection: true,
        ),
      if (_recommendedProducts.isNotEmpty)
        _HomeProductSection(
          title: l10n.recommended,
          subtitle: l10n.recommendedSubtitle,
          products: _recommendedProducts,
          useBrandIcon: false,
          leadingIcon: Icons.star_rounded,
          leadingIconColor: const Color(0xFFD1BC00),
        ),
      if (favoriteStoreProducts.isNotEmpty)
        _HomeProductSection(
          title: l10n.favoriteStores,
          subtitle: l10n.favoriteStoresSubtitle,
          products: favoriteStoreProducts,
          useBrandIcon: false,
          leadingIcon: Icons.favorite_rounded,
          leadingIconColor: const Color(0xFFD1BC00),
        ),
      if (timeProducts.isNotEmpty)
        _HomeProductSection(
          title: _timeBasedSectionTitle(context),
          subtitle: l10n.timeBasedSubtitle,
          products: timeProducts,
          useBrandIcon: true,
        ),
      _HomeProductSection(
        title: l10n.all,
        subtitle: l10n.allAvailableNearby,
        products: _products,
        useBrandIcon: true,
        loadsCatalog: true,
      ),
    ];

    return sections;
  }

  Widget _buildEmptyHotList() {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 180),
        Center(
          child: Text(
            l10n.noHotOffers,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: _filterProducts,
                  style: const TextStyle(
                    color: Color(0xFF242124),
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.searchFoodStoreDeal,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade600,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showSortMenu,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _currentSortType == 'none'
                        ? const Color(0xFFF3F3F3)
                        : const Color(0xFFD1BC00),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: _currentSortType == 'none'
                        ? const Color(0xFF242124)
                        : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _TagChip(
                  title: l10n.all,
                  count: _allHotCount,
                  selected: _selectedTagSlugs.isEmpty,
                  onTap: _selectAllTags,
                ),
                ..._allTags.map((tag) {
                  final count = _hotTagCounts[tag.slug] ?? 0;
                  if (count == 0) return const SizedBox.shrink();

                  return _TagChip(
                    title: tag.name,
                    count: count,
                    selected: _selectedTagSlugs.contains(tag.slug),
                    onTap: () => _toggleTag(tag.slug),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

// ================= РљРћРњРџРћРќР•РќРўР« =================

class _CompanyLogoSection extends StatelessWidget {
  final List<Company> companies;

  const _CompanyLogoSection({required this.companies});

  static const Color accentColor = Color(0xFFD1BC00);

  @override
  Widget build(BuildContext context) {
    final companyProvider = context.watch<CompanyProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 24),
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: accentColor,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.salesPoints,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.35,
                          color: Color(0xFF242124),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.salesPointsSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: companies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                final company = companies[index];
                final name = company.name?.trim().isNotEmpty == true
                    ? company.name!.trim()
                    : company.address;
                final distanceText = _distanceText(
                  companyProvider.distanceKmBySlug(company.slug),
                );

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CompanyScreen(company: company),
                      ),
                    );
                  },
                  child: Container(
                    width: 92,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFEFEFEF),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accentColor.withOpacity(0.55),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.07),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: company.imageUrl.isNotEmpty
                                ? Image.network(
                              company.imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return const ImageLoadingShimmer();
                              },
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.storefront_rounded,
                                color: accentColor,
                              ),
                            )
                                : const Icon(
                              Icons.storefront_rounded,
                              color: accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF242124),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: accentColor,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              company.rating <= 0
                                  ? l10n.newStore
                                  : company.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 10,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF242124),
                              ),
                            ),
                            if (distanceText.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  distanceText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _distanceText(double? km) {
    if (km == null) return '';

    if (km < 1) {
      return '${(km * 1000).round()} Рј';
    }

    if (km >= 10) {
      return '${km.round()} РєРј';
    }

    final rounded = (km * 10).round() / 10;
    return '${rounded.toString().replaceAll('.', ',')} РєРј';
  }
}

class _HomeProductSection {
  final String title;
  final String subtitle;
  final List<Product> products;
  final bool useBrandIcon;
  final bool isTopSection;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final bool loadsCatalog;

  const _HomeProductSection({
    required this.title,
    required this.subtitle,
    required this.products,
    this.useBrandIcon = true,
    this.isTopSection = false,
    this.leadingIcon,
    this.leadingIconColor,
    this.loadsCatalog = false,
  });
}

class _ProductSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Product> products;
  final bool useBrandIcon;
  final bool isTopSection;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final Future<void> Function()? onEndReached;
  final bool isLoadingMore;
  final bool hasMore;

  const _ProductSection({
    required this.title,
    required this.subtitle,
    required this.products,
    this.useBrandIcon = true,
    this.isTopSection = false,
    this.leadingIcon,
    this.leadingIconColor,
    this.onEndReached,
    this.isLoadingMore = false,
    this.hasMore = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: Color(0xFF242124),
              ),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;

              // На телефоне показываем большую часть первой карточки и край
              // следующей. На планшете/Web ограничиваем максимальную ширину,
              // чтобы карточки не разрастались вместе с окном.
              final cardWidth =
              (availableWidth * 0.82).clamp(240.0, 325.0).toDouble();

              // В отличие от горизонтального ListView, SingleChildScrollView
              // может взять реальную высоту Row. Поэтому высоту секции больше
              // не нужно угадывать: она автоматически равна высоте самой
              // высокой ProductCard и не создаёт RenderFlex overflow.
              return NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis == Axis.horizontal &&
                      hasMore &&
                      !isLoadingMore &&
                      notification.metrics.extentAfter < cardWidth * 0.8) {
                    onEndReached?.call();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int index = 0; index < products.length; index++) ...[
                        SizedBox(
                          width: cardWidth,
                          child: ProductCard(
                            product: products[index],
                          ),
                        ),
                        if (index != products.length - 1 || isLoadingMore)
                          const SizedBox(width: 6),
                      ],
                      if (isLoadingMore)
                        SizedBox(
                          width: cardWidth,
                          child: const ProductCardSkeleton(),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String title;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({
    required this.title,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFD1BC00) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? const Color(0xFFD1BC00) : const Color(0xFFE7E7E7),
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                color: Colors.orange.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF242124),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.22)
                      : const Color(0xFFF1F1F1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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
