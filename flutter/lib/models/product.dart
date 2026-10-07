import '../services/api_service.dart';
import 'tag.dart';

class Product {
  final String name;
  final String imageUrl;
  final String imageCardUrl;
  final String imageThumbUrl;
  final String slug;
  final double price;
  final double getDiscountPrice;
  final String type;
  final String? description;
  final Company company;
  final List<Tag>? tag;
  final int count;
  final bool dineInOnly;

  // Seller statistics from backend
  final int soldCount;
  final int viewsCount;
  final int sharesCount;

  /// Pickup window for HOT products. Backend returns timezone-aware ISO 8601.
  final String? pickupFrom;
  final String? pickupUntil;

  /// Compatibility alias returned by the backend during migration.
  final String? pickupDeadline;
  final bool isActive;
  final String inactiveReason;

  final String? packageQuantity;
  final String? weight;
  final String? deliveryType;
  final int? deliveryDays;
  final int? deliveryRadiusKm;
  final String? locationAddress;
  final double? locationLatitude;
  final double? locationLongitude;
  final String? expirationDate;
  final String? canUseUntil;

  final bool isPromoted;
  final String? promotionUntil;

  Product({
    required this.name,
    required this.imageUrl,
    this.imageCardUrl = '',
    this.imageThumbUrl = '',
    required this.slug,
    required this.price,
    required this.getDiscountPrice,
    required this.type,
    this.description,
    required this.company,
    this.tag,
    required this.count,
    this.dineInOnly = false,
    this.soldCount = 0,
    this.viewsCount = 0,
    this.sharesCount = 0,
    this.pickupFrom,
    this.pickupUntil,
    this.pickupDeadline,
    this.isActive = true,
    this.inactiveReason = '',
    this.packageQuantity,
    this.weight,
    this.deliveryType,
    this.deliveryDays,
    this.deliveryRadiusKm,
    this.locationAddress,
    this.locationLatitude,
    this.locationLongitude,
    this.expirationDate,
    this.canUseUntil,

    this.isPromoted = false,
    this.promotionUntil,
  });

  double get discountPrice => getDiscountPrice;

  /// 640 px image for cards/lists. Falls back to the main image for old products.
  String get cardImageUrl =>
      imageCardUrl.trim().isNotEmpty ? imageCardUrl : imageUrl;

  /// 320 px image for compact lists/cart/orders. Falls back to the main image.
  String get thumbImageUrl =>
      imageThumbUrl.trim().isNotEmpty ? imageThumbUrl : imageUrl;

  static const Duration armeniaUtcOffset = Duration(hours: 4);

  static DateTime nowInArmenia() {
    return DateTime.now().toUtc().add(armeniaUtcOffset);
  }

  static DateTime? parseArmeniaDateTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return null;

    return parsed.toUtc().add(armeniaUtcOffset);
  }

  static DateTime armeniaWallTimeToUtc(DateTime wallTime) {
    return DateTime.utc(
      wallTime.year,
      wallTime.month,
      wallTime.day,
      wallTime.hour,
      wallTime.minute,
      wallTime.second,
    ).subtract(armeniaUtcOffset);
  }

  static String armeniaWallTimeToIso(DateTime wallTime) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${wallTime.year.toString().padLeft(4, '0')}-'
        '${two(wallTime.month)}-${two(wallTime.day)}T'
        '${two(wallTime.hour)}:${two(wallTime.minute)}:'
        '${two(wallTime.second)}+04:00';
  }

  DateTime? get pickupFromArmenia => parseArmeniaDateTime(pickupFrom);
  DateTime? get pickupUntilArmenia => parseArmeniaDateTime(pickupUntil);

  bool get pickupExpired {
    if (type.toLowerCase() != 'hot') return false;

    final value = pickupUntil;
    if (value == null || value.trim().isEmpty) return true;

    final instant = DateTime.tryParse(value);
    if (instant == null) return true;

    return !instant.isAfter(DateTime.now());
  }

  bool get isAvailableForSale {
    if (!isActive || count <= 0) return false;
    if (type.toLowerCase() == 'hot' && pickupExpired) return false;
    return true;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    List<Tag>? tagList;

    if (json['tag'] != null && json['tag'] is List) {
      tagList = (json['tag'] as List)
          .map((tagJson) => Tag.fromJson(tagJson))
          .toList();
    }

    return Product(
      name: json['name']?.toString() ?? '',
      imageUrl: ApiService.fixImageUrl(json['image_url']?.toString() ?? ''),
      imageCardUrl: ApiService.fixImageUrl(
        json['image_card_url']?.toString() ?? '',
      ),
      imageThumbUrl: ApiService.fixImageUrl(
        json['image_thumb_url']?.toString() ?? '',
      ),
      slug: json['slug']?.toString() ?? '',
      price: _parseDouble(json['price']),
      getDiscountPrice: _parseDouble(json['get_discount_price']),
      type: json['type']?.toString() ?? '',
      description: json['description']?.toString(),
      company: Company.fromJson(json['company'] ?? {}),
      tag: tagList,
      count: int.tryParse(json['count']?.toString() ?? '0') ?? 0,
      dineInOnly: json['dine_in_only'] == true ||
          json['dine_in_only']?.toString().toLowerCase() == 'true',
      soldCount: int.tryParse(json['sold_count']?.toString() ?? '0') ?? 0,
      viewsCount: int.tryParse(json['views_count']?.toString() ?? '0') ?? 0,
      sharesCount: int.tryParse(json['shares_count']?.toString() ?? '0') ?? 0,
      pickupFrom: json['pickup_from']?.toString(),
      pickupUntil: json['pickup_until']?.toString() ??
          json['pickup_deadline']?.toString(),
      pickupDeadline: json['pickup_deadline']?.toString() ??
          json['pickup_until']?.toString(),
      isActive: json['is_active'] != false,
      inactiveReason: json['inactive_reason']?.toString() ?? '',
      packageQuantity: json['package_quantity']?.toString(),
      weight: json['weight']?.toString(),

      deliveryType: json['delivery_type']?.toString(),

      deliveryDays: json['delivery_days'] == null
          ? null
          : int.tryParse(json['delivery_days'].toString()),

      deliveryRadiusKm: json['delivery_radius_km'] == null
          ? null
          : int.tryParse(json['delivery_radius_km'].toString()),

      locationAddress: json['location_address']?.toString(),
      locationLatitude: json['location_latitude'] == null
          ? null
          : _parseDouble(json['location_latitude']),
      locationLongitude: json['location_longitude'] == null
          ? null
          : _parseDouble(json['location_longitude']),

      expirationDate: json['expiration_date']?.toString(),

      canUseUntil: json['can_use_until']?.toString(),

      isPromoted: json['is_promoted'] == true,

      promotionUntil: json['promotion_until']?.toString(),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final cleaned = value.trim().replaceAll(',', '.');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'image_url': imageUrl,
      'image_card_url': cardImageUrl,
      'image_thumb_url': thumbImageUrl,
      'slug': slug,
      'price': price.toString(),
      'get_discount_price': getDiscountPrice.toString(),
      'type': type,
      'description': description,
      'company': company.toJson(),
      'tag': tag?.map((t) => t.toJson()).toList(),
      'count': count,
      'dine_in_only': dineInOnly,
      'sold_count': soldCount,
      'views_count': viewsCount,
      'shares_count': sharesCount,
      'pickup_from': pickupFrom,
      'pickup_until': pickupUntil,
      'pickup_deadline': pickupDeadline ?? pickupUntil,
      'is_active': isActive,
      'inactive_reason': inactiveReason,
      'package_quantity': packageQuantity,
      'weight': weight,
      'delivery_type': deliveryType,
      'delivery_days': deliveryDays,
      'delivery_radius_km': deliveryRadiusKm,
      'location_address': locationAddress,
      'location_latitude': locationLatitude,
      'location_longitude': locationLongitude,
      'expiration_date': expirationDate,
      'can_use_until': canUseUntil,

      'is_promoted': isPromoted,
      'promotion_until': promotionUntil,
    };
  }

  String get shopName => company.name ?? company.address;
  String get displayShopName => company.name ?? company.address;
}

