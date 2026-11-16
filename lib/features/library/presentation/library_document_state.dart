import 'package:equatable/equatable.dart';

import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_document_detail.dart';

/// Immutable state of the document reader (ADR-0009).
///
/// A document is header + articles read together, so one [ViewState] covers
/// both: a loading document and a loading article list are the same wait.
class LibraryDocumentState extends Equatable {
  const LibraryDocumentState({
    this.detail = const ViewLoading<LegalDocumentDetail>(),
  });

  final ViewState<LegalDocumentDetail> detail;

  LibraryDocumentState copyWith({ViewState<LegalDocumentDetail>? detail}) {
    return LibraryDocumentState(detail: detail ?? this.detail);
  }

  @override
  List<Object?> get props => <Object?>[detail];
}
