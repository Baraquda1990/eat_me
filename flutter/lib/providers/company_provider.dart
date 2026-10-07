// lib/providers/company_provider.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_company.dart';
import '../services/api_service.dart';

class CompanyProvider with ChangeNotifier {
  List<MapCompany> _companies = [];
  LatLng? _userLocation;
  bool _isLoading = false;

  List<MapCompany> get companies => _companies;
  LatLng? get userLocation => _userLocation;
  bool get isLoading => _isLoading;

  Future<void> loadCompanies({bool force = false}) async {
    if (_isLoading) return;
    if (!force && _companies.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      _companies = await ApiService.getMapCompanies();
      await loadUserLocation(notify: false);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserLocation({bool notify = true}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _userLocation = LatLng(position.latitude, position.longitude);
      if (notify) notifyListeners();
    } catch (_) {
      _userLocation = null;
      if (notify) notifyListeners();
    }
  }

  MapCompany? companyBySlug(String slug) {
    for (final company in _companies) {
      if (company.slug == slug) return company;
    }
    return null;
  }

  double? distanceKmBySlug(String slug) {
    final company = companyBySlug(slug);
    if (company == null || _userLocation == null) return null;

    final meters = Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      company.latitude,
      company.longitude,
    );

    return meters / 1000;
  }
}
