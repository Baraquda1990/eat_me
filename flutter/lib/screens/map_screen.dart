// lib/screens/map_screen.dart

import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

import '../models/map_company.dart';
import '../models/product.dart';
import '../models/tag.dart';
import '../providers/favorite_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/api_service.dart';
import '../utils/app_feedback.dart';
import '../screens/product_detail_screen.dart';
import '../widgets/product_card.dart';

enum MapSortType {
  rating,
  distance,
  price,
}

class MapScreen extends StatefulWidget {
  final String? selectedCompanySlug;

  const MapScreen({Key? key, this.selectedCompanySlug}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final PageController _productsCarouselController = PageController(
    viewportFraction: 0.68,
  );

  static const LatLng _defaultCenter = LatLng(40.1772, 44.5035);
  static const double _nearbyKm = 3.0;

  static const List<double> _radiusOptionsKm = [
    0.1,
    0.2,
    0.5,
    1,
    2,
    5,
    10,
    20,
    50,
    100,
    200,
  ];

  List<MapCompany> _companies = [];
  List<Product> _allProducts = [];
  Map<String, List<Product>> _productsByCompany = {};

  MapCompany? _selectedCompany;

  LatLng? _userLocation;

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  final Set<String> _selectedTagSlugs = <String>{};
  bool _onlyNearby = false;
  bool _onlyOpenNow = false;
  bool _filtersExpanded = false;
  bool _bottomFilterMenuOpen = false;
  bool _bottomTagsOpen = false;
  bool _showFilteredProductsCarousel = false;

  double _radiusKm = 10.0;
  int _radiusOptionIndex = 6;
  bool _useRadiusFilter = false;

  double _currentZoom = 13;

  MapSortType? _sortType;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _productsCarouselController.dispose();
    super.dispose();
  }

  Future<void> _loadMapData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // GPS must never block the first map render.
      Future.microtask(() => _loadUserLocation());

      // Load independent backend data in parallel.
      final companiesFuture = ApiService.getMapCompanies();
      final productsFuture = _loadAllProductsForMap();
      final favoritesFuture =
      context.read<FavoriteProvider>().loadFavorites();

      final companies = await companiesFuture;
      final products = await productsFuture;
      await favoritesFuture;

      if (!mounted) return;

      setState(() {
        _companies = companies.where(_isValidCompany).toList();
        _allProducts = products;
        _productsByCompany = _groupProductsByCompany(products);
        _isLoading = false;
      });

