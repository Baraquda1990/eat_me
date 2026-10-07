// lib/providers/products_refresh_provider.dart

import 'package:flutter/material.dart';

class ProductsRefreshProvider extends ChangeNotifier {
  int _version = 0;
  final Set<String> _purchasedSlugs = {};

  int get version => _version;
  Set<String> get purchasedSlugs => Set.unmodifiable(_purchasedSlugs);

  void refreshProducts() {
    _version++;
    notifyListeners();
  }

  void markPurchasedSlugs(List<String> slugs) {
    _purchasedSlugs.addAll(slugs);
    _version++;
    notifyListeners();
  }

  void clearPurchasedSlugs() {
    if (_purchasedSlugs.isNotEmpty) {
      _purchasedSlugs.clear();
      // Не вызываем notifyListeners() здесь, чтобы не было лишних перерисовок
    }
  }
}