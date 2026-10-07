// lib/screens/past_orders_screen.dart

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class PastOrdersScreen extends StatefulWidget {
  const PastOrdersScreen({super.key});

  @override
  State<PastOrdersScreen> createState() => _PastOrdersScreenState();
}

class _PastOrdersScreenState extends State<PastOrdersScreen> {
  bool _isLoading = true;
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    await auth.checkLoginStatus();

    if (!mounted) return;

    if (!auth.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }

    final orders = await context.read<CartProvider>().loadPastOrders();

    if (!mounted) return;

    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  Future<void> _goLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    if (result == true && mounted) {
      setState(() => _isLoading = true);
      await _load();
    }
  }

  void _goHome() {
    context.read<NavigationProvider>().setIndex(0);
  }

  void _markCompanyAsReviewed(
      int cardId,
      int companyId,
      ) {
    setState(() {
      for (final order in _orders) {
        if (order is! Map) continue;

        final currentCardId =
            int.tryParse(order['id'].toString()) ?? 0;

        if (currentCardId != cardId) continue;

        final reviewed =
        List<int>.from(order['reviewed_company_ids'] ?? []);

        if (!reviewed.contains(companyId)) {
          reviewed.add(companyId);
        }

        order['reviewed_company_ids'] = reviewed;
      }
    });
  }

  String _statusText(String status, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    switch (status.toLowerCase()) {
      case 'pending':
        return l10n.pending;
      case 'ordered':
        return l10n.ordered;
      case 'paid':
      case 'paided':
        return l10n.paid;
      case 'completed':
        return l10n.completed;
      case 'cancelled':
      case 'canceled':
        return l10n.cancelled;
      default:
        return l10n.processing;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'ordered':
        return Colors.blue;
      case 'paid':
      case 'paided':
        return Colors.green;
      case 'completed':
        return Colors.teal;
      case 'cancelled':
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showReviewDialog({
    required BuildContext context,
    required int cardId,
    required int companyId,
    required String companyName,
    required VoidCallback onSuccess,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    int quality = 5;
    int value = 5;
    int descriptionMatch = 5;
    int service = 5;
    final commentController = TextEditingController();
    bool isSending = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Widget ratingRow(String title, int current, Function(int) onChanged) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      return IconButton(
                        onPressed: () => onChanged(value),
                        icon: Icon(
                          value <= current
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFFD1BC00),
                          size: 28,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text('$l10n.reviewCompany $companyName'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ratingRow(l10n.productQuality, quality, (v) {
                      setState(() => quality = v);
                    }),
                    ratingRow(l10n.valueSet, value, (v) {
                      setState(() => value = v);
                    }),
                    ratingRow(l10n.descriptionMatch, descriptionMatch, (v) {
                      setState(() => descriptionMatch = v);
                    }),
                    ratingRow(l10n.service, service, (v) {
                      setState(() => service = v);
                    }),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: l10n.commentOptional,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                    setState(() => isSending = true);

                    try {
                      await ApiService.addReview(
                        cardId: cardId,
                        companyId: companyId,
                        quality: quality,
                        value: value,
                        descriptionMatch: descriptionMatch,
                        service: service,
                        comment: commentController.text.trim(),
                      );

                      onSuccess();

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.reviewThanks),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      setState(() => isSending = false);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.reviewAlreadyOrCant),
                            backgroundColor: Colors.orange,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD1BC00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSending
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(l10n.send),
                ),
              ],
            );
          },
        );
      },
    );

    commentController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        title: Text(
          l10n.ordersHistory,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: !auth.isLoggedIn
          ? _AuthRequired(onLogin: _goLogin)
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: _orders.isEmpty
            ? _OrdersEmptyState(onHome: _goHome)
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length,
          itemBuilder: (_, index) {
            final order = _orders[index];
            return _OrderCard(
              order: order,
              statusText: _statusText,
              statusColor: _statusColor,
              onReview: ({
                required BuildContext context,
                required int cardId,
                required int companyId,
                required String companyName,
              }) {
                return _showReviewDialog(
                  context: context,
                  cardId: cardId,
                  companyId: companyId,
                  companyName: companyName,
                  onSuccess: () {
                    _markCompanyAsReviewed(
                      cardId,
                      companyId,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AuthRequired extends StatelessWidget {
  final VoidCallback onLogin;

  const _AuthRequired({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 44,
                  color: Color(0xFFD1BC00),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.loginToAccount,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.ordersAuthSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD1BC00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    l10n.login,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  final VoidCallback onHome;

  const _OrdersEmptyState({required this.onHome});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.noOrders,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.noOrdersSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onHome,
                  icon: const Icon(Icons.home_outlined),
                  label: Text(l10n.chooseProducts),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD1BC00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final dynamic order;
  final String Function(String, BuildContext) statusText;
  final Color Function(String) statusColor;
  final Future<void> Function({
  required BuildContext context,
  required int cardId,
  required int companyId,
  required String companyName,
  }) onReview;

  const _OrderCard({
    required this.order,
    required this.statusText,
    required this.statusColor,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final map = order is Map ? order as Map : {};
    final status = map['status']?.toString() ?? '';
    final total = map['total_price']?.toString() ?? '0';
    final created = map['created']?.toString() ?? '';
    final items = map['items'] is List ? map['items'] as List : [];

    final orderId = int.tryParse(map['id']?.toString() ?? '0') ?? 0;

    // РџРѕР»СѓС‡Р°РµРј СЃРїРёСЃРѕРє ID РєРѕРјРїР°РЅРёР№, РєРѕС‚РѕСЂС‹Рµ СѓР¶Рµ РѕС†РµРЅРµРЅС‹
    final reviewedCompanyIds = (map['reviewed_company_ids'] as List?)
        ?.map((e) => int.tryParse(e.toString()))
        .whereType<int>()
        .toSet() ?? {};

    final companies = <int, Map<String, dynamic>>{};

    for (final item in items) {
      if (item is! Map) continue;

      final product = item['product'];
      if (product is! Map) continue;

      final company = product['company'];
      if (company is! Map) continue;

      final companyId = int.tryParse(company['id']?.toString() ?? '0') ?? 0;
      if (companyId == 0) continue;

      companies[companyId] = {
        'id': companyId,
        'name': company['name']?.toString() ?? l10n.company,
      };
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  statusText(status, context),
                  style: TextStyle(
                    color: statusColor(status),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$total \u058F',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (created.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              created.replaceFirst('T', ' ').split('.').first,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 12),
          // рџ‘‡ РР—РњР•РќР•РќРћ: РёСЃРїРѕР»СЊР·РѕРІР°РЅРёРµ l10n.itemsCount
          Text(
            l10n.itemsCount(items.length),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...items.take(3).map((item) {
            final product = item is Map ? item['product'] : null;
            final name = product is Map ? product['name']?.toString() : null;
            final q = item is Map ? item['quantity']?.toString() : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '\u2022 ${name ?? l10n.product} \u00D7 ${q ?? '1'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
          if (items.length > 3)
          // рџ‘‡ РР—РњР•РќР•РќРћ: РёСЃРїРѕР»СЊР·РѕРІР°РЅРёРµ l10n.moreItems
            Text(
              l10n.moreItems(items.length - 3),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          if (companies.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),
            ...companies.values.map((company) {
              final isReviewed = reviewedCompanyIds.contains(company['id']);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        company['name']?.toString() ?? l10n.company,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (isReviewed)
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                        // рџ‘‡ РР—РњР•РќР•РќРћ: РёСЃРїРѕР»СЊР·РѕРІР°РЅРёРµ l10n.rated
                        label: Text(l10n.rated),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () {
                          onReview(
                            context: context,
                            cardId: orderId,
                            companyId: company['id'] as int,
                            companyName: company['name']?.toString() ?? l10n.company,
                          );
                        },
                        icon: const Icon(Icons.star_rounded, size: 18, color: Color(0xFFD1BC00)),
                        // рџ‘‡ РР—РњР•РќР•РќРћ: РёСЃРїРѕР»СЊР·РѕРІР°РЅРёРµ l10n.rate
                        label: Text(l10n.rate),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD1BC00),
                          side: const BorderSide(color: Color(0xFFD1BC00)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
