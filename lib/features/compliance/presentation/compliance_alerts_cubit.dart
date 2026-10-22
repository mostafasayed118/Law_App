import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/compliance_alert.dart';
import '../domain/compliance_gateway.dart';
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

  bool _acting = false;

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
  /// length before submitting); an empty description becomes null.
  Future<AppError?> create(ComplianceAlertDraft draft) async {
    if (isClosed || _acting) {
      return null;
    }
    _acting = true;
    final Result<String> result = await _gateway.create(
      ComplianceAlertDraft(
        organizationId: draft.organizationId,
        matterId: draft.matterId,
        title: draft.title.trim(),
        kind: draft.kind,
        severity: draft.severity,
        description: _trimOrNull(draft.description),
        dueAt: draft.dueAt,
      ),
    );
    _acting = false;
    if (isClosed) {
      return null;
    }
    switch (result) {
      case Success<String>():
        await load();
        return null;
      case Failure<String>(error: final AppError error):
        return error;
    }
  }

  /// Acknowledges an open alert. Returns null on success, the failure's
  /// [AppError] otherwise; a success re-reads the filtered list.
  Future<AppError?> acknowledge(String id) {
    return _runWrite(() => _gateway.acknowledge(id));
  }

  /// Resolves an open/acknowledged alert. Returns null on success, the
  /// failure's [AppError] otherwise; a success re-reads the filtered list.
  Future<AppError?> resolve(String id, {String? note}) {
    return _runWrite(() => _gateway.resolve(id, note: _trimOrNull(note)));
  }

  Future<AppError?> _runWrite(Future<Result<void>> Function() write) async {
    if (isClosed || _acting) {
      return null;
    }
    _acting = true;
    final Result<void> result = await write();
    _acting = false;
    if (isClosed) {
      return null;
    }
    switch (result) {
      case Success<void>():
        await load();
        return null;
      case Failure<void>(error: final AppError error):
        return error;
    }
  }

  String? _trimOrNull(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
