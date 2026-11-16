import 'package:equatable/equatable.dart';

import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';

/// State of the saved-highlights list (ADR-0010).
///
/// Stale highlights are kept in the list rather than hidden: the reader still
/// wants to see what they marked, and the row says the text has changed.
class LibraryHighlightsState extends Equatable {
  const LibraryHighlightsState({
    this.highlights = const ViewLoading<List<LegalHighlight>>(),
  });

  final ViewState<List<LegalHighlight>> highlights;

  LibraryHighlightsState copyWith({
    ViewState<List<LegalHighlight>>? highlights,
  }) {
    return LibraryHighlightsState(highlights: highlights ?? this.highlights);
  }

  @override
  List<Object?> get props => <Object?>[highlights];
}
