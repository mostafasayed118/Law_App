import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';
import 'package:legalhub/shared/state/write_gate.dart';
import 'package:legalhub/shared/text/trim.dart';
import 'compliance_alerts_state.dart';

/// Owns the org-scoped compliance-alert list and its writes (design §4).
///
/// [load] reads through [ComplianceAlertsGateway] using the active
/// [ComplianceAlertsState.status]/[ComplianceAlertsState.severity] filters;
/// [setStatus]/[setSeverity] switch a filter and re-read. [create] /
/// [acknowledge] / [resolve] return the typed [AppError] on failure and null
/// on success so the sheets can render localized inline copy; a successful
/// write re-reads the list.
class ComplianceAlertsCubit extends Cubit<ComplianceAlertsState> {
  ComplianceAlertsCubit(this._gateway) : super(const ComplianceAlertsState());

  final ComplianceAlertsGateway _gateway;

  /// Monotonic request id: a filter switch while a read is in flight must not
  /// be overwritten by the older response (the SearchCubit request-sequence
  /// pattern).
  int _request = 0;

  final WriteGate _writeGate = WriteGate();

  Future<void> load() async {
    final int request = ++_request;
    if (state.alerts is! ViewLoading<List<ComplianceAlert>>) {
      emit(state.copyWith(alerts: const ViewLoading<List<ComplianceAlert>>()));
    }
    final Result<List<ComplianceAlert>> result = await _gateway.fetchAlerts(
      status: state.status,
      severity: state.severity,
    );
    if (isClosed || request != _request) {
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
        emit(
          state.copyWith(
            alerts: viewStateForFailure<List<ComplianceAlert>>(error),
          ),
        );
    }
  }

  /// Switches the status filter and re-reads. Selecting the active filter is
  /// a no-op.
  Future<void> setStatus(AlertStatus? status) async {
    if (state.status == status) {
      return;
    }
    emit(state.copyWith(status: status));
    await load();
  }

  /// Switches the severity filter and re-reads. Selecting the active filter
  /// is a no-op.
  Future<void> setSeverity(AlertSeverity? severity) async {
    if (state.severity == severity) {
      return;
    }
    emit(state.copyWith(severity: severity));
    await load();
  }

  /// Creates an alert. The title is trimmed here (the sheet validates its
  /// length before submitting); an empty description becomes null. A write
  /// that loses the in-flight race returns [WriteGate.busyError], never null.
  Future<AppError?> create(ComplianceAlertDraft draft) {
    return _writeGate.run<String>(
      isClosed: () => isClosed,
      write: () => _gateway.create(
        ComplianceAlertDraft(
          organizationId: draft.organizationId,
          matterId: draft.matterId,
          title: draft.title.trim(),
          kind: draft.kind,
          severity: draft.severity,
          description: trimOrNull(draft.description),
          dueAt: draft.dueAt,
        ),
      ),
      onSuccess: load,
    );
  }

  /// Acknowledges an open alert. Returns null on success, the failure's
  /// [AppError] otherwise; a success re-reads the filtered list.
  Future<AppError?> acknowledge(String id) {
    return _writeGate.run<void>(
      isClosed: () => isClosed,
      write: () => _gateway.acknowledge(id),
      onSuccess: load,
    );
  }

  /// Resolves an open/acknowledged alert. Returns null on success, the
  /// failure's [AppError] otherwise; a success re-reads the filtered list.
  Future<AppError?> resolve(String id, {String? note}) {
    return _writeGate.run<void>(
      isClosed: () => isClosed,
      write: () => _gateway.resolve(id, note: trimOrNull(note)),
      onSuccess: load,
    );
  }
}
