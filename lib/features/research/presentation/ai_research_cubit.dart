import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/ai_finding.dart';
import '../domain/ai_gateway.dart';
import 'ai_research_state.dart';

/// Owns the AI research surface (AI research slice 1.1, plan 2026-09-02).
///
/// [research] submits a natural-language query through the [AiGateway] seam
/// and renders the deterministic findings lifecycle. Widgets dispatch the
/// intent and render [AiResearchState]; they never call the gateway
/// directly. **Advisory-only posture**: no write path exists here (C-4/D-3)
/// and nothing about the query or findings is retained beyond the cubit's
/// feature-scoped lifetime (C-1 — no persistence; D-R2 — last answer only).
class AiResearchCubit extends Cubit<AiResearchState> {
  AiResearchCubit(this._gateway) : super(const AiResearchState());

  final AiGateway _gateway;

  /// In-flight guard — the [NotificationCubit] pattern: the flag, not a
  /// state check, distinguishes "research in flight" from "idle", and
  /// duplicate submits while a query is running are ignored (AC-4).
  bool _loading = false;

  /// Submits [rawQuery]. Blank queries are a no-op (the screen blocks the
  /// submit; the cubit re-asserts). A new query **replaces** the previous
  /// answer — the previous findings are dropped, never stacked (D-R2).
  Future<void> research(String rawQuery) async {
    final String query = rawQuery.trim();
    if (isClosed || _loading || query.isEmpty) {
      return;
    }
    _loading = true;
    emit(
      state.copyWith(
        findings: const ViewLoading<List<AiFinding>>(),
        lastQuery: query,
      ),
    );
    final Result<List<AiFinding>> result = await _gateway.research(query);
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<AiFinding>>(value: final List<AiFinding> findings):
        emit(state.copyWith(findings: ViewSuccess<List<AiFinding>>(findings)));
      case Failure<List<AiFinding>>(error: final AppError error):
        emit(state.copyWith(findings: ViewError<List<AiFinding>>(error)));
    }
  }
}
