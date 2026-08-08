import '../../../core/errors/result.dart';
import 'compliance_alert.dart';

/// Compliance-alerts integration boundary (v1 queue, 2026-08-09 scope draft).
///
/// Read-only demo surface: a dev fake serves the deterministic synthetic
/// list in env-less runs and tests (the Phase 5–12 fake-domain discipline).
/// **No real compliance verification** — rows are synthetic and never render
/// a regulatory verdict (INSTRUCTIONS §1.2/§4.4).
abstract interface class ComplianceAlertsGateway {
  Future<Result<List<ComplianceAlert>>> fetchAlerts();
}