      _openSelectedCompanyIfNeeded(widget.selectedCompanySlug);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserLocation({
    bool requestIfDenied = false,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied && requestIfDenied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // Cached location makes first positioning fast on Android.
      if (!kIsWeb) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null && mounted) {
            setState(() {
              _userLocation =
                  LatLng(lastKnown.latitude, lastKnown.longitude);
            });
          }
        } catch (_) {
          // Cached position is optional.
        }
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );

        if (!mounted) return;

        setState(() {
          _userLocation = LatLng(
            position.latitude,
            position.longitude,
          );
        });
      } catch (_) {
        // Keep last-known location or the default Yerevan center.
      }
    } catch (_) {
      // Location failure must not make the map fail.
    }
  }

  Future<List<Product>> _loadAllProductsForMap() async {
    final List<Product> result = [];

    for (int page = 1; page <= 30; page++) {
      final products = await ApiService.getProducts(
        page: page,
        type: 'hot',
      );
      result.addAll(products);

      if (products.length < ApiService.pageSize) break;
    }

    return result;
  }

  Map<String, List<Product>> _groupProductsByCompany(List<Product> products) {
    final Map<String, List<Product>> grouped = {};

    for (final product in products) {
      final slug = product.company.slug;
      grouped.putIfAbsent(slug, () => []);
      grouped[slug]!.add(product);
    }

    return grouped;
  }

  List<Tag> get _alarmTags {
    final Map<String, Tag> result = {};

    for (final product in _allProducts) {
      final tags = product.tag ?? [];
      for (final tag in tags) {
        if (tag.slug.isNotEmpty) {
          result[tag.slug] = tag;
        }
      }
    }

    return result.values.toList();
  }

  List<Tag> get _hotTags {
    final Map<String, Tag> result = {};

    for (final product in _allProducts) {
      if (product.type.toLowerCase() != 'hot') continue;

      final tags = product.tag ?? [];
      for (final tag in tags) {
        if (tag.slug.isNotEmpty) {
          result[tag.slug] = tag;
        }
      }
    }

    final tags = result.values.toList();
    tags.sort((a, b) => b.productsCount.compareTo(a.productsCount));
    return tags;
  }

  bool _isValidCompany(MapCompany company) {
    return company.latitude.abs() <= 90 && company.longitude.abs() <= 180;
  }

  List<MapCompany> get _visibleCompanies {
    List<MapCompany> filtered = _companies.where((company) {
      final products = _productsForCompany(company);

      if (products.isEmpty) return false;

      final query = _searchQuery.trim().toLowerCase();

      if (query.isNotEmpty) {
        final matchCompany = company.name.toLowerCase().contains(query) ||
            company.address.toLowerCase().contains(query);

        final matchProducts = products.any(
              (p) =>
          p.name.toLowerCase().contains(query) ||
              (p.description ?? '').toLowerCase().contains(query),
        );

        if (!matchCompany && !matchProducts) return false;
      }

      if (_onlyNearby) {
        final distance = _distanceKm(company);
        if (distance == null || distance > _nearbyKm) return false;
      }

      if (_useRadiusFilter) {
        final distance = _distanceKm(company);
        if (distance == null || distance > _radiusKm) return false;
      }

      if (_onlyOpenNow && !_isOpenNow(company)) return false;

      return true;
    }).toList();

    // Применяем сортировку
    if (_sortType != null) {
      switch (_sortType!) {
        case MapSortType.rating:
          filtered.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case MapSortType.distance:
          filtered.sort(
                (a, b) =>
                (_distanceKm(a) ?? 999999)
                    .compareTo(_distanceKm(b) ?? 999999),
          );
          break;
        case MapSortType.price:
          filtered.sort(
                (a, b) => _minPrice(a).compareTo(_minPrice(b)),
          );
          break;
      }
    }

    return filtered;
  }

  double _minPrice(MapCompany company) {
    final products = _productsForCompany(company);
    if (products.isEmpty) return double.infinity;

    double minPrice = products.first.price;
    for (final product in products) {
      final price = product.discountPrice > 0 && product.discountPrice < product.price
          ? product.discountPrice
          : product.price;
      if (price < minPrice) {
        minPrice = price;
      }
    }
    return minPrice;
  }

  List<Product> _productsForCompany(MapCompany company) {
    final products = _productsByCompany[company.slug] ?? [];

    return products.where((product) {
      if (product.type.toLowerCase() != 'hot') return false;

      if (_selectedTagSlugs.isNotEmpty) {
        final tags = product.tag ?? [];
        final hasTag = tags.any(
              (tag) => _selectedTagSlugs.contains(tag.slug),
        );
        if (!hasTag) return false;
      }

      return true;
    }).toList();
  }

  double? _distanceKm(MapCompany company) {
    if (_userLocation == null) return null;

    final meters = Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      company.latitude,
      company.longitude,
    );

    return meters / 1000;
  }

  double _distanceBetweenCompanies(MapCompany a, MapCompany b) {
    final meters = Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );

    return meters / 1000;
  }

  String _distanceText(MapCompany company, AppLocalizations l10n) {
    final km = _distanceKm(company);
    if (km == null) return '';

    if (km < 1) return '${(km * 1000).round()} ${l10n.m}';
    if (km >= 10) return '${km.round()} ${l10n.km}';
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} ${l10n.km}';
  }

  bool _isOpenNow(MapCompany company) {
    try {
      final now = TimeOfDay.now();
      final open = _parseTime(company.openTime);
      final close = _parseTime(company.closeTime);

      if (open == null || close == null) return true;

      final nowMinutes = now.hour * 60 + now.minute;
      final openMinutes = open.hour * 60 + open.minute;
      final closeMinutes = close.hour * 60 + close.minute;

      if (closeMinutes < openMinutes) {
        return nowMinutes >= openMinutes || nowMinutes <= closeMinutes;
      }

      return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
    } catch (_) {
      return true;
    }
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.length < 5) return null;

    final hour = int.tryParse(value.substring(0, 2));
    final minute = int.tryParse(value.substring(3, 5));

    if (hour == null || minute == null) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _moveToUser() async {
    const actionKey = 'map.move-to-user';
    if (!AppActionGuard.tryLock(actionKey)) return;

    try {
      if (_userLocation == null) {
        await _loadUserLocation(requestIfDenied: true);
      }

      if (!mounted) return;

      if (_userLocation == null) {
        final l10n = AppLocalizations.of(context)!;
        AppFeedback.warning(
          context,
          l10n.allowLocationAccess,
          key: 'map.location-access',
        );
        return;
      }

      _mapController.move(_userLocation!, 15);
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  void _resetMapFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedTagSlugs.clear();
      _onlyNearby = false;
      _onlyOpenNow = false;
      _useRadiusFilter = false;
      _radiusKm = 10.0;
      _radiusOptionIndex = 6;
      _selectedCompany = null;
      _bottomTagsOpen = false;
      _showFilteredProductsCarousel = false;
      _sortType = null;
    });
  }

  String _radiusText(double km, AppLocalizations l10n) {
    if (km < 1) return '${(km * 1000).round()} ${l10n.m}';
    if (km >= 10) return '${km.round()} ${l10n.km}';
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} ${l10n.km}';
  }

  double _clusterDistanceKm() {
    if (_currentZoom >= 16) return 0;
    if (_currentZoom >= 15) return 0.08;
    if (_currentZoom >= 14) return 0.16;
    if (_currentZoom >= 13) return 0.35;
    if (_currentZoom >= 12) return 0.75;
    if (_currentZoom >= 11) return 1.5;
    if (_currentZoom >= 10) return 3.0;
    if (_currentZoom >= 9) return 6.0;
    return 12.0;
  }

  List<_CompanyCluster> _buildClusters(List<MapCompany> companies) {
    final threshold = _clusterDistanceKm();
    if (threshold <= 0) {
      return companies.map((c) => _CompanyCluster.single(c)).toList();
    }

    final List<_CompanyCluster> clusters = [];

    for (final company in companies) {
      _CompanyCluster? found;

      for (final cluster in clusters) {
        final distance = Geolocator.distanceBetween(
          company.latitude,
          company.longitude,
          cluster.center.latitude,
          cluster.center.longitude,
        ) / 1000;

        if (distance <= threshold) {
          found = cluster;
          break;
        }
      }

      if (found == null) {
        clusters.add(_CompanyCluster([company]));
      } else {
        found.add(company);
      }
    }

    return clusters;
  }

  void _selectCompanyOnMap(MapCompany company) {
    final products = _productsForCompany(company);

    if (products.isEmpty) return;

    setState(() {
      _selectedCompany = company;
      _showFilteredProductsCarousel = false;
      _bottomFilterMenuOpen = false;
      _bottomTagsOpen = false;
    });

    _mapController.move(
      LatLng(company.latitude, company.longitude),
      _currentZoom < 15 ? 15 : _currentZoom,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_productsCarouselController.hasClients) return;
      _productsCarouselController.jumpToPage(0);
    });
  }

  void _clearSelectedCompany() {
    if (_selectedCompany == null) return;

    setState(() {
      _selectedCompany = null;
    });
  }

  void _openCluster(_CompanyCluster cluster) {
    if (cluster.companies.length <= 1) {
      _selectCompanyOnMap(cluster.companies.first);
      return;
    }

    if (_currentZoom < 15.5) {
      _mapController.move(cluster.center, (_currentZoom + 1.6).clamp(3, 18));
      return;
    }

    _showClusterCompaniesSheet(cluster);
  }

  void _showClusterCompaniesSheet(_CompanyCluster cluster) {
    final l10n = AppLocalizations.of(context)!;
    final companies = [...cluster.companies]
      ..sort((a, b) => a.name.compareTo(b.name));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.48,
          minChildSize: 0.30,
          maxChildSize: 0.86,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF6F6F6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '${companies.length} ${l10n.shopsNearby}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...companies.map((company) {
                    final productsCount = _productsForCompany(company).length;
                    final distance = _distanceText(company, l10n);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            Navigator.pop(context);
                            _mapController.move(
                              LatLng(company.latitude, company.longitude),
                              16,
                            );
                            Future.delayed(const Duration(milliseconds: 220), () {
                              if (mounted) _selectCompanyOnMap(company);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                _CompanyLogo(imageUrl: company.imageUrl, size: 52),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        company.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        company.address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Row(
                                        children: [
                                          _InfoChip(
                                            icon: Icons.inventory_2_outlined,
                                            text: '$productsCount ${l10n.products}',
                                          ),
                                          if (distance.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            _InfoChip(
                                              icon: Icons.near_me_outlined,
                                              text: distance,
                                              color: const Color(0xFFD1BC00),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Marker> _buildMarkers(List<MapCompany> visibleCompanies) {
    final clusters = _buildClusters(visibleCompanies);

    final markers = <Marker>[];

    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 54,
          height: 54,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.my_location,
                color: Colors.blue,
                size: 28,
              ),
            ),
          ),
        ),
      );
    }

    for (final cluster in clusters) {
      if (cluster.companies.length == 1) {
        final company = cluster.companies.first;
        final productsCount = _productsForCompany(company).length;

        markers.add(
          Marker(
            point: LatLng(company.latitude, company.longitude),
            width: 62,
            height: 58,
            child: GestureDetector(
              onTap: () => _selectCompanyOnMap(company),
              child: _CompanyMarker(
                imageUrl: company.imageUrl,
                count: productsCount,
                isOpen: _isOpenNow(company),
              ),
            ),
          ),
        );
      } else {
        markers.add(
          Marker(
            point: cluster.center,
            width: 84,
            height: 84,
            child: GestureDetector(
              onTap: () => _openCluster(cluster),
              child: _ClusterMarker(
                companiesCount: cluster.companies.length,
                productsCount: cluster.productsCount(
                      (company) => _productsForCompany(company).length,
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  void _showRadiusSearchSheet() {
    final l10n = AppLocalizations.of(context)!;

    if (_userLocation == null) {
      AppFeedback.warning(
        context,
        l10n.allowLocationAccess,
        key: 'map.location-access',
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.selectRadius,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.showShopsInRadius,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F4),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.travel_explore, color: Color(0xFFD1BC00)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.radius,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Text(
                                _radiusText(_radiusKm, l10n),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFD1BC00),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _radiusOptionIndex.toDouble(),
                            min: 0,
                            max: (_radiusOptionsKm.length - 1).toDouble(),
                            divisions: _radiusOptionsKm.length - 1,
                            label: _radiusText(_radiusKm, l10n),
                            activeColor: const Color(0xFFD1BC00),
                            inactiveColor: Colors.orange.withOpacity(0.20),
                            onChanged: (value) {
                              final index = value.round().clamp(0, _radiusOptionsKm.length - 1);
                              final radius = _radiusOptionsKm[index];

                              setSheetState(() {
                                _radiusOptionIndex = index;
                                _radiusKm = radius;
                              });

                              setState(() {
                                _radiusOptionIndex = index;
                                _radiusKm = radius;
                                _useRadiusFilter = true;
                                _onlyNearby = false;
                                _showFilteredProductsCarousel = false;
                              });
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '100 ${l10n.m}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '200 ${l10n.km}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: _radiusOptionsKm.map((radius) {
                              final selected = radius == _radiusKm;

                              return GestureDetector(
                                onTap: () {
                                  final index = _radiusOptionsKm.indexOf(radius);

                                  setSheetState(() {
                                    _radiusOptionIndex = index;
                                    _radiusKm = radius;
                                  });

                                  setState(() {
                                    _radiusOptionIndex = index;
                                    _radiusKm = radius;
                                    _useRadiusFilter = true;
                                    _onlyNearby = false;
                                    _showFilteredProductsCarousel = false;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: selected ? const Color(0xFFD1BC00) : Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: selected ? const Color(0xFFD1BC00) : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    _radiusText(radius, l10n),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: selected ? Colors.white : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _useRadiusFilter = true;
                            _onlyNearby = false;
                            _showFilteredProductsCarousel = false;
                          });

                          _mapController.move(_userLocation!, 12);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF242424),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          '${l10n.showInRadius} ${_radiusText(_radiusKm, l10n)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() => _useRadiusFilter = false);
                        Navigator.pop(context);
                      },
                      child: Text(
                        l10n.resetRadius,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSortSheet() {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Сортировка',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 24),
                ...MapSortType.values.map((type) {
                  final isSelected = _sortType == type;
                  final icon = type == MapSortType.rating
                      ? Icons.star_rounded
                      : type == MapSortType.distance
                      ? Icons.near_me_rounded
                      : Icons.attach_money_rounded;
                  final label = type == MapSortType.rating
                      ? l10n.byRating
                      : type == MapSortType.distance
                      ? 'По дистанции'
                      : 'По цене';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: isSelected ? const Color(0xFFD1BC00).withOpacity(0.10) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            if (_sortType == type) {
                              _sortType = null;
                            } else {
                              _sortType = type;
                            }
                            _showFilteredProductsCarousel = false;
                          });
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                color: isSelected ? const Color(0xFFD1BC00) : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? const Color(0xFFD1BC00) : Colors.black87,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFFD1BC00),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _sortType = null;
                    });
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Сбросить сортировку',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSelectedCompanyIfNeeded([String? slug]) {
    final targetSlug = slug;
    if (targetSlug == null || targetSlug.isEmpty) return;

    MapCompany? company;
    for (final c in _companies) {
      if (c.slug == targetSlug) {
        company = c;
        break;
      }
    }

    if (company == null) return;

    _mapController.move(LatLng(company.latitude, company.longitude), 16);

    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _selectCompanyOnMap(company!);
    });
  }

  Future<void> _openUrl(String url) async {
    final text = url.trim();
    if (text.isEmpty) return;

    final uri = Uri.tryParse(text);
    if (uri == null) return;

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }


  bool get _hasActiveMapFilters {
    return _searchQuery.trim().isNotEmpty ||
        _selectedTagSlugs.isNotEmpty ||
        _useRadiusFilter ||
        _onlyNearby ||
        _sortType != null;
  }

  bool get _hasBottomCarousel {
    return (_selectedCompany != null && _productsForCompany(_selectedCompany!).isNotEmpty) ||
        (_showFilteredProductsCarousel && _filteredProductsForCarousel.isNotEmpty);
  }

  List<Product> get _filteredProductsForCarousel {
    final List<Product> result = [];

    for (final company in _visibleCompanies) {
      result.addAll(_productsForCompany(company));
    }

    return result;
  }

  MapCompany? _companyForProduct(Product product) {
    final slug = product.company.slug;
    for (final company in _companies) {
      if (company.slug == slug) return company;
    }
    return null;
  }

  void _openFilteredProductsCarousel() {
    if (_filteredProductsForCarousel.isEmpty) return;

    setState(() {
      _selectedCompany = null;
      _bottomFilterMenuOpen = false;
      _bottomTagsOpen = false;
      _showFilteredProductsCarousel = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_productsCarouselController.hasClients) return;
      _productsCarouselController.jumpToPage(0);
    });
  }

  void _hideProductsPanel() {
    setState(() {
      _selectedCompany = null;
      _showFilteredProductsCarousel = false;
    });
  }

  void _closeFilterMenu() {
    final shouldShowFilteredProducts = _hasActiveMapFilters && _filteredProductsForCarousel.isNotEmpty;

    setState(() {
      _bottomFilterMenuOpen = false;
      _bottomTagsOpen = false;
      _showFilteredProductsCarousel = shouldShowFilteredProducts;
      if (shouldShowFilteredProducts) {
        _selectedCompany = null;
      }
    });

    if (shouldShowFilteredProducts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_productsCarouselController.hasClients) return;
        _productsCarouselController.jumpToPage(0);
      });
    }
  }

  void _showCompanyProductsSheet(MapCompany company) {
    final l10n = AppLocalizations.of(context)!;
    final products = _productsForCompany(company);
    final allCompanyProducts = _productsByCompany[company.slug] ?? [];
    final distance = _distanceText(company, l10n);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.38,
          maxChildSize: 0.93,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF4F4F4),
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _CompanyLogo(imageUrl: company.imageUrl, size: 64),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                company.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                company.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (distance.isNotEmpty)
                                    _InfoChip(
                                      icon: Icons.near_me_outlined,
                                      text: distance,
                                      color: const Color(0xFFD1BC00),
                                    ),
                                  _InfoChip(
                                    icon: _isOpenNow(company)
                                        ? Icons.check_circle_outline
                                        : Icons.schedule_outlined,
                                    text: _isOpenNow(company) ? l10n.open : l10n.closed,
                                    color: _isOpenNow(company) ? Colors.green : Colors.redAccent,
                                  ),
                                  _InfoChip(
                                    icon: Icons.inventory_2_outlined,
                                    text: '${allCompanyProducts.length} ${l10n.products}',
                                  ),
                                ],
                              ),
                              if (company.instagram.isNotEmpty || company.facebook.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (company.instagram.isNotEmpty)
                                      _SocialButton(
                                        icon: Icons.camera_alt_outlined,
                                        label: 'Instagram',
                                        onTap: () => _openUrl(company.instagram),
                                      ),
                                    if (company.instagram.isNotEmpty && company.facebook.isNotEmpty)
                                      const SizedBox(width: 8),
                                    if (company.facebook.isNotEmpty)
                                      _SocialButton(
                                        icon: Icons.facebook,
                                        label: 'Facebook',
                                        onTap: () => _openUrl(company.facebook),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (company.description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      company.description,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    _selectedTagSlugs.isEmpty
                        ? l10n.hotOffers
                        : l10n.offersByTag,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  if (products.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(l10n.noProductsForFilter),
                      ),
                    )
                  else
                    ...products.map(
                          (product) => ProductCard(
                        product: product,
                        showCompanyLogo: false,
                        onFavoriteChanged: _loadMapData,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final navigation = context.watch<NavigationProvider>();
    final targetSlug = navigation.mapCompanySlug;

    if (targetSlug != null && targetSlug.isNotEmpty && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final slug = context.read<NavigationProvider>().consumeMapCompanySlug();

        if (slug != null && slug.isNotEmpty) {
          _openSelectedCompanyIfNeeded(slug);
        }
      });
    }

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${l10n.mapLoadError}:\n$_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMapData,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    final visibleCompanies = _visibleCompanies;
    final visibleProductsCount = visibleCompanies.fold<int>(
      0,
          (sum, company) => sum + _productsForCompany(company).length,
    );

    final mediaPadding = MediaQuery.of(context).padding;
    final safeTop = mediaPadding.top;
    final safeBottom = mediaPadding.bottom;
    final hasBottomCarousel = _hasBottomCarousel;
    final productsPanelBaseHeight = _mapProductsPanelBaseHeight(
      MediaQuery.sizeOf(context).width,
      _productsCarouselController.viewportFraction,
    );

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation ?? _defaultCenter,
            initialZoom: 13,
            onTap: (_, __) {
              if (_selectedCompany != null ||
                  _showFilteredProductsCarousel ||
                  _bottomFilterMenuOpen) {
                setState(() {
                  _selectedCompany = null;
                  _showFilteredProductsCarousel = false;
                  _bottomFilterMenuOpen = false;
                  _bottomTagsOpen = false;
                });
              }
            },
            onPositionChanged: (position, hasGesture) {
              final zoom = position.zoom;
              if (zoom != null && (zoom - _currentZoom).abs() >= 0.15) {
                setState(() => _currentZoom = zoom);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'am.apsosa.app',
              tileProvider: NetworkTileProvider(),
            ),
            if (_userLocation != null && _useRadiusFilter)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _userLocation!,
                    radius: 250000,
                    useRadiusInMeter: true,
                    color: Colors.black.withOpacity(0.22),
                    borderColor: Colors.transparent,
                    borderStrokeWidth: 0,
                  ),
                  CircleMarker(
                    point: _userLocation!,
                    radius: _radiusKm * 1000,
                    useRadiusInMeter: true,
                    color: Colors.white.withOpacity(0.50),
                    borderColor: Colors.orange.withOpacity(0.85),
                    borderStrokeWidth: 2.5,
                  ),
                ],
              ),
            MarkerLayer(markers: _buildMarkers(visibleCompanies)),
          ],
        ),
        Positioned(
          // Keep the search/filter panel below the status bar and display cutout.
          // The map itself still renders edge-to-edge behind the system UI.
          top: safeTop + 8,
          left: 16,
          right: 16,
          child: _MapTopPanel(
            searchController: _searchController,
            tags: _hotTags,
            selectedTagSlug: _selectedTagSlugs.isEmpty
                ? null
                : _selectedTagSlugs.first,
            onTagChanged: (slug) {
              setState(() {
                _selectedTagSlugs
                  ..clear()
                  ..addAll(slug == null ? const <String>[] : <String>[slug]);
                _selectedCompany = null;
                _showFilteredProductsCarousel = false;
              });
            },
            onlyNearby: _onlyNearby,
            onlyOpenNow: _onlyOpenNow,
            companiesCount: visibleCompanies.length,
            productsCount: visibleProductsCount,
            filtersExpanded: _filtersExpanded,
            onToggleFilters: () => setState(() => _filtersExpanded = !_filtersExpanded),
            onSearchChanged: (value) {
              setState(() {
                _searchQuery = value;
                _selectedCompany = null;
                _showFilteredProductsCarousel = false;
              });
            },
            onClearSearch: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _showFilteredProductsCarousel = false;
              });
            },
            onNearbyChanged: () {
              setState(() {
                _onlyNearby = !_onlyNearby;
                _showFilteredProductsCarousel = false;
              });
            },
            onOpenNowChanged: () {
              setState(() {
                _onlyOpenNow = !_onlyOpenNow;
                _showFilteredProductsCarousel = false;
              });
            },
          ),
        ),
        if (_selectedCompany != null &&
            _productsForCompany(_selectedCompany!).isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Builder(
              builder: (context) {
                final products = _productsForCompany(_selectedCompany!);

                void openProduct(Product product) {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false,
                      barrierColor: Colors.black.withOpacity(0.50),
                      transitionDuration: const Duration(milliseconds: 320),
                      reverseTransitionDuration: const Duration(milliseconds: 260),
                      pageBuilder: (_, animation, __) {
                        return FadeTransition(
                          opacity: animation,
                          child: ProductDetailScreen(product: product),
                        );
                      },
                    ),
                  );
                }

                return _MapProductsPullPanel(
                  products: products,
                  controller: _productsCarouselController,
                  safeBottom: safeBottom,
                  distanceBuilder: (_) => _distanceText(_selectedCompany!, l10n),
                  onProductTap: openProduct,
                  onClose: _hideProductsPanel,
                );
              },
            ),
          )
        else if (_showFilteredProductsCarousel && _filteredProductsForCarousel.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Builder(
              builder: (context) {
                final products = _filteredProductsForCarousel;

                void openProduct(Product product) {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false,
                      barrierColor: Colors.black.withOpacity(0.50),
                      transitionDuration: const Duration(milliseconds: 320),
                      reverseTransitionDuration: const Duration(milliseconds: 260),
                      pageBuilder: (_, animation, __) {
                        return FadeTransition(
                          opacity: animation,
                          child: ProductDetailScreen(product: product),
                        );
                      },
                    ),
                  );
                }

                return _MapProductsPullPanel(
                  products: products,
                  controller: _productsCarouselController,
                  safeBottom: safeBottom,
                  distanceBuilder: (product) {
                    final company = _companyForProduct(product);
                    return company == null ? '' : _distanceText(company, l10n);
                  },
                  onProductTap: openProduct,
                  onClose: _hideProductsPanel,
                );
              },
            ),
          ),
        if (!_bottomFilterMenuOpen &&
            _selectedCompany == null &&
            !_showFilteredProductsCarousel &&
            _filteredProductsForCarousel.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _MapProductsCollapsedPanel(
              safeBottom: safeBottom,
              onOpen: _openFilteredProductsCarousel,
            ),
          ),
        if (_bottomFilterMenuOpen)
          Positioned(
            left: 12,
            right: 12,
            bottom: hasBottomCarousel
                ? productsPanelBaseHeight - 14 + safeBottom
                : 34 + safeBottom,
            child: _MapBottomFilterPanel(
              tags: _hotTags,
              selectedTagSlugs: _selectedTagSlugs,
              radiusOptionsKm: _radiusOptionsKm,
              radiusKm: _radiusKm,
              useRadiusFilter: _useRadiusFilter,
              sortType: _sortType,
              filtersActive: _searchQuery.isNotEmpty ||
                  _selectedTagSlugs.isNotEmpty ||
                  _useRadiusFilter ||
                  _onlyNearby ||
                  _sortType != null,
              onTagToggle: (slug) {
                setState(() {
                  if (_selectedTagSlugs.contains(slug)) {
                    _selectedTagSlugs.remove(slug);
                  } else {
                    _selectedTagSlugs.add(slug);
                  }
                  _selectedCompany = null;
                  _showFilteredProductsCarousel = false;
                });
              },
              onClearTags: () {
                setState(() {
                  _selectedTagSlugs.clear();
                  _selectedCompany = null;
                  _showFilteredProductsCarousel = false;
                });
              },
              onRadiusChanged: (radius) {
                if (radius != null && _userLocation == null) {
                  AppFeedback.warning(
                    context,
                    l10n.allowLocationAccess,
                    key: 'map.location-access',
                  );
                  return;
                }

                setState(() {
                  if (radius == null) {
                    _useRadiusFilter = false;
                  } else {
                    _radiusKm = radius;
                    _radiusOptionIndex = _radiusOptionsKm.indexOf(radius);
                    _useRadiusFilter = true;
                    _onlyNearby = false;
                  }
                  _selectedCompany = null;
                  _showFilteredProductsCarousel = false;
                });
              },
              onSortChanged: (type) {
                setState(() {
                  _sortType = _sortType == type ? null : type;
                  _selectedCompany = null;
                  _showFilteredProductsCarousel = false;
                });
              },
              onResetTap: _resetMapFilters,
            ),
          ),
        Positioned(
          right: 16,
          bottom: hasBottomCarousel ? productsPanelBaseHeight - 16 + safeBottom : 36 + safeBottom,
          child: _MapFilterFab(
            icon: Icons.filter_alt_rounded,
            onTap: () {
              if (_bottomFilterMenuOpen) {
                _closeFilterMenu();
                return;
              }

              setState(() {
                _selectedCompany = null;
                _showFilteredProductsCarousel = false;
                _bottomFilterMenuOpen = true;
              });
            },
            active: _bottomFilterMenuOpen ||
                _selectedTagSlugs.isNotEmpty ||
                _useRadiusFilter ||
                _sortType != null,
          ),
        ),
        Positioned(
          right: 16,
          bottom: hasBottomCarousel ? productsPanelBaseHeight + 56 + safeBottom : 108 + safeBottom,
          child: _MapFab(
            icon: Icons.near_me_outlined,
            onTap: _moveToUser,
          ),
        ),
      ],
    );
  }
}


