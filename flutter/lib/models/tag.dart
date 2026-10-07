// lib/models/tag.dart

class Tag {
  static const Set<String> _supportedLanguages = {'ru', 'en', 'hy'};
  static String _languageCode = 'en';

  final String _fallbackName;
  final String nameRu;
  final String nameEn;
  final String nameHy;
  final String slug;
  final int productsCount;
  final String imageUrl;

  Tag({
    required String name,
    String? nameRu,
    String? nameEn,
    String? nameHy,
    required this.slug,
    required this.productsCount,
    required this.imageUrl,
  })  : _fallbackName = name.trim(),
        nameRu = (nameRu ?? '').trim(),
        nameEn = (nameEn ?? '').trim(),
        nameHy = (nameHy ?? '').trim();

  static void setLanguageCode(String code) {
    final normalized = code.trim().toLowerCase().split('-').first;
    _languageCode = _supportedLanguages.contains(normalized) ? normalized : 'en';
  }

  static String get languageCode => _languageCode;

  String get name {
    switch (_languageCode) {
      case 'ru':
        return _firstNonEmpty([nameRu, _fallbackName, nameEn, nameHy]);
      case 'hy':
        return _firstNonEmpty([nameHy, _fallbackName, nameRu, nameEn]);
      case 'en':
      default:
        return _firstNonEmpty([nameEn, _fallbackName, nameRu, nameHy]);
    }
  }

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      // `name` is kept as a fallback for compatibility with an older backend
      // and is also the currently localized value on the new backend.
      name: json['name'] as String? ?? '',
      nameRu: json['name_ru'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      nameHy: json['name_hy'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      productsCount: json['products_count'] as int? ?? 0,
      imageUrl: _fixImageUrl(
        json['image_url'] as String? ?? '',
      ),
    );
  }

  static String _fixImageUrl(String url) {
    if (url.isEmpty) return '';

    return url
        .replaceAll(
      'http://127.0.0.1:8000',
      'http://85.29.147.68',
    )
        .replaceAll(
      'https://127.0.0.1:8000',
      'http://85.29.147.68',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'name_ru': nameRu,
      'name_en': nameEn,
      'name_hy': nameHy,
      'slug': slug,
      'products_count': productsCount,
      'image_url': imageUrl,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Tag && other.slug == slug;
  }

  @override
  int get hashCode => slug.hashCode;
}
