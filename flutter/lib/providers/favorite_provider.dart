// lib/providers/favorite_provider.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_service.dart';

class FavoriteProvider extends ChangeNotifier {
  Set<String> _favoriteSlugs = {};
  List<Product> _favoriteProducts = [];

  bool _isLoading = false;
  Object? _loadError;
  final Set<String> _updatingSlugs = {};

  Future<void>? _loadFuture;
  DateTime? _lastLoadedAt;
  bool _hasLoadedOnce = false;
  int _revision = 0;

  static const Duration _cacheTtl = Duration(seconds: 30);

  Set<String> get favoriteSlugs => Set.unmodifiable(_favoriteSlugs);
  List<Product> get favoriteProducts => List.unmodifiable(_favoriteProducts);
  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;

  bool isFavorite(String slug) => _favoriteSlugs.contains(slug);
  bool isUpdating(String slug) => _updatingSlugs.contains(slug);

  Future<void> loadFavorites({
    bool force = false,
    bool silent = false,
  }) {
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;

    if (!force && _hasLoadedOnce && _lastLoadedAt != null) {
      final age = DateTime.now().difference(_lastLoadedAt!);
      if (age < _cacheTtl) {
        return Future<void>.value();
      }
    }

    final future = _performLoadFavorites(silent: silent);
    _loadFuture = future;

    return future.whenComplete(() {
      if (identical(_loadFuture, future)) {
        _loadFuture = null;
      }
    });
  }

  Future<void> _performLoadFavorites({required bool silent}) async {
    if (!await ApiService.isLoggedIn()) {
      final changed = _favoriteSlugs.isNotEmpty ||
          _favoriteProducts.isNotEmpty ||
          _isLoading;

      _favoriteSlugs = {};
      _favoriteProducts = [];
      _isLoading = false;
      _loadError = null;
      _hasLoadedOnce = false;
      _lastLoadedAt = null;
      _revision++;

      if (changed) notifyListeners();
      return;
    }

    final requestRevision = _revision;
    _loadError = null;

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final products = await ApiService.getFavorites();

      // Do not let an older GET overwrite a favorite that the user changed
      // while this request was still in flight.
      if (requestRevision == _revision) {
        _favoriteProducts = products;
        _favoriteSlugs = products.map((p) => p.slug).toSet();
        _hasLoadedOnce = true;
        _lastLoadedAt = DateTime.now();
        _loadError = null;
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      _loadError = e;
      // Keep the previous local state on a refresh/network failure.
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<bool> addFavorite(
      String slug, {
        Product? product,
      }) async {
    if (slug.isEmpty) return false;
    if (_updatingSlugs.contains(slug)) return false;
    if (_favoriteSlugs.contains(slug)) return true;

    _updatingSlugs.add(slug);

    final addedProduct = product != null &&
        !_favoriteProducts.any((p) => p.slug == slug);

    // Optimistic update: heart changes immediately, without waiting for GET.
    _favoriteSlugs.add(slug);
    if (addedProduct) {
      _favoriteProducts.insert(0, product);
    }
    _revision++;
    notifyListeners();

    try {
      await ApiService.addToFavorites(slug);
      _hasLoadedOnce = true;
      _lastLoadedAt = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('Error adding favorite: $e');

      // Roll back only the optimistic change made by this operation.
      _favoriteSlugs.remove(slug);
      if (addedProduct) {
        _favoriteProducts.removeWhere((p) => p.slug == slug);
      }
      _revision++;
      notifyListeners();
      return false;
    } finally {
      _updatingSlugs.remove(slug);
      notifyListeners();
    }
  }

  Future<bool> removeFavorite(String slug) async {
    if (slug.isEmpty) return false;
    if (_updatingSlugs.contains(slug)) return false;
    if (!_favoriteSlugs.contains(slug)) return true;

    _updatingSlugs.add(slug);

    final removedProducts = _favoriteProducts
        .where((p) => p.slug == slug)
        .toList(growable: false);
    final oldIndex = _favoriteProducts.indexWhere((p) => p.slug == slug);

    // Optimistic update: remove from Favorites immediately.
    _favoriteSlugs.remove(slug);
    _favoriteProducts.removeWhere((p) => p.slug == slug);
    _revision++;
    notifyListeners();

    try {
      await ApiService.removeFromFavorites(slug);
      _hasLoadedOnce = true;
      _lastLoadedAt = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('Error removing favorite: $e');

      // Network/backend failed -> restore previous state.
      _favoriteSlugs.add(slug);
      if (removedProducts.isNotEmpty &&
          !_favoriteProducts.any((p) => p.slug == slug)) {
        final insertAt = oldIndex < 0
            ? 0
            : oldIndex.clamp(0, _favoriteProducts.length).toInt();
        _favoriteProducts.insertAll(insertAt, removedProducts);
      }
      _revision++;
      notifyListeners();
      return false;
    } finally {
      _updatingSlugs.remove(slug);
      notifyListeners();
    }
  }

  Future<bool> toggleFavorite(
      String slug, {
        Product? product,
      }) {
    if (isFavorite(slug)) {
      return removeFavorite(slug);
    }
    return addFavorite(slug, product: product);
  }

  void clear() {
    _favoriteSlugs = {};
    _favoriteProducts = [];
    _isLoading = false;
    _loadError = null;
    _updatingSlugs.clear();
    _hasLoadedOnce = false;
    _lastLoadedAt = null;
    _revision++;
    notifyListeners();
  }
}
