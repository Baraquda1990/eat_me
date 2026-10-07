// lib/screens/deals_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/products_refresh_provider.dart';

import '../models/product.dart';
import '../models/tag.dart';
import '../services/api_service.dart';
import '../widgets/alarm_floating_button.dart';
import '../widgets/deal_product_card.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/app_error_state.dart';
import '../providers/favorite_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/company_provider.dart';
import '../providers/location_provider.dart';
import '../providers/auth_provider.dart';
import 'product_detail_screen.dart';
import 'login_screen.dart';
import 'cart_screen.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({Key? key}) : super(key: key);

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _headerKey = GlobalKey();

  List<Product> _products = [];
  List<Tag> _tags = [];

  final Map<String, int> _dealTagCounts = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreCatalog = true;

  Object? _loadError;
  Object? _catalogError;
  Object? _paginationError;

  int _allDealsCount = 0;
  int _catalogTotalCount = 0;
  int _untaggedCount = 0;
  int _catalogPage = 1;
  int _catalogGeneration = 0;

  String _searchQuery = '';
  String _sortType = 'none';
  String? _selectedTagSlug;
  final Set<String> _cartLoadingSlugs = {};
  final Set<String> _favoriteLoadingSlugs = {};

  Timer? _searchDebounce;
  int _lastRefreshVersion = 0;
  double _headerHeight = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateHeaderHeight();
    });
  }

  void _updateHeaderHeight() {
    final RenderBox? renderBox = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final newHeight = renderBox.size.height;
      if (_headerHeight != newHeight) {
        setState(() {
          _headerHeight = newHeight;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.extentAfter < 650) {
      _loadMore();
    }
  }

  String _getOrdering() {
    switch (_sortType) {
      case 'price_asc':
        return 'discount_price,-created,-id';
      case 'price_desc':
        return '-discount_price,-created,-id';
      default:
        return 'discount_price,-created,-id';
    }
  }

  Future<ProductPageResult> _fetchPage(
      int page, {
        bool includeMeta = false,
      }) {
    final selected = _selectedTagSlug;

    return ApiService.getProductsPage(
      page: page,
      search: _searchQuery.isEmpty ? null : _searchQuery,
      ordering: _getOrdering(),
      tagSlug: selected != null && selected != 'other' ? selected : null,
      untagged: selected == 'other',
      type: 'long',
      includeMeta: includeMeta,
    );
  }

  Future<void> _loadInitial({bool showInitialSkeleton = true}) async {
    final hadProducts = _products.isNotEmpty;
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
      final results = await Future.wait<dynamic>([
        ApiService.getTags(),
        _fetchPage(
          1,
          includeMeta:
          _searchQuery.isEmpty && _selectedTagSlug == null,
        ),
        favoriteProvider.loadFavorites(),
      ]);

      if (!mounted || generation != _catalogGeneration) return;

      final tags = results[0] as List<Tag>;
      final page = results[1] as ProductPageResult;

      setState(() {
        _tags = tags;
        _products = page.products
            .where((p) => p.type.toLowerCase() == 'long' && p.count > 0)
            .toList();

        _catalogPage = 1;
        _catalogTotalCount = page.count;
        _hasMoreCatalog = page.hasMore;
        _isLoadingMore = false;
        _catalogError = null;
        _paginationError = null;

        if (_searchQuery.isEmpty && _selectedTagSlug == null) {
          _allDealsCount = page.count;
          _untaggedCount = page.untaggedCount;
          _dealTagCounts
            ..clear()
            ..addAll(page.tagCounts);
        }

        _loadError = null;
        _catalogError = null;
        _paginationError = null;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateHeaderHeight();
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
        debugPrint('Deals refresh failed: $e');
      }
    }
  }

  Future<void> _reloadCatalog() async {
    final generation = ++_catalogGeneration;

    setState(() {
      _isLoadingMore = true;
      _catalogError = null;
      _paginationError = null;
    });

    try {
      final page = await _fetchPage(
        1,
        includeMeta:
        _searchQuery.isEmpty && _selectedTagSlug == null,
      );

      if (!mounted || generation != _catalogGeneration) return;

      setState(() {
        _products = page.products
            .where((p) => p.type.toLowerCase() == 'long' && p.count > 0)
            .toList();

        _catalogPage = 1;
        _catalogTotalCount = page.count;
        _hasMoreCatalog = page.hasMore;
        _isLoadingMore = false;

        if (_searchQuery.isEmpty && _selectedTagSlug == null) {
          _allDealsCount = page.count;
          _untaggedCount = page.untaggedCount;
          _dealTagCounts
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
      debugPrint('Deals catalogue reload failed: $e');
    }
  }

  Future<void> _loadMore() async {
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
      final page = await _fetchPage(nextPage);

      if (!mounted || generation != _catalogGeneration) return;

      final existingSlugs = _products.map((p) => p.slug).toSet();
      final additions = page.products.where((p) {
        return p.type.toLowerCase() == 'long' &&
            p.count > 0 &&
            !existingSlugs.contains(p.slug);
      }).toList();

      setState(() {
        _products.addAll(additions);
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
      debugPrint('Deals next page failed: $e');
    }
  }

  Future<void> _retryLoadMore() async {
    if (!mounted) return;
    setState(() => _paginationError = null);
    await _loadMore();
  }

  Future<void> _refresh() async {
    await _loadInitial(showInitialSkeleton: false);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
    });

    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      _reloadCatalog,
    );
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.toLowerCase();

    return _products.where((product) {
      if (query.isEmpty) return true;

      final name = product.name.toLowerCase();
      final description = (product.description ?? '').toLowerCase();
      final companyName = (product.company.name ?? '').toLowerCase();
      final address = product.company.address.toLowerCase();

      return name.contains(query) ||
          description.contains(query) ||
          companyName.contains(query) ||
          address.contains(query);
    }).toList();
  }

  List<Product> get _visibleProducts {
    if (_selectedTagSlug == null) return _filteredProducts;

    if (_selectedTagSlug == 'other') {
      return _filteredProducts.where((product) {
        return product.tag == null || product.tag!.isEmpty;
      }).toList();
    }

    return _filteredProducts.where((product) {
      return product.tag?.any((tag) => tag.slug == _selectedTagSlug) ?? false;
    }).toList();
  }

  Tag? get _selectedTag {
    if (_selectedTagSlug == null) return null;

    if (_selectedTagSlug == 'other') {
      return Tag(
        name: AppLocalizations.of(context)!.other,
        slug: 'other',
        productsCount: _untaggedCount,
        imageUrl: '',
      );
    }

    for (final tag in _tags) {
      if (tag.slug == _selectedTagSlug) return tag;
    }

    return null;
  }

  Map<Tag, List<Product>> get _groupedProducts {
    final filtered = _filteredProducts;
    final Map<Tag, List<Product>> grouped = {};

    for (final tag in _tags) {
      final tagProducts = filtered.where((product) {
        return product.tag?.any((t) => t.slug == tag.slug) ?? false;
      }).toList();

      if (tagProducts.isNotEmpty) {
        grouped[tag] = tagProducts;
      }
    }

    final withoutTags = filtered.where((product) {
      return product.tag == null || product.tag!.isEmpty;
    }).toList();

    if (withoutTags.isNotEmpty) {
      grouped[
      Tag(
        name: AppLocalizations.of(context)!.other,
        slug: 'other',
        productsCount: withoutTags.length,
        imageUrl: '',
      )
      ] = withoutTags;
    }

    return grouped;
  }

  int _countByTag(String tagSlug) {
    if (tagSlug == 'other') return _untaggedCount;
    return _dealTagCounts[tagSlug] ?? 0;
  }

  int _sectionTotalCount(Tag tag, List<Product> products) {
    if (tag.slug == 'other') {
      return _untaggedCount > 0 ? _untaggedCount : products.length;
    }
    return _dealTagCounts[tag.slug] ?? products.length;
  }

  void _selectTag(String? slug) {
    if (_selectedTagSlug == slug) return;

    setState(() {
      _selectedTagSlug = slug;
    });

    _reloadCatalog();
  }

  void _setSortType(String type) {
    Navigator.pop(context);

    setState(() {
      _sortType = type;
    });

    _reloadCatalog();
  }

  void _showSortMenu() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
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
                const SizedBox(height: 12),
                _sortItem(
                  icon: Icons.clear,
                  title: l10n.defaultSort,
                  selected: _sortType == 'none',
                  onTap: () => _setSortType('none'),
                ),
                _sortItem(
                  icon: Icons.arrow_upward,
                  title: l10n.cheaperFirst,
                  selected: _sortType == 'price_asc',
                  onTap: () => _setSortType('price_asc'),
                ),
                _sortItem(
                  icon: Icons.arrow_downward,
                  title: l10n.expensiveFirst,
                  selected: _sortType == 'price_desc',
                  onTap: () => _setSortType('price_desc'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sortItem({
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
      trailing: selected ? const Icon(Icons.check_circle, color: Color(0xFFD1BC00)) : null,
    );
  }

  Future<void> _toggleFavorite(Product product) async {
    if (_favoriteLoadingSlugs.contains(product.slug)) return;

    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    setState(() {
      _favoriteLoadingSlugs.add(product.slug);
    });

    try {
      final favoriteProvider = context.read<FavoriteProvider>();

      final wasFavorite = favoriteProvider.favoriteSlugs.contains(product.slug);
      final ok = wasFavorite
          ? await favoriteProvider.removeFavorite(product.slug)
          : await favoriteProvider.addFavorite(
        product.slug,
        product: product,
      );

      if (!ok || !mounted) return;

      // Success is already visible immediately through the heart icon.
      // Do not show a SnackBar here: repeated favorite toggles would queue
      // multiple notifications and make the UI feel noisy.
    } catch (e) {
      if (!mounted) return;

      if (e.toString().toLowerCase().contains('not authenticated')) {
        _showLoginRequiredDialog();
        return;
      }

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.favoritesError}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _favoriteLoadingSlugs.remove(product.slug);
        });
      }
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(AppLocalizations.of(dialogContext)!.authRequired),
          content: Text(
            AppLocalizations.of(dialogContext)!.loginToUseFavoritesCart,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(dialogContext)!.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );

                if (result == true && mounted) {
                  await context.read<AuthProvider>().checkLoginStatus();
                  await Future.wait<dynamic>([
                    context.read<FavoriteProvider>().loadFavorites(force: true),
                    context.read<CartProvider>().loadCart(
                      force: true,
                      silent: true,
                    ),
                  ]);
                  if (mounted) setState(() {});
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD1BC00),
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(dialogContext)!.login),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addToCart(Product product, {int quantity = 1}) async {
    if (_cartLoadingSlugs.contains(product.slug)) return;

    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    setState(() {
      _cartLoadingSlugs.add(product.slug);
    });

    try {
      final added = await context.read<CartProvider>().addProduct(
        product,
        quantity: quantity,
      );

      if (!mounted) return;

      if (!added) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.productAddFailed),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} ${AppLocalizations.of(context)!.addedToCartSuffix}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1300),
        ),
      );

      if (!mounted) return;

      // Quick-add from Deals should also continue directly to checkout/cart.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const CartScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().toLowerCase();

      if (message.contains('not authenticated') ||
          message.contains('401') ||
          message.contains('credentials')) {
        await authProvider.checkLoginStatus();
        _showLoginRequiredDialog();
        return;
      }

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.addToCartError}: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cartLoadingSlugs.remove(product.slug);
        });
      }
    }
  }

  void _showTagProducts(Tag tag, List<Product> products) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.86,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                itemCount: products.length + 1,
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          tag.name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_sectionTotalCount(tag, products)} ${l10n.offers}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }

                  final product = products[index - 1];
                  return DealProductCard(
                    product: product,
                    width: double.infinity,
                    onAddToCart: (quantity) => _addToCart(
                      product,
                      quantity: quantity,
                    ),
                    onToggleFavorite: () => _toggleFavorite(product),
                    isAddingToCart: _cartLoadingSlugs.contains(product.slug),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // РџРѕР»СѓС‡Р°РµРј Р±РµР·РѕРїР°СЃРЅС‹Р№ РѕС‚СЃС‚СѓРї СЃРЅРёР·Сѓ (РґР»СЏ СЃРёСЃС‚РµРјРЅРѕР№ РїР°РЅРµР»Рё Android)
    final safeBottom = MediaQuery.of(context).padding.bottom;

    final refreshVersion = context.watch<ProductsRefreshProvider>().version;

    if (refreshVersion != _lastRefreshVersion) {
      _lastRefreshVersion = refreshVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refresh();
        }
      });
    }

    return Consumer<FavoriteProvider>(
      builder: (context, favorites, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              _isLoading
                  ? const DealsProductsSkeleton()
                  : _loadError != null
                  ? AppErrorState(
                error: _loadError,
                onRetry: () => _loadInitial(),
              )
                  : Column(
                children: [
                  // Р¤РёРєСЃРёСЂРѕРІР°РЅРЅР°СЏ РІРµСЂС…РЅСЏСЏ С‡Р°СЃС‚СЊ: Р·Р°РіРѕР»РѕРІРѕРє, РїРѕРёСЃРє Рё С‚РµРіРё.
                  // РћРЅР° РЅР°С…РѕРґРёС‚СЃСЏ РІРЅРµ CustomScrollView, РїРѕСЌС‚РѕРјСѓ РЅРµ СѓРµР·Р¶Р°РµС‚ РїСЂРё СЃРєСЂРѕР»Р»Рµ С‚РѕРІР°СЂРѕРІ.
                  Material(
                    color: Colors.white,
                    elevation: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        key: _headerKey,
                        color: Colors.white,
                        child: _buildHeader(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          if (_catalogError != null)
                            SliverToBoxAdapter(
                              child: AppInlineError(
                                error: _catalogError,
                                onRetry: _reloadCatalog,
                              ),
                            ),
                          if (_visibleProducts.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Text(
                                  AppLocalizations.of(context)!.noDeals,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                          else if (_selectedTagSlug != null)
                            SliverList(
                              delegate: SliverChildListDelegate(
                                [
                                  _SelectedTagHeader(
                                    tagName: _selectedTag?.name ?? AppLocalizations.of(context)!.category,
                                    count: _catalogTotalCount,
                                  ),
                                  ..._visibleProducts.map((product) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: DealProductCard(
                                        product: product,
                                        width: double.infinity,
                                        onAddToCart: (quantity) => _addToCart(
                                          product,
                                          quantity: quantity,
                                        ),
                                        onToggleFavorite: () => _toggleFavorite(product),
                                        isAddingToCart: _cartLoadingSlugs.contains(product.slug),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            )
                          else
                            SliverList(
                              delegate: SliverChildListDelegate(
                                _groupedProducts.entries.map<Widget>((entry) {
                                  return _DealsSection(
                                    tag: entry.key,
                                    products: entry.value,
                                    totalCount: _sectionTotalCount(
                                      entry.key,
                                      entry.value,
                                    ),
                                    onSeeAll: () => _selectTag(entry.key.slug),
                                    onEndReached: _loadMore,
                                    hasMore: _hasMoreCatalog,
                                    isLoadingMore: _isLoadingMore,
                                    onAddToCart: (product, quantity) =>
                                        _addToCart(product, quantity: quantity),
                                    onToggleFavorite: _toggleFavorite,
                                    isAddingToCart: (product) =>
                                        _cartLoadingSlugs.contains(product.slug),
                                  );
                                }).toList(),
                              ),
                            ),
                          if (_paginationError != null)
                            SliverToBoxAdapter(
                              child: AppInlineError(
                                error: _paginationError,
                                loadMore: true,
                                onRetry: _retryLoadMore,
                              ),
                            )
                          else if (_isLoadingMore &&
                              _selectedTagSlug != null)
                            const SliverToBoxAdapter(
                              child: PaginationLoadingSkeleton(),
                            ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 72 + safeBottom,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 16,
                // Р”РѕР±Р°РІР»СЏРµРј safeBottom Рє РѕС‚СЃС‚СѓРїСѓ РґР»СЏ РєРЅРѕРїРєРё Р±СѓРґРёР»СЊРЅРёРєР°
                bottom: 16 + safeBottom,
                child: AlarmFloatingButton(tags: _tags),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final activeTags = _tags.where((tag) => _countByTag(tag.slug) > 0).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: l10n.searchDeals,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      icon: const Icon(Icons.close),
                    )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
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
                    color: _sortType == 'none'
                        ? const Color(0xFFF3F3F3)
                        : const Color(0xFFD1BC00),
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: _sortType == 'none'
                        ? const Color(0xFF242124)
                        : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: activeTags.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                if (index == 0) {
                  return _TagTile(
                    title: l10n.all,
                    count: _allDealsCount,
                    selected: _selectedTagSlug == null,
                    imageUrl: '',
                    icon: Icons.local_offer_rounded,
                    onTap: () => _selectTag(null),
                  );
                }
                final tag = activeTags[index - 1];
                return _TagTile(
                  title: tag.name,
                  count: _countByTag(tag.slug),
                  selected: _selectedTagSlug == tag.slug,
                  imageUrl: tag.imageUrl,
                  onTap: () => _selectTag(tag.slug),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

class _SelectedTagHeader extends StatelessWidget {
  final String tagName;
  final int count;

  const _SelectedTagHeader({
    required this.tagName,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tagName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: Color(0xFF242424),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$count ${l10n.offers}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DealsSection extends StatelessWidget {
  final Tag tag;
  final List<Product> products;
  final int totalCount;
  final VoidCallback onSeeAll;
  final Future<void> Function()? onEndReached;
  final bool hasMore;
  final bool isLoadingMore;
  final Future<void> Function(Product product, int quantity) onAddToCart;
  final Future<void> Function(Product product) onToggleFavorite;
  final bool Function(Product product) isAddingToCart;

  const _DealsSection({
    required this.tag,
    required this.products,
    required this.totalCount,
    required this.onSeeAll,
    this.onEndReached,
    this.hasMore = false,
    this.isLoadingMore = false,
    required this.onAddToCart,
    required this.onToggleFavorite,
    required this.isAddingToCart,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tag.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF242424),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onSeeAll,
                  child: Text(
                    l10n.all,
                    style: const TextStyle(
                      color: Color(0xFFD1BC00),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$totalCount ${l10n.offers}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.sizeOf(context).width;
              final cardWidth = (screenWidth * 0.74).clamp(260.0, 310.0);

              return NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis == Axis.horizontal &&
                      hasMore &&
                      !isLoadingMore &&
                      notification.metrics.extentAfter < cardWidth * 0.7) {
                    onEndReached?.call();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int index = 0; index < products.length; index++) ...[
                        if (index > 0) const SizedBox(width: 14),
                        DealProductCard(
                          product: products[index],
                          width: cardWidth,
                          onAddToCart: (quantity) => onAddToCart(
                            products[index],
                            quantity,
                          ),
                          onToggleFavorite: () =>
                              onToggleFavorite(products[index]),
                          isAddingToCart: isAddingToCart(products[index]),
                        ),
                      ],
                      if (isLoadingMore) ...[
                        if (products.isNotEmpty) const SizedBox(width: 14),
                        DealProductCardSkeleton(width: cardWidth),
                      ],
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

class _TagTile extends StatelessWidget {
  final String title;
  final int count;
  final bool selected;
  final String imageUrl;
  final IconData? icon;
  final VoidCallback onTap;

  const _TagTile({
    required this.title,
    required this.count,
    required this.selected,
    required this.imageUrl,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              child: Center(
                child: imageUrl.isNotEmpty
                    ? Image.network(
                  imageUrl,
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const ImageLoadingShimmer(
                      width: 32,
                      height: 32,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    );
                  },
                  errorBuilder: (_, __, ___) => Icon(
                    icon ?? Icons.local_offer_rounded,
                    color: selected ? const Color(0xFFD1BC00) : Colors.grey.shade500,
                    size: 28,
                  ),
                )
                    : icon != null
                    ? SvgPicture.asset(
                  'assets/icons/all_filters.svg',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  placeholderBuilder: (_) => Icon(
                    Icons.grid_view_rounded,
                    color: selected ? const Color(0xFFD1BC00) : Colors.grey.shade500,
                    size: 28,
                  ),
                )
                    : Icon(
                  icon ?? Icons.local_offer_rounded,
                  color: selected ? const Color(0xFFD1BC00) : Colors.grey.shade500,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w800,
                color: selected ? const Color(0xFFD1BC00) : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
