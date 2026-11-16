import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_document_detail.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'library_document_state.dart';

/// Owns one document's header and article list.
///
/// A `legal_document_not_found` failure maps to [ViewEmpty] so the reader shows
/// the localized not-found copy instead of a generic error with a retry that
/// cannot succeed; denials and outages keep their typed arms.
class LibraryDocumentCubit extends Cubit<LibraryDocumentState> {
  LibraryDocumentCubit(this._gateway) : super(const LibraryDocumentState());

  final LibraryGateway _gateway;

  bool _loading = false;

  Future<void> load(String documentId) async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.detail is! ViewLoading<LegalDocumentDetail>) {
      emit(state.copyWith(detail: const ViewLoading<LegalDocumentDetail>()));
    }
    final Result<LegalDocumentDetail> result;
    try {
      result = await _gateway.getDocument(documentId);
    } finally {
      _loading = false;
    }
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<LegalDocumentDetail>(
        value: final LegalDocumentDetail detail,
      ):
        emit(state.copyWith(detail: ViewSuccess<LegalDocumentDetail>(detail)));
      case Failure<LegalDocumentDetail>(error: final AppError error):
        emit(
          state.copyWith(
            detail: error.code == 'legal_document_not_found'
                ? const ViewEmpty<LegalDocumentDetail>()
                : viewStateForFailure<LegalDocumentDetail>(error),
          ),
        );
    }
  }
}
