import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';

import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import 'seller_registration_provider.dart';
import 'seller_registration_service.dart';
import 'seller_documents_screen.dart';
import 'widgets/seller_registration_header.dart';
import 'widgets/seller_step_indicator.dart';

class SellerCategoryScreen extends StatefulWidget {
  const SellerCategoryScreen({super.key});

  @override
  State<SellerCategoryScreen> createState() => _SellerCategoryScreenState();
}

class _SellerCategoryScreenState extends State<SellerCategoryScreen> {
  static const Color _accent = Color(0xFFD1BC00);

  late Future<List<SellerBusinessCategory>> _categoriesFuture;
  SellerBusinessCategory? _selectedCategory;
  bool _isSaving = false;
  bool _showCategoryError = false;

  @override
  void initState() {
    super.initState();

    final registration = context.read<SellerRegistrationProvider>();

    final service = SellerRegistrationService(
      dio: Dio(
        BaseOptions(
          headers: {
            'Accept': 'application/json',
          },
        ),
      ),
      // При необходимости замени на твою переменную API URL.
      baseUrl: ApiService.apiUrl,
    );

    _categoriesFuture = service.getCategories(
      channelCode: registration.channelCode,
    );
  }

  void _selectCategory(SellerBusinessCategory category) {
    setState(() {
      _selectedCategory = category;
      _showCategoryError = false;
    });
  }

  String _text({
    required String en,
    required String ru,
    required String hy,
  }) {
    final languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode == 'hy') return hy;
    if (languageCode == 'ru') return ru;
    return en;
  }


  String _guardMessage(
      AppLocalizations l10n,
      SellerApplicationGuardException error,
      ) {
    if (error.requiresResume || error.applicationMismatch) {
      return l10n.sellerRegistrationResumeRequiredMessage;
    }

    return switch (error.status) {
      'approved' => l10n.sellerRegistrationApprovedMessage,
      'pending' => l10n.sellerRegistrationPendingMessage,
      'rejected' => l10n.sellerRegistrationRejectedMessage,
      _ => l10n.sellerRegistrationLockedMessage,
    };
  }

  Future<void> _showGuardError(
      SellerApplicationGuardException error,
      ) async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            error.statusDisplay.trim().isNotEmpty
                ? error.statusDisplay.trim()
                : l10n.sellerApplication,
          ),
          content: Text(_guardMessage(l10n, error)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
              ),
              child: Text(l10n.done),
            ),
          ],
        );
      },
    );
  }

  Future<void> _next() async {
    final category = _selectedCategory;

    if (category == null) {
      setState(() => _showCategoryError = true);
      return;
    }

    if (_isSaving) return;

    final registration = context.read<SellerRegistrationProvider>();
    registration.saveCategory(category);

    setState(() => _isSaving = true);

    try {
      final service = SellerRegistrationService(
        dio: Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {'Accept': 'application/json'},
          ),
        ),
        baseUrl: ApiService.apiUrl,
      );

      final draft = await service.saveDraft(provider: registration);
      final applicationId = int.tryParse(draft['id'].toString());

      if (applicationId == null) {
        throw FormatException(
          _text(
            en: 'Application ID is missing.',
            ru: 'Не найден номер заявки.',
            hy: 'Դիմումի համարը չի գտնվել։',
          ),
        );
      }

      registration.setApplicationId(applicationId);

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: registration,
            child: const SellerDocumentsScreen(),
          ),
        ),
      );
    } on SellerApplicationGuardException catch (e) {
      if (!mounted) return;
      await _showGuardError(e);
    } on DioException catch (e) {
      if (!mounted) return;
      final message = e.response?.data?.toString() ??
          e.message ??
          AppLocalizations.of(context)!.networkError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_text(en: 'Failed to save draft', ru: 'Не удалось сохранить черновик', hy: 'Չհաջողվեց պահպանել սևագիրը')}: $message',
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
            _text(
              en: 'Failed to save draft. Please try again.',
              ru: 'Не удалось сохранить черновик. Попробуйте ещё раз.',
              hy: 'Չհաջողվեց պահպանել սևագիրը։ Փորձեք կրկին։',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registration = context.watch<SellerRegistrationProvider>();
    final languageCode =
        context.watch<LocaleProvider>().locale.languageCode;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SellerRegistrationBackground(
          child: Column(
            children: [
              SellerRegistrationHeader(
                onBack: () => Navigator.of(context).maybePop(),
              ),
              const SellerStepIndicator(currentStep: 3),
              const SizedBox(height: 18),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: FutureBuilder<List<SellerBusinessCategory>>(
                    future: _categoriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: _accent,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return _ErrorState(
                          message: _text(
                            en: 'Could not load categories.',
                            ru: 'Не удалось загрузить категории.',
                            hy: 'Չհաջողվեց բեռնել կատեգորիաները։',
                          ),
                          onRetry: () {
                            setState(() {
                              final service = SellerRegistrationService(
                                dio: Dio(),
                                baseUrl: ApiService.apiUrl,
                              );

                              _categoriesFuture = service.getCategories(
                                channelCode: registration.channelCode,
                              );
                            });
                          },
                        );
                      }

                      final categories =
                          snapshot.data ?? const <SellerBusinessCategory>[];

                      if (categories.isEmpty) {
                        return Center(
                          child: Text(
                            _text(
                              en: 'No categories are available for this direction.',
                              ru: 'Для этого направления пока нет доступных категорий.',
                              hy: 'Այս ուղղության համար հասանելի կատեգորիաներ դեռ չկան։',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      // Безопасное восстановление выбранной категории
                      if (_selectedCategory == null &&
                          registration.businessCategoryId != null) {
                        for (final category in categories) {
                          if (category.id == registration.businessCategoryId) {
                            _selectedCategory = category;
                            break;
                          }
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text(
                              en: 'Category',
                              ru: 'Категория',
                              hy: 'Կատեգորիա',
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _text(
                                    en: "Let's choose the category that best describes your business",
                                    ru: 'Выберите категорию, которая лучше всего описывает ваш бизнес',
                                    hy: 'Ընտրեք ձեր բիզնեսը լավագույնս նկարագրող կատեգորիան',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.info_outline,
                                size: 13,
                                color: Color(0xFFB0B0B0),
                              ),
                            ],
                          ),
                          const SizedBox(height: 42),
                          _CategorySelector(
                            selected: _selectedCategory,
                            languageCode: languageCode,
                            onTap: () {
                              _showCategorySheet(
                                context,
                                categories,
                                languageCode,
                              );
                            },
                          ),
                          if (_showCategoryError) ...[
                            const SizedBox(height: 7),
                            Text(
                              _text(
                                en: 'Choose a business category',
                                ru: 'Выберите категорию бизнеса',
                                hy: 'Ընտրեք բիզնեսի կատեգորիան',
                              ),
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _next,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                                  : Text(
                                AppLocalizations.of(context)!.next,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCategorySheet(
      BuildContext context,
      List<SellerBusinessCategory> categories,
      String languageCode,
      ) async {
    final selected = await showModalBottomSheet<SellerBusinessCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.72,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _text(
                        en: 'Choose your business category',
                        ru: 'Выберите категорию бизнеса',
                        hy: 'Ընտրեք ձեր բիզնեսի կատեգորիան',
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = categories[index];
                      final selected =
                          item.id == _selectedCategory?.id;

                      return ListTile(
                        title: Text(
                          item.localizedName(languageCode),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(
                          Icons.check_circle,
                          color: _accent,
                        )
                            : null,
                        onTap: () =>
                            Navigator.of(sheetContext).pop(item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      _selectCategory(selected);
    }
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.selected,
    required this.languageCode,
    required this.onTap,
  });

  final SellerBusinessCategory? selected;
  final String languageCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final placeholder = languageCode == 'hy'
        ? 'Մենք ... ենք'
        : languageCode == 'ru'
        ? 'Мы — ...'
        : 'We are a ...';

    final title = selected == null
        ? placeholder
        : selected!.localizedName(languageCode);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFD1BC00),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected == null
                      ? const Color(0xFFD1BC00)
                      : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFFD1BC00),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD1BC00),
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}