class _MapProductsCarousel extends StatelessWidget {
  final PageController controller;
  final MapCompany company;
  final List<Product> products;
  final String distanceText;
  final VoidCallback onClose;
  final ValueChanged<Product> onProductTap;

  const _MapProductsCarousel({
    required this.controller,
    required this.company,
    required this.products,
    required this.distanceText,
    required this.onClose,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 224,
      child: Column(
        children: [
          Container(
            width: 96,
            height: 5,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: controller,
              padEnds: false,
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];

                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 16 : 6,
                    right: index == products.length - 1 ? 16 : 6,
                  ),
                  child: _MapProductMiniCard(
                    product: product,
                    distanceText: distanceText,
                    onTap: () => onProductTap(product),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _MapProductsCollapsedPanel extends StatelessWidget {
  final double safeBottom;
  final VoidCallback onOpen;

  const _MapProductsCollapsedPanel({
    required this.safeBottom,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -120) onOpen();
      },
      child: Container(
        height: 46 + safeBottom,
        padding: EdgeInsets.only(bottom: safeBottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 76,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.38),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

double _mapProductsPanelBaseHeight(double availableWidth, double viewportFraction) {
  // PageView gives each item availableWidth * viewportFraction.
  // The card then has small horizontal page paddings and 10 px image inset.
  // Its image is always 3:2, so the panel height can be derived from width
  // instead of relying on a fixed pixel height.
  final pageWidth = availableWidth * viewportFraction;
  final imageWidth = (pageWidth - 32).clamp(120.0, double.infinity);
  final imageHeight = imageWidth * 2 / 3;

  // 136 px = pull handle + compact information area + bottom page inset.
  return imageHeight + 136;
}

class _MapProductsPullPanel extends StatelessWidget {
  final List<Product> products;
  final PageController controller;
  final double safeBottom;
  final String Function(Product product) distanceBuilder;
  final ValueChanged<Product> onProductTap;
  final VoidCallback onClose;

  const _MapProductsPullPanel({
    required this.products,
    required this.controller,
    required this.safeBottom,
    required this.distanceBuilder,
    required this.onProductTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 120) onClose();
      },
      child: Container(
        height: _mapProductsPanelBaseHeight(
          MediaQuery.sizeOf(context).width,
          controller.viewportFraction,
        ) +
            safeBottom,
        padding: EdgeInsets.only(bottom: safeBottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity > 80) onClose();
              },
              child: SizedBox(
                height: 34,
                child: Center(
                  child: Container(
                    width: 76,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.38),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: controller,
                padEnds: false,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];

                  return Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 16 : 6,
                      right: index == products.length - 1 ? 16 : 6,
                      bottom: 10,
                    ),
                    child: _MapProductMiniCard(
                      product: product,
                      distanceText: distanceBuilder(product),
                      onTap: () => onProductTap(product),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapProductMiniCard extends StatelessWidget {
  final Product product;
  final String distanceText;
  final VoidCallback onTap;

  const _MapProductMiniCard({
    required this.product,
    required this.distanceText,
    required this.onTap,
  });

  static const Color accentColor = Color(0xFFD1BC00);

  double get _finalPrice {
    if (product.discountPrice > 0 && product.discountPrice < product.price) {
      return product.discountPrice;
    }
    return product.price;
  }

  int? get _discountPercent {
    if (product.discountPrice <= 0 || product.discountPrice >= product.price) {
      return null;
    }

    return ((1 - product.discountPrice / product.price) * 100).round();
  }

  String get _pickupTimeText {
    final open = product.company.openTime?.toString() ?? '';
    final close = product.company.closeTime?.toString() ?? '';

    if (open.length < 5 || close.length < 5) return '';

    return '${open.substring(0, 5)}–${close.substring(0, 5)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final companyName = product.company.name?.trim().isNotEmpty == true
        ? product.company.name!.trim()
        : product.company.address;
    final discount = _discountPercent;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.14),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFEFEFEF),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 3 / 2,
                        child: Image.network(
                          product.cardImageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.black26,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (discount != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '-$discount%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF242424),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_finalPrice.toStringAsFixed(0)} \u058F',
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.0,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF242424),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (_pickupTimeText.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: Color(0xFF777777),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${l10n.pickupLabel} $_pickupTimeText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF777777),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      height: 1.3,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAD867),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                product.company.rating > 0
                                    ? product.company.rating.toStringAsFixed(1)
                                    : l10n.newStore,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (distanceText.isNotEmpty) ...[
                          const Icon(
                            Icons.near_me_outlined,
                            size: 12,
                            color: Color(0xFF666666),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            distanceText,
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
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
}

class _CompanyCluster {
  final List<MapCompany> companies;

  _CompanyCluster(this.companies);

  factory _CompanyCluster.single(MapCompany company) => _CompanyCluster([company]);

  LatLng get center {
    double lat = 0;
    double lng = 0;

    for (final company in companies) {
      lat += company.latitude;
      lng += company.longitude;
    }

    return LatLng(lat / companies.length, lng / companies.length);
  }

  void add(MapCompany company) {
    companies.add(company);
  }

  int productsCount(int Function(MapCompany company) countBuilder) {
    int total = 0;
    for (final company in companies) {
      total += countBuilder(company);
    }
    return total;
  }
}

class _MapTopPanel extends StatelessWidget {
  final TextEditingController searchController;
  final List<Tag> tags;
  final String? selectedTagSlug;
  final ValueChanged<String?> onTagChanged;
  final bool onlyNearby;
  final bool onlyOpenNow;
  final int companiesCount;
  final int productsCount;
  final bool filtersExpanded;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onNearbyChanged;
  final VoidCallback onOpenNowChanged;
  final VoidCallback onToggleFilters;

  const _MapTopPanel({
    required this.searchController,
    required this.tags,
    required this.selectedTagSlug,
    required this.onTagChanged,
    required this.onlyNearby,
    required this.onlyOpenNow,
    required this.companiesCount,
    required this.productsCount,
    required this.filtersExpanded,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onNearbyChanged,
    required this.onOpenNowChanged,
    required this.onToggleFilters,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      style: const TextStyle(
        color: Color(0xFF202020),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: l10n.searchShopOrProduct,
        hintStyle: TextStyle(
          color: Colors.black.withOpacity(0.38),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Colors.black45,
          size: 21,
        ),
        suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
          onPressed: onClearSearch,
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.black45,
            size: 20,
          ),
        )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 0,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.black.withOpacity(0.06),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFD1BC00),
            width: 1.2,
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;

  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.24),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withOpacity(0.20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFD1BC00)
                : Colors.grey.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFFD1BC00)
                  : Colors.grey.withOpacity(0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                selected
                    ? 'assets/icons/notifications_active.png'
                    : 'assets/icons/notifications.png',
                width: 15,
                height: 15,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : const Color(0xFF303030),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyMarker extends StatelessWidget {
  final String imageUrl;
  final int count;
  final bool isOpen;

  const _CompanyMarker({
    required this.imageUrl,
    required this.count,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isOpen ? const Color(0xFFD1BC00) : Colors.grey.shade400,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(isOpen ? 0.42 : 0.08),
                blurRadius: 14,
                spreadRadius: 1.5,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: imageUrl.isNotEmpty
                  ? Image.network(
                ApiService.fixImageUrl(imageUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.store,
                  color: Color(0xFFD1BC00),
                  size: 20,
                ),
              )
                  : const Icon(Icons.store, color: Color(0xFFD1BC00), size: 20),
            ),
          ),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFD1BC00),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClusterMarker extends StatelessWidget {
  final int companiesCount;
  final int productsCount;

  const _ClusterMarker({
    required this.companiesCount,
    required this.productsCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD1BC00),
            Color(0xFFFFE26A),
          ],
        ),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$companiesCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$productsCount ${l10n.productsShort}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _MapBottomFilterPanel extends StatelessWidget {
  static const Color _yellow = Color(0xFFD1BC00);

  final List<Tag> tags;
  final Set<String> selectedTagSlugs;
  final List<double> radiusOptionsKm;
  final double radiusKm;
  final bool useRadiusFilter;
  final MapSortType? sortType;
  final bool filtersActive;
  final ValueChanged<String> onTagToggle;
  final VoidCallback onClearTags;
  final ValueChanged<double?> onRadiusChanged;
  final ValueChanged<MapSortType> onSortChanged;
  final VoidCallback onResetTap;

  const _MapBottomFilterPanel({
    required this.tags,
    required this.selectedTagSlugs,
    required this.radiusOptionsKm,
    required this.radiusKm,
    required this.useRadiusFilter,
    required this.sortType,
    required this.filtersActive,
    required this.onTagToggle,
    required this.onClearTags,
    required this.onRadiusChanged,
    required this.onSortChanged,
    required this.onResetTap,
  });

  String _tr(
      BuildContext context, {
        required String ru,
        required String en,
        required String hy,
      }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'hy':
        return hy;
      case 'en':
        return en;
      default:
        return ru;
    }
  }

  String _radiusLabel(
      double? value,
      AppLocalizations l10n,
      ) {
    if (value == null) return l10n.all;
    if (value < 1) return '${(value * 1000).round()} ${l10n.m}';
    if (value >= 10) return '${value.round()} ${l10n.km}';
    return '${value.toStringAsFixed(1).replaceAll('.', ',')} ${l10n.km}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screen = MediaQuery.sizeOf(context);
    final compactHeight = screen.height < 700;
    final maxTagRows = compactHeight ? 2 : 3;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: screen.height * (compactHeight ? 0.76 : 0.78),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: _yellow.withOpacity(0.30),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        width: 48,
                        height: 5,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),

                // 1. Categories: icon-only grid, up to 3 rows.
                _MapFigmaFilterGroup(
                  icon: SvgPicture.asset(
                    'assets/icons/all_filters.svg',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF7E7E7E),
                      BlendMode.srcIn,
                    ),
                  ),
                  child: _MapTagsScrollableGrid(
                    tags: tags,
                    selectedTagSlugs: selectedTagSlugs,
                    maxRows: maxTagRows,
                    allLabel: l10n.all,
                    onTagToggle: onTagToggle,
                    onClearTags: onClearTags,
                  ),
                ),

                const SizedBox(height: 1),

                // 2. Radius: one horizontal scrollable row.
                _MapFigmaFilterGroup(
                  icon: const Icon(
                    Icons.radar_rounded,
                    size: 32,
                    color: Color(0xFF7E7E7E),
                  ),
                  childTopGap: 30,
                  child: SizedBox(
                    height: 78,
                    child: Center(
                      child: SizedBox(
                        height: 56,
                        child: _MapRadiusHorizontalList(
                          radiusOptionsKm: radiusOptionsKm,
                          radiusKm: radiusKm,
                          useRadiusFilter: useRadiusFilter,
                          labelBuilder: (value) => _radiusLabel(value, l10n),
                          onChanged: onRadiusChanged,
                        ),
                      ),
                    ),
                  ),
                ),

                // No extra gap here: the 30 px top section of the next group
                // is part of the visual space between the two yellow lines.
                // This keeps the radius values exactly in the middle.
                const SizedBox(height: 0),

                // 3. Sort: text list centered with top/bottom breathing room.
                _MapFigmaFilterGroup(
                  icon: const _MapSortDoubleChevronIcon(),
                  childTopGap: 10,
                  child: SizedBox(
                    height: 92,
                    child: Center(
                      child: SizedBox(
                        width: 152,
                        child: _MapSortTextList(
                          sortType: sortType,
                          ratingLabel: _tr(
                            context,
                            ru: 'Рейтинг',
                            en: 'Rating',
                            hy: 'Վարկանիշ',
                          ),
                          priceLabel: _tr(
                            context,
                            ru: 'Цена',
                            en: 'Price',
                            hy: 'Գին',
                          ),
                          distanceLabel: _tr(
                            context,
                            ru: 'Расстояние',
                            en: 'Distance',
                            hy: 'Հեռավորություն',
                          ),
                          onChanged: onSortChanged,
                        ),
                      ),
                    ),
                  ),
                ),

                if (filtersActive)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 7,
                        top: 2,
                      ),
                      child: _MapResetMiniButton(
                        active: true,
                        onTap: onResetTap,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _MapFigmaFilterGroup extends StatelessWidget {
  static const Color _yellow = Color(0xFFD1BC00);

  final Widget icon;
  final Widget child;
  final double childTopGap;

  const _MapFigmaFilterGroup({
    required this.icon,
    required this.child,
    this.childTopGap = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: _yellow.withOpacity(0.94),
              width: 1.15,
            ),
          ),
          child: Center(child: icon),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                height: 1,
                color: _yellow.withOpacity(0.88),
              ),
              SizedBox(height: childTopGap),
              child,
            ],
          ),
        ),
      ],
    );
  }
}


class _MapSortDoubleChevronIcon extends StatelessWidget {
  const _MapSortDoubleChevronIcon();

