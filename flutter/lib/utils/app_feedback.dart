// lib/utils/app_feedback.dart
import 'package:flutter/material.dart';

enum AppMessageType {
  info,
  success,
  warning,
  error,
}

/// Единая система коротких сообщений приложения.
///
/// Что делает:
/// - не ставит SnackBar в длинную очередь;
/// - одинаковое сообщение не показывается повторно в течение cooldown;
/// - новое сообщение заменяет текущее;
/// - единые success/error/warning/info методы.
class AppFeedback {
  AppFeedback._();

  static final Map<String, DateTime> _lastShownAt = <String, DateTime>{};

  static const Duration defaultCooldown = Duration(milliseconds: 1800);
  static const Duration defaultDuration = Duration(seconds: 2);

  static bool _isDuplicate(
      String key,
      Duration cooldown,
      ) {
    final now = DateTime.now();
    final previous = _lastShownAt[key];

    if (previous != null && now.difference(previous) < cooldown) {
      return true;
    }

    _lastShownAt[key] = now;
    _cleanupOldEntries(now);
    return false;
  }

  static void _cleanupOldEntries(DateTime now) {
    if (_lastShownAt.length < 80) return;

    _lastShownAt.removeWhere(
          (_, time) => now.difference(time) > const Duration(minutes: 5),
    );
  }

  static void show(
      BuildContext context,
      String message, {
        String? key,
        AppMessageType type = AppMessageType.info,
        Duration cooldown = defaultCooldown,
        Duration duration = defaultDuration,
      }) {
    if (!context.mounted) return;

    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) return;

    final dedupeKey = (key?.trim().isNotEmpty ?? false)
        ? key!.trim()
        : '${type.name}:$normalizedMessage';

    if (_isDuplicate(dedupeKey, cooldown)) return;

    final messenger = ScaffoldMessenger.of(context);

    // Никакой очереди из десятков SnackBar.
    // Новое актуальное сообщение заменяет текущее.
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(normalizedMessage),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        backgroundColor: _backgroundColor(type),
      ),
    );
  }

  static void info(
      BuildContext context,
      String message, {
        String? key,
        Duration cooldown = defaultCooldown,
      }) {
    show(
      context,
      message,
      key: key,
      type: AppMessageType.info,
      cooldown: cooldown,
    );
  }

  static void success(
      BuildContext context,
      String message, {
        String? key,
        Duration cooldown = defaultCooldown,
      }) {
    show(
      context,
      message,
      key: key,
      type: AppMessageType.success,
      cooldown: cooldown,
    );
  }

  static void warning(
      BuildContext context,
      String message, {
        String? key,
        Duration cooldown = defaultCooldown,
      }) {
    show(
      context,
      message,
      key: key,
      type: AppMessageType.warning,
      cooldown: cooldown,
    );
  }

  static void error(
      BuildContext context,
      String message, {
        String? key,
        Duration cooldown = defaultCooldown,
      }) {
    show(
      context,
      message,
      key: key,
      type: AppMessageType.error,
      cooldown: cooldown,
    );
  }

  static void clear(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  static Color? _backgroundColor(AppMessageType type) {
    return switch (type) {
      AppMessageType.info => const Color(0xFF333333),
      AppMessageType.success => const Color(0xFF21884A),
      AppMessageType.warning => const Color(0xFF9A7200),
      AppMessageType.error => const Color(0xFFC62828),
    };
  }
}

/// Глобальная защита асинхронных действий от двойных/многократных нажатий.
///
/// Примеры ключей:
///   cart.checkout
///   product.reserve:<slug>
///   favorite.toggle:<slug>
///   seller.publish:<slug>
///
/// Пока действие выполняется, повторный запуск с тем же ключом игнорируется.
/// После завершения действует короткий cooldown.
class AppActionGuard {
  AppActionGuard._();

  static final Set<String> _running = <String>{};
  static final Map<String, DateTime> _lastFinishedAt = <String, DateTime>{};

  static const Duration defaultCooldown = Duration(milliseconds: 700);

  static bool isRunning(String key) => _running.contains(key);

  static bool tryLock(
      String key, {
        Duration cooldown = defaultCooldown,
      }) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return false;

    if (_running.contains(normalizedKey)) {
      return false;
    }

    final previous = _lastFinishedAt[normalizedKey];
    if (previous != null &&
        DateTime.now().difference(previous) < cooldown) {
      return false;
    }

    _running.add(normalizedKey);
    return true;
  }

  static void unlock(String key) {
    final normalizedKey = key.trim();
    _running.remove(normalizedKey);
    _lastFinishedAt[normalizedKey] = DateTime.now();

    if (_lastFinishedAt.length > 100) {
      final now = DateTime.now();
      _lastFinishedAt.removeWhere(
            (_, time) => now.difference(time) > const Duration(minutes: 5),
      );
    }
  }

  static Future<T?> run<T>(
      String key,
      Future<T> Function() action, {
        Duration cooldown = defaultCooldown,
      }) async {
    if (!tryLock(key, cooldown: cooldown)) {
      return null;
    }

    try {
      return await action();
    } finally {
      unlock(key);
    }
  }
}
