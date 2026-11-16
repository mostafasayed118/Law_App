import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:legalhub/app/legal_config.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Which bundled document a screen renders.
enum LegalDocumentKind { privacy, terms }

/// One section of a bundled legal document.
///
/// The id is a stable parity key: all three locales must declare exactly the
/// same set, checked by `test/legal/legal_content_parity_test.dart`.
class LegalSection {
  const LegalSection({
    required this.id,
    required this.heading,
    required this.paragraphs,
  });

  final String id;
  final String heading;
  final List<String> paragraphs;
}

/// Loads the bundled, per-locale legal content.
///
/// No markdown package: the assets are structured JSON and this tiny renderer
/// handles the shape the app actually needs (heading + paragraphs). Adding a
/// dependency for four headings and seven paragraphs would be bloat.
abstract final class LegalContent {
  static Future<List<LegalSection>> load(
    LegalDocumentKind kind,
    String languageCode,
  ) async {
    final String code = switch (languageCode) {
      'ar' => 'ar',
      'tr' => 'tr',
      _ => 'en',
    };
    final String raw = await rootBundle.loadString(
      'assets/legal/legal_$code.json',
    );
    final Map<String, dynamic> decoded =
        jsonDecode(raw) as Map<String, dynamic>;
    final String key = switch (kind) {
      LegalDocumentKind.privacy => 'privacy',
      LegalDocumentKind.terms => 'terms',
    };
    final List<dynamic> rows = decoded[key] as List<dynamic>;
    return rows
        .map(
          (dynamic rawRow) => LegalSection(
            id: (rawRow as Map<String, dynamic>)['id'] as String,
            heading: rawRow['heading'] as String,
            paragraphs: (rawRow['paragraphs'] as List<dynamic>)
                .map((dynamic p) => p as String)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }
}

/// Renders one bundled legal document with a single, shared scaffold.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({required this.kind, super.key});

  final LegalDocumentKind kind;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late final Future<List<LegalSection>> _sections = LegalContent.load(
    widget.kind,
    Localizations.localeOf(context).languageCode,
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String title = switch (widget.kind) {
      LegalDocumentKind.privacy => l10n.legalPrivacyTitle,
      LegalDocumentKind.terms => l10n.legalTermsTitle,
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<LegalSection>>(
        future: _sections,
        builder:
            (BuildContext context, AsyncSnapshot<List<LegalSection>> snapshot) {
              // A static placeholder, not a spinning indicator: an infinitely
              // animating progress ring prevents pumpAndSettle from ever
              // settling, which made the responsive matrix flaky under load.
              // The asset load is local and completes in a frame or two.
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: SizedBox(width: 24, height: 24));
              }
              final List<LegalSection> sections =
                  snapshot.data ?? const <LegalSection>[];
              return ListView(
                padding: const EdgeInsetsDirectional.all(
                  LegalHubTheme.marginMobile,
                ),
                children: <Widget>[
                  Text(
                    l10n.legalLastUpdated(
                      LegalConfig.isConfigured
                          ? LegalConfig.lastUpdated
                          : l10n.legalContactNotConfigured,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: LegalHubTheme.spaceLg),
                  for (final LegalSection section in sections) ...<Widget>[
                    Text(
                      section.heading,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: LegalHubTheme.spaceSm),
                    for (final String paragraph in section.paragraphs)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          bottom: LegalHubTheme.spaceMd,
                        ),
                        child: Text(
                          paragraph,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(height: 1.6),
                        ),
                      ),
                    const SizedBox(height: LegalHubTheme.spaceSm),
                  ],
                  if (widget.kind == LegalDocumentKind.terms &&
                      LegalConfig.governingLaw.startsWith('REPLACE_'))
                    Text(
                      l10n.legalContactNotConfigured,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              );
            },
      ),
    );
  }
}

/// A small, accessible link used by the sign-up checkbox label.
class LegalLink extends StatelessWidget {
  const LegalLink({required this.kind, required this.label, super.key});

  final LegalDocumentKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        // Inside a RichText WidgetSpan the link is only as tall as its text;
        // give it a 48dp target so the Android guideline (and real fingers)
        // can hit it reliably.
        height: 48,
        child: InkWell(
          onTap: () => context.push(
            kind == LegalDocumentKind.privacy
                ? AppRoutes.privacy
                : AppRoutes.terms,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
