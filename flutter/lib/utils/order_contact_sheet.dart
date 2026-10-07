// lib/utils/order_contact_sheet.dart

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import 'app_feedback.dart';
import 'armenian_phone.dart';

/// Ensures the buyer has the contact data required for the current order.
///
/// Rules:
/// - every order requires a phone number;
/// - delivery orders additionally require an address;
/// - saved data is stored in Profile and reused for the next order;
/// - only one contact sheet can be open at a time.
Future<bool> ensureOrderContactData(
    BuildContext context, {
      required bool requireAddress,
    }) async {
  const actionKey = 'order.contact-data';

  if (!AppActionGuard.tryLock(actionKey)) {
    return false;
  }

  try {
    Map<String, dynamic> profile;

    try {
      profile = await ApiService.getProfile();
    } catch (_) {
      if (context.mounted) {
        AppFeedback.error(
          context,
          AppLocalizations.of(context)!.profileSaveError,
          key: 'order.contact.profile-load-error',
        );
      }
      return false;
    }

    final initialPhone = profile['phone']?.toString().trim() ?? '';
    final initialAddress = profile['address']?.toString().trim() ?? '';

    final hasPhone = ArmenianPhone.isValid(initialPhone);
    final hasAddress = initialAddress.isNotEmpty;

    if (hasPhone && (!requireAddress || hasAddress)) {
      return true;
    }

    if (!context.mounted) return false;

    return await _showOrderContactSheet(
      context,
      initialPhone: initialPhone,
      initialAddress: initialAddress,
      requireAddress: requireAddress,
    );
  } finally {
    AppActionGuard.unlock(actionKey);
  }
}

Future<bool> _showOrderContactSheet(
    BuildContext parentContext, {
      required String initialPhone,
      required String initialAddress,
      required bool requireAddress,
    }) async {
  final l10n = AppLocalizations.of(parentContext)!;
  final phoneController = TextEditingController(
    text: ArmenianPhone.formatLocal(initialPhone),
  );
  final addressController = TextEditingController(text: initialAddress);
  bool saving = false;

  final result = await showModalBottomSheet<bool>(
    context: parentContext,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (_, setModalState) {
          Future<void> saveAndClose() async {
            if (saving) return;

            final phone = phoneController.text.trim();
            final localPhone = ArmenianPhone.localDigits(phone);
            final address = addressController.text.trim();

            if (localPhone.isEmpty) {
              AppFeedback.warning(
                parentContext,
                requireAddress && address.isEmpty
                    ? l10n.enterPhoneAndAddress
                    : l10n.enterPhoneNumber,
                key: 'order.contact.phone-missing',
              );
              return;
            }

            if (localPhone.length != ArmenianPhone.localDigitsLength) {
              final languageCode =
                  Localizations.localeOf(parentContext).languageCode;
              final message = switch (languageCode) {
                'ru' => 'Введите 8 цифр: +374 XX-XX-XX-XX',
                'hy' => 'Մուտքագրեք 8 թվանշան՝ +374 XX-XX-XX-XX',
                _ => 'Enter 8 digits: +374 XX-XX-XX-XX',
              };

              AppFeedback.warning(
                parentContext,
                message,
                key: 'order.contact.phone-invalid',
              );
              return;
            }

            if (requireAddress && address.isEmpty) {
              AppFeedback.warning(
                parentContext,
                l10n.enterDeliveryAddress,
                key: 'order.contact.address-missing',
              );
              return;
            }

            setModalState(() => saving = true);

            try {
              await ApiService.updateProfile(
                phone: ArmenianPhone.normalize(phone),
                // Do not erase a previously saved address for a phone-only
                // order such as HOT pickup.
                address: requireAddress ? address : initialAddress,
              );

              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop(true);
            } catch (_) {
              if (sheetContext.mounted) {
                setModalState(() => saving = false);
              }

              if (parentContext.mounted) {
                AppFeedback.error(
                  parentContext,
                  l10n.profileSaveError,
                  key: 'order.contact.save-error',
                );
              }
            }
          }

          final mediaQuery = MediaQuery.of(sheetContext);

          return SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 12),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: mediaQuery.viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        requireAddress
                            ? l10n.deliveryDataTitle
                            : l10n.orderPhoneTitle,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        requireAddress
                            ? l10n.deliveryDataDescription
                            : l10n.orderPhoneDescription,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _OrderContactField(
                        controller: phoneController,
                        label: l10n.profilePhone,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        armenianPhone: true,
                      ),
                      if (requireAddress) ...[
                        const SizedBox(height: 12),
                        _OrderContactField(
                          controller: addressController,
                          label: l10n.deliveryAddress,
                          icon: Icons.location_on_outlined,
                          keyboardType: TextInputType.streetAddress,
                          maxLines: 3,
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: saving ? null : saveAndClose,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD1BC00),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: saving
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            requireAddress
                                ? l10n.saveAndCheckout
                                : l10n.saveAndContinue,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  phoneController.dispose();
  addressController.dispose();

  return result == true;
}

class _OrderContactField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool armenianPhone;

  const _OrderContactField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.armenianPhone = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection:
      armenianPhone ? TextDirection.ltr : null,
      inputFormatters: armenianPhone
          ? const [ArmenianPhoneInputFormatter()]
          : null,
      minLines: 1,
      maxLines: maxLines,
      textInputAction:
      maxLines > 1 ? TextInputAction.newline : TextInputAction.done,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: armenianPhone ? '+374 ' : null,
        prefixStyle: armenianPhone
            ? const TextStyle(
          color: Color(0xFF333333),
          fontWeight: FontWeight.w800,
        )
            : null,
        hintText: armenianPhone ? 'XX-XX-XX-XX' : null,
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFD1BC00),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
