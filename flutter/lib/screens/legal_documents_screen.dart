import 'package:flutter/material.dart';

import '../models/legal_document.dart';
import '../services/api_service.dart';
import '../utils/legal_ui_text.dart';
import '../widgets/app_error_state.dart';
import 'legal_document_screen.dart';

class LegalDocumentsScreen extends StatefulWidget {
  const LegalDocumentsScreen({super.key});

  @override
  State<LegalDocumentsScreen> createState() => _LegalDocumentsScreenState();
}

class _LegalDocumentsScreenState extends State<LegalDocumentsScreen> {
  static const Color _accent = Color(0xFFD1BC00);

  Future<List<LegalDocumentInfo>>? _future;
  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (_language != language) {
      _language = language;
      _future = ApiService.getLegalDocuments(
        action: 'all',
        language: language,
      );
    }
  }

  void _retry() {
    setState(() {
      _future = ApiService.getLegalDocuments(
        action: 'all',
        language: _language,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = LegalUiText.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
        title: Text(
          text.legalInformation,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<List<LegalDocumentInfo>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }

          if (snapshot.hasError) {
            return AppErrorState(
              error: snapshot.error,
              onRetry: () async => _retry(),
            );
          }

          final documents = snapshot.data ?? const <LegalDocumentInfo>[];
          if (documents.isEmpty) {
            return Center(child: Text(text.loadFailed));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: documents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final document = documents[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: _accent,
                    ),
                  ),
                  title: Text(
                    document.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${text.version} ${document.version}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LegalDocumentScreen(
                          document: document,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
