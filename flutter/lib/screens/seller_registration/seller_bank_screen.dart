import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/download_bytes.dart';
import '../seller_agreement_view_screen.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import 'seller_registration_provider.dart';
import 'seller_registration_service.dart';
import 'seller_registration_success_screen.dart';
import 'widgets/seller_registration_header.dart';
import 'widgets/seller_step_indicator.dart';

class SellerBankScreen extends StatefulWidget {
  const SellerBankScreen({super.key});
  @override
  State<SellerBankScreen> createState() => _SellerBankScreenState();
}

class _SellerBankScreenState extends State<SellerBankScreen> {
  static const _accent = Color(0xFFD1BC00);
  final _formKey = GlobalKey<FormState>();
  final _bank = TextEditingController();
  final _iban = TextEditingController();
  final _holder = TextEditingController();
  final _description = TextEditingController();
  bool _ready = false;
  bool _loading = false;
  bool _showValidationErrors = false;
  bool _agreementAccepted = false;
  bool _showAgreementError = false;
  bool _agreementPreviewLoading = false;
  bool _agreementDownloading = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final p = context.read<SellerRegistrationProvider>();
    _bank.text = p.bankName; _iban.text = p.iban;
    _holder.text = p.accountHolderName; _description.text = p.publicDescription;
  }

  @override
  void dispose() {
    _bank.dispose(); _iban.dispose(); _holder.dispose(); _description.dispose();
    super.dispose();
  }

  SellerRegistrationService _service() => SellerRegistrationService(
    dio: Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 60))),
    baseUrl: ApiService.apiUrl,
  );

  String? _required(String? v) => v == null || v.trim().isEmpty ? AppLocalizations.of(context)!.requiredField : null;

  String _text({
    required String ru,
    required String en,
    required String hy,
  }) {
    return switch (Localizations.localeOf(context).languageCode) {
      'en' => en,
      'hy' => hy,
      _ => ru,
    };
  }

  String get _agreementLanguage {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'hy' || code == 'ru' ? code : 'en';
  }

  Future<int?> _agreementApplicationId() async {
    final applicationId =
        context.read<SellerRegistrationProvider>().applicationId;

    if (applicationId != null) return applicationId;
    if (!mounted) return null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.applicationNotFound,
        ),
      ),
    );

    return null;
  }

  Future<void> _viewAgreement() async {
    if (_loading || _agreementPreviewLoading) return;

    final applicationId = await _agreementApplicationId();
    if (applicationId == null || !mounted) return;

    setState(() => _agreementPreviewLoading = true);

    try {
      final preview = await _service().getAgencyAgreementPreview(
        applicationId: applicationId,
        language: _agreementLanguage,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SellerAgreementViewScreen(
            preview: preview,
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;

      final detail = e.response?.data is Map
          ? (e.response?.data as Map)['detail']?.toString()
          : null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail?.trim().isNotEmpty == true
                ? detail!
                : _text(
              ru: 'Не удалось открыть договор.',
              en: 'Could not open the agreement.',
              hy: 'Չհաջողվեց բացել պայմանագիրը։',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('AGREEMENT PREVIEW ERROR: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              ru: 'Не удалось открыть договор.',
              en: 'Could not open the agreement.',
              hy: 'Չհաջողվեց բացել պայմանագիրը։',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _agreementPreviewLoading = false);
      }
    }
  }

  Future<void> _downloadAgreement() async {
    if (_loading || _agreementDownloading) return;

    final applicationId = await _agreementApplicationId();
    if (applicationId == null || !mounted) return;

    setState(() => _agreementDownloading = true);

    try {
      final bytes = await _service().downloadAgencyAgreement(
        applicationId: applicationId,
      );

      final fileName = 'Appsosa_Agency_Agreement_$applicationId.docx';
      bool saved = false;

      if (kIsWeb) {
        saved = await downloadBytesInBrowser(
          bytes: bytes,
          fileName: fileName,
          mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      } else {
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: _text(
            ru: 'Сохранить агентский договор',
            en: 'Save Agency Agreement',
            hy: 'Պահպանել գործակալության պայմանագիրը',
          ),
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['docx'],
          bytes: bytes,
        );
        saved = savedPath != null;
      }

      if (!mounted || !saved) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              ru: 'Договор скачан.',
              en: 'Agreement downloaded.',
              hy: 'Համաձայնագիրը ներբեռնվել է։',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;

      final detail = e.response?.data is Map
          ? (e.response?.data as Map)['detail']?.toString()
          : null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail?.trim().isNotEmpty == true
                ? detail!
                : _text(
              ru: 'Не удалось скачать договор.',
              en: 'Could not download the agreement.',
              hy: 'Չհաջողվեց ներբեռնել պայմանագիրը։',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('AGREEMENT DOWNLOAD ERROR: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              ru: 'Не удалось скачать договор.',
              en: 'Could not download the agreement.',
              hy: 'Չհաջողվեց ներբեռնել պայմանագիրը։',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _agreementDownloading = false);
      }
    }
  }

  Future<void> _setLogoBytes({
    required List<int> bytes,
    required String fileName,
  }) async {
    if (bytes.length > 10 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.logoTooLarge10,
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    context.read<SellerRegistrationProvider>().setLogo(
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
    );
  }

  Future<void> _pickLogoFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    await _setLogoBytes(
      bytes: bytes,
      fileName: file.name,
    );
  }

  Future<void> _takeLogoPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        maxWidth: 2200,
        maxHeight: 2200,
        requestFullMetadata: false,
      );

      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      final fileName = photo.name.trim().isNotEmpty
          ? photo.name.trim()
          : 'company_logo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _setLogoBytes(
        bytes: bytes,
        fileName: fileName,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              ru: 'Не удалось сделать фото логотипа.',
              en: 'Could not take a photo of the logo.',
              hy: 'Չհաջողվեց լուսանկարել լոգոն։',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showLogoSourceSheet() async {
    if (_loading) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _text(
                    ru: 'Добавить логотип компании',
                    en: 'Add company logo',
                    hy: 'Ավելացնել ընկերության լոգոն',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _text(
                    ru: 'Выберите изображение с телефона или сделайте фото сейчас.',
                    en: 'Choose an image from your device or take a photo now.',
                    hy: 'Ընտրեք պատկերը հեռախոսից կամ լուսանկարեք հիմա։',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  onTap: () => Navigator.of(sheetContext).pop('device'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: _accent),
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF8D2),
                    child: Icon(
                      Icons.photo_library_outlined,
                      color: Color(0xFF7A6C00),
                    ),
                  ),
                  title: Text(
                    _text(
                      ru: 'Выбрать с телефона',
                      en: 'Choose from device',
                      hy: 'Ընտրել հեռախոսից',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _text(
                      ru: 'JPG, PNG или WEBP',
                      en: 'JPG, PNG or WEBP',
                      hy: 'JPG, PNG կամ WEBP',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  onTap: () => Navigator.of(sheetContext).pop('camera'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: _accent),
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF8D2),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      color: Color(0xFF7A6C00),
                    ),
                  ),
                  title: Text(
                    _text(
                      ru: 'Сделать фото',
                      en: 'Take photo',
                      hy: 'Լուսանկարել',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _text(
                      ru: 'Открыть камеру и сфотографировать логотип',
                      en: 'Open the camera and photograph the logo',
                      hy: 'Բացել տեսախցիկը և լուսանկարել լոգոն',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'camera') {
      await _takeLogoPhoto();
    } else if (action == 'device') {
      await _pickLogoFromDevice();
    }
  }

  Future<void> _submit() async {
    if (_loading) return;

    if (!_showValidationErrors) {
      setState(() => _showValidationErrors = true);
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_agreementAccepted) {
      setState(() => _showAgreementError = true);
      return;
    }

    final p = context.read<SellerRegistrationProvider>();
    final id = p.applicationId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.applicationNotFound)));
      return;
    }
    p.saveBankInfo(bankName: _bank.text, iban: _iban.text, accountHolderName: _holder.text, publicDescription: _description.text);
    setState(() => _loading = true);
    try {
      final service = _service();
      final saved = await service.saveBankAndBranding(
        applicationId: id,
        bankName: p.bankName,
        iban: p.iban,
        accountHolderName: p.accountHolderName,
        publicDescription: p.publicDescription,
        logoBytes: p.logoBytes,
        logoFileName: p.logoFileName,
      );
      p.applyApplicationState(saved);

      final result = await service.submitApplication(
        applicationId: id,
        agreementAccepted: true,
        agreementLanguage: _agreementLanguage,
      );
      p.applyApplicationState(result);

      if (!mounted) return;

      // Replace only the bank screen with the success screen.
      // The registration route stays in the stack until the user presses
      // "Done". When SuccessScreen closes the whole registration flow,
      // ProfileScreen's awaited Navigator.push completes and reloads
      // /seller-applications/my/ from the backend.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SellerRegistrationSuccessScreen(
            applicationId: id,
            status: result['status']?.toString() ?? 'pending',
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?.toString() ?? e.message ?? AppLocalizations.of(context)!.networkError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.applicationSubmitFailed(msg)), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.applicationSubmitFailed(e.toString())), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _d(String label) => InputDecoration(
    labelText: label, filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 1.6)),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SellerRegistrationProvider>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/auth_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.white),
          ),
          SafeArea(
            child: Column(children: [
              SellerRegistrationHeader(onBack: () => Navigator.of(context).maybePop()),
              const SellerStepIndicator(currentStep: 5),
              const SizedBox(height: 14),
              Expanded(child: Form(
                key: _formKey,
                autovalidateMode: _showValidationErrors
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
                  Text(AppLocalizations.of(context)!.bankDetails, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(AppLocalizations.of(context)!.bankDetailsSubtitle, style: TextStyle(color: Colors.black54, height: 1.4)),
                  const SizedBox(height: 22),
                  TextFormField(controller: _bank, validator: _required, decoration: _d(AppLocalizations.of(context)!.bankName)),
                  const SizedBox(height: 14),
                  TextFormField(controller: _iban, validator: _required, textCapitalization: TextCapitalization.characters, decoration: _d('IBAN')),
                  const SizedBox(height: 14),
                  TextFormField(controller: _holder, validator: _required, decoration: _d(AppLocalizations.of(context)!.accountHolder)),
                  const SizedBox(height: 14),
                  TextFormField(controller: _description, minLines: 4, maxLines: 6, decoration: _d(AppLocalizations.of(context)!.companyDescriptionOptional)),
                  const SizedBox(height: 20),
                  Text(AppLocalizations.of(context)!.companyLogo, style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (p.logoBytes != null)
                    Row(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(p.logoBytes!, width: 82, height: 82, fit: BoxFit.cover)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p.logoFileName ?? AppLocalizations.of(context)!.logo,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: _loading ? null : _showLogoSourceSheet,
                        icon: const Icon(Icons.photo_camera_outlined),
                      ),
                      IconButton(
                        onPressed: _loading ? null : p.clearLogo,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ])
                  else
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _showLogoSourceSheet,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(AppLocalizations.of(context)!.chooseLogo),
                    ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _showAgreementError && !_agreementAccepted
                            ? Colors.red.shade300
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(
                            ru: 'Агентский договор',
                            en: 'Agency Agreement',
                            hy: 'Գործակալության պայմանագիր',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF222222),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _text(
                            ru: 'Перед отправкой заявки ознакомьтесь с условиями договора. Вы можете открыть его в приложении или скачать DOCX.',
                            en: 'Before submitting your application, review the agreement. You can open it in the app or download the DOCX.',
                            hy: 'Դիմումն ուղարկելուց առաջ ծանոթացեք պայմանագրի պայմաններին։ Կարող եք այն բացել հավելվածում կամ ներբեռնել DOCX-ը։',
                          ),
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Tooltip(
                              message: _text(
                                ru: 'Просмотреть договор',
                                en: 'View agreement',
                                hy: 'Դիտել պայմանագիրը',
                              ),
                              child: SizedBox(
                                width: 58,
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: _loading || _agreementPreviewLoading
                                      ? null
                                      : _viewAgreement,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF6F6200),
                                    side: const BorderSide(color: _accent),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _agreementPreviewLoading
                                      ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _accent,
                                    ),
                                  )
                                      : const Icon(
                                    Icons.visibility_outlined,
                                    size: 21,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Tooltip(
                              message: _text(
                                ru: 'Скачать договор',
                                en: 'Download agreement',
                                hy: 'Ներբեռնել պայմանագիրը',
                              ),
                              child: SizedBox(
                                width: 58,
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: _loading || _agreementDownloading
                                      ? null
                                      : _downloadAgreement,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF6F6200),
                                    side: const BorderSide(color: _accent),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _agreementDownloading
                                      ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _accent,
                                    ),
                                  )
                                      : const Icon(
                                    Icons.download_outlined,
                                    size: 21,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _agreementAccepted,
                              activeColor: _accent,
                              onChanged: _loading
                                  ? null
                                  : (value) {
                                setState(() {
                                  _agreementAccepted = value == true;
                                  if (_agreementAccepted) {
                                    _showAgreementError = false;
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  _text(
                                    ru: 'Я ознакомился с Агентским договором и Условиями предоставления услуг и согласен с ними.',
                                    en: 'I have read and agree to the Agency Agreement and Terms of Service.',
                                    hy: 'Ես կարդացել և համաձայն եմ Գործակալության պայմանագրին և Ծառայության պայմաններին։',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_showAgreementError && !_agreementAccepted)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 2, 8, 6),
                            child: Text(
                              _text(
                                ru: 'Чтобы отправить заявку, подтвердите согласие с договором.',
                                en: 'Accept the agreement before submitting the application.',
                                hy: 'Դիմումն ուղարկելու համար հաստատեք համաձայնությունը պայմանագրին։',
                              ),
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(height: 54, child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                    child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text(AppLocalizations.of(context)!.submitApplication, style: TextStyle(fontWeight: FontWeight.w800)),
                  )),
                ]),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

