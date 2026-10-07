// lib/screens/favorite_screen.dart

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/favorite_provider.dart';
import '../providers/navigation_provider.dart';
import '../utils/app_feedback.dart';
import '../widgets/product_card.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/app_error_state.dart';
import 'login_screen.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({Key? key}) : super(key: key);

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        context.read<FavoriteProvider>().loadFavorites();
      }
    });
  }

  Future<void> _openLogin() async {
    const actionKey = 'favorites.open-login';
    if (!AppActionGuard.tryLock(actionKey)) return;

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );

      if (!mounted) return;

      await context.read<AuthProvider>().checkLoginStatus();

      if (result == true || context.read<AuthProvider>().isLoggedIn) {
        await context.read<FavoriteProvider>().loadFavorites(force: true);
      }
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  void _goHome() {
    context.read<NavigationProvider>().setIndex(0);

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final favorites = context.watch<FavoriteProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.favorites,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF333333)),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/auth_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: !auth.isLoggedIn
            ? _buildAuthRequiredWidget()
            : favorites.isLoading && favorites.favoriteProducts.isEmpty
            ? const ProductListSkeleton()
            : favorites.loadError != null &&
            favorites.favoriteProducts.isEmpty
            ? AppErrorState(
          error: favorites.loadError,
          onRetry: () => favorites.loadFavorites(force: true),
        )
            : favorites.favoriteProducts.isEmpty
            ? _buildEmptyWidget()
            : RefreshIndicator(
          onRefresh: () => favorites.loadFavorites(force: true, silent: true),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
            itemCount: favorites.favoriteProducts.length +
                (favorites.loadError != null ? 1 : 0),
            itemBuilder: (_, index) {
              if (favorites.loadError != null && index == 0) {
                return AppInlineError(
                  error: favorites.loadError,
                  onRetry: () => favorites.loadFavorites(
                    force: true,
                    silent: true,
                  ),
                );
              }

              final productIndex =
                  index - (favorites.loadError != null ? 1 : 0);
              final product = favorites.favoriteProducts[productIndex];
              return ProductCard(
                product: product,
                showCompanyLogo: true,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAuthRequiredWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1BC00).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 44,
                  color: Color(0xFFD1BC00),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                AppLocalizations.of(context)!.loginToAccount,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF333333)),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.favoritesAuthSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD1BC00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.login,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return RefreshIndicator(
      onRefresh: () => context.read<FavoriteProvider>().loadFavorites(
        force: true,
        silent: true,
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1BC00).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    size: 48,
                    color: Color(0xFFD1BC00),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  AppLocalizations.of(context)!.favoriteEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF333333)),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.favoritesEmptySubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _goHome,
                    icon: const Icon(Icons.home_outlined),
                    label: Text(AppLocalizations.of(context)!.goHome),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD1BC00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
