// lib/widgets/alarm_floating_button.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/app_localizations.dart';
import '../models/tag.dart';
import '../models/map_company.dart';
import '../providers/location_provider.dart';
import '../services/api_service.dart';

final ValueNotifier<bool> alarmSavedGlobal = ValueNotifier<bool>(false);
final ValueNotifier<List<Map<String, dynamic>>> alarmActiveListGlobal =
ValueNotifier<List<Map<String, dynamic>>>([]);

DateTime? _alarmDeadline(Map<String, dynamic> alarm) {
  final raw = alarm['notify_until'] ?? alarm['notify_at'];
  if (raw == null) return null;

  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) return null;
  return parsed.toUtc();
}

bool _isCurrentActiveAlarm(Map<String, dynamic> alarm) {
  if (alarm['is_active'] != true) return false;
  final deadline = _alarmDeadline(alarm);
  if (deadline == null) return true;
  return deadline.isAfter(DateTime.now().toUtc());
}

class AlarmFloatingButton extends StatefulWidget {
  final List<Tag> tags;

  const AlarmFloatingButton({
    Key? key,
    this.tags = const [],
  }) : super(key: key);

  static const Color accentColor = Color(0xFFD1BC00);

  @override
  State<AlarmFloatingButton> createState() => _AlarmFloatingButtonState();
}

class _AlarmFloatingButtonState extends State<AlarmFloatingButton> {
  bool _isOpen = false;
  bool _isLoadingAlarms = false;
  List<Map<String, dynamic>> _activeAlarms = [];

  @override
  void initState() {
    super.initState();
    _loadActiveAlarms();
  }

