import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/compliance_alert.dart';
import '../domain/compliance_gateway.dart';
import 'compliance_alerts_state.dart';

/// Owns the compliance-alerts list (v1 queue, 2026-08-09).
///
/// [load] fetches the deterministic synthetic list on screen open (the
/// vault/messages pattern); loading/empty/error+retry via the shared
/// [ViewState] vocabulary.
class ComplianceAlertsCubit extends Cubit<ComplianceAlertsState> {
  ComplianceAlertsCubit(this._gateway) : super(const ComplianceAlertsState());

  final ComplianceAlertsGateway _gateway;

  bool _loading = false;

  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.alerts is! ViewLoading<List<ComplianceAlert>>) {
      emit(state.copyWith(alerts: const ViewLoading<List<ComplianceAlert>>()));
    }
    final Result<List<ComplianceAlert>> result = await _gateway.fetchAlerts();
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<ComplianceAlert>>(
        value: final List<ComplianceAlert> alerts,
      ):
        emit(
          state.copyWith(
            alerts: alerts.isEmpty
                ? const ViewEmpty<List<ComplianceAlert>>()
                : ViewSuccess<List<ComplianceAlert>>(alerts),
          ),
        );
      case Failure<List<ComplianceAlert>>(error: final AppError error):
        emit(state.copyWith(alerts: ViewError<List<ComplianceAlert>>(error)));
    }
  }
}
