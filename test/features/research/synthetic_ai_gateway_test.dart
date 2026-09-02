import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/documents/data/fake_document_gateway.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/research/data/synthetic_ai_gateway.dart';
import 'package:legalhub/features/research/domain/ai_finding.dart';

/// A document gateway that always fails — drives the typed-failure
/// passthrough pin (AC-3) without touching the real seams' success paths.
class _FailingDocumentGateway implements DocumentGateway {
  @override
  Future<Result<List<Document>>> fetchDocuments() async =>
      const Result<List<Document>>.failure(
        AppError(code: 'doc-fail', userMessage: 'documents unavailable'),
      );
}

/// A matter gateway that always fails — drives the typed-failure
/// passthrough pin (AC-3).
class _FailingMatterGateway implements MatterGateway {
  @override
  Future<Result<List<Matter>>> fetchMatters() async =>
      const Result<List<Matter>>.failure(
        AppError(code: 'matter-fail', userMessage: 'matters unavailable'),
      );
}

void main() {
  late SyntheticAiGateway gateway;

  setUp(() {
    gateway = SyntheticAiGateway(
      documentGateway: FakeDocumentGateway(),
      matterGateway: FakeMatterGateway(),
    );
  });

  group('SyntheticAiGateway', () {
    test(
      'matching query returns findings citing shipped corpus rows (AC-1)',
      () async {
        final result = await gateway.research('acquisition review');
        expect(result, isA<Success<List<AiFinding>>>());
        final findings = result.valueOrNull!;
        expect(findings, isNotEmpty);
        for (final finding in findings) {
          expect(finding.sources, isNotEmpty);
          expect(finding.headline, isNotEmpty);
          expect(finding.summary, isNotEmpty);
          expect(finding.excerpt, isNotEmpty);
        }
      },
    );

    test(
      'determinism: the same query yields identical findings twice (AC-1)',
      () async {
        final first = await gateway.research('lease consultation');
        final second = await gateway.research('lease consultation');
        expect(first.valueOrNull, equals(second.valueOrNull));
      },
    );

    test(
      'citations always non-empty and point at document/matter kinds (AC-1)',
      () async {
        final result = await gateway.research('settlement draft');
        final findings = result.valueOrNull!;
        expect(findings, isNotEmpty);
        for (final finding in findings) {
          expect(
            finding.sources.every(
              (source) =>
                  source.kind == AiSourceKind.document ||
                  source.kind == AiSourceKind.matter,
            ),
            isTrue,
          );
          expect(finding.sources.first.title, isNotEmpty);
          expect(finding.sources.first.detail, isNotEmpty);
        }
      },
    );

    test(
      'matches against shipped corpus titles/types/areas only (AC-2)',
      () async {
        final byTitle = await gateway.research('engagement letter');
        expect(byTitle.valueOrNull, isNotEmpty);

        final byType = await gateway.research('evidence');
        expect(byType.valueOrNull, isNotEmpty);

        final byArea = await gateway.research('family');
        expect(byArea.valueOrNull, isNotEmpty);
      },
    );

    test('no-match query returns an honest empty list (AC-2)', () async {
      final result = await gateway.research('quantum entanglement filings');
      expect(result, isA<Success<List<AiFinding>>>());
      expect(result.valueOrNull, isEmpty);
    });

    test(
      'empty/blank query returns empty without fabricating rows (AC-2)',
      () async {
        expect((await gateway.research('')).valueOrNull, isEmpty);
        expect((await gateway.research('   ')).valueOrNull, isEmpty);
      },
    );

    test('document-gateway failure maps to a typed failure (AC-3)', () async {
      final failing = SyntheticAiGateway(
        documentGateway: _FailingDocumentGateway(),
        matterGateway: FakeMatterGateway(),
      );
      final result = await failing.research('anything');
      expect(result, isA<Failure<List<AiFinding>>>());
      expect(result.errorOrNull!.code, 'doc-fail');
    });

    test('matter-gateway failure maps to a typed failure (AC-3)', () async {
      final failing = SyntheticAiGateway(
        documentGateway: FakeDocumentGateway(),
        matterGateway: _FailingMatterGateway(),
      );
      final result = await failing.research('anything');
      expect(result, isA<Failure<List<AiFinding>>>());
      expect(result.errorOrNull!.code, 'matter-fail');
    });

    test(
      'synthetic copy never claims advice or clearance (A-3/C-3 pin)',
      () async {
        final result = await gateway.research('acquisition');
        for (final finding in result.valueOrNull!) {
          final text =
              '${finding.headline} ${finding.summary} ${finding.excerpt}'
                  .toLowerCase();
          expect(text.contains('not legal analysis'), isTrue);
          expect(text.contains('clear'), isFalse);
          expect(text.contains('approved'), isFalse);
        }
      },
    );
  });
}
