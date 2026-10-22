import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/compliance_alert.dart';

/// Immutable state of the compliance-alerts surface (design §4).
///
/// [status] and [severity] are the active server-side filters (null = all);
/// [alerts] is the current list arm.
class ComplianceAlertsState extends Equatable {
  const ComplianceAlertsState({
    this.alerts = const ViewLoading<List<ComplianceAlert>>(),
    this.status,
    this.severity,
  });

  final ViewState<List<ComplianceAlert>> alerts;
  final AlertStatus? status;
  final AlertSeverity? severity;

  ComplianceAlertsState copyWith({
    ViewState<List<ComplianceAlert>>? alerts,
    Object? status = _unset,
    Object? severity = _unset,
  }) {
    return ComplianceAlertsState(
      alerts: alerts ?? this.alerts,
      status: identical(status, _unset) ? this.status : status as AlertStatus?,
      severity: identical(severity, _unset)
          ? this.severity
          : severity as AlertSeverity?,
    );
  }

  static const Object _unset = Object();

  @override
  List<Object?> get props => <Object?>[alerts, status, severity];
}
