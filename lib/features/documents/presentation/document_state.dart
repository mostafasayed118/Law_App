import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/document.dart';

/// Immutable state of the document-vault list surface (Phase 8, slice 8.1).
///
/// [documents] holds the document-metadata load lifecycle using the shared
/// [ViewState] vocabulary (loading / success / empty / error+retry). There is
/// deliberately no filter or search field (D-V5 note: the vault is a plain
/// list in this slice) — the smallest surface that satisfies the AC-2
/// metadata-only line.
class DocumentState extends Equatable {
  const DocumentState({this.documents = const ViewLoading<List<Document>>()});

  final ViewState<List<Document>> documents;

  DocumentState copyWith({ViewState<List<Document>>? documents}) {
    return DocumentState(documents: documents ?? this.documents);
  }

  @override
  List<Object?> get props => <Object?>[documents];
}
