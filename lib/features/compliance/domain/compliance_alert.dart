import 'package:equatable/equatable.dart';

/// Severity of a compliance alert (v1 read-only demo surface, 2026-08-09).
///
/// Rendered with text + icon, never color alone (INSTRUCTIONS §4.5).
enum AlertSeverity { info, attention, critical }

/// A compliance-alert row (v1 queue; `legalhub_specification.md` §6
/// `compliance_alerts`, deferred→v1 read-only).
///
/// **Non-PII metadata only**: stable synthetic id, generic demo title,
/// severity, and created date. No content, no client names, no regulatory
/// verdict — the demo posture (no real compliance claim, INSTRUCTIONS §1.1).
class ComplianceAlert extends Equatable {
  const ComplianceAlert({
    required this.id,
    required this.title,
    required this.severity,
    required this.createdAt,
  });

  final String id;
  final String title;
  final AlertSeverity severity;
  final DateTime createdAt;

  @override
  List<Object?> get props => <Object?>[id, title, severity, createdAt];
}
