import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/document.dart';
import '../domain/document_gateway.dart';
import 'document_state.dart';

/// Owns the document-vault list surface (Phase 8, slice 8.1).
///
/// [load] fetches the synthetic document-metadata list on screen open (the
/// screen wires it after first frame, matching the roster/discovery/matters
/// pattern). Metadata only — nothing but the D-V4 surface ever crosses the
/// [DocumentGateway] boundary (D-V1/D-V2). Widgets render [DocumentState]
/// and dispatch intents; they never call the gateway directly.
class DocumentCubit extends Cubit<DocumentState> {
  DocumentCubit(this._gateway) : super(const DocumentState());

  final DocumentGateway _gateway;

  /// In-flight guard. The initial state IS loading (like
  /// [MatterCubit.load]'s contract), so the flag — not a state check —
  /// distinguishes "loading in flight" from "not loaded yet"; duplicate
  /// calls while a load is in flight are ignored.
  bool _loading = false;

  /// Loads the synthetic document-metadata list. The initial state is
  /// already loading, so the first open never re-emits a redundant loading
  /// frame; a retry after an error re-enters loading. An empty list maps to
  /// [ViewEmpty]; a failure to [ViewError].
  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.documents is! ViewLoading<List<Document>>) {
      emit(state.copyWith(documents: const ViewLoading<List<Document>>()));
    }
    final Result<List<Document>> result = await _gateway.fetchDocuments();
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<Document>>(value: final List<Document> documents):
        emit(
          state.copyWith(
            documents: documents.isEmpty
                ? const ViewEmpty<List<Document>>()
                : ViewSuccess<List<Document>>(documents),
          ),
        );
      case Failure<List<Document>>(error: final AppError error):
        emit(state.copyWith(documents: ViewError<List<Document>>(error)));
    }
  }
}
