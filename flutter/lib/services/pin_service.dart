import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _pinKey = 'appsosa_local_pin_v1';
  static const String _ownerKey = 'appsosa_local_pin_owner_v1';

  static String _normalizeOwner(String value) => value.trim().toLowerCase();

  static bool isValidPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

  static Future<bool> hasPinFor(String? owner) async {
    final normalizedOwner = _normalizeOwner(owner ?? '');
    if (normalizedOwner.isEmpty) return false;

    final savedOwner = _normalizeOwner(
      await _storage.read(key: _ownerKey) ?? '',
    );
    final pin = await _storage.read(key: _pinKey);

    return savedOwner == normalizedOwner &&
        pin != null &&
        isValidPin(pin);
  }

  static Future<void> savePin({
    required String owner,
    required String pin,
  }) async {
    final normalizedOwner = _normalizeOwner(owner);

    if (normalizedOwner.isEmpty) {
      throw ArgumentError('PIN owner is empty');
    }
    if (!isValidPin(pin)) {
      throw ArgumentError('PIN must contain exactly 4 digits');
    }

    // The PIN is local only and is stored in flutter_secure_storage.
    await _storage.write(key: _ownerKey, value: normalizedOwner);
    await _storage.write(key: _pinKey, value: pin);
  }

  static Future<bool> verifyPin({
    required String owner,
    required String pin,
  }) async {
    if (!isValidPin(pin)) return false;

    final normalizedOwner = _normalizeOwner(owner);
    if (normalizedOwner.isEmpty) return false;

    final savedOwner = _normalizeOwner(
      await _storage.read(key: _ownerKey) ?? '',
    );
    if (savedOwner != normalizedOwner) return false;

    final savedPin = await _storage.read(key: _pinKey);
    return savedPin == pin;
  }

  static Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _pinKey),
      _storage.delete(key: _ownerKey),
    ]);
  }
}
