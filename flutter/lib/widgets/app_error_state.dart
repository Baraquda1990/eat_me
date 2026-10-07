// lib/widgets/app_error_state.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

enum AppErrorKind {
  network,
  timeout,
  server,
  auth,
  generic,
}

class AppErrorCopy {
  final AppErrorKind kind;
  final IconData icon;
  final String title;
  final String message;
  final String retryLabel;
  final String loadMoreTitle;

  const AppErrorCopy({
    required this.kind,
    required this.icon,
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.loadMoreTitle,
  });

  static AppErrorCopy from(BuildContext context, Object? error) {
    final kind = _kindFrom(error);
    final language = Localizations.localeOf(context).languageCode.toLowerCase();

    if (language == 'hy') {
      return _hy(kind);
    }
    if (language == 'en') {
      return _en(kind);
    }
    return _ru(kind);
  }

  static AppErrorKind _kindFrom(Object? error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return AppErrorKind.timeout;
        case DioExceptionType.connectionError:
          return AppErrorKind.network;
        case DioExceptionType.badResponse:
          final status = error.response?.statusCode ?? 0;
          if (status == 401 || status == 403) return AppErrorKind.auth;
          if (status >= 500) return AppErrorKind.server;
          return AppErrorKind.generic;
        case DioExceptionType.cancel:
        case DioExceptionType.badCertificate:
        case DioExceptionType.unknown:
          break;
      }
    }

    final text = (error?.toString() ?? '').toLowerCase();

    if (text.contains('timeout') ||
        text.contains('timed out') ||
        text.contains('время ожидания')) {
      return AppErrorKind.timeout;
    }

    if (text.contains('socket') ||
        text.contains('connection refused') ||
        text.contains('connection error') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('xmlhttprequest error') ||
        text.contains('networkerror') ||
        text.contains('network error')) {
      return AppErrorKind.network;
    }

    if (text.contains('not authenticated') ||
        text.contains('unauthorized') ||
        text.contains('401') ||
        text.contains('403')) {
      return AppErrorKind.auth;
    }

    if (text.contains('500') ||
        text.contains('502') ||
        text.contains('503') ||
        text.contains('504') ||
        text.contains('internal server')) {
      return AppErrorKind.server;
    }

    return AppErrorKind.generic;
  }

  static AppErrorCopy _ru(AppErrorKind kind) {
    switch (kind) {
      case AppErrorKind.network:
        return const AppErrorCopy(
          kind: AppErrorKind.network,
          icon: Icons.wifi_off_rounded,
          title: 'Нет подключения',
          message: 'Проверьте интернет-соединение и попробуйте снова.',
          retryLabel: 'Повторить',
          loadMoreTitle: 'Не удалось загрузить ещё',
        );
      case AppErrorKind.timeout:
        return const AppErrorCopy(
          kind: AppErrorKind.timeout,
          icon: Icons.schedule_rounded,
          title: 'Сервер отвечает слишком долго',
          message: 'Соединение заняло больше времени, чем обычно. Попробуйте ещё раз.',
          retryLabel: 'Повторить',
          loadMoreTitle: 'Не удалось догрузить товары',
        );
      case AppErrorKind.server:
        return const AppErrorCopy(
          kind: AppErrorKind.server,
          icon: Icons.cloud_off_rounded,
          title: 'Сервис временно недоступен',
          message: 'Не удалось получить данные с сервера. Попробуйте немного позже.',
          retryLabel: 'Повторить',
          loadMoreTitle: 'Сервер не загрузил следующую страницу',
        );
      case AppErrorKind.auth:
        return const AppErrorCopy(
          kind: AppErrorKind.auth,
          icon: Icons.lock_outline_rounded,
          title: 'Нужно войти в аккаунт',
          message: 'Авторизуйтесь и повторите действие.',
          retryLabel: 'Повторить',
          loadMoreTitle: 'Не удалось обновить данные',
        );
      case AppErrorKind.generic:
        return const AppErrorCopy(
          kind: AppErrorKind.generic,
          icon: Icons.sentiment_dissatisfied_rounded,
          title: 'Не удалось загрузить данные',
          message: 'Что-то пошло не так. Попробуйте ещё раз.',
          retryLabel: 'Повторить',
          loadMoreTitle: 'Не удалось загрузить ещё',
        );
    }
  }

  static AppErrorCopy _en(AppErrorKind kind) {
    switch (kind) {
      case AppErrorKind.network:
        return const AppErrorCopy(
          kind: AppErrorKind.network,
          icon: Icons.wifi_off_rounded,
          title: 'No internet connection',
          message: 'Check your internet connection and try again.',
          retryLabel: 'Try again',
          loadMoreTitle: 'Could not load more',
        );
      case AppErrorKind.timeout:
        return const AppErrorCopy(
          kind: AppErrorKind.timeout,
          icon: Icons.schedule_rounded,
          title: 'The server is taking too long',
          message: 'The connection took longer than usual. Please try again.',
          retryLabel: 'Try again',
          loadMoreTitle: 'Could not load more items',
        );
      case AppErrorKind.server:
        return const AppErrorCopy(
          kind: AppErrorKind.server,
          icon: Icons.cloud_off_rounded,
          title: 'Service temporarily unavailable',
          message: 'We could not get data from the server. Please try again later.',
          retryLabel: 'Try again',
          loadMoreTitle: 'The next page could not be loaded',
        );
      case AppErrorKind.auth:
        return const AppErrorCopy(
          kind: AppErrorKind.auth,
          icon: Icons.lock_outline_rounded,
          title: 'Sign in required',
          message: 'Sign in and try the action again.',
          retryLabel: 'Try again',
          loadMoreTitle: 'Could not refresh data',
        );
      case AppErrorKind.generic:
        return const AppErrorCopy(
          kind: AppErrorKind.generic,
          icon: Icons.sentiment_dissatisfied_rounded,
          title: 'Could not load data',
          message: 'Something went wrong. Please try again.',
          retryLabel: 'Try again',
          loadMoreTitle: 'Could not load more',
        );
    }
  }

  static AppErrorCopy _hy(AppErrorKind kind) {
    switch (kind) {
      case AppErrorKind.network:
        return const AppErrorCopy(
          kind: AppErrorKind.network,
          icon: Icons.wifi_off_rounded,
          title: 'Ինտերնետ կապ չկա',
          message: 'Ստուգեք ինտերնետ կապը և փորձեք կրկին։',
          retryLabel: 'Կրկին փորձել',
          loadMoreTitle: 'Չհաջողվեց բեռնել ավելին',
        );
      case AppErrorKind.timeout:
        return const AppErrorCopy(
          kind: AppErrorKind.timeout,
          icon: Icons.schedule_rounded,
          title: 'Սերվերը ուշ է պատասխանում',
          message: 'Կապը սովորականից երկար տևեց։ Փորձեք կրկին։',
          retryLabel: 'Կրկին փորձել',
          loadMoreTitle: 'Չհաջողվեց բեռնել հաջորդ ապրանքները',
        );
      case AppErrorKind.server:
        return const AppErrorCopy(
          kind: AppErrorKind.server,
          icon: Icons.cloud_off_rounded,
          title: 'Ծառայությունը ժամանակավորապես անհասանելի է',
          message: 'Չհաջողվեց ստանալ տվյալները սերվերից։ Փորձեք մի փոքր ուշ։',
          retryLabel: 'Կրկին փորձել',
          loadMoreTitle: 'Չհաջողվեց բեռնել հաջորդ էջը',
        );
      case AppErrorKind.auth:
        return const AppErrorCopy(
          kind: AppErrorKind.auth,
          icon: Icons.lock_outline_rounded,
          title: 'Անհրաժեշտ է մուտք գործել',
          message: 'Մուտք գործեք հաշիվ և կրկին փորձեք։',
          retryLabel: 'Կրկին փորձել',
          loadMoreTitle: 'Չհաջողվեց թարմացնել տվյալները',
        );
      case AppErrorKind.generic:
        return const AppErrorCopy(
          kind: AppErrorKind.generic,
          icon: Icons.sentiment_dissatisfied_rounded,
          title: 'Չհաջողվեց բեռնել տվյալները',
          message: 'Ինչ-որ բան սխալ գնաց։ Փորձեք կրկին։',
          retryLabel: 'Կրկին փորձել',
          loadMoreTitle: 'Չհաջողվեց բեռնել ավելին',
        );
    }
  }
}

