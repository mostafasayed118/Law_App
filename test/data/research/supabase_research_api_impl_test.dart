import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/app_message_key.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/research/supabase_research_api.dart';
import 'package:legalhub/data/research/supabase_research_api_impl.dart';
import 'package:legalhub/features/research/data/supabase_research_gateway.dart';
import 'package:legalhub/features/research/domain/research_outcome.dart';
import 'package:legalhub/features/research/domain/research_request.dart';
import 'package:legalhub/features/research/domain/research_wire_codes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A function caller that always fails with an unrecognized wire code and an
/// HTTP status outside the classifier's table, so neither fallback maps it.
SupabaseResearchApiImpl _apiWithUnknownWireCode() => SupabaseResearchApiImpl(
  functionCaller: (String function, Map<String, dynamic> body) async {
    throw const FunctionException(
      status: 418,
      details: <String, dynamic>{'error': 'mystery_wire_code'},
    );
  },
);

void main() {
  test(
    'an unknown wire code stays SupabaseResearchFailureKind.unknown',
    () async {
      await expectLater(
        _apiWithUnknownWireCode().analyze(
          organizationId: 'org-1',
          documentIds: const <String>[],
          question: 'What changed?',
        ),
        throwsA(
          isA<SupabaseResearchException>()
              .having(
                (e) => e.kind,
                'kind',
                SupabaseResearchFailureKind.unknown,
              )
              .having((e) => e.code, 'code', 'mystery_wire_code'),
        ),
      );
    },
  );

  test(
    'an unknown wire code keeps the localized research failure key',
    () async {
      final SupabaseResearchGateway gateway = SupabaseResearchGateway(
        _apiWithUnknownWireCode(),
        organizationId: () => 'org-1',
      );

      final Result<ResearchOutcome> result = await gateway.analyze(
        ResearchRequest(organizationId: 'org-1', question: 'What changed?'),
      );

      expect(result, isA<Failure<ResearchOutcome>>());
      expect(result.errorOrNull?.code, ResearchWireCodes.researchFailed);
      expect(result.errorOrNull?.kind, AppErrorKind.unknown);
      expect(
        result.errorOrNull?.messageKey,
        AppMessageKey.errUnableToRunAIResearchPleaseTryAgain,
      );
    },
  );
}
