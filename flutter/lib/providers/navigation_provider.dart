// lib/providers/navigation_provider.dart
import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  String? _mapCompanySlug;

  int get currentIndex => _currentIndex;
  String? get mapCompanySlug => _mapCompanySlug;

  void setIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  void openMapForCompany(String companySlug) {
    _currentIndex = 1;
    _mapCompanySlug = companySlug;
    notifyListeners();
  }


  String? consumeMapCompanySlug() {
    final slug = _mapCompanySlug;
    _mapCompanySlug = null;
    return slug;
  }
}
