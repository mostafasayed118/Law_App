import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/compliance_alert.dart';

/// Immutable state of the compliance-alerts surface (v1 queue 2026-08-09).
class ComplianceAlertsState extends Equatable {
  const ComplianceAlertsState({
    this.alerts = const ViewLoading<List<ComplianceAlert>>(),
  });

  final ViewState<List<ComplianceAlert>> alerts;

  ComplianceAlertsState copyWith({
    ViewState<List<ComplianceAlert>>? alerts,
  }) {
    return ComplianceAlertsState(alerts: alerts ?? this.alerts);
  }

  @override
  List<Object?> get props => <Object?>[alerts];
}