  @override
  Widget build(BuildContext context) {
    // Two overlapping chevrons inside one box. Using Stack avoids the
    // old Column overflow (23 + 23 px inside a 31 px box).
    return const SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 1,
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 26,
              color: Color(0xFF7E7E7E),
            ),
          ),
          Positioned(
            bottom: 1,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 26,
              color: Color(0xFF7E7E7E),
            ),
          ),
        ],
      ),
    );
  }
}


class _MapResetMiniButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _MapResetMiniButton({
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFD1BC00);

    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: yellow.withOpacity(active ? 0.95 : 0.45),
              width: 1.1,
            ),
          ),
          child: Icon(
            Icons.restart_alt_rounded,
            size: 20,
            color: active ? Colors.black87 : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}


class _MapTagsScrollableGrid extends StatefulWidget {
  final List<Tag> tags;
  final Set<String> selectedTagSlugs;
  final int maxRows;
  final String allLabel;
  final ValueChanged<String> onTagToggle;
  final VoidCallback onClearTags;

  const _MapTagsScrollableGrid({
    required this.tags,
    required this.selectedTagSlugs,
    required this.maxRows,
    required this.allLabel,
    required this.onTagToggle,
    required this.onClearTags,
  });

  @override
  State<_MapTagsScrollableGrid> createState() =>
      _MapTagsScrollableGridState();
}