  Future<void> _loadActiveAlarms() async {
    if (_isLoadingAlarms) return;

    setState(() => _isLoadingAlarms = true);

    try {
      final alarms = await ApiService.getNotificationAlarms();
      final active = alarms
          .where(_isCurrentActiveAlarm)
          .map((alarm) => Map<String, dynamic>.from(alarm))
          .toList();

      alarmActiveListGlobal.value = active;
      alarmSavedGlobal.value = active.isNotEmpty;

      if (!mounted) return;

      setState(() {
        _activeAlarms = active;
        _isLoadingAlarms = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingAlarms = false);
    }
  }

  Future<void> _openSheet() async {
    if (_isOpen) return;

    setState(() => _isOpen = true);

    // Перед открытием всегда берём актуальные уведомления с сервера,
    // чтобы на Home/Deals/Map показывалось одно и то же активное уведомление.
    await _loadActiveAlarms();

    if (!mounted) return;

    final saved = await showAlarmSheet(
      context,
      widget.tags,
      initialAlarms: alarmActiveListGlobal.value,
    );

    if (!mounted) return;
    setState(() => _isOpen = false);

    if (saved == true) {
      await _loadActiveAlarms();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: alarmActiveListGlobal,
      builder: (context, activeAlarms, _) {
        final hasSavedAlarm = activeAlarms.isNotEmpty || alarmSavedGlobal.value;
        final active = _isOpen || hasSavedAlarm;

        return Material(
          color: active ? AlarmFloatingButton.accentColor : Colors.white.withOpacity(0.96),
          shape: const CircleBorder(),
          elevation: 12,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _openSheet,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? AlarmFloatingButton.accentColor
                      : AlarmFloatingButton.accentColor.withOpacity(0.65),
                  width: 1.3,
                ),
              ),
              child: _isLoadingAlarms
                  ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
                  : Icon(
                hasSavedAlarm ? Icons.notifications_active_rounded : Icons.add_rounded,
                color: active ? Colors.white : AlarmFloatingButton.accentColor,
                size: hasSavedAlarm ? 27 : 34,
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<bool?> showAlarmSheet(
    BuildContext context,
    List<Tag> tags, {
      List<Map<String, dynamic>> initialAlarms = const [],
    }) async {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AlarmSheet(
      tags: tags,
      initialAlarms: initialAlarms,
    ),
  );
}

class _AlarmSheet extends StatefulWidget {
  final List<Tag> tags;
  final List<Map<String, dynamic>> initialAlarms;

  const _AlarmSheet({
    required this.tags,
    this.initialAlarms = const [],
  });

  @override
  State<_AlarmSheet> createState() => _AlarmSheetState();
}

class _AlarmSheetState extends State<_AlarmSheet> {
  static const Color accentColor = Color(0xFFD1BC00);
  static const List<double> radiusOptions = [1, 3, 5, 10, 25, 0];

  List<Tag> _realTags = [];
  List<MapCompany> _companies = [];
  bool _tagsLoading = true;
  final ScrollController _tagsScrollController = ScrollController();

  late DateTime _selectedDate;
  late TimeOfDay _fromTime;
  late TimeOfDay _toTime;
  double _radiusKm = 3;

  bool _isHot = true;
  bool _isLong = false;
  int _typeLoadGeneration = 0;

  double? _selectedLatitude;
  double? _selectedLongitude;

  final Set<String> _selectedHotTagSlugs = {};
  final Set<String> _selectedLongTagSlugs = {};
  final Set<String> _selectedHotCompanySlugs = {};
  final Set<String> _selectedLongCompanySlugs = {};
  final List<int> _activeAlarmIds = [];
  bool _hasExistingAlarm = false;
  bool _isDeletingAlarm = false;
  bool _isSaving = false;
  String? _sheetMessage;
  bool _sheetMessageIsError = true;

  @override
  void initState() {
    super.initState();
    _applyDefaultDateTime();
    _applyInitialAlarms();
    _loadRealTags();
  }

  @override
  void dispose() {
    _tagsScrollController.dispose();
    super.dispose();
  }

  void _applyDefaultDateTime() {
    final now = DateTime.now();
    final minimum = now.add(const Duration(minutes: 10));

    // Round the default start up to the next 5-minute mark.
    final roundedMinute = ((minimum.minute + 4) ~/ 5) * 5;
    final start = DateTime(
      minimum.year,
      minimum.month,
      minimum.day,
      minimum.hour,
      roundedMinute,
    );

    var end = start.add(const Duration(hours: 4));
    final endOfDay = DateTime(start.year, start.month, start.day, 23, 59);
    if (end.isAfter(endOfDay)) end = endOfDay;
    if (!end.isAfter(start)) {
      end = start.add(const Duration(minutes: 30));
    }

    _selectedDate = DateTime(start.year, start.month, start.day);
    _fromTime = TimeOfDay(hour: start.hour, minute: start.minute);
    _toTime = TimeOfDay(hour: end.hour, minute: end.minute);
  }

  void _applyInitialAlarms() {
    final activeAlarms = widget.initialAlarms
        .where(_isCurrentActiveAlarm)
        .toList();

    if (activeAlarms.isEmpty) return;

    _hasExistingAlarm = true;
    _isHot = false;
    _isLong = false;

    for (final alarm in activeAlarms) {
      final id = int.tryParse(alarm['id']?.toString() ?? '');
      if (id != null) _activeAlarmIds.add(id);

      final type = alarm['product_type']?.toString();
      if (type == 'hot') _isHot = true;
      if (type == 'long') _isLong = true;

      final selectedTagSlugs = type == 'long'
          ? _selectedLongTagSlugs
          : _selectedHotTagSlugs;
      final selectedCompanySlugs = type == 'long'
          ? _selectedLongCompanySlugs
          : _selectedHotCompanySlugs;

      final radius = double.tryParse(alarm['radius_km']?.toString() ?? '');
      if (radius != null) _radiusKm = radius;

      final latitude = double.tryParse(alarm['latitude']?.toString() ?? '');
      final longitude = double.tryParse(alarm['longitude']?.toString() ?? '');

      if (latitude != null && longitude != null) {
        _selectedLatitude = latitude;
        _selectedLongitude = longitude;
      }

      final tagSlugs = alarm['tags'];
      if (tagSlugs is List) {
        for (final slug in tagSlugs) {
          final value = slug.toString();
          if (value.isNotEmpty) selectedTagSlugs.add(value);
        }
      }

      final tagsDetail = alarm['tags_detail'];
      if (tagsDetail is List) {
        for (final tag in tagsDetail) {
          if (tag is Map && tag['slug'] != null) {
            final value = tag['slug'].toString();
            if (value.isNotEmpty) selectedTagSlugs.add(value);
          }
        }
      }

      final companySlugs = alarm['companies'];
      if (companySlugs is List) {
        for (final slug in companySlugs) {
          final value = slug.toString();
          if (value.isNotEmpty) selectedCompanySlugs.add(value);
        }
      }

      final companiesDetail = alarm['companies_detail'];
      if (companiesDetail is List) {
        for (final company in companiesDetail) {
          if (company is Map && company['slug'] != null) {
            final value = company['slug'].toString();
            if (value.isNotEmpty) selectedCompanySlugs.add(value);
          }
        }
      }
    }

    if (!_isHot && !_isLong) _isHot = true;

    final firstAlarm = activeAlarms.first;
    final firstNotifyAt = DateTime.tryParse(
      firstAlarm['notify_at']?.toString() ?? '',
    );
    final firstNotifyUntil = DateTime.tryParse(
      firstAlarm['notify_until']?.toString() ?? '',
    );

    if (firstNotifyAt != null) {
      final storedOffsetMinutes = int.tryParse(
        firstAlarm['timezone_offset_minutes']?.toString() ?? '',
      );

      if (storedOffsetMinutes != null) {
        final originalLocalStart = firstNotifyAt.toUtc().add(
          Duration(minutes: storedOffsetMinutes),
        );
        final originalLocalEnd = firstNotifyUntil?.toUtc().add(
          Duration(minutes: storedOffsetMinutes),
        );

        _selectedDate = DateTime(
          originalLocalStart.year,
          originalLocalStart.month,
          originalLocalStart.day,
        );
        _fromTime = TimeOfDay(
          hour: originalLocalStart.hour,
          minute: originalLocalStart.minute,
        );
        if (originalLocalEnd != null) {
          _toTime = TimeOfDay(
            hour: originalLocalEnd.hour,
            minute: originalLocalEnd.minute,
          );
        } else {
          var fallbackEnd = originalLocalStart.add(const Duration(hours: 4));
          final endOfDay = DateTime(
            originalLocalStart.year,
            originalLocalStart.month,
            originalLocalStart.day,
            23,
            59,
          );
          if (fallbackEnd.isAfter(endOfDay)) fallbackEnd = endOfDay;
          _toTime = TimeOfDay(hour: fallbackEnd.hour, minute: fallbackEnd.minute);
        }
      } else {
        final localStart = firstNotifyAt.toLocal();
        final localEnd = firstNotifyUntil?.toLocal();
        _selectedDate = DateTime(localStart.year, localStart.month, localStart.day);
        _fromTime = TimeOfDay(hour: localStart.hour, minute: localStart.minute);
        if (localEnd != null) {
          _toTime = TimeOfDay(hour: localEnd.hour, minute: localEnd.minute);
        } else {
          var fallbackEnd = localStart.add(const Duration(hours: 4));
          final endOfDay = DateTime(
            localStart.year,
            localStart.month,
            localStart.day,
            23,
            59,
          );
          if (fallbackEnd.isAfter(endOfDay)) fallbackEnd = endOfDay;
          _toTime = TimeOfDay(hour: fallbackEnd.hour, minute: fallbackEnd.minute);
        }
      }
    }
  }

  List<String> get _selectedProductTypes => [
    if (_isHot) 'hot',
    if (_isLong) 'long',
  ];

  bool _isTagSelectedForActiveTypes(String slug) {
    if (_isHot && _isLong) {
      return _selectedHotTagSlugs.contains(slug) &&
          _selectedLongTagSlugs.contains(slug);
    }
    if (_isHot) return _selectedHotTagSlugs.contains(slug);
    if (_isLong) return _selectedLongTagSlugs.contains(slug);
    return false;
  }

  void _toggleTagForActiveTypes(String slug) {
    final selected = _isTagSelectedForActiveTypes(slug);

    setState(() {
      if (_isHot) {
        selected
            ? _selectedHotTagSlugs.remove(slug)
            : _selectedHotTagSlugs.add(slug);
      }
      if (_isLong) {
        selected
            ? _selectedLongTagSlugs.remove(slug)
            : _selectedLongTagSlugs.add(slug);
      }
    });
  }

  bool get _allTagsSelectedForActiveTypes {
    if (_isHot && _isLong) {
      return _selectedHotTagSlugs.isEmpty && _selectedLongTagSlugs.isEmpty;
    }
    if (_isHot) return _selectedHotTagSlugs.isEmpty;
    if (_isLong) return _selectedLongTagSlugs.isEmpty;
    return true;
  }

  void _clearTagsForActiveTypes() {
    setState(() {
      if (_isHot) _selectedHotTagSlugs.clear();
      if (_isLong) _selectedLongTagSlugs.clear();
    });
  }

  bool _isCompanySelectedForActiveTypes(String slug) {
    if (_isHot && _isLong) {
      return _selectedHotCompanySlugs.contains(slug) &&
          _selectedLongCompanySlugs.contains(slug);
    }
    if (_isHot) return _selectedHotCompanySlugs.contains(slug);
    if (_isLong) return _selectedLongCompanySlugs.contains(slug);
    return false;
  }

  void _toggleCompanyForActiveTypes(String slug) {
    final selected = _isCompanySelectedForActiveTypes(slug);

    setState(() {
      if (_isHot) {
        selected
            ? _selectedHotCompanySlugs.remove(slug)
            : _selectedHotCompanySlugs.add(slug);
      }
      if (_isLong) {
        selected
            ? _selectedLongCompanySlugs.remove(slug)
            : _selectedLongCompanySlugs.add(slug);
      }
    });
  }

  List<Tag> _mergeTags(List<List<Tag>> groups) {
    final bySlug = <String, Tag>{};

    for (final group in groups) {
      for (final tag in group) {
        if (tag.slug.isEmpty) continue;

        final existing = bySlug[tag.slug];
        if (existing == null || tag.productsCount > existing.productsCount) {
          bySlug[tag.slug] = tag;
        }
      }
    }

    return bySlug.values.toList();
  }

  List<MapCompany> _mergeCompanies(List<List<MapCompany>> groups) {
    final bySlug = <String, MapCompany>{};

    for (final group in groups) {
      for (final company in group) {
        if (company.slug.isEmpty) continue;
        bySlug.putIfAbsent(company.slug, () => company);
      }
    }

    return bySlug.values.toList();
  }

  Future<void> _loadRealTags() async {
    if (!mounted) return;

    // Нулевого состояния больше нет: хотя бы один тип всегда выбран.
    if (!_isHot && !_isLong) {
      setState(() => _isHot = true);
    }

    final types = _selectedProductTypes;
    final generation = ++_typeLoadGeneration;

    setState(() {
      _tagsLoading = true;
      // Не показываем список от предыдущего типа, пока загружается новый.
      _realTags = [];
      _companies = [];
    });

    try {
      // При выборе обоих типов запросы для HOT и Deals стартуют параллельно.
      final tagGroupsFuture = Future.wait<List<Tag>>(
        types.map((type) => ApiService.getTagsByType(type)),
      );
      final companyGroupsFuture = Future.wait<List<MapCompany>>(
        types.map((type) => ApiService.getCompaniesByType(type)),
      );

      final tagGroups = await tagGroupsFuture;
      final companyGroups = await companyGroupsFuture;

      if (!mounted || generation != _typeLoadGeneration) return;

      setState(() {
        _realTags = _mergeTags(tagGroups);
        _companies = _mergeCompanies(companyGroups);
        _tagsLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_tagsScrollController.hasClients) return;
        _tagsScrollController.jumpTo(0);
      });
    } catch (_) {
      if (!mounted || generation != _typeLoadGeneration) return;

      // Для фильтра по типу нельзя подменять результат общим widget.tags:
      // иначе HOT/Deals снова визуально смешиваются при ошибке API.
      setState(() {
        _realTags = [];
        _companies = [];
        _tagsLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_tagsScrollController.hasClients) return;
        _tagsScrollController.jumpTo(0);
      });
    }
  }

  List<Tag> get _visibleTags {
    final result =
    _realTags.where((tag) => tag.slug.isNotEmpty).toList();

    result.sort((a, b) {
      final countCompare = b.productsCount.compareTo(a.productsCount);
      if (countCompare != 0) return countCompare;
      return a.name.compareTo(b.name);
    });

    return result;
  }

  void _toggleHotType() {
    // Нельзя выключить единственный активный тип.
    if (_isHot && !_isLong) return;

    setState(() {
      if (!_isHot) {
        _isHot = true;

        // При переходе Deals -> оба переносим текущие фильтры и на HOT.
        if (_isLong) {
          _selectedHotTagSlugs
            ..clear()
            ..addAll(_selectedLongTagSlugs);
          _selectedHotCompanySlugs
            ..clear()
            ..addAll(_selectedLongCompanySlugs);
        }
      } else {
        _isHot = false;
      }
      _sheetMessage = null;
    });

    _loadRealTags();
  }

  void _toggleLongType() {
    // Нельзя выключить единственный активный тип.
    if (_isLong && !_isHot) return;

    setState(() {
      if (!_isLong) {
        _isLong = true;

        // При переходе HOT -> оба переносим текущие фильтры и на Deals.
        if (_isHot) {
          _selectedLongTagSlugs
            ..clear()
            ..addAll(_selectedHotTagSlugs);
          _selectedLongCompanySlugs
            ..clear()
            ..addAll(_selectedHotCompanySlugs);
        }
      } else {
        _isLong = false;
      }
      _sheetMessage = null;
    });

    _loadRealTags();
  }

  String _tagImageUrl(Tag tag) {
    if (tag.imageUrl.trim().isNotEmpty) return tag.imageUrl.trim();

    for (final candidate in widget.tags) {
      if (candidate.slug == tag.slug && candidate.imageUrl.trim().isNotEmpty) {
        return candidate.imageUrl.trim();
      }
    }

    for (final candidate in _realTags) {
      if (candidate.slug == tag.slug && candidate.imageUrl.trim().isNotEmpty) {
        return candidate.imageUrl.trim();
      }
    }

    return '';
  }

  String _radiusText(AppLocalizations l10n) {
    if (_radiusKm <= 0) return l10n.alarmAnyDistance;
    final value = _radiusKm % 1 == 0
        ? _radiusKm.toInt().toString()
        : _radiusKm.toStringAsFixed(1);
    return '$value ${l10n.km}';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.97),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                if (_hasExistingAlarm) ...[
                  _buildActiveAlarmCard(),
                  const SizedBox(height: 12),
                ],
                _buildDateTimeCard(),
                const SizedBox(height: 12),
                _buildTags(),
                const SizedBox(height: 6),
                _buildCompanies(),
                const SizedBox(height: 14),
                _buildBottomActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _alarmTypeLabel(String type) {
    final languageCode = Localizations.localeOf(context).languageCode;

    if (type == 'long') {
      switch (languageCode) {
        case 'hy':
          return 'Առաքում';
        case 'en':
          return 'Delivery';
        default:
          return 'Доставка';
      }
    }

    switch (languageCode) {
      case 'hy':
        return 'Վերցնել տեղում';
      case 'en':
        return 'Pickup';
      default:
        return 'Самовывоз';
    }
  }

  Widget _buildActiveAlarmCard() {
    final l10n = AppLocalizations.of(context)!;
    final types = <String>[
      if (_isHot) _alarmTypeLabel('hot'),
      if (_isLong) _alarmTypeLabel('long'),
    ].join(' + ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.black,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.alarmNotificationsActive,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_dateText(_selectedDate)} • ${_formatTime(_fromTime)}–${_formatTime(_toTime)} • ${_radiusText(l10n)}${types.isNotEmpty ? ' • $types' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeCard() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _pickDate,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE9E9E9)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 21,
                  color: Color(0xFF5E6570),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.date,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    _dateText(_selectedDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _InlineTimeEditor(
                label: l10n.alarmFrom,
                value: _fromTime,
                onChanged: _onFromTimeChanged,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7),
              child: Text(
                '—',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black54,
                ),
              ),
            ),
            Expanded(
              child: _InlineTimeEditor(
                label: l10n.alarmTo,
                value: _toTime,
                onChanged: _onToTimeChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTags() {
    final tags = _visibleTags;

    if (_tagsLoading) {
      return const SizedBox(
        height: 176,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        // In the alarm sheet tags are intentionally a little larger than on
        // MapScreen, so long names stay readable and are easier to tap.
        final columns = constraints.maxWidth < 285 ? 4 : 5;
        const rowHeight = 88.0;
        const maxVisibleRows = 2;

        // +1 is the explicit "All" category tile, matching MapScreen.
        final itemCount = tags.length + 1;
        final totalRows = (itemCount / columns).ceil();
        final visibleRows =
        totalRows < maxVisibleRows ? totalRows : maxVisibleRows;
        final canScroll = totalRows > maxVisibleRows;
        final gridHeight = (visibleRows <= 0 ? 1 : visibleRows) * rowHeight;

        final grid = GridView.builder(
          controller: _tagsScrollController,
          padding: EdgeInsets.only(
            top: 2,
            right: canScroll ? 8 : 0,
          ),
          physics: canScroll
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 5,
            mainAxisSpacing: 0,
            mainAxisExtent: rowHeight,
          ),
          itemCount: itemCount,
          itemBuilder: (_, index) {
            if (index == 0) {
              final selected = _allTagsSelectedForActiveTypes;

              return Tooltip(
                message: l10n.all,
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: l10n.all,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: _clearTagsForActiveTypes,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: selected
                                  ? accentColor.withOpacity(0.22)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/icons/all_filters.svg',
                                width: 34,
                                height: 34,
                                fit: BoxFit.contain,
                                colorFilter: ColorFilter.mode(
                                  selected
                                      ? Colors.black87
                                      : Colors.grey.shade500,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: 66,
                            child: Text(
                              l10n.all,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.05,
                                fontWeight: selected
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                color: selected
                                    ? Colors.black
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final tag = tags[index - 1];
            final selected = _isTagSelectedForActiveTypes(tag.slug);
            final imageUrl = _tagImageUrl(tag);

            return Tooltip(
              message: tag.name,
              child: Semantics(
                button: true,
                selected: selected,
                label: tag.name,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => _toggleTagForActiveTypes(tag.slug),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: selected
                                ? accentColor.withOpacity(0.22)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Center(
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                              ApiService.fixImageUrl(imageUrl),
                              width: 36,
                              height: 36,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  _TagFallbackIcon(selected: selected),
                            )
                                : _TagFallbackIcon(selected: selected),
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          width: 66,
                          child: Text(
                            tag.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.05,
                              fontWeight: selected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color:
                              selected ? Colors.black : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );

        return SizedBox(
          height: gridHeight,
          child: canScroll
              ? RawScrollbar(
            controller: _tagsScrollController,
            thumbVisibility: true,
            trackVisibility: false,
            interactive: true,
            thickness: 2.5,
            radius: const Radius.circular(999),
            minThumbLength: 24,
            thumbColor: Colors.black26,
            child: grid,
          )
              : grid,
        );
      },
    );
  }

  Widget _buildCompanies() {
    if (_tagsLoading) {
      return const SizedBox(
        height: 90,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_companies.isEmpty) {
      return const SizedBox.shrink();
    }

    final companies = List<MapCompany>.from(_companies)
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: companies.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final company = companies[index];
              final selected =
              _isCompanySelectedForActiveTypes(company.slug);

              return GestureDetector(
                onTap: () => _toggleCompanyForActiveTypes(company.slug),
                child: SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: selected
                                ? accentColor
                                : const Color(0xFFE3E3E3),
                            width: selected ? 2.6 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                selected ? 0.14 : 0.06,
                              ),
                              blurRadius: selected ? 14 : 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: ClipOval(
                            child: Image.network(
                              ApiService.fixImageUrl(company.imageUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  color: const Color(0xFFF5F5F5),
                                  child: const Icon(
                                    Icons.storefront_rounded,
                                    size: 24,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        company.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1,
                          fontWeight:
                          selected ? FontWeight.w900 : FontWeight.w700,
                          color: selected ? Colors.black : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSheetMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    setState(() {
      _sheetMessage = message;
      _sheetMessageIsError = isError;
    });
  }

  void _clearSheetMessage() {
    if (_sheetMessage == null || !mounted) return;
    setState(() => _sheetMessage = null);
  }

  Widget _buildSheetMessage() {
    final message = _sheetMessage;
    if (message == null || message.isEmpty) return const SizedBox.shrink();

    final background = _sheetMessageIsError
        ? const Color(0xFFFFF1F0)
        : const Color(0xFFF4F0C8);
    final border = _sheetMessageIsError
        ? const Color(0xFFE57373)
        : accentColor;
    final iconColor = _sheetMessageIsError
        ? const Color(0xFFD84343)
        : const Color(0xFF665A00);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withOpacity(0.75), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _sheetMessageIsError
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded,
            size: 19,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w800,
                color: _sheetMessageIsError
                    ? const Color(0xFF9E2F2F)
                    : const Color(0xFF4E4600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_sheetMessage != null) ...[
          _buildSheetMessage(),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            _RadiusInfo(
              text: _radiusText(AppLocalizations.of(context)!),
            ),
            const SizedBox(width: 6),
            _AreaButton(
              onTap: _openAreaPicker,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _buildMiniTypeSwitch(),
            ),
            const Spacer(),
            SizedBox(
              width: 104,
              height: 38,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAlarm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  side: const BorderSide(
                    color: accentColor,
                    width: 1.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _hasExistingAlarm
                          ? AppLocalizations.of(context)!.alarmSave
                          : AppLocalizations.of(context)!.alarmSet,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_hasExistingAlarm) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _isDeletingAlarm ? null : _deleteCurrentAlarms,
              icon: _isDeletingAlarm
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.notifications_off_rounded),
              label: Text(AppLocalizations.of(context)!.alarmDisable),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMiniTypeSwitch() {
    final bothSelected = _isHot && _isLong;

    return SizedBox(
      width: 112,
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final switchWidth = constraints.maxWidth;
          // Один выбранный сегмент занимает 58% фактической ширины.
          // Поэтому заливка немного заходит за центральную линию, как в Figma.
          final singleSegmentInset = switchWidth * 0.42;

          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  // Белая основа всей цельной кнопки.
                  Positioned.fill(
                    child: Container(color: Colors.white),
                  ),

                  // Адаптивная заливка. Здесь нет фиксированных 40/45 px,
                  // поэтому она корректно занимает область даже если
                  // переключатель сжимается на небольшом экране.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 210),
                    curve: Curves.easeOutCubic,
                    top: 0,
                    bottom: 0,
                    left: bothSelected
                        ? 0
                        : _isHot
                        ? 0
                        : singleSegmentInset,
                    right: bothSelected
                        ? 0
                        : _isLong
                        ? 0
                        : singleSegmentInset,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 210),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6DC74),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),

                  // HOT и Deals всегда занимают ровно по половине кнопки.
                  Positioned.fill(
                    child: Row(
                      children: [
                        _TypeIconSegment(
                          assetPath: 'assets/icons/home.svg',
                          activeAssetPath: 'assets/icons/home.svg',
                          selected: _isHot,
                          visualOffsetX: 1.0,
                          onTap: _toggleHotType,
                        ),
                        _TypeIconSegment(
                          assetPath: 'assets/icons/deals.svg',
                          activeAssetPath: 'assets/icons/deals.svg',
                          selected: _isLong,
                          visualOffsetX: -5.0,
                          onTap: _toggleLongType,
                        ),
                      ],
                    ),
                  ),

                  // Контур всегда поверх заливки — получается одна цельная
                  // капсула без белого зазора по краям выбранной части.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFD1BC00),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAreaPicker() async {
    // Выбор точки/радиуса не должен влиять на дату и время уведомления.
    // Сохраняем именно значения, выбранные на телефоне, до перехода на карту.
    final preservedDate = _selectedDate;
    final preservedFromTime = _fromTime;
    final preservedToTime = _toTime;

    final locationProvider = context.read<LocationProvider>();

    if (locationProvider.position == null) {
      await locationProvider.loadLocation();
    }

    final position = locationProvider.position;

    final initialPoint = LatLng(
      _selectedLatitude ?? position?.latitude ?? 40.1772,
      _selectedLongitude ?? position?.longitude ?? 44.5035,
    );

    final result = await Navigator.push<_AlarmAreaResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _AlarmAreaPickerScreen(
          initialCenter: initialPoint,
          initialRadiusKm: _radiusKm <= 0 ? 3 : _radiusKm,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _selectedLatitude = result.center.latitude;
      _selectedLongitude = result.center.longitude;
      _radiusKm = result.radiusKm;

      // Карта меняет только область поиска. Время остаётся временем телефона.
      _selectedDate = preservedDate;
      _fromTime = preservedFromTime;
      _toTime = preservedToTime;
    });
  }

  Future<void> _showRadiusPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = radiusOptions.indexWhere((value) => value == _radiusKm);
    int selectedIndex = currentIndex >= 0 ? currentIndex : 1;
    final controller = FixedExtentScrollController(initialItem: selectedIndex);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.alarmNotificationRadius,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.alarmRadiusHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: ListWheelScrollView.useDelegate(
                    controller: controller,
                    itemExtent: 44,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) => selectedIndex = index,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: radiusOptions.length,
                      builder: (context, index) {
                        final value = radiusOptions[index];
                        final text = value <= 0
                            ? l10n.alarmAnyDistanceLong
                            : '${value.toInt()} ${l10n.km}';
                        return Center(
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _radiusKm = radiusOptions[selectedIndex]);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      l10n.done,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
  }


  Future<void> _showAuthRequiredDialog() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            l10n.alarmLoginTitle,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            l10n.alarmLoginBody,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                l10n.alarmUnderstood,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  bool _isNotAuthenticatedError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('not authenticated') ||
        text.contains('authentication') ||
        text.contains('unauthorized') ||
        text.contains('401');
  }


  DateTime _buildSelectedNotifyAt() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _fromTime.hour,
      _fromTime.minute,
    );
  }

  DateTime _buildSelectedNotifyUntil() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _toTime.hour,
      _toTime.minute,
    );
  }

  DateTime _minimumAllowedNotifyAt() {
    return DateTime.now().add(const Duration(minutes: 5));
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  void _adjustTimeForTodayIfNeeded() {
    final now = DateTime.now();
    if (!_isSameCalendarDay(_selectedDate, now)) return;

    final selected = _buildSelectedNotifyAt();
    final minimum = _minimumAllowedNotifyAt();

    if (selected.isAfter(minimum)) return;

    final roundedMinute = ((minimum.minute + 4) ~/ 5) * 5;
    final rounded = DateTime(
      minimum.year,
      minimum.month,
      minimum.day,
      minimum.hour,
      roundedMinute,
    );

    _fromTime = TimeOfDay(hour: rounded.hour, minute: rounded.minute);

    final currentEnd = _buildSelectedNotifyUntil();
    if (!currentEnd.isAfter(rounded)) {
      var newEnd = rounded.add(const Duration(hours: 1));
      final endOfDay = DateTime(rounded.year, rounded.month, rounded.day, 23, 59);
      if (newEnd.isAfter(endOfDay)) newEnd = endOfDay;
      _toTime = TimeOfDay(hour: newEnd.hour, minute: newEnd.minute);
    }
  }

  void _onFromTimeChanged(TimeOfDay value) {
    setState(() {
      _sheetMessage = null;
      _fromTime = value;
      final start = _buildSelectedNotifyAt();
      final end = _buildSelectedNotifyUntil();
      if (!end.isAfter(start)) {
        var newEnd = start.add(const Duration(hours: 1));
        final endOfDay = DateTime(start.year, start.month, start.day, 23, 59);
        if (newEnd.isAfter(endOfDay)) newEnd = endOfDay;
        _toTime = TimeOfDay(hour: newEnd.hour, minute: newEnd.minute);
      }
    });
  }

  void _onToTimeChanged(TimeOfDay value) {
    setState(() {
      _sheetMessage = null;
      _toTime = value;
    });
  }

  Future<void> _saveAlarm() async {
    final l10n = AppLocalizations.of(context)!;
    final notifyAt = _buildSelectedNotifyAt();
    final notifyUntil = _buildSelectedNotifyUntil();
    final minimumAllowed = _minimumAllowedNotifyAt();

    FocusScope.of(context).unfocus();
    _clearSheetMessage();

    if (!notifyAt.isAfter(minimumAllowed)) {
      _showSheetMessage(l10n.alarmMinFiveMinutes);
      return;
    }

    if (!notifyUntil.isAfter(notifyAt)) {
      _showSheetMessage(l10n.alarmEndAfterStart);
      return;
    }

    // Берём offset именно для выбранной даты/времени.
    // Это лучше, чем DateTime.now().timeZoneOffset: в странах с DST
    // смещение на будущую дату может отличаться.
    final timezoneOffsetMinutes = notifyAt.timeZoneOffset.inMinutes;

    final types = <String>[
      if (_isHot) 'hot',
      if (_isLong) 'long',
    ];

    if (types.isEmpty) {
      _showSheetMessage(l10n.alarmChooseType);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final locationProvider = context.read<LocationProvider>();
      if (locationProvider.position == null) {
        await locationProvider.loadLocation();
      }

      final position = locationProvider.position;

      if (_activeAlarmIds.isNotEmpty) {
        for (final id in List<int>.from(_activeAlarmIds)) {
          await ApiService.deleteNotificationAlarm(id);
        }
      }

      for (final type in types) {
        final tagSlugs = type == 'long'
            ? _selectedLongTagSlugs.toList()
            : _selectedHotTagSlugs.toList();
        final companySlugs = type == 'long'
            ? _selectedLongCompanySlugs.toList()
            : _selectedHotCompanySlugs.toList();

        debugPrint(
          'ALARM PAYLOAD: type=$type tags=$tagSlugs companies=$companySlugs '
              'radius=$_radiusKm lat=${_selectedLatitude ?? position?.latitude} '
              'lng=${_selectedLongitude ?? position?.longitude} notifyAt=$notifyAt '
              'notifyUntil=$notifyUntil timezoneOffsetMinutes=$timezoneOffsetMinutes',
        );

        await ApiService.createNotificationAlarm(
          productType: type,
          tagSlugs: tagSlugs,
          companySlugs: companySlugs,
          notifyAt: notifyAt,
          notifyUntil: notifyUntil,
          timezoneOffsetMinutes: timezoneOffsetMinutes,
          radiusKm: _radiusKm,
          latitude: _selectedLatitude ?? position?.latitude,
          longitude: _selectedLongitude ?? position?.longitude,
        );
      }

      try {
        final alarms = await ApiService.getNotificationAlarms();
        final active = alarms
            .where(_isCurrentActiveAlarm)
            .map((alarm) => Map<String, dynamic>.from(alarm))
            .toList();
        alarmActiveListGlobal.value = active;
        alarmSavedGlobal.value = active.isNotEmpty;
      } catch (_) {
        alarmSavedGlobal.value = true;
      }

      if (!mounted) return;

      setState(() => _isSaving = false);
      Navigator.pop(context, true);

      final savedPrefix = _hasExistingAlarm ? l10n.alarmUpdated : l10n.alarmSaved;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$savedPrefix: ${_dateText(_selectedDate)} • '
                '${_formatTime(_fromTime)}–${_formatTime(_toTime)} • ${_radiusText(l10n)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      // 👇 ИЗМЕНЕНО: теперь ошибка логируется
      debugPrint('ALARM SAVE ERROR: $e');
      debugPrint('ALARM SAVE STACK: $st');

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (_isNotAuthenticatedError(e)) {
        await _showAuthRequiredDialog();
        return;
      }

      _showSheetMessage(l10n.alarmSaveFailed);
    }
  }

  Future<void> _deleteCurrentAlarms() async {
    final l10n = AppLocalizations.of(context)!;
    if (_activeAlarmIds.isEmpty) {
      Navigator.pop(context, true);
      alarmSavedGlobal.value = false;
      alarmActiveListGlobal.value = [];
      return;
    }

    setState(() => _isDeletingAlarm = true);

    try {
      for (final id in List<int>.from(_activeAlarmIds)) {
        await ApiService.deleteNotificationAlarm(id);
      }

      alarmSavedGlobal.value = false;
      alarmActiveListGlobal.value = [];

      if (!mounted) return;
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.alarmDisabled),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeletingAlarm = false);

      _showSheetMessage(l10n.alarmDisableFailed);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final l10n = AppLocalizations.of(context)!;

    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(DateTime(now.year, now.month, now.day))
          ? DateTime(now.year, now.month, now.day)
          : _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
      helpText: l10n.chooseDate,
      cancelText: l10n.cancel,
      confirmText: l10n.done,
      fieldLabelText: l10n.date,
      fieldHintText: l10n.dateHint,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: accentColor,
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (result == null) return;

    setState(() {
      _sheetMessage = null;
      _selectedDate = result;
      _adjustTimeForTodayIfNeeded();
    });
  }

  String _dateText(DateTime date) {
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}

class _InlineTimeEditor extends StatefulWidget {
  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  const _InlineTimeEditor({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_InlineTimeEditor> createState() => _InlineTimeEditorState();
}

class _InlineTimeEditorState extends State<_InlineTimeEditor> {
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  late final FocusNode _hourFocus;
  late final FocusNode _minuteFocus;

  @override
  void initState() {
    super.initState();
    _hourController = TextEditingController(text: _two(widget.value.hour));
    _minuteController = TextEditingController(text: _two(widget.value.minute));
    _hourFocus = FocusNode()..addListener(_normalizeIfNeeded);
    _minuteFocus = FocusNode()..addListener(_normalizeIfNeeded);
  }

  @override
  void didUpdateWidget(covariant _InlineTimeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hourFocus.hasFocus && oldWidget.value.hour != widget.value.hour) {
      _hourController.text = _two(widget.value.hour);
    }
    if (!_minuteFocus.hasFocus && oldWidget.value.minute != widget.value.minute) {
      _minuteController.text = _two(widget.value.minute);
    }
  }

  @override
  void dispose() {
    _hourFocus.removeListener(_normalizeIfNeeded);
    _minuteFocus.removeListener(_normalizeIfNeeded);
    _hourFocus.dispose();
    _minuteFocus.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  void _emitIfValid() {
    final hour = int.tryParse(_hourController.text);
    final minute = int.tryParse(_minuteController.text);
    if (hour == null || minute == null) return;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return;
    widget.onChanged(TimeOfDay(hour: hour, minute: minute));
  }

  void _normalizeIfNeeded() {
    if (_hourFocus.hasFocus || _minuteFocus.hasFocus) return;

    var hour = int.tryParse(_hourController.text) ?? widget.value.hour;
    var minute = int.tryParse(_minuteController.text) ?? widget.value.minute;
    hour = hour.clamp(0, 23);
    minute = minute.clamp(0, 59);

    _hourController.text = _two(hour);
    _minuteController.text = _two(minute);
    widget.onChanged(TimeOfDay(hour: hour, minute: minute));
  }

  Widget _numberField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int maxValue,
    FocusNode? nextFocus,
  }) {
    return SizedBox(
      width: 34,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textInputAction: nextFocus == null ? TextInputAction.done : TextInputAction.next,
        textAlign: TextAlign.center,
        maxLength: 2,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        style: const TextStyle(
          fontSize: 19,
          height: 1,
          fontWeight: FontWeight.w900,
          color: Colors.black,
        ),
        decoration: const InputDecoration(
          counterText: '',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 2),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFD1BC00), width: 1.5),
          ),
        ),
        onChanged: (value) {
          final parsed = int.tryParse(value);
          if (value.length == 2 && parsed != null && parsed <= maxValue) {
            _emitIfValid();
            if (nextFocus != null) nextFocus.requestFocus();
          }
        },
        onSubmitted: (_) {
          _normalizeIfNeeded();
          if (nextFocus != null) nextFocus.requestFocus();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9E9E9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _numberField(
                      controller: _hourController,
                      focusNode: _hourFocus,
                      maxValue: 23,
                      nextFocus: _minuteFocus,
                    ),
                    const Text(
                      ':',
                      style: TextStyle(
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    _numberField(
                      controller: _minuteController,
                      focusNode: _minuteFocus,
                      maxValue: 59,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadiusInfo extends StatelessWidget {
  final String text;

  const _RadiusInfo({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 44,
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _RadiusButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _RadiusButton({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 44,
      child: Material(
        color: const Color(0xFFF6F2D0),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE6D962), width: 1.1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.near_me_rounded, size: 17, color: Color(0xFF5C5200)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5C5200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeIconSegment extends StatelessWidget {
  final String assetPath;
  final String activeAssetPath;
  final bool selected;
  final VoidCallback onTap;
  final double visualOffsetX;

  const _TypeIconSegment({
    required this.assetPath,
    required this.activeAssetPath,
    required this.selected,
    required this.onTap,
    this.visualOffsetX = 0,
  });

  @override
  Widget build(BuildContext context) {
    final path = selected ? activeAssetPath : assetPath;
    final color = selected
        ? const Color(0xFF5C5C5C)
        : const Color(0xFF8A8A8A);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Center(
            child: Transform.translate(
              offset: Offset(visualOffsetX, 0),
              child: path.toLowerCase().endsWith('.svg')
                  ? SvgPicture.asset(
                path,
                width: 18,
                height: 18,
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              )
                  : Image.asset(
                path,
                width: 18,
                height: 18,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.notifications_rounded,
                  size: 18,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagFallbackIcon extends StatelessWidget {
  final bool selected;

  const _TagFallbackIcon({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.notifications_rounded,
      size: 30,
      color: selected ? const Color(0xFFD1BC00) : Colors.grey.shade500,
    );
  }
}

class _AlarmAreaResult {
  final LatLng center;
  final double radiusKm;

  const _AlarmAreaResult({
    required this.center,
    required this.radiusKm,
  });
}

class _AreaButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AreaButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 44,
      child: Material(
        color: const Color(0xFFF6F2D0),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFE6D962),
                width: 1.1,
              ),
            ),
            child: const Icon(
              Icons.map_rounded,
              size: 21,
              color: Color(0xFF5C5200),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlarmAreaPickerScreen extends StatefulWidget {
  final LatLng initialCenter;
  final double initialRadiusKm;

  const _AlarmAreaPickerScreen({
    required this.initialCenter,
    required this.initialRadiusKm,
  });

  @override
  State<_AlarmAreaPickerScreen> createState() => _AlarmAreaPickerScreenState();
}

class _AlarmAreaPickerScreenState extends State<_AlarmAreaPickerScreen> {
  static const Color accentColor = Color(0xFFD1BC00);

  late LatLng _center;
  late double _radiusKm;

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter;
    _radiusKm = widget.initialRadiusKm;
  }

  @override
  Widget build(BuildContext context) {
    final radiusMeters = _radiusKm * 1000;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.alarmSelectArea,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onTap: (_, point) {
                setState(() => _center = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.armenia',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _center,
                    radius: radiusMeters,
                    useRadiusInMeter: true,
                    color: accentColor.withOpacity(0.18),
                    borderColor: accentColor,
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 46,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${AppLocalizations.of(context)!.radius}: '
                          '${_radiusKm.toStringAsFixed(_radiusKm % 1 == 0 ? 0 : 1)} '
                          '${AppLocalizations.of(context)!.km}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Slider(
                      value: _radiusKm,
                      min: 1,
                      max: 25,
                      divisions: 24,
                      activeColor: accentColor,
                      onChanged: (value) {
                        setState(() => _radiusKm = value);
                      },
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(
                            context,
                            _AlarmAreaResult(
                              center: _center,
                              radiusKm: _radiusKm,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.alarmChooseArea,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}