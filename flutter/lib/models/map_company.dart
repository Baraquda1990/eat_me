import '../services/api_service.dart';

class MapCompany {
  final int id;  // ← ДОБАВЛЕНО
  final String name;
  final String slug;
  final double latitude;
  final double longitude;
  final String address;
  final String instagram;
  final String facebook;
  final String imageUrl;
  final String description;
  final String? openTime;
  final String? closeTime;
  final double rating;
  final int reviewsCount;

  MapCompany({
    required this.id,  // ← ДОБАВЛЕНО
    required this.name,
    required this.slug,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.imageUrl,
    required this.description,
    this.openTime,
    this.closeTime,
    this.rating = 0,
    this.reviewsCount = 0,
    this.instagram = '',
    this.facebook = '',
  });

  factory MapCompany.fromJson(Map<String, dynamic> json) {
    return MapCompany(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '') ?? 0,
      address: json['address']?.toString() ?? '',
      imageUrl: ApiService.fixImageUrl(json['image_url']?.toString() ?? ''),
      description: json['description']?.toString() ?? '',
      openTime: json['open_time']?.toString(),
      closeTime: json['close_time']?.toString(),
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      reviewsCount: int.tryParse(json['reviews_count']?.toString() ?? '0') ?? 0,
      instagram: json['instagram']?.toString() ?? '',
      facebook: json['facebook']?.toString() ?? '',
    );
  }
}