import 'package:equatable/equatable.dart';

import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';

/// Immutable state of the library browse surface (ADR-0009).
///
/// - [documents] — the list load lifecycle, using the shared [ViewState]
///   vocabulary (loading / success / empty / error+retry / offline / denied).
/// - [category] — the active taxonomy chip, or null for "All".
class LibraryBrowseState extends Equatable {
  const LibraryBrowseState({
    this.documents = const ViewLoading<List<LegalDocument>>(),
    this.category,
  });

  final ViewState<List<LegalDocument>> documents;
  final LegalCategory? category;

  /// Sentinel distinguishing "not provided" from "explicitly null" so the
  /// category can be cleared (back to "All") through copyWith.
  static const Object _unset = Object();

  LibraryBrowseState copyWith({
    ViewState<List<LegalDocument>>? documents,
    Object? category = _unset,
  }) {
    return LibraryBrowseState(
      documents: documents ?? this.documents,
      category: identical(category, _unset)
          ? this.category
          : category as LegalCategory?,
    );
  }

  @override
  List<Object?> get props => <Object?>[documents, category];
}