class _MapTagsScrollableGridState extends State<_MapTagsScrollableGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _MapTagsScrollableGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the tag set gets shorter, keep the scroll offset inside the new range.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (_scrollController.offset > max) {
        _scrollController.jumpTo(max);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 255
            ? 4
            : width < 315
            ? 5
            : 6;

        final itemCount = widget.tags.length + 1;
        final totalRows = (itemCount / columns).ceil();
        final visibleRows =
        totalRows < widget.maxRows ? totalRows : widget.maxRows;
        final canScroll = totalRows > widget.maxRows;
        // Two-line tag captions need a little more vertical room.
        const tagRowHeight = 80.0;
        final gridHeight =
            (visibleRows <= 0 ? 1 : visibleRows) * tagRowHeight;

        final grid = GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(
            top: 3,
            // Reserve a little room so the thumb never sits on tag icons.
            right: canScroll ? 7 : 0,
          ),
          physics: canScroll
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 3,
            mainAxisSpacing: 0,
            mainAxisExtent: tagRowHeight,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _MapFilterTagTile(
                tooltip: widget.allLabel,
                label: widget.allLabel,
                selected: widget.selectedTagSlugs.isEmpty,
                svgAsset: 'assets/icons/all_filters.svg',
                onTap: widget.onClearTags,
              );
            }

            final tag = widget.tags[index - 1];

            return _MapFilterTagTile(
              tooltip: tag.name,
              label: tag.name,
              selected: widget.selectedTagSlugs.contains(tag.slug),
              imageUrl: tag.imageUrl,
              onTap: () => widget.onTagToggle(tag.slug),
            );
          },
        );

        return SizedBox(
          height: gridHeight,
          child: canScroll
              ? RawScrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            trackVisibility: false,
            interactive: true,
            thickness: 2.5,
            radius: const Radius.circular(999),
            minThumbLength: 24,
            thumbColor: Colors.black26,
            child: grid,
          )
              : grid,
        );
      },
    );
  }
}


