import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';

import 'seller_company_info_screen.dart';
import 'seller_registration_provider.dart';
import 'seller_registration_service.dart';

class SellerTypeScreen extends StatefulWidget {
  const SellerTypeScreen({super.key});

  static const Color accent = Color(0xFFD1BC00);
  static const Color dealsButton = Color(0xFFE30620);

  @override
  State<SellerTypeScreen> createState() => _SellerTypeScreenState();
}

class _SellerTypeScreenState extends State<SellerTypeScreen>
    with WidgetsBindingObserver {
  bool _checkingApplication = true;
  bool _routing = false;
  String? _checkError;

  SellerRegistrationService _service() {
    return SellerRegistrationService(
      dio: Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: const {'Accept': 'application/json'},
        ),
      ),
      baseUrl: ApiService.apiUrl,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inspectExistingApplication();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_routing) {
      _inspectExistingApplication();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _lockedMessage(
      AppLocalizations l10n,
      Map<String, dynamic> application,
      ) {
    final status =
        application['status']?.toString().trim().toLowerCase() ?? '';

    return switch (status) {
      'approved' => l10n.sellerRegistrationApprovedMessage,
      'pending' => l10n.sellerRegistrationPendingMessage,
      'rejected' => l10n.sellerRegistrationRejectedMessage,
      _ => l10n.sellerRegistrationLockedMessage,
    };
  }

  Future<void> _showLockedApplication(
      Map<String, dynamic> application,
      ) async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final statusDisplay =
        application['status_display']?.toString().trim() ?? '';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            statusDisplay.isNotEmpty
                ? statusDisplay
                : l10n.sellerApplication,
          ),
          content: Text(_lockedMessage(l10n, application)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: SellerTypeScreen.accent,
                foregroundColor: Colors.black,
              ),
              child: Text(l10n.done),
            ),
          ],
        );
      },
    );

    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _resumeExistingApplication(
      Map<String, dynamic> application,
      ) async {
    if (_routing) return;
    _routing = true;

    try {
      final service = _service();
      final channelCodes =
      await service.resolveApplicationChannelCodes(application);

      final provider = SellerRegistrationProvider()
        ..loadFromApplication(
          application,
          channelCodes: channelCodes,
        );

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const SellerCompanyInfoScreen(),
          ),
        ),
      );
    } finally {
      _routing = false;
    }
  }

  Future<void> _inspectExistingApplication() async {
    if (_routing) return;

    if (mounted) {
      setState(() {
        _checkingApplication = true;
        _checkError = null;
      });
    }

    try {
      final application = await _service().getMyApplication();
      if (!mounted) return;

      if (application == null) {
        setState(() => _checkingApplication = false);
        return;
      }

      if (application['is_editable'] == true) {
        await _resumeExistingApplication(application);
        return;
      }

      setState(() => _checkingApplication = false);
      await _showLockedApplication(application);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingApplication = false;
        _checkError =
            AppLocalizations.of(context)!.sellerRegistrationCheckFailed;
      });
    }
  }

  Future<void> _openNext(String channelCode) async {
    if (_checkingApplication || _routing) return;

    setState(() {
      _routing = true;
      _checkError = null;
    });

    try {
      // Check one more time at the exact moment the user starts a new
      // registration. This closes the race with an approval/change made
      // while SellerTypeScreen was already open.
      final application = await _service().getMyApplication();
      if (!mounted) return;

      if (application != null) {
        _routing = false;

        if (application['is_editable'] == true) {
          await _resumeExistingApplication(application);
        } else {
          await _showLockedApplication(application);
        }
        return;
      }

      final provider = SellerRegistrationProvider()
        ..setChannelCode(channelCode);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const SellerCompanyInfoScreen(),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkError =
            AppLocalizations.of(context)!.sellerRegistrationCheckFailed;
      });
    } finally {
      if (mounted) {
        setState(() => _routing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final disabled = _checkingApplication || _routing;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 18, 4),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: 0.88),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          switch (
                          Localizations.localeOf(context).languageCode) {
                            'ru' => 'Как вы будете продавать?',
                            'hy' => 'Ինչպե՞ս եք վաճառելու',
                            _ => 'How will you sell?',
                          },
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF242424),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_checkError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Material(
                      color: Colors.white.withOpacity(.92),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _checkError!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _inspectExistingApplication,
                              child: Text(l10n.retry),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _SellerTypePanel(
                    background: const Color(0xFFFFE9C7),
                    assetPath: 'assets/images/seller_hot.svg',
                    title: l10n.sellerTypeHotTitle,
                    buttonColor: SellerTypeScreen.accent,
                    onPressed: disabled ? null : () => _openNext('hot'),
                  ),
                ),
                Expanded(
                  child: _SellerTypePanel(
                    background: const Color(0xFFDDF3E2),
                    assetPath: 'assets/images/seller_deals.svg',
                    title: l10n.sellerTypeDealsTitle,
                    buttonColor: SellerTypeScreen.dealsButton,
                    onPressed: disabled ? null : () => _openNext('deals'),
                  ),
                ),
              ],
            ),
          ),
          if (_checkingApplication || _routing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black12,
                child: Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: SellerTypeScreen.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SellerTypePanel extends StatelessWidget {
  const _SellerTypePanel({
    required this.background,
    required this.assetPath,
    required this.title,
    required this.buttonColor,
    required this.onPressed,
  });

  final Color background;
  final String assetPath;
  final String title;
  final Color buttonColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: background.withOpacity(0.88),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 300;
          final imageHeight = compact
              ? (constraints.maxHeight * 0.54).clamp(124.0, 158.0)
              : (constraints.maxHeight * 0.58).clamp(158.0, 210.0);

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: SvgPicture.asset(
                  assetPath,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF333333),
                    fontSize: compact ? 12 : 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: compact ? 42 : 46,
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.submitAnApplication,
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
