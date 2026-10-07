import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import 'seller_registration_provider.dart';
import 'seller_registration_service.dart';
import 'seller_bank_screen.dart';
import 'widgets/seller_registration_header.dart';
import 'widgets/seller_step_indicator.dart';

String localizedDocumentType(BuildContext context, String code) {
  final l10n = AppLocalizations.of(context)!;
  return switch (code) {
    'registration' => l10n.docRegistration,
    'tax' => l10n.docTax,
    'license' => l10n.docLicense,
    'food_safety' => l10n.docFoodSafety,
    'certificate' => l10n.docCertificate,
    'identity' => l10n.docIdentity,
    'bank' => l10n.docBank,
    _ => l10n.docOther,
  };
}


class SellerDocumentsScreen extends StatefulWidget {
  const SellerDocumentsScreen({super.key});

  @override
  State<SellerDocumentsScreen> createState() =>
      _SellerDocumentsScreenState();
}

class _SellerDocumentsScreenState extends State<SellerDocumentsScreen> {
  static const Color _accent = Color(0xFFD1BC00);

  String _selectedDocumentType = 'registration';
  bool _isUploading = false;
  bool _showDocumentsError = false;
  final List<Map<String, dynamic>> _uploadedDocuments = [];
  bool _initializedDocuments = false;
  final ImagePicker _imagePicker = ImagePicker();


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedDocuments) return;
    _initializedDocuments = true;
    final provider = context.read<SellerRegistrationProvider>();
    _uploadedDocuments.addAll(
      provider.documents.map((document) => {
        'id': document.id,
        'document_type': document.documentType,
        'original_name': document.originalName,
        'file_url': document.fileUrl,
      }),
    );
  }

  SellerRegistrationService _createService() {
    return SellerRegistrationService(
      dio: Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          headers: const {'Accept': 'application/json'},
        ),
      ),
      baseUrl: ApiService.apiUrl,
    );
  }

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

  int? _applicationIdOrShowError() {
    final applicationId =
        context.read<SellerRegistrationProvider>().applicationId;

    if (applicationId != null) return applicationId;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.createApplicationFirst),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return null;
  }

  Future<void> _uploadDocumentBytes({
    required int applicationId,
    required List<int> bytes,
    required String fileName,
  }) async {
    if (_isUploading) return;

    if (bytes.length > 20 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.fileTooLarge20),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uploaded = await _createService().uploadDocument(
        applicationId: applicationId,
        documentType: _selectedDocumentType,
        bytes: Uint8List.fromList(bytes),
        fileName: fileName,
      );

      if (!mounted) return;

      setState(() {
        _uploadedDocuments.add(uploaded);
        _showDocumentsError = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.documentUploaded),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final message =
          e.response?.data?.toString() ??
              e.message ??
              AppLocalizations.of(context)!.networkError;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.documentUploadFailed(message),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.documentUploadFailed(e.toString()),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _showUploadSourceSheet() async {
    if (_isUploading) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    ru: 'Добавить документ',
                    en: 'Add document',
                    hy: 'Ավելացնել փաստաթուղթ',
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
                    ru: 'Выберите готовый файл или сфотографируйте документ сейчас.',
                    en: 'Choose an existing file or take a photo of the document now.',
                    hy: 'Ընտրեք պատրաստի ֆայլ կամ լուսանկարեք փաստաթուղթը հիմա։',
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
                      Icons.folder_open_outlined,
                      color: Color(0xFF7A6C00),
                    ),
                  ),
                  title: Text(
                    _text(
                      ru: 'Выбрать с телефона',
                      en: 'Choose from device',
                      hy: 'Ընտրել հեռախոսից',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _text(
                      ru: 'Фото, PDF или другой поддерживаемый файл',
                      en: 'Photo, PDF or another supported file',
                      hy: 'Լուսանկար, PDF կամ այլ աջակցվող ֆայլ',
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
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _text(
                      ru: 'Открыть камеру и сфотографировать документ',
                      en: 'Open the camera and photograph the document',
                      hy: 'Բացել տեսախցիկը և լուսանկարել փաստաթուղթը',
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
      await _takePhotoAndUploadDocument();
    } else if (action == 'device') {
      await _pickAndUploadDocument();
    }
  }

  Future<void> _takePhotoAndUploadDocument() async {
    if (_isUploading) return;

    final applicationId = _applicationIdOrShowError();
    if (applicationId == null) return;

    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        maxWidth: 2600,
        maxHeight: 3600,
        requestFullMetadata: false,
      );

      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      if (!mounted) return;

      final originalName = photo.name.trim();
      final fileName = originalName.isNotEmpty
          ? originalName
          : 'seller_document_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _uploadDocumentBytes(
        applicationId: applicationId,
        bytes: bytes,
        fileName: fileName,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              ru: 'Не удалось сделать фото документа.',
              en: 'Could not take a photo of the document.',
              hy: 'Չհաջողվեց լուսանկարել փաստաթուղթը։',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickAndUploadDocument() async {
    if (_isUploading) return;

    final applicationId = _applicationIdOrShowError();
    if (applicationId == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'doc',
        'docx',
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.single;
    final bytes = pickedFile.bytes;

    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.fileReadFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _uploadDocumentBytes(
      applicationId: applicationId,
      bytes: bytes,
      fileName: pickedFile.name,
    );
  }

  Future<void> _deleteDocument(Map<String, dynamic> document) async {
    final id = int.tryParse(document['id'].toString());
    if (id == null) return;

    try {
      await _createService().deleteDocument(id);
      if (!mounted) return;
      setState(() => _uploadedDocuments.remove(document));
    } on DioException catch (e) {
      if (!mounted) return;
      final message = e.response?.data?.toString() ?? e.message ?? AppLocalizations.of(context)!.networkError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.documentDeleteFailed(message))),
      );
    }
  }

  void _next() {
    if (_uploadedDocuments.isEmpty) {
      setState(() => _showDocumentsError = true);
      return;
    }

    final provider = context.read<SellerRegistrationProvider>();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const SellerBankScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              children: [
                SellerRegistrationHeader(
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SellerStepIndicator(currentStep: 4),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      Text(
                        AppLocalizations.of(context)!.documents,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _text(
                          ru: 'Чтобы укрепить доверие нашего сообщества и обеспечить полную прозрачность, мы просим вас загрузить соответствующие разрешения на ведение бизнеса и сертификаты безопасности пищевых продуктов. Эти документы позволяют нам подтвердить, что все партнеры соответствуют высоким стандартам, принятым в сфере общественного питания, обеспечивая безопасный и надежный опыт для всех наших пользователей.',
                          en: 'As part of our commitment to quality and safety, we require all partners to provide their valid business licenses and food industry permits. Please upload your certifications below. This information is essential for maintaining a secure marketplace and verifying your business for the community.',
                          hy: 'Մեր համայնքի վստահությունը ձեռք բերելու և թափանցիկությունն ապահովելու համար խնդրում ենք վերբեռնել ձեր գործունեության համապատասխան թույլտվությունները և սննդի անվտանգության հավաստագրերը: Այս փաստաթղթերը մեզ հնարավորություն են տալիս հաստատել, որ բոլոր գործընկերները համապատասխանում են սննդի ոլորտում ընդունված բարձր չափանիշներին, ինչը ապահով և հուսալի փորձ է երաշխավորում մեր օգտատերերի համար։',
                        ),
                        style: const TextStyle(
                          height: 1.38,
                          fontSize: 13,
                          color: Color(0xFF333333),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.documentsSubtitle,
                        style: const TextStyle(
                          height: 1.35,
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: _selectedDocumentType,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.documentType,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _accent),
                          ),
                        ),
                        items: const ['registration', 'tax', 'license', 'food_safety', 'certificate', 'identity', 'bank', 'other']
                            .map(
                              (entry) => DropdownMenuItem<String>(
                            value: entry,
                            child: Text(localizedDocumentType(context, entry)),
                          ),
                        )
                            .toList(),
                        onChanged: _isUploading
                            ? null
                            : (value) {
                          if (value != null) {
                            setState(() => _selectedDocumentType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isUploading
                              ? null
                              : _showUploadSourceSheet,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accent,
                            side: const BorderSide(
                              color: _accent,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                          ),
                          label: Text(
                            _text(
                              ru: 'Загрузить фото/файл',
                              en: 'Upload photo/file',
                              hy: 'Վերբեռնել լուսանկար/ֆայլ',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (_isUploading) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: _accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              AppLocalizations.of(context)!.uploading,
                              style: const TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_showDocumentsError) ...[
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.uploadAtLeastOneDocument,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_uploadedDocuments.isNotEmpty) ...[
                        Text(
                          AppLocalizations.of(context)!.uploadedDocuments,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._uploadedDocuments.map((document) {
                          final type = document['document_type']?.toString() ?? 'other';
                          final name = document['original_name']?.toString().trim();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const Icon(
                                Icons.description_outlined,
                                color: _accent,
                              ),
                              title: Text(
                                name == null || name.isEmpty
                                    ? AppLocalizations.of(context)!.document
                                    : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(localizedDocumentType(context, type)),
                              trailing: IconButton(
                                onPressed: () => _deleteDocument(document),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: AppLocalizations.of(context)!.delete,
                              ),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.next,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
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

