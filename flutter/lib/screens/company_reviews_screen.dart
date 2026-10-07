// lib/screens/company_reviews_screen.dart

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class CompanyReviewsScreen extends StatefulWidget {
  const CompanyReviewsScreen({
    super.key,
    required this.company,
  });

  final Company company;

  @override
  State<CompanyReviewsScreen> createState() => _CompanyReviewsScreenState();
}

class _CompanyReviewsScreenState extends State<CompanyReviewsScreen> {
  static const Color _accent = Color(0xFFD1BC00);

  late Future<List<Map<String, dynamic>>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _reviewsFuture = ApiService.getCompanyReviews(
      companySlug: widget.company.slug,
    );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _reviewsFuture;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(
      value?.toString().trim().replaceAll(',', '.') ?? '',
    ) ??
        0;
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(local.day)}.${two(local.month)}.${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final companyName = widget.company.name?.trim().isNotEmpty == true
        ? widget.company.name!.trim()
        : widget.company.address;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF161616),
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          l10n.customerReviews,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _reviewsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }

          if (snapshot.hasError) {
            return _ReviewsState(
              icon: Icons.error_outline_rounded,
              title: l10n.loadDataError,
              subtitle: l10n.customerReviewsSubtitle,
              buttonText: l10n.tryAgain,
              onPressed: () => setState(_reload),
            );
          }

          final reviews = snapshot.data ?? const <Map<String, dynamic>>[];

          return RefreshIndicator(
            color: _accent,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 32),
              children: [
                _CompanyRatingSummary(
                  companyName: companyName,
                  rating: widget.company.rating,
                  reviewsCount: widget.company.reviewsCount,
                  subtitle: l10n.customerReviewsSubtitle,
                ),
                const SizedBox(height: 12),
                if (reviews.isEmpty)
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.48,
                    child: _ReviewsState(
                      icon: Icons.rate_review_outlined,
                      title: l10n.noReviewsYet,
                      subtitle: l10n.customerReviewsSubtitle,
                      buttonText: l10n.tryAgain,
                      onPressed: () => setState(_reload),
                      compact: true,
                    ),
                  )
                else
                  ...reviews.map(
                        (review) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PublicReviewCard(
                        username:
                        review['username']?.toString().trim().isNotEmpty ==
                            true
                            ? review['username'].toString().trim()
                            : '—',
                        rating: _asDouble(review['rating']),
                        quality: _asInt(review['quality']),
                        value: _asInt(review['value']),
                        descriptionMatch:
                        _asInt(review['description_match']),
                        service: _asInt(review['service']),
                        comment: review['comment']?.toString().trim() ?? '',
                        dateText: _formatDate(review['created']),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CompanyRatingSummary extends StatelessWidget {
  const _CompanyRatingSummary({
    required this.companyName,
    required this.rating,
    required this.reviewsCount,
    required this.subtitle,
  });

  static const Color _accent = Color(0xFFD1BC00);

  final String companyName;
  final double rating;
  final int reviewsCount;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ratingText = rating > 0 ? rating.toStringAsFixed(1) : '—';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: _accent,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF242424),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: _accent,
                    size: 24,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ratingText,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF555555),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '($reviewsCount)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF777777),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublicReviewCard extends StatelessWidget {
  const _PublicReviewCard({
    required this.username,
    required this.rating,
    required this.quality,
    required this.value,
    required this.descriptionMatch,
    required this.service,
    required this.comment,
    required this.dateText,
  });

  static const Color _accent = Color(0xFFD1BC00);

  final String username;
  final double rating;
  final int quality;
  final int value;
  final int descriptionMatch;
  final int service;
  final String comment;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _accent.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 21,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.buyer}: $username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF555555),
                      ),
                    ),
                    if (dateText.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        dateText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: _accent,
                    size: 21,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ReviewMetric(label: l10n.quality, value: quality),
          _ReviewMetric(label: l10n.valueForMoney, value: value),
          _ReviewMetric(
            label: l10n.descriptionMatch,
            value: descriptionMatch,
          ),
          _ReviewMetric(label: l10n.service, value: service),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                comment,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF242424),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewMetric extends StatelessWidget {
  const _ReviewMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF242424),
              ),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF242424),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsState extends StatelessWidget {
  const _ReviewsState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
    this.compact = false,
  });

  static const Color _accent = Color(0xFFD1BC00);

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: _accent,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF333333),
                side: const BorderSide(color: _accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
