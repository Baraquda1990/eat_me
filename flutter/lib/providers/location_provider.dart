import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationProvider extends ChangeNotifier {
  Position? _position;
  bool _isLoading = false;
  LocationPermission? _permission;

  Position? get position => _position;
  bool get isLoading => _isLoading;
  LocationPermission? get permission => _permission;

  bool get hasLocationPermission {
    return _permission == LocationPermission.whileInUse ||
        _permission == LocationPermission.always;
  }

  Future<void> loadLocation({
    bool requestPermission = false,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      _permission = permission;

      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
        _permission = permission;
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // Fast initial value. Geolocator documents that the fresh GPS fix can
      // take several seconds, so use the cached position first when possible.
      if (!kIsWeb) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            _position = lastKnown;
            notifyListeners();
          }
        } catch (_) {
          // Last known location is optional.
        }
      }

      try {
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );

        _position = current;
        notifyListeners();
      } catch (_) {
        // Keep the last-known position if the fresh GPS fix times out.
      }
    } catch (_) {
      // Location must never block the rest of the application.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestPermissionAndLoad() {
    return loadLocation(requestPermission: true);
  }

  Future<void> refreshIfAllowed() {
    return loadLocation(requestPermission: false);
  }

  double? distanceTo({
    required double latitude,
    required double longitude,
  }) {
    if (_position == null) return null;

    final meters = Geolocator.distanceBetween(
      _position!.latitude,
      _position!.longitude,
      latitude,
      longitude,
    );

    return meters / 1000;
  }
}
