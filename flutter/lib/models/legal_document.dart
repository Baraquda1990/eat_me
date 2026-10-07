class LegalDocumentInfo {
  final int id;
  final String type;
  final String version;
  final String placement;
  final bool requiresAcceptance;
  final String title;
  final String content;
  final String hash;
  final String language;
  final String? snapshotUrl;
  final DateTime? effectiveAt;
  final bool? accepted;

  const LegalDocumentInfo({
    required this.id,
    required this.type,
    required this.version,
    required this.placement,
    required this.requiresAcceptance,
    required this.title,
    required this.content,
    required this.hash,
    required this.language,
    this.snapshotUrl,
    this.effectiveAt,
    this.accepted,
  });

  factory LegalDocumentInfo.fromJson(Map<String, dynamic> json) {
    return LegalDocumentInfo(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      type: json['type']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      placement: json['placement']?.toString() ?? '',
      requiresAcceptance: json['requires_acceptance'] == true,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      hash: json['hash']?.toString() ?? '',
      language: json['language']?.toString() ?? 'en',
      snapshotUrl: json['snapshot_url']?.toString(),
      effectiveAt: DateTime.tryParse(json['effective_at']?.toString() ?? ''),
      accepted: json.containsKey('accepted') ? json['accepted'] == true : null,
    );
  }

  Map<String, dynamic> toAcceptancePayload() {
    return {
      'type': type,
      'version': version,
      'hash': hash,
      'language': language,
    };
  }
}

class LegalStatusResult {
  final bool ready;
  final String action;
  final List<LegalDocumentInfo> missing;

  const LegalStatusResult({
    required this.ready,
    required this.action,
    required this.missing,
  });

  factory LegalStatusResult.fromJson(Map<String, dynamic> json) {
    final raw = json['missing'];
    final missing = raw is List
        ? raw
        .whereType<Map>()
        .map((e) => LegalDocumentInfo.fromJson(
      Map<String, dynamic>.from(e),
    ))
        .toList()
        : <LegalDocumentInfo>[];

    return LegalStatusResult(
      ready: json['ready'] == true,
      action: json['action']?.toString() ?? '',
      missing: missing,
    );
  }
}
