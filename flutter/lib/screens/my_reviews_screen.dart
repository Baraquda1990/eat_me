// lib/screens/my_reviews_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/app_feedback.dart';

const int _reviewCommentMaxLength = 400;

Future<bool> _confirmDiscardReviewChanges(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Есть несохранённые изменения'),
        content: const Text(
          'Вы изменили оценку или комментарий. Выйти без сохранения?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Остаться'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD1BC00),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Выйти'),
          ),
        ],
      );
    },
  );

  return discard ?? false;
}

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({Key? key}) : super(key: key);

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  static const Color accentColor = Color(0xFFD1BC00);

  late Future<List<Map<String, dynamic>>> _reviewsFuture;
  late Future<List<dynamic>> _ordersFuture;

  Timer? _reviewAvailabilityTimer;

  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  void _reloadAll() {
    _reviewsFuture = _loadReviewsWithProductImages();
    _ordersFuture = _loadOrdersForReview();
  }

  @override
  void dispose() {
    _reviewAvailabilityTimer?.cancel();
    super.dispose();
  }

  Future<List<dynamic>> _loadOrdersForReview() async {
    final orders = await ApiService.getPastOrders();

    if (mounted) {
      _scheduleNextReviewAvailabilityRefresh(orders);
    }

    return orders;
  }

  void _scheduleNextReviewAvailabilityRefresh(List<dynamic> orders) {
    _reviewAvailabilityTimer?.cancel();
    _reviewAvailabilityTimer = null;

    final now = DateTime.now();
    DateTime? nextAvailableAt;

    for (final rawOrder in orders) {
      if (rawOrder is! Map) continue;

      final rawAvailability = rawOrder['review_availability'];
      if (rawAvailability is! List) continue;

      for (final rawItem in rawAvailability) {
        if (rawItem is! Map) continue;
        if (rawItem['can_review'] == true) continue;

        final rawDate = rawItem['available_at']?.toString().trim() ?? '';
        if (rawDate.isEmpty) continue;

        DateTime? availableAt;
        try {
          availableAt = DateTime.parse(rawDate).toLocal();
        } catch (_) {
          availableAt = null;
        }

        if (availableAt == null || !availableAt.isAfter(now)) continue;

        if (nextAvailableAt == null ||
            availableAt.isBefore(nextAvailableAt)) {
          nextAvailableAt = availableAt;
        }
      }
    }

    if (nextAvailableAt == null) return;

    final delay = nextAvailableAt.difference(now) +
        const Duration(seconds: 2);

    _reviewAvailabilityTimer = Timer(delay, () {
      if (!mounted) return;

      setState(() {
        _ordersFuture = _loadOrdersForReview();
      });
    });
  }

  bool _orderHasAvailableReview(Map<dynamic, dynamic> order) {
    final companies = _companiesFromOrder(order);

    if (companies.isEmpty) return false;

    return companies.values.any(
          (company) => company['can_review'] != false,
    );
  }

  List<dynamic> _visibleReviewOrders(List<dynamic> orders) {
    return orders.where((rawOrder) {
      if (rawOrder is! Map) return false;
      return _orderHasAvailableReview(rawOrder);
    }).toList();
  }

  String _reviewWaitingEmptyTitle() {
    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => 'Пока нечего оценивать',
      'hy' => 'Դեռ գնահատելու ոչինչ չկա',
      _ => 'Nothing to review yet',
    };
  }

  String _reviewWaitingEmptySubtitle() {
    return switch (Localizations.localeOf(context).languageCode) {
      'ru' =>
      'Покупки появятся здесь, когда наступит время оставить оценку и отзыв.',
      'hy' =>
      'Գնումները այստեղ կհայտնվեն, երբ հնարավոր լինի գնահատական և կարծիք թողնել։',
      _ =>
      'Purchases will appear here when they become available for rating and review.',
    };
  }

  String _refreshLabel() {
    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => 'Обновить',
      'hy' => 'Թարմացնել',
      _ => 'Refresh',
    };
  }

  void _reload() {
    setState(_reloadAll);
  }

  Future<List<Map<String, dynamic>>> _loadReviewsWithProductImages() async {
    final reviews = await ApiService.getMyReviews();

    if (reviews.isEmpty) return reviews;

    try {
      final orders = await ApiService.getPastOrders();

      return reviews.map((review) {
        final enriched = Map<String, dynamic>.from(review);

        final directImage = _extractProductImage(review);
        if (directImage.isNotEmpty) {
          enriched['_product_image_url'] = directImage;
          return enriched;
        }

        final reviewCardId = _extractId(
          review['card_id'] ?? review['card'],
        );
        final reviewCompanyId = _extractId(
          review['company_id'] ?? review['company'],
        );
        final reviewCompanyName =
        (review['company_name']?.toString() ?? '').trim().toLowerCase();

        for (final rawOrder in orders) {
          if (rawOrder is! Map) continue;

          final order = Map<String, dynamic>.from(rawOrder);
          final orderId = _extractId(order['id'] ?? order['card_id']);

          if (reviewCardId > 0 && orderId != reviewCardId) {
            continue;
          }

          final items = order['items'];
          if (items is! List) continue;

          for (final rawItem in items) {
            if (rawItem is! Map) continue;

            final item = Map<String, dynamic>.from(rawItem);
            final productValue = item['product'];
            if (productValue is! Map) continue;

            final product = Map<String, dynamic>.from(productValue);
            final companyValue = product['company'];

            int productCompanyId = 0;
            String productCompanyName = '';

            if (companyValue is Map) {
              productCompanyId = _extractId(companyValue);
              productCompanyName =
                  (companyValue['name']?.toString() ?? '')
                      .trim()
                      .toLowerCase();
            } else {
              productCompanyId = _extractId(companyValue);
            }

            final sameCompany = reviewCompanyId > 0
                ? productCompanyId == reviewCompanyId
                : reviewCompanyName.isNotEmpty &&
                productCompanyName == reviewCompanyName;

            if (!sameCompany) continue;

            final image = _extractProductImage(product);
            if (image.isNotEmpty) {
              enriched['_product_image_url'] = image;
              return enriched;
            }
          }
        }

        return enriched;
      }).toList();
    } catch (_) {
      return reviews;
    }
  }

  int _extractId(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();

    if (value is Map) {
      return _extractId(value['id']);
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _extractProductImage(Map<dynamic, dynamic> source) {
    final nestedProduct = source['product'];
    if (nestedProduct is Map) {
      final nestedImage = _extractProductImage(nestedProduct);
      if (nestedImage.isNotEmpty) return nestedImage;
    }

    final candidates = [
      source['_product_image_url'],
      source['product_image_url'],
      source['product_image'],
      source['image_thumb_url'],
      source['image_card_url'],
      source['image_url'],
      source['image'],
    ];

    for (final candidate in candidates) {
      final raw = candidate?.toString().trim() ?? '';
      if (raw.isNotEmpty) {
        return ApiService.fixImageUrl(raw);
      }
    }

    return '';
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';

    try {
      final date = DateTime.parse(raw).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day.$month.$year';
    } catch (_) {
      return raw;
    }
  }

  String _statusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Ожидает';
      case 'ordered':
        return 'Оформлен';
      case 'paid':
      case 'paided':
        return 'Оплачен';
      case 'completed':
        return 'Выполнен';
      case 'cancelled':
      case 'canceled':
        return 'Отменён';
      default:
        return 'В обработке';
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

  Set<int> _reviewedCompanyIds(Map<dynamic, dynamic> order) {
    return (order['reviewed_company_ids'] as List?)
        ?.map((value) => int.tryParse(value.toString()))
        .whereType<int>()
        .toSet() ??
        <int>{};
  }

  Map<String, dynamic>? _reviewAvailabilityForCompany(
      Map<dynamic, dynamic> order,
      int companyId,
      ) {
    final raw = order['review_availability'];
    if (raw is! List) return null;

    for (final item in raw) {
      if (item is! Map) continue;
      if (_extractId(item['company_id']) != companyId) continue;
      return Map<String, dynamic>.from(item);
    }

    return null;
  }

  Map<int, Map<String, dynamic>> _companiesFromOrder(
      Map<dynamic, dynamic> order,
      ) {
    final companies = <int, Map<String, dynamic>>{};
    final items = order['items'] is List ? order['items'] as List : const [];

    for (final rawItem in items) {
      if (rawItem is! Map) continue;

      final product = rawItem['product'];
      if (product is! Map) continue;

      final productType =
      (product['type']?.toString() ?? '').trim().toLowerCase();

      // Reviews are available only for purchased HOT products.
      if (productType != 'hot') continue;

      final company = product['company'];
      if (company is! Map) continue;

      final companyId = _extractId(company['id']);
      if (companyId <= 0) continue;

      final availability = _reviewAvailabilityForCompany(order, companyId);

      // The HOT-only backend explicitly publishes review availability.
      // If there is no entry, never fall back to making the company reviewable.
      if (availability == null) continue;

      companies[companyId] = {
        'id': companyId,
        'name': company['name']?.toString().trim().isNotEmpty == true
            ? company['name'].toString().trim()
            : 'Компания',
        'can_review': availability['can_review'] == true,
        'review_reason': availability['reason']?.toString() ?? '',
        'review_available_at': availability['available_at'],
      };
    }

    return companies;
  }

  void _markCompanyAsReviewed(int cardId, int companyId) {
    _ordersFuture = _ordersFuture.then((orders) {
      for (final rawOrder in orders) {
        if (rawOrder is! Map) continue;

        final currentCardId = _extractId(rawOrder['id'] ?? rawOrder['card_id']);
        if (currentCardId != cardId) continue;

        final reviewed = _reviewedCompanyIds(rawOrder);
        reviewed.add(companyId);
        rawOrder['reviewed_company_ids'] = reviewed.toList();
      }
      return orders;
    });
  }

  Future<void> _createReview({
    required int cardId,
    required int companyId,
    required String companyName,
  }) async {
    final actionKey = 'reviews.create:$cardId:$companyId';
    if (!AppActionGuard.tryLock(actionKey)) return;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => _CreateReviewSheet(
          cardId: cardId,
          companyId: companyId,
          companyName: companyName,
        ),
      );

      if (!mounted || saved != true) return;

      setState(() {
        _markCompanyAsReviewed(cardId, companyId);
        _reviewsFuture = _loadReviewsWithProductImages();
      });

      AppFeedback.success(
        context,
        'Спасибо за отзыв!',
        key: 'reviews.create.success:$cardId:$companyId',
      );
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  Future<void> _handleReviewEdit(Map<String, dynamic> review) async {
    final l10n = AppLocalizations.of(context)!;
    final reviewId = _asInt(review['id']);
    if (reviewId <= 0) return;

    final status = (review['edit_request_status']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final canEdit = review['can_edit'] == true || status == 'approved';

    if (canEdit) {
      await _openReviewEditor(review);
      return;
    }

    if (status == 'pending') {
      try {
        final refreshedReviews = await _loadReviewsWithProductImages();
        if (!mounted) return;

        setState(() {
          _reviewsFuture = Future.value(refreshedReviews);
        });

        Map<String, dynamic>? refreshedReview;
        for (final item in refreshedReviews) {
          if (_asInt(item['id']) == reviewId) {
            refreshedReview = item;
            break;
          }
        }

        final refreshedStatus =
        (refreshedReview?['edit_request_status']?.toString() ?? '')
            .trim()
            .toLowerCase();
        final refreshedCanEdit = refreshedReview?['can_edit'] == true ||
            refreshedStatus == 'approved';

        if (refreshedReview != null && refreshedCanEdit) {
          AppFeedback.success(
            context,
            l10n.reviewEditSupportApproved,
            key: 'reviews.edit.approved:$reviewId',
          );
          await _openReviewEditor(refreshedReview);
          return;
        }

        if (refreshedStatus == 'rejected') {
          AppFeedback.warning(
            context,
            l10n.reviewEditRejectedCanRetry,
            key: 'reviews.edit.rejected:$reviewId',
          );
          return;
        }

        AppFeedback.warning(
          context,
          l10n.reviewEditPendingSupport,
          key: 'reviews.edit.pending:$reviewId',
        );
      } catch (_) {
        if (!mounted) return;
        AppFeedback.error(
          context,
          l10n.reviewEditStatusCheckFailed,
          key: 'reviews.edit.pending.refresh-error:$reviewId',
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.reviewEditRequestTitle),
          content: Text(
            status == 'rejected'
                ? l10n.reviewEditRequestRejectedPrompt
                : l10n.reviewEditRequestPrompt,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(l10n.reviewEditRequestSend),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final actionKey = 'reviews.edit.request:$reviewId';
    if (!AppActionGuard.tryLock(actionKey)) return;

    try {
      final result = await ApiService.requestReviewEdit(reviewId: reviewId);
      if (!mounted) return;

      final responseStatus =
      (result['status']?.toString() ?? '').trim().toLowerCase();
      final responseCanEdit = result['can_edit'] == true ||
          responseStatus == 'approved';
      if (responseCanEdit) {
        AppFeedback.success(
          context,
          l10n.reviewEditAllowed,
          key: 'reviews.edit.already-approved:$reviewId',
        );
        _reload();

        final refreshed = Map<String, dynamic>.from(review)
          ..['can_edit'] = true
          ..['edit_request_status'] = 'approved';
        await _openReviewEditor(refreshed);
        return;
      }

      AppFeedback.success(
        context,
        l10n.reviewEditRequestSent,
        key: 'reviews.edit.request.success:$reviewId',
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        key: 'reviews.edit.request.error:$reviewId',
      );
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  Future<void> _openReviewEditor(Map<String, dynamic> review) async {
    final l10n = AppLocalizations.of(context)!;
    final reviewId = _asInt(review['id']);
    if (reviewId <= 0) return;

    final actionKey = 'reviews.edit.open:$reviewId';
    if (!AppActionGuard.tryLock(actionKey)) return;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => _EditReviewSheet(review: review),
      );

      if (!mounted || saved != true) return;

      AppFeedback.success(
        context,
        l10n.reviewEditSavedNeedsNewRequest,
        key: 'reviews.edit.success:$reviewId',
      );
      _reload();
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }

  Future<void> _deleteReview(Map<String, dynamic> review) async {
    final id = _asInt(review['id']);
    if (id <= 0) return;

    final actionKey = 'reviews.delete:$id';
    if (!AppActionGuard.tryLock(actionKey)) return;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Удалить отзыв?'),
            content: const Text(
              'Отзыв и оценки будут удалены. Это действие нельзя отменить.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  'Удалить',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      try {
        await ApiService.deleteReview(id);

        if (!mounted) return;

        AppFeedback.success(
          context,
          'Отзыв удалён',
          key: 'reviews.delete.success:$id',
        );
        _reload();
      } catch (_) {
        if (!mounted) return;

        AppFeedback.error(
          context,
          'Не удалось удалить отзыв',
          key: 'reviews.delete.error:$id',
        );
      }
    } finally {
      AppActionGuard.unlock(actionKey);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Мои отзывы',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              height: 58,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ReviewTabButton(
                      label: 'Оценить',
                      icon: Icons.star_outline_rounded,
                      selected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _ReviewTabButton(
                      label: 'Мои отзывы',
                      icon: Icons.rate_review_outlined,
                      selected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _selectedTab == 0
                  ? _buildOrdersTab()
                  : _buildReviewsTab(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return FutureBuilder<List<dynamic>>(
      key: const ValueKey('orders'),
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: accentColor),
          );
        }

        if (snapshot.hasError) {
          return _StateMessage(
            icon: Icons.error_outline_rounded,
            title: 'Не удалось загрузить покупки',
            subtitle: 'Проверьте интернет или попробуйте позже',
            buttonText: 'Повторить',
            onPressed: _reload,
          );
        }

        final orders = snapshot.data ?? const [];
        final visibleOrders = _visibleReviewOrders(orders);

        if (visibleOrders.isEmpty) {
          return _StateMessage(
            icon: Icons.schedule_rounded,
            title: _reviewWaitingEmptyTitle(),
            subtitle: _reviewWaitingEmptySubtitle(),
            buttonText: _refreshLabel(),
            onPressed: _reload,
          );
        }

        return RefreshIndicator(
          color: accentColor,
          onRefresh: () async => _reload(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
            itemCount: visibleOrders.length,
            itemBuilder: (context, index) {
              final raw = visibleOrders[index];
              if (raw is! Map) return const SizedBox.shrink();

              return _ReviewOrderCard(
                order: raw,
                statusText: _statusText,
                statusColor: _statusColor,
                extractImage: _extractProductImage,
                reviewedCompanyIds: _reviewedCompanyIds(raw),
                companies: _companiesFromOrder(raw),
                onReview: _createReview,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: const ValueKey('reviews'),
      future: _reviewsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: accentColor),
          );
        }

        if (snapshot.hasError) {
          return _StateMessage(
            icon: Icons.error_outline_rounded,
            title: 'Не удалось загрузить отзывы',
            subtitle: 'Проверьте интернет или попробуйте позже',
            buttonText: 'Повторить',
            onPressed: _reload,
          );
        }

        final reviews = snapshot.data ?? [];

        if (reviews.isEmpty) {
          return _StateMessage(
            icon: Icons.rate_review_outlined,
            title: 'У вас пока нет отзывов',
            subtitle: 'На вкладке «Оценить» можно оценить прошлые покупки',
            buttonText: 'Перейти к покупкам',
            onPressed: () => setState(() => _selectedTab = 0),
          );
        }

        return RefreshIndicator(
          color: accentColor,
          onRefresh: () async => _reload(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              return _ReviewCard(
                review: review,
                rating: _asDouble(review['rating']),
                quality: _asInt(review['quality']),
                value: _asInt(review['value']),
                descriptionMatch: _asInt(review['description_match']),
                service: _asInt(review['service']),
                dateText: _formatDate(review['created']),
                onEdit: () => _handleReviewEdit(review),
                onDelete: () => _deleteReview(review),
              );
            },
          ),
        );
      },
    );
  }
}

class _ReviewTabButton extends StatelessWidget {
  static const Color accentColor = Color(0xFFD1BC00);

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ReviewTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: selected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? const Color(0xFF2F2F2F)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: selected
                      ? const Color(0xFF2F2F2F)
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewOrderCard extends StatelessWidget {
  static const Color accentColor = Color(0xFFD1BC00);

  final Map<dynamic, dynamic> order;
  final String Function(String) statusText;
  final Color Function(String) statusColor;
  final String Function(Map<dynamic, dynamic>) extractImage;
  final Set<int> reviewedCompanyIds;
  final Map<int, Map<String, dynamic>> companies;
  final Future<void> Function({
  required int cardId,
  required int companyId,
  required String companyName,
  }) onReview;

  const _ReviewOrderCard({
    required this.order,
    required this.statusText,
    required this.statusColor,
    required this.extractImage,
    required this.reviewedCompanyIds,
    required this.companies,
    required this.onReview,
  });

  int _id(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatCreated(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';

    try {
      final date = DateTime.parse(raw).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day.$month.${date.year}  $hour:$minute';
    } catch (_) {
      return raw;
    }
  }

  String _reviewWaitLabel(BuildContext context, String reason) {
    final l10n = AppLocalizations.of(context)!;

    switch (reason) {
      case 'waiting_delivery':
        return l10n.reviewWaitAfterDelivery;
      case 'waiting_pickup':
        return l10n.reviewWaitAfterPickup;
      case 'waiting_delay':
        return l10n.reviewWaitSoon;
      default:
        return l10n.reviewWaitUnavailable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString() ?? '';
    final items = order['items'] is List ? order['items'] as List : const [];
    final cardId = _id(order['id'] ?? order['card_id']);
    final orderNumber = _id(
      order['order_number'] ?? order['id'] ?? order['card_id'],
    );
    final total =
        order['total_price']?.toString() ?? order['total']?.toString() ?? '0';

    String imageUrl = '';
    if (items.isNotEmpty && items.first is Map) {
      final product = (items.first as Map)['product'];
      if (product is Map) {
        imageUrl = extractImage(product);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.42),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ReviewProductImage(imageUrl: imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor(status).withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText(status),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: statusColor(status),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$total ֏',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Заказ #${orderNumber > 0 ? orderNumber : cardId}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (_formatCreated(order['created']).isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _formatCreated(order['created']),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...items.take(3).map((rawItem) {
              if (rawItem is! Map) return const SizedBox.shrink();
              final product = rawItem['product'];
              final name = product is Map
                  ? product['name']?.toString() ?? 'Товар'
                  : 'Товар';
              final quantity = rawItem['quantity']?.toString() ?? '1';

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $name × $quantity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF555555),
                  ),
                ),
              );
            }),
            if (items.length > 3)
              Text(
                '+ ещё ${items.length - 3}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
          if (companies.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ...companies.values.map((company) {
              final companyId = _id(company['id']);
              final companyName =
                  company['name']?.toString() ?? 'Компания';
              final reviewed = reviewedCompanyIds.contains(companyId);
              final canReview = company['can_review'] != false;
              final reviewReason = company['review_reason']?.toString() ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    reviewed
                        ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        size: 17,
                        color: Colors.green,
                      ),
                      label: const Text('Оценено'),
                      style: OutlinedButton.styleFrom(
                        disabledForegroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                        : !canReview
                        ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(
                        Icons.schedule_rounded,
                        size: 17,
                      ),
                      label: Text(_reviewWaitLabel(context, reviewReason)),
                      style: OutlinedButton.styleFrom(
                        disabledForegroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                        : OutlinedButton.icon(
                      onPressed: cardId <= 0 || companyId <= 0
                          ? null
                          : () => onReview(
                        cardId: cardId,
                        companyId: companyId,
                        companyName: companyName,
                      ),
                      icon: const Icon(
                        Icons.star_rounded,
                        size: 18,
                      ),
                      label: const Text('Оценить'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: const BorderSide(color: accentColor),
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

class _CreateReviewSheet extends StatefulWidget {
  final int cardId;
  final int companyId;
  final String companyName;

  const _CreateReviewSheet({
    required this.cardId,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<_CreateReviewSheet> createState() => _CreateReviewSheetState();
}

class _CreateReviewSheetState extends State<_CreateReviewSheet> {
  static const Color accentColor = Color(0xFFD1BC00);

  int _quality = 0;
  int _value = 0;
  int _descriptionMatch = 0;
  int _service = 0;
  bool _saving = false;

  final TextEditingController _commentController = TextEditingController();

  bool get _hasUnsavedChanges =>
      _quality > 0 ||
          _value > 0 ||
          _descriptionMatch > 0 ||
          _service > 0 ||
          _commentController.text.isNotEmpty;

  Future<void> _requestClose() async {
    if (_saving) return;

    if (!_hasUnsavedChanges) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }

    final discard = await _confirmDiscardReviewChanges(context);
    if (!discard || !mounted) return;

    Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    if (_quality <= 0 ||
        _value <= 0 ||
        _descriptionMatch <= 0 ||
        _service <= 0) {
      AppFeedback.warning(
        context,
        'Пожалуйста, поставьте оценку по всем пунктам',
        key: 'reviews.create.rating-required:${widget.cardId}:${widget.companyId}',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await ApiService.addReview(
        cardId: widget.cardId,
        companyId: widget.companyId,
        quality: _quality,
        value: _value,
        descriptionMatch: _descriptionMatch,
        service: _service,
        comment: _commentController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      setState(() => _saving = false);

      AppFeedback.warning(
        context,
        'Отзыв уже оставлен или эту покупку нельзя оценить',
        key: 'reviews.create.not-allowed:${widget.cardId}:${widget.companyId}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return WillPopScope(
      onWillPop: () async {
        if (_saving) return false;
        if (!_hasUnsavedChanges) return true;
        return _confirmDiscardReviewChanges(context);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
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
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Оценить покупку',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: _saving ? null : _requestClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.companyName,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _RatingEditorRow(
                    title: 'Качество',
                    value: _quality,
                    onChanged: (value) => setState(() => _quality = value),
                  ),
                  _RatingEditorRow(
                    title: 'Цена/качество',
                    value: _value,
                    onChanged: (value) => setState(() => _value = value),
                  ),
                  _RatingEditorRow(
                    title: 'Соответствие описанию',
                    value: _descriptionMatch,
                    onChanged: (value) =>
                        setState(() => _descriptionMatch = value),
                  ),
                  _RatingEditorRow(
                    title: 'Сервис',
                    value: _service,
                    onChanged: (value) => setState(() => _service = value),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Комментарий',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_commentController.text.length}/$_reviewCommentMaxLength',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _commentController.text.length >=
                              _reviewCommentMaxLength
                              ? Colors.redAccent
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _commentController,
                    minLines: 3,
                    maxLines: 5,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        _reviewCommentMaxLength,
                      ),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Комментарий (необязательно)',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF6F6F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'Отправить отзыв',
                        style: TextStyle(
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
      ),
    );
  }
}


class _EditReviewSheet extends StatefulWidget {
  final Map<String, dynamic> review;

  const _EditReviewSheet({required this.review});

  @override
  State<_EditReviewSheet> createState() => _EditReviewSheetState();
}

class _EditReviewSheetState extends State<_EditReviewSheet> {
  static const Color accentColor = Color(0xFFD1BC00);

  late int _quality;
  late int _value;
  late int _descriptionMatch;
  late int _service;
  late final int _initialQuality;
  late final int _initialValue;
  late final int _initialDescriptionMatch;
  late final int _initialService;
  late final String _initialComment;
  late final TextEditingController _commentController;

  bool _saving = false;

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int get _reviewId => _intValue(widget.review['id']);

  String get _companyName =>
      widget.review['company_name']?.toString().trim().isNotEmpty == true
          ? widget.review['company_name'].toString().trim()
          : 'Компания';

  bool get _hasUnsavedChanges =>
      _quality != _initialQuality ||
          _value != _initialValue ||
          _descriptionMatch != _initialDescriptionMatch ||
          _service != _initialService ||
          _commentController.text.trim() != _initialComment;

  @override
  void initState() {
    super.initState();

    _quality = _intValue(widget.review['quality']).clamp(0, 5).toInt();
    _value = _intValue(widget.review['value']).clamp(0, 5).toInt();
    _descriptionMatch =
        _intValue(widget.review['description_match']).clamp(0, 5).toInt();
    _service = _intValue(widget.review['service']).clamp(0, 5).toInt();
    _initialComment = widget.review['comment']?.toString().trim() ?? '';

    _initialQuality = _quality;
    _initialValue = _value;
    _initialDescriptionMatch = _descriptionMatch;
    _initialService = _service;
    _commentController = TextEditingController(text: _initialComment);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _requestClose() async {
    if (_saving) return;

    if (!_hasUnsavedChanges) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }

    final discard = await _confirmDiscardReviewChanges(context);
    if (!discard || !mounted) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _save() async {
    if (_saving) return;

    if (_reviewId <= 0) {
      AppFeedback.error(
        context,
        'Не удалось определить отзыв',
        key: 'reviews.edit.invalid-id',
      );
      return;
    }

    if (_quality <= 0 ||
        _value <= 0 ||
        _descriptionMatch <= 0 ||
        _service <= 0) {
      AppFeedback.warning(
        context,
        'Пожалуйста, поставьте оценку по всем пунктам',
        key: 'reviews.edit.rating-required:$_reviewId',
      );
      return;
    }

    if (!_hasUnsavedChanges) {
      AppFeedback.warning(
        context,
        'Вы ничего не изменили',
        key: 'reviews.edit.no-changes:$_reviewId',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await ApiService.updateReview(
        reviewId: _reviewId,
        quality: _quality,
        value: _value,
        descriptionMatch: _descriptionMatch,
        service: _service,
        comment: _commentController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);

      AppFeedback.error(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        key: 'reviews.edit.save.error:$_reviewId',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return WillPopScope(
      onWillPop: () async {
        if (_saving) return false;
        if (!_hasUnsavedChanges) return true;
        return _confirmDiscardReviewChanges(context);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.reviewEditTitle,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: _saving ? null : _requestClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _companyName,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.reviewEditOneTimeApproved,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _RatingEditorRow(
                    title: 'Качество',
                    value: _quality,
                    onChanged: (value) => setState(() => _quality = value),
                  ),
                  _RatingEditorRow(
                    title: 'Цена/качество',
                    value: _value,
                    onChanged: (value) => setState(() => _value = value),
                  ),
                  _RatingEditorRow(
                    title: 'Соответствие описанию',
                    value: _descriptionMatch,
                    onChanged: (value) =>
                        setState(() => _descriptionMatch = value),
                  ),
                  _RatingEditorRow(
                    title: 'Сервис',
                    value: _service,
                    onChanged: (value) => setState(() => _service = value),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Комментарий',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_commentController.text.length}/$_reviewCommentMaxLength',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _commentController.text.length >=
                              _reviewCommentMaxLength
                              ? Colors.redAccent
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _commentController,
                    minLines: 3,
                    maxLines: 5,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        _reviewCommentMaxLength,
                      ),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Комментарий (необязательно)',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF6F6F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'Сохранить изменения',
                        style: TextStyle(
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
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  static const Color accentColor = Color(0xFFD1BC00);

  final Map<String, dynamic> review;
  final double rating;
  final int quality;
  final int value;
  final int descriptionMatch;
  final int service;
  final String dateText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReviewCard({
    required this.review,
    required this.rating,
    required this.quality,
    required this.value,
    required this.descriptionMatch,
    required this.service,
    required this.dateText,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final companyName = review['company_name']?.toString() ?? 'Компания';
    final comment = review['comment']?.toString().trim() ?? '';
    final productImageUrl =
        review['_product_image_url']?.toString().trim() ?? '';
    final editStatus =
    (review['edit_request_status']?.toString() ?? '').trim().toLowerCase();
    final canEdit = review['can_edit'] == true || editStatus == 'approved';

    String? editStatusLabel;
    IconData editIcon = Icons.edit_outlined;
    Color editColor = accentColor;

    switch (editStatus) {
      case 'pending':
        editStatusLabel = l10n.reviewEditStatusPending;
        editIcon = Icons.schedule_rounded;
        editColor = Colors.orange;
        break;
      case 'approved':
        editStatusLabel = l10n.reviewEditStatusApproved;
        editIcon = Icons.edit_rounded;
        editColor = Colors.green;
        break;
      case 'rejected':
        editStatusLabel = l10n.reviewEditStatusRejected;
        editIcon = Icons.refresh_rounded;
        editColor = Colors.redAccent;
        break;
      case 'used':
        editStatusLabel = l10n.reviewEditStatusUsed;
        editIcon = Icons.edit_outlined;
        editColor = accentColor;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ReviewProductImage(imageUrl: productImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (dateText.isNotEmpty)
                Text(
                  dateText,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stars(value: rating.round().clamp(0, 5)),
              const SizedBox(width: 8),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ScoreLine(title: 'Качество', value: quality),
          _ScoreLine(title: 'Цена/качество', value: value),
          _ScoreLine(title: 'Соответствие описанию', value: descriptionMatch),
          _ScoreLine(title: 'Сервис', value: service),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (editStatusLabel != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: editColor.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: editColor.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Icon(editIcon, size: 17, color: editColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      editStatusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: editColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Tooltip(
                message: canEdit
                    ? l10n.reviewEditTooltipEdit
                    : editStatus == 'pending'
                    ? l10n.reviewEditTooltipPending
                    : l10n.reviewEditTooltipRequest,
                child: SizedBox(
                  width: 46,
                  height: 40,
                  child: OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: editColor,
                      padding: EdgeInsets.zero,
                      side: BorderSide(
                        color: editColor.withValues(alpha: 0.40),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Icon(editIcon, size: 19),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Удалить',
                child: SizedBox(
                  width: 46,
                  height: 40,
                  child: OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: Color(0xFFFFCDD2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Icon(Icons.delete_outline, size: 19),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewProductImage extends StatelessWidget {
  static const Color accentColor = Color(0xFFD1BC00);

  final String imageUrl;

  const _ReviewProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    const size = 52.0;

    if (imageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.storefront_rounded,
          color: accentColor,
          size: 24,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: size,
            height: size,
            color: accentColor.withValues(alpha: 0.12),
            child: const Icon(
              Icons.storefront_rounded,
              color: accentColor,
              size: 24,
            ),
          );
        },
      ),
    );
  }
}

class _ScoreLine extends StatelessWidget {
  final String title;
  final int value;

  const _ScoreLine({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0, 5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _Stars(value: safeValue),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  static const Color accentColor = Color(0xFFD1BC00);

  final int value;

  const _Stars({
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final active = index < safeValue;

        return Icon(
          active ? Icons.star_rounded : Icons.star_border_rounded,
          size: 19,
          color: active ? accentColor : Colors.grey[350],
        );
      }),
    );
  }
}

class _RatingEditorRow extends StatelessWidget {
  static const Color accentColor = Color(0xFFD1BC00);

  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  const _RatingEditorRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0, 5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final active = starValue <= safeValue;

              return IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
                onPressed: () => onChanged(starValue),
                icon: Icon(
                  active ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 31,
                  color: active ? accentColor : Colors.grey[350],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  static const Color accentColor = Color(0xFFD1BC00);

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: accentColor,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
