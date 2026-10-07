// lib/providers/cart_provider.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isCheckingOut = false;
  Object? _loadError;
  final Set<String> _updatingSlugs = {};

  int _itemsCount = 0;
  double _totalPrice = 0;
  List<dynamic> _items = [];

  Future<void>? _loadFuture;
  DateTime? _lastLoadedAt;
  bool _hasLoadedOnce = false;
  int _revision = 0;

  static const Duration _cacheTtl = Duration(seconds: 10);

  bool get isLoading => _isLoading;
  bool get isCheckingOut => _isCheckingOut;
  Object? get loadError => _loadError;
  int get itemsCount => _itemsCount;
  double get totalPrice => _totalPrice;
  List<dynamic> get items => List.unmodifiable(_items);

  bool isUpdating(String slug) => _updatingSlugs.contains(slug);

  Future<void> loadCart({
    bool silent = false,
    bool force = false,
  }) {
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;

    if (!force && _hasLoadedOnce && _lastLoadedAt != null) {
      final age = DateTime.now().difference(_lastLoadedAt!);
      if (age < _cacheTtl) {
        return Future<void>.value();
      }
    }

    final future = _performLoadCart(silent: silent);
    _loadFuture = future;

    return future.whenComplete(() {
      if (identical(_loadFuture, future)) {
        _loadFuture = null;
      }
    });
  }

  Future<void> _performLoadCart({required bool silent}) async {
    final requestRevision = _revision;
    _loadError = null;

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final data = await ApiService.getCart();

      // Ignore an older GET response if the user changed the cart while the
      // request was in flight. This prevents stale data from jumping back in.
      if (requestRevision == _revision) {
        _items = data['items'] is List ? data['items'] as List : [];
        _itemsCount = _calculateItemsCount(_items);
        _totalPrice = _parseDouble(data['total_price']);
        _hasLoadedOnce = true;
        _lastLoadedAt = DateTime.now();
        _loadError = null;
      }
    } catch (e) {
      debugPrint('Cart load error: $e');
      _loadError = e;
      // Keep the current local cart on a temporary network failure.
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<bool> addProduct(Product product, {int quantity = 1}) async {
    if (quantity <= 0 || product.slug.isEmpty) return false;
    if (_updatingSlugs.contains(product.slug)) return false;

    _updatingSlugs.add(product.slug);

    final snapshot = _takeSnapshot();

    // Update badge/list/total before the network round trip.
    _applyProductDelta(product, quantity);
    _revision++;
    notifyListeners();

    try {
      // One mutation request only. No GET /cart/ afterwards.
      await ApiService.addToCart(
        productSlug: product.slug,
        quantity: quantity,
      );
      _hasLoadedOnce = true;
      _lastLoadedAt = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('Cart add error: $e');
      _restoreSnapshot(snapshot);
      _revision++;
      notifyListeners();
      return false;
    } finally {
      _updatingSlugs.remove(product.slug);
      notifyListeners();
    }
  }

  /// Use after another confirmed backend action (for example HOT reserve)
  /// already added a product to the server cart. This updates local state
  /// without issuing another GET /cart/ request.
  void applyConfirmedProduct(Product product, {int quantity = 1}) {
    if (quantity <= 0 || product.slug.isEmpty) return;
    _applyProductDelta(product, quantity);
    _revision++;
    _hasLoadedOnce = true;
    _lastLoadedAt = DateTime.now();
    notifyListeners();
  }

  Future<bool> updateQuantity({
    required String productSlug,
    required int quantity,
  }) async {
    if (productSlug.isEmpty) return false;
    if (_updatingSlugs.contains(productSlug)) return false;

    _updatingSlugs.add(productSlug);
    final snapshot = _takeSnapshot();

    final localChanged = _setLocalQuantity(productSlug, quantity);
    if (localChanged) {
      _revision++;
      notifyListeners();
    }

    try {
      if (quantity <= 0) {
        await ApiService.removeCartItem(productSlug);
      } else {
        await ApiService.updateCartItemQuantity(
          productSlug: productSlug,
          quantity: quantity,
        );
      }

      _hasLoadedOnce = true;
      _lastLoadedAt = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('Cart quantity update error: $e');
      if (localChanged) {
        _restoreSnapshot(snapshot);
        _revision++;
        notifyListeners();
      }
      return false;
    } finally {
      _updatingSlugs.remove(productSlug);
      notifyListeners();
    }
  }

  Future<bool> increaseQuantity({
    required String productSlug,
    required int currentQuantity,
  }) {
    return updateQuantity(
      productSlug: productSlug,
      quantity: currentQuantity + 1,
    );
  }

  Future<bool> decreaseQuantity({
    required String productSlug,
    required int currentQuantity,
  }) {
    return updateQuantity(
      productSlug: productSlug,
      quantity: currentQuantity - 1,
    );
  }

  Future<bool> removeProduct(String productSlug) {
    return updateQuantity(productSlug: productSlug, quantity: 0);
  }

  Future<bool> checkout({String status = 'paided'}) async {
    if (_isCheckingOut) return false;

    _isCheckingOut = true;
    notifyListeners();

    try {
      await ApiService.checkoutCart(status: status);

      // Backend confirmed checkout: local cart is now authoritatively empty.
      // Do not GET it again just to learn that it is empty.
      _items = [];
      _itemsCount = 0;
      _totalPrice = 0;
      _revision++;
      _hasLoadedOnce = true;
      _lastLoadedAt = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Checkout error: $e');
      return false;
    } finally {
      _isCheckingOut = false;
      notifyListeners();
    }
  }

  Future<List<dynamic>> loadPastOrders() async {
    try {
      return await ApiService.getPastOrders();
    } catch (_) {
      return [];
    }
  }

  void clear() {
    _items = [];
    _itemsCount = 0;
    _totalPrice = 0;
    _isLoading = false;
    _isCheckingOut = false;
    _loadError = null;
    _updatingSlugs.clear();
    _hasLoadedOnce = false;
    _lastLoadedAt = null;
    _revision++;
    notifyListeners();
  }

  void _applyProductDelta(Product product, int delta) {
    final index = _findItemIndex(product.slug);

    if (index >= 0) {
      final original = _asStringMap(_items[index]);
      if (original == null) return;

      final oldQuantity = _quantityOf(original);
      final newQuantity = oldQuantity + delta;
      final unitPrice = _unitPriceOfItem(original, fallback: _productPrice(product));

      final updated = Map<String, dynamic>.from(original);
      updated['quantity'] = newQuantity;
      updated['price_by_quantity'] = unitPrice * newQuantity;
      _items[index] = updated;
    } else {
      final unitPrice = _productPrice(product);
      _items.add(<String, dynamic>{
        'id': null,
        'product': product.toJson(),
        'quantity': delta,
        'price_by_quantity': unitPrice * delta,
      });
    }

    _recalculateFromItems();
  }

  bool _setLocalQuantity(String slug, int quantity) {
    final index = _findItemIndex(slug);
    if (index < 0) return false;

    if (quantity <= 0) {
      _items.removeAt(index);
      _recalculateFromItems();
      return true;
    }

    final original = _asStringMap(_items[index]);
    if (original == null) return false;

    final oldQuantity = _quantityOf(original);
    final unitPrice = _unitPriceOfItem(original);

    final updated = Map<String, dynamic>.from(original);
    updated['quantity'] = quantity;

    if (unitPrice > 0 || oldQuantity > 0) {
      updated['price_by_quantity'] = unitPrice * quantity;
    }

    _items[index] = updated;
    _recalculateFromItems();
    return true;
  }

  int _findItemIndex(String slug) {
    return _items.indexWhere((item) => _slugOf(item) == slug);
  }

  String _slugOf(dynamic item) {
    if (item is! Map) return '';
    final product = item['product'];
    if (product is! Map) return '';
    return product['slug']?.toString() ?? '';
  }

  int _quantityOf(dynamic item) {
    if (item is! Map) return 0;
    final raw = item['quantity'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '0') ?? 0;
  }

  double _unitPriceOfItem(dynamic item, {double fallback = 0}) {
    final quantity = _quantityOf(item);
    if (item is Map && quantity > 0) {
      final total = _parseDouble(item['price_by_quantity']);
      if (total > 0) return total / quantity;

      final product = item['product'];
      if (product is Map) {
        final regular = _parseDouble(product['price']);
        final discounted = _parseDouble(
          product['get_discount_price'] ?? product['discount_price'],
        );
        if (discounted > 0 && (regular <= 0 || discounted < regular)) {
          return discounted;
        }
        if (regular > 0) return regular;
      }
    }
    return fallback;
  }

  double _productPrice(Product product) {
    if (product.discountPrice > 0 && product.discountPrice < product.price) {
      return product.discountPrice;
    }
    return product.price;
  }

  int _calculateItemsCount(List<dynamic> source) {
    var result = 0;
    for (final item in source) {
      result += _quantityOf(item);
    }
    return result;
  }

  void _recalculateFromItems() {
    _itemsCount = _calculateItemsCount(_items);
    _totalPrice = 0;
    for (final item in _items) {
      if (item is Map) {
        _totalPrice += _parseDouble(item['price_by_quantity']);
      }
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  _CartSnapshot _takeSnapshot() {
    return _CartSnapshot(
      items: _items.map((item) {
        final map = _asStringMap(item);
        return map == null ? item : Map<String, dynamic>.from(map);
      }).toList(growable: true),
      itemsCount: _itemsCount,
      totalPrice: _totalPrice,
    );
  }

  void _restoreSnapshot(_CartSnapshot snapshot) {
    _items = snapshot.items;
    _itemsCount = snapshot.itemsCount;
    _totalPrice = snapshot.totalPrice;
  }
}

class _CartSnapshot {
  final List<dynamic> items;
  final int itemsCount;
  final double totalPrice;

  const _CartSnapshot({
    required this.items,
    required this.itemsCount,
    required this.totalPrice,
  });
}