class _MapFilterTagTile extends StatelessWidget {
  final String tooltip;
  final String label;
  final bool selected;
  final String? imageUrl;
  final String? svgAsset;
  final VoidCallback onTap;

  const _MapFilterTagTile({
    required this.tooltip,
    required this.label,
    required this.selected,
    required this.onTap,
    this.imageUrl,
    this.svgAsset,
  });

  @override
  Widget build(BuildContext context) {
    const selectedFill = Color(0xFFE4D21D);

    Widget icon;

    if (svgAsset != null && svgAsset!.isNotEmpty) {
      icon = SvgPicture.asset(
        svgAsset!,
        width: 31,
        height: 31,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          selected ? Colors.black87 : Colors.grey.shade500,
          BlendMode.srcIn,
        ),
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      icon = Image.network(
        ApiService.fixImageUrl(imageUrl!),
        width: 40,
        height: 40,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.local_dining_rounded,
          size: 31,
          color: selected ? Colors.black87 : Colors.grey.shade500,
        ),
      );
    } else {
      icon = Icon(
        Icons.local_dining_rounded,
        size: 31,
        color: selected ? Colors.black87 : Colors.grey.shade500,
      );
    }

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected ? selectedFill : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(child: icon),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 58,
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.05,
                      fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? const Color(0xFF171717)
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _MapRadiusHorizontalList extends StatefulWidget {
  final List<double> radiusOptionsKm;
  final double radiusKm;
  final bool useRadiusFilter;
  final String Function(double? value) labelBuilder;
  final ValueChanged<double?> onChanged;

  const _MapRadiusHorizontalList({
    required this.radiusOptionsKm,
    required this.radiusKm,
    required this.useRadiusFilter,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  State<_MapRadiusHorizontalList> createState() =>
      _MapRadiusHorizontalListState();
}


class _MapRadiusHorizontalListState
    extends State<_MapRadiusHorizontalList> {
  final ScrollController _controller = ScrollController();

  List<double?> get _values => <double?>[
    null,
    ...widget.radiusOptionsKm,
  ];

  bool _isSelected(double? value) {
    if (value == null) return !widget.useRadiusFilter;
    return widget.useRadiusFilter && value == widget.radiusKm;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = _values;

    return ListView.separated(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: values.length,
      separatorBuilder: (_, __) => const SizedBox(width: 18),
      itemBuilder: (context, index) {
        final value = values[index];
        final selected = _isSelected(value);

        return Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => widget.onChanged(value),
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 150),
                      style: TextStyle(
                        fontSize: selected ? 18.0 : 16.0,
                        height: 1,
                        fontWeight:
                        selected ? FontWeight.w900 : FontWeight.w700,
                        color: selected
                            ? const Color(0xFF171717)
                            : Colors.grey.shade400,
                      ),
                      child: Text(
                        widget.labelBuilder(value),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class _MapRadiusWheel extends StatefulWidget {
  final List<double> radiusOptionsKm;
  final double radiusKm;
  final bool useRadiusFilter;
  final String Function(double? value) labelBuilder;
  final ValueChanged<double?> onChanged;

  const _MapRadiusWheel({
    required this.radiusOptionsKm,
    required this.radiusKm,
    required this.useRadiusFilter,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  State<_MapRadiusWheel> createState() => _MapRadiusWheelState();
}


class _MapRadiusWheelState extends State<_MapRadiusWheel> {
  late FixedExtentScrollController _controller;

  List<double?> get _values => <double?>[
    null,
    ...widget.radiusOptionsKm,
  ];

  int get _selectedIndex {
    if (!widget.useRadiusFilter) return 0;
    final index = widget.radiusOptionsKm.indexOf(widget.radiusKm);
    return index < 0 ? 0 : index + 1;
  }

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: _selectedIndex,
    );
  }

  @override
  void didUpdateWidget(covariant _MapRadiusWheel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldIndex = !oldWidget.useRadiusFilter
        ? 0
        : oldWidget.radiusOptionsKm.indexOf(oldWidget.radiusKm) + 1;
    final newIndex = _selectedIndex;

    if (oldIndex != newIndex && _controller.hasClients) {
      _controller.animateToItem(
        newIndex,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = _values;
    final selectedIndex = _selectedIndex;

    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.18, 0.82, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: 28,
        diameterRatio: 2.5,
        perspective: 0.002,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          final value = values[index];
          final currentlySelected =
              selectedIndex == index;

          if (!currentlySelected) {
            widget.onChanged(value);
          }
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: values.length,
          builder: (context, index) {
            final selected = index == selectedIndex;
            return Center(
              child: Text(
                widget.labelBuilder(values[index]),
                maxLines: 1,
                style: TextStyle(
                  fontSize: selected ? 15.5 : 13.0,
                  height: 1,
                  fontWeight:
                  selected ? FontWeight.w900 : FontWeight.w600,
                  color: selected
                      ? const Color(0xFF171717)
                      : Colors.grey.shade300,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


class _MapSortTextList extends StatelessWidget {
  final MapSortType? sortType;
  final String ratingLabel;
  final String priceLabel;
  final String distanceLabel;
  final ValueChanged<MapSortType> onChanged;

  const _MapSortTextList({
    required this.sortType,
    required this.ratingLabel,
    required this.priceLabel,
    required this.distanceLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MapSortTextOption(
          label: ratingLabel,
          selected: sortType == MapSortType.rating,
          onTap: () => onChanged(MapSortType.rating),
        ),
        _MapSortTextOption(
          label: priceLabel,
          selected: sortType == MapSortType.price,
          onTap: () => onChanged(MapSortType.price),
        ),
        _MapSortTextOption(
          label: distanceLabel,
          selected: sortType == MapSortType.distance,
          onTap: () => onChanged(MapSortType.distance),
        ),
      ],
    );
  }
}


class _MapSortTextOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MapSortTextOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: 28,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: TextStyle(
                fontSize: selected ? 17 : 15,
                height: 1,
                fontWeight:
                selected ? FontWeight.w900 : FontWeight.w700,
                color: selected
                    ? const Color(0xFF171717)
                    : Colors.grey.shade300,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _MapFilterFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _MapFilterFab({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFFEDE37A) : Colors.white,
      shape: const CircleBorder(),
      elevation: 9,
      shadowColor: Colors.black.withOpacity(0.20),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Icon(
            icon,
            size: 27,
            color: active ? Colors.grey.shade700 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _MapFab({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFFEDE37A) : Colors.white,
      shape: const CircleBorder(),
      elevation: 7,
      shadowColor: Colors.black.withOpacity(0.18),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 17,
            color: active ? Colors.grey.shade700 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  final String imageUrl;
  final double size;

  const _CompanyLogo({
    required this.imageUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.store),
        )
            : const Icon(Icons.store),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: const Color(0xFFD1BC00)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