class Company {
  final int id;
  final String imageUrl;
  final String address;
  final String slug;
  final String? name;
  final String? phone;
  final String? description;
  final String? latitude;
  final String? longitude;
  final String? openTime;
  final String? closeTime;
  final double rating;
  final int reviewsCount;
  final int successfulOrders;
  final int companyScore;
  final bool hasHotProducts;

  // Новые поля для средних оценок
  final double avgQuality;
  final double avgValue;
  final double avgDescriptionMatch;
  final double avgService;

  // 👇 ДОБАВЛЕНЫ ПОЛЯ ДЛЯ СОЦСЕТЕЙ
  final String? instagram;
  final String? facebook;

  Company({
    required this.id,
    required this.imageUrl,
    required this.address,
    required this.slug,
    this.name,
    this.phone,
    this.description,
    this.latitude,
    this.longitude,
    this.openTime,
    this.closeTime,
    this.rating = 0,
    this.reviewsCount = 0,
    this.successfulOrders = 0,
    this.companyScore = 0,
    this.hasHotProducts = false,
    this.avgQuality = 0,
    this.avgValue = 0,
    this.avgDescriptionMatch = 0,
    this.avgService = 0,
    // 👇 ДОБАВЛЕНЫ В КОНСТРУКТОР
    this.instagram,
    this.facebook,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      imageUrl: ApiService.fixImageUrl(json['image_url']?.toString() ?? ''),
      address: json['address']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      description: json['description']?.toString(),
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      openTime: json['open_time']?.toString(),
      closeTime: json['close_time']?.toString(),
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      reviewsCount: int.tryParse(json['reviews_count']?.toString() ?? '0') ?? 0,
      successfulOrders: int.tryParse(json['successful_orders']?.toString() ?? '0') ?? 0,
      companyScore: int.tryParse(json['company_score']?.toString() ?? '0') ?? 0,
      hasHotProducts: json['has_hot_products'] == true,
      avgQuality: double.tryParse(json['avg_quality']?.toString() ?? '0') ?? 0,
      avgValue: double.tryParse(json['avg_value']?.toString() ?? '0') ?? 0,
      avgDescriptionMatch: double.tryParse(json['avg_description_match']?.toString() ?? '0') ?? 0,
      avgService: double.tryParse(json['avg_service']?.toString() ?? '0') ?? 0,
      // 👇 ДОБАВЛЕНЫ В fromJson()
      instagram: json['instagram']?.toString(),
      facebook: json['facebook']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'address': address,
      'slug': slug,
      'name': name,
      'phone': phone,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'open_time': openTime,
      'close_time': closeTime,
      'rating': rating,
      'reviews_count': reviewsCount,
      'successful_orders': successfulOrders,
      'company_score': companyScore,
      'has_hot_products': hasHotProducts,
      'avg_quality': avgQuality,
      'avg_value': avgValue,
      'avg_description_match': avgDescriptionMatch,
      'avg_service': avgService,
      // 👇 ДОБАВЛЕНЫ В toJson()
      'instagram': instagram,
      'facebook': facebook,
    };
  }
}