import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/research/domain/ai_finding.dart';
import 'package:legalhub/features/research/domain/ai_gateway.dart';
import 'package:legalhub/features/research/domain/research_outcome.dart';
import 'package:legalhub/features/research/domain/research_request.dart';
import 'package:legalhub/features/research/domain/research_run.dart';
import 'package:legalhub/features/research/domain/research_wire_codes.dart';

/// Screenshot-only research fixture seam.
///
/// Called ONLY by the screenshot capture test and its RED regression test. It
/// replaces the credential-free [AiGateway] in the service locator with a
/// delegating wrapper whose run history contains one clearly synthetic,
/// completed run. No production model, RPC, RLS policy or runtime path changes.
Future<void> seedScreenshotResearchFixture() async {
  final AiGateway delegate = serviceLocator<AiGateway>();
  await serviceLocator.unregister<AiGateway>();
  serviceLocator.registerSingleton<AiGateway>(
    _ScreenshotResearchGateway(delegate),
  );
}

class _ScreenshotResearchGateway implements AiGateway {
  const _ScreenshotResearchGateway(this._delegate);

  final AiGateway _delegate;

  static final ResearchRun _demoRun = ResearchRun(
    id: '00000000-0000-4000-8000-0000000000f1',
    organizationId: '00000000-0000-4000-8000-0000000000d1',
    status: ResearchRunStatus.completed,
    promptSummary: 'Demo research: sample matter brief',
    model: 'synthetic-demo',
    createdAt: DateTime.utc(2026, 11, 17, 12),
    completedAt: DateTime.utc(2026, 11, 17, 12, 0, 2),
  );

  @override
  Future<Result<List<AiFinding>>> research(String query) =>
      _delegate.research(query);

  @override
  Future<Result<ResearchOutcome>> analyze(ResearchRequest request) =>
      _delegate.analyze(request);

  @override
  Future<Result<List<ResearchRun>>> fetchRuns({
    int limit = kResearchRunPageSize,
  }) async => Result<List<ResearchRun>>.success(<ResearchRun>[_demoRun]);

  @override
  Future<Result<List<AiFinding>>> fetchFindings(String runId) =>
      _delegate.fetchFindings(runId);
}
