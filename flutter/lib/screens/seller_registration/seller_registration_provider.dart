import 'dart:typed_data';

import 'package:flutter/material.dart';

class SellerBusinessCategory {
  const SellerBusinessCategory({
    required this.id,
    required this.code,
    required this.nameEn,
    required this.nameRu,
    required this.nameHy,
  });

  final int id;
  final String code;
  final String nameEn;
  final String nameRu;
  final String nameHy;

  factory SellerBusinessCategory.fromJson(Map<String, dynamic> json) {
    return SellerBusinessCategory(
      id: json['id'] as int,
      code: json['code']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? '',
      nameRu: json['name_ru']?.toString() ?? '',
      nameHy: json['name_hy']?.toString() ?? '',
    );
  }

  String localizedName(String languageCode) {
    switch (languageCode) {
      case 'hy':
        return nameHy.isNotEmpty ? nameHy : nameEn;
      case 'ru':
        return nameRu.isNotEmpty ? nameRu : nameEn;
      default:
        return nameEn;
    }
  }
}

class SellerApplicationDocumentItem {
  final int id;
  final String documentType;
  final String originalName;
  final String? fileUrl;

  SellerApplicationDocumentItem({
    required this.id,
    required this.documentType,
    required this.originalName,
    this.fileUrl,
  });
}

class SellerRegistrationProvider extends ChangeNotifier {
  String _channelCode = '';

  String organizationName = '';
  String taxNumber = '';
  String address = '';

  double? latitude;
  double? longitude;

  String businessPhone = '';
  String businessEmail = '';

  String contactName = '';
  String contactPhone = '';
  String contactEmail = '';

  int? businessCategoryId;
  String businessCategoryCode = '';

  int? applicationId;
  final List<SellerApplicationDocumentItem> documents = [];

  String applicationStatus = '';
  String statusDisplay = '';
  String adminComment = '';
  bool isEditable = false;
  String? existingLogoUrl;

  String bankName = '';
  String iban = '';
  String accountHolderName = '';
  String publicDescription = '';
  Uint8List? logoBytes;
  String? logoFileName;

  String get channelCode => _channelCode;

  void setChannelCode(String value) {
    _channelCode = value.trim().toLowerCase();
    notifyListeners();
  }


  static String _phoneWithoutCountryCode(dynamic value) {
    final phone = value?.toString().trim() ?? '';
    return phone.startsWith('+374') ? phone.substring(4) : phone;
  }

  void loadFromApplication(
      Map<String, dynamic> application, {
        required List<String> channelCodes,
      }) {
    applicationId = int.tryParse(application['id']?.toString() ?? '');
    _channelCode = channelCodes.length > 1
        ? 'both'
        : (channelCodes.isEmpty ? '' : channelCodes.first);

    organizationName = application['organization_name']?.toString() ?? '';
    taxNumber = application['tax_number']?.toString() ?? '';
    address = application['address']?.toString() ?? '';
    latitude = double.tryParse(application['latitude']?.toString() ?? '');
    longitude = double.tryParse(application['longitude']?.toString() ?? '');
    businessPhone = _phoneWithoutCountryCode(application['business_phone']);
    businessEmail = application['business_email']?.toString() ?? '';
    contactName = application['contact_name']?.toString() ?? '';
    contactPhone = _phoneWithoutCountryCode(application['contact_phone']);
    contactEmail = application['contact_email']?.toString() ?? '';
    businessCategoryId = int.tryParse(
      application['business_category']?.toString() ?? '',
    );
    bankName = application['bank_name']?.toString() ?? '';
    iban = application['iban']?.toString() ?? '';
    accountHolderName = application['account_holder_name']?.toString() ?? '';
    publicDescription = application['public_description']?.toString() ?? '';
    existingLogoUrl = application['logo']?.toString();
    applicationStatus = application['status']?.toString() ?? '';
    statusDisplay = application['status_display']?.toString() ?? '';
    adminComment = application['admin_comment']?.toString() ?? '';
    isEditable = application['is_editable'] == true;

    final rawDocuments = application['documents'];
    documents.clear();
    if (rawDocuments is List) {
      documents.addAll(
        rawDocuments.whereType<Map>().map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return SellerApplicationDocumentItem(
            id: int.tryParse(item['id']?.toString() ?? '') ?? 0,
            documentType: item['document_type']?.toString() ?? 'other',
            originalName: item['original_name']?.toString() ?? '',
            fileUrl: item['file_url']?.toString(),
          );
        }).where((item) => item.id > 0),
      );
    }
    notifyListeners();
  }

  void applyApplicationState(Map<String, dynamic> application) {
    final parsedId = int.tryParse(application['id']?.toString() ?? '');
    if (parsedId != null) {
      applicationId = parsedId;
    }

    applicationStatus = application['status']?.toString() ?? applicationStatus;
    statusDisplay =
        application['status_display']?.toString() ?? statusDisplay;
    adminComment =
        application['admin_comment']?.toString() ?? adminComment;

    if (application.containsKey('is_editable')) {
      isEditable = application['is_editable'] == true;
    }

    final logo = application['logo']?.toString();
    if (logo != null && logo.isNotEmpty) {
      existingLogoUrl = logo;
    }

    notifyListeners();
  }

  void saveCompanyInfo({
    required String organizationName,
    required String taxNumber,
    required String address,
    required double latitude,
    required double longitude,
    required String businessPhone,
    required String businessEmail,
    required String contactName,
    required String contactPhone,
    required String contactEmail,
  }) {
    this.organizationName = organizationName.trim();
    this.taxNumber = taxNumber.trim();
    this.address = address.trim();

    this.latitude = latitude;
    this.longitude = longitude;

    this.businessPhone = businessPhone.trim();
    this.businessEmail = businessEmail.trim();

    this.contactName = contactName.trim();
    this.contactPhone = contactPhone.trim();
    this.contactEmail = contactEmail.trim();

    notifyListeners();
  }

  void saveCategory(SellerBusinessCategory category) {
    businessCategoryId = category.id;
    businessCategoryCode = category.code;
    notifyListeners();
  }

  void setApplicationId(int id) {
    applicationId = id;
    notifyListeners();
  }

  void setDocuments(
      List<SellerApplicationDocumentItem> value,
      ) {
    documents
      ..clear()
      ..addAll(value);

    notifyListeners();
  }

  void saveBankInfo({required String bankName, required String iban, required String accountHolderName, required String publicDescription}) {
    this.bankName = bankName.trim();
    this.iban = iban.trim();
    this.accountHolderName = accountHolderName.trim();
    this.publicDescription = publicDescription.trim();
    notifyListeners();
  }

  void setLogo({required Uint8List bytes, required String fileName}) {
    logoBytes = bytes;
    logoFileName = fileName;
    notifyListeners();
  }

  void clearLogo() {
    logoBytes = null;
    logoFileName = null;
    notifyListeners();
  }

  Map<String, dynamic> toDraftJson({int currentStep = 3}) {
    return {
      'requested_channel_code': channelCode,
      'organization_name': organizationName,
      'tax_number': taxNumber,
      'address': address,
      'latitude': latitude == null ? null : latitude!.toStringAsFixed(6),
      'longitude': longitude == null ? null : longitude!.toStringAsFixed(6),
      'business_phone': businessPhone,
      'business_email': businessEmail,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'business_category': businessCategoryId,
      'bank_name': bankName,
      'iban': iban,
      'account_holder_name': accountHolderName,
      'public_description': publicDescription,
      'current_step': currentStep,
    };
  }
}