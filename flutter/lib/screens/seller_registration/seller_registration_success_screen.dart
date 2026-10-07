import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class SellerRegistrationSuccessScreen extends StatelessWidget {
  const SellerRegistrationSuccessScreen({super.key, required this.applicationId, required this.status});
  final int applicationId;
  final String status;
  static const _accent = Color(0xFFD1BC00);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const Spacer(),
                  Container(width: 104, height: 104, decoration: BoxDecoration(color: _accent.withOpacity(.15), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 58, color: _accent)),
                  const SizedBox(height: 28),
                  Text(AppLocalizations.of(context)!.applicationSent, textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context)!.applicationSentSubtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF666666))),
                  const SizedBox(height: 24),
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(14)), child: Column(children: [
                    Row(children: [Expanded(child: Text(AppLocalizations.of(context)!.applicationNumber)), Text('#$applicationId', style: const TextStyle(fontWeight: FontWeight.w800))]),
                    const SizedBox(height: 10),
                    Row(children: [Expanded(child: Text(AppLocalizations.of(context)!.status)), Text(status == 'pending' ? AppLocalizations.of(context)!.underReview : status, style: const TextStyle(fontWeight: FontWeight.w800))]),
                  ])),
                  const Spacer(),
                  SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                    child: Text(AppLocalizations.of(context)!.done, style: TextStyle(fontWeight: FontWeight.w900)),
                  )),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

