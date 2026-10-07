// lib/screens/seller_reviews_screen.dart

import 'package:flutter/material.dart';
import 'package:armenia/l10n/app_localizations.dart'; // 👈 ДОБАВЛЕН ИМПОРТ

import '../services/api_service.dart';
import 'seller_dashboard_screen.dart';

class SellerReviewsScreen extends StatefulWidget {
  const SellerReviewsScreen({super.key});

  @override
  State<SellerReviewsScreen> createState() =>
      _SellerReviewsScreenState();
}

class _SellerReviewsScreenState
    extends State<SellerReviewsScreen> {

  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();

    _future = ApiService.getSellerReviews();
  }

  String _formatRating(dynamic value) {
    final rating = double.tryParse(value?.toString() ?? '');
    if (rating == null) return value?.toString() ?? '0';

    return rating.toStringAsFixed(1);
  }

  Widget _ratingRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$title: $value',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),

      appBar: AppBar(
        title: Text(l10n.customerReviews),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),

      body: FutureBuilder<List<Map<String,dynamic>>>(
        future: _future,

        builder: (context,snapshot){

          if(snapshot.connectionState ==
              ConnectionState.waiting){

            return const Center(
              child:CircularProgressIndicator(),
            );
          }

          if(snapshot.hasError){

            return Center(
              child: Text(
                snapshot.error.toString(),
              ),
            );
          }

          final reviews = snapshot.data ?? [];

          if(reviews.isEmpty){

            return Center(
              child: Text(
                l10n.noReviewsYet,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                ),
              ),
            );
          }

          return ListView.builder(

            padding: const EdgeInsets.all(16),

            itemCount: reviews.length,

            itemBuilder:(context,index){

              final item = reviews[index];

              return Container(

                margin:
                const EdgeInsets.only(bottom:16),

                padding:
                const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                  BorderRadius.circular(20),
                ),

                child: Column(

                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    Text(
                      item['company_name']?.toString() ?? l10n.company,
                      style: const TextStyle(
                        fontSize:18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height:4),

                    Text(
                      '${l10n.buyer}: ${item['username']?.toString() ?? l10n.user}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height:8),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 20,
                          color: SellerDashboardScreen.accentColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatRating(item['rating']),
                          style: const TextStyle(
                            color: SellerDashboardScreen.accentColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height:12),

                    _ratingRow(
                      l10n.quality,
                      item['quality'],
                    ),

                    _ratingRow(
                      l10n.valueForMoney,
                      item['value'],
                    ),

                    _ratingRow(
                      l10n.descriptionMatch,
                      item['description_match'],
                    ),

                    _ratingRow(
                      l10n.service,
                      item['service'],
                    ),

                    if((item['comment'] ?? '')
                        .toString()
                        .isNotEmpty)...[

                      const SizedBox(height:12),

                      Text(
                        item['comment'],
                      ),
                    ]
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}