class AppErrorState extends StatelessWidget {
  static const Color accentColor = Color(0xFFD1BC00);

  final Object? error;
  final Future<void> Function()? onRetry;
  final EdgeInsetsGeometry padding;

  const AppErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final copy = AppErrorCopy.from(context, error);

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFEEEEEE)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.055),
                blurRadius: 24,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  copy.icon,
                  size: 44,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                copy.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF242124),
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                copy.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => onRetry!.call(),
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 21),
                    label: Text(
                      copy.retryLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppInlineError extends StatelessWidget {
  static const Color accentColor = Color(0xFFD1BC00);

  final Object? error;
  final Future<void> Function()? onRetry;
  final bool loadMore;
  final EdgeInsetsGeometry margin;

  const AppInlineError({
    super.key,
    required this.error,
    this.onRetry,
    this.loadMore = false,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 14),
  });

  @override
  Widget build(BuildContext context) {
    final copy = AppErrorCopy.from(context, error);

    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEDED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(copy.icon, color: accentColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loadMore ? copy.loadMoreTitle : copy.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF242124),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  copy.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: copy.retryLabel,
              onPressed: () => onRetry!.call(),
              style: IconButton.styleFrom(
                backgroundColor: accentColor.withOpacity(0.12),
                foregroundColor: accentColor,
              ),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ],
      ),
    );
  }
}
