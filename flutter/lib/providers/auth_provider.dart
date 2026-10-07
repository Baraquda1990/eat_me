import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _username;
  bool _initialized = false;
  String _userType = 'buyer';

  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;
  bool get initialized => _initialized;

  String get userType => _userType;
  bool get isSeller => _userType == 'seller';
  bool get isBuyer => _userType == 'buyer';

  Future<void> initialize() async {
    await checkLoginStatus();
    _initialized = true;
    notifyListeners();
  }

  Future<void> checkLoginStatus() async {
    try {
      final loggedIn = await ApiService.isLoggedIn();

      _isLoggedIn = loggedIn;

      if (_isLoggedIn) {
        try {
          final user = await ApiService.getCurrentUser();
          _username = user.username;

          final seller = await ApiService.checkIsSeller();
          _userType = seller ? 'seller' : 'buyer';
        } catch (e) {
          _username = null;
          _isLoggedIn = false;
          _userType = 'buyer';
        }
      } else {
        _username = null;
        _userType = 'buyer';
      }

      notifyListeners();
    } catch (e) {
      _isLoggedIn = false;
      _username = null;
      _userType = 'buyer';
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    await ApiService.login(
      username: username,
      password: password,
    );

    await checkLoginStatus();
  }

  Future<void> logout() async {
    await ApiService.logout();

    _isLoggedIn = false;
    _username = null;
    _userType = 'buyer';

    notifyListeners();
  }
}
