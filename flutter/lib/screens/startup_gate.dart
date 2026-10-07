// lib/screens/startup_gate.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import 'main_screen.dart';
import 'welcome_screen.dart';
import 'pin_unlock_screen.dart';
import '../widgets/legal_consent_gate.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  static const String _welcomeCompletedKey = 'welcome_completed';

  Future<bool>? _welcomeCompletedFuture;

  @override
  void initState() {
    super.initState();
    _welcomeCompletedFuture = _loadWelcomeCompleted();
  }

  Future<bool> _loadWelcomeCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_welcomeCompletedKey) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.initialized) {
      return const _StartupLoader();
    }

    if (auth.isLoggedIn) {
      return PinLockGate(
        username: auth.username ?? '',
        child: const LegalConsentGate(
          child: MainScreen(),
        ),
      );
    }

    return FutureBuilder<bool>(
      future: _welcomeCompletedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupLoader();
        }

        final welcomeCompleted = snapshot.data ?? false;
        return welcomeCompleted
            ? const MainScreen()
            : const WelcomeScreen();
      },
    );
  }
}

class _StartupLoader extends StatelessWidget {
  const _StartupLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFD1BC00),
        ),
      ),
    );
  }
}
