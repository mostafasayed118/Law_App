import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/presentation/highlighted_body.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Structural pins for the article body's highlight spans.
///
/// A highlight range must be ONE TextSpan carrying the background: the text
/// before/after is unhighlighted, and the concatenation of every span is the
/// article body byte-for-byte. These tests cannot see painted pixels; they pin
/// the span construction that the earlier per-word fallback-run defect came
/// from.
void main() {
  LegalHighlight highlight({
    required int start,
    required int end,
    required String quote,
    String id = 'h1',
  }) {
    return LegalHighlight(
      id: id,
      articleId: 'legal-art-1-1',
      documentId: 'legal-doc-1',
      documentTitleAr: 'قانون تجريبي للإيجارات (نموذج)',
      articleNumber: '1',
      startOffset: start,
      endOffset: end,
      quote: quote,
      color: HighlightColorSlot.yellow,
      isStale: false,
      articleSample: true,
      documentSample: true,
      createdAt: DateTime.utc(2026, 11, 17),
    );
  }

  Future<void> pumpBody(
    WidgetTester tester, {
    required String body,
    required List<LegalHighlight> highlights,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: LegalHubTheme.forLocale(locale),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HighlightedBody(
              body: body,
              highlights: highlights,
              textStyle: const TextStyle(fontSize: 16, height: 1.7),
              onSelectionHighlight: (int start, int end) {},
              onHighlightTapped: (LegalHighlight tapped) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<InlineSpan> spansOf(WidgetTester tester) {
    final SelectableText selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    final TextSpan root = selectable.textSpan!;
    return root.children ?? const <InlineSpan>[];
  }

  List<TextSpan> highlightedOf(List<InlineSpan> spans) => spans
      .whereType<TextSpan>()
      .where((TextSpan span) => span.style?.backgroundColor != null)
      .toList();

  String joinedText(List<InlineSpan> spans) => spans
      .whereType<TextSpan>()
      .map((TextSpan span) => span.text ?? '')
      .join();

  testWidgets('English multi-word highlight is exactly one background span', (
    WidgetTester tester,
  ) async {
    const String body = 'The quick brown fox jumps over the lazy dog.';
    const String quote = 'quick brown fox';
    final int start = body.indexOf(quote);
    final int end = start + quote.length;

    await pumpBody(
      tester,
      body: body,
      highlights: <LegalHighlight>[
        highlight(start: start, end: end, quote: quote),
      ],
    );

    final List<InlineSpan> spans = spansOf(tester);
    final List<TextSpan> highlighted = highlightedOf(spans);

    expect(
      highlighted,
      hasLength(1),
      reason: 'a highlight range must paint as one span, not per word',
    );
    expect(highlighted.single.text, quote);
    expect(
      spans.whereType<TextSpan>().map((TextSpan s) => s.text).toList(),
      <String>['The ', quote, ' jumps over the lazy dog.'],
    );
    expect(joinedText(spans), body);
  });

  testWidgets('Arabic RTL multi-word highlight is one span and flows RTL', (
    WidgetTester tester,
  ) async {
    // Sample corpus text (is_sample = true); no invented legal text.
    const String body =
        'ينظم هذا النموذج العلاقة الإيجارية بين المؤجر والمستأجر من حيث المدة والأجرة.';
    const String quote = 'العلاقة الإيجارية';
    final int start = body.indexOf(quote);
    final int end = start + quote.length;

    await pumpBody(
      tester,
      body: body,
      highlights: <LegalHighlight>[
        highlight(start: start, end: end, quote: quote),
      ],
      locale: const Locale('ar'),
    );

    final List<InlineSpan> spans = spansOf(tester);
    final List<TextSpan> highlighted = highlightedOf(spans);

    expect(highlighted, hasLength(1));
    expect(highlighted.single.text, quote);
    expect(joinedText(spans), body);
    expect(
      Directionality.of(tester.element(find.byType(SelectableText))),
      TextDirection.rtl,
    );
  });

  testWidgets('highlight that starts and ends mid-word stays one span', (
    WidgetTester tester,
  ) async {
    const String body = 'The quick brown fox jumps over the lazy dog.';
    const String quote = 'uick bro';
    final int start = body.indexOf(quote);
    final int end = start + quote.length;

    await pumpBody(
      tester,
      body: body,
      highlights: <LegalHighlight>[
        highlight(start: start, end: end, quote: quote),
      ],
    );

    final List<InlineSpan> spans = spansOf(tester);
    final List<TextSpan> highlighted = highlightedOf(spans);

    expect(highlighted, hasLength(1));
    expect(highlighted.single.text, quote);
    expect(joinedText(spans), body);
  });

  testWidgets('overlapping highlights keep the existing skip behaviour', (
    WidgetTester tester,
  ) async {
    const String body = 'The quick brown fox jumps over the lazy dog.';
    final int firstStart = body.indexOf('quick brown');
    final int secondStart = body.indexOf('brown fox');

    await pumpBody(
      tester,
      body: body,
      highlights: <LegalHighlight>[
        highlight(
          id: 'h1',
          start: firstStart,
          end: firstStart + 'quick brown'.length,
          quote: 'quick brown',
        ),
        highlight(
          id: 'h2',
          start: secondStart,
          end: secondStart + 'brown fox'.length,
          quote: 'brown fox',
        ),
      ],
    );

    final List<InlineSpan> spans = spansOf(tester);
    final List<TextSpan> highlighted = highlightedOf(spans);

    // The renderer deliberately skips an overlapping range rather than
    // stacking two backgrounds; this test documents that behaviour.
    expect(highlighted, hasLength(1));
    expect(highlighted.single.text, 'quick brown');
    expect(joinedText(spans), body);
  });
}
