import 'package:equatable/equatable.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';

/// State of the per-user layer for the article currently open (ADR-0010).
///
/// - [bookmarked] — the toggle's value. It is flipped optimistically and put
///   back if the server refuses, so the control never lags a tap.
/// - [bookmarkBusy] — true while the toggle is in flight; the control is
///   disabled rather than queued, because two toggles racing would resolve in
///   whichever order the responses arrived.
/// - [highlights] — the article's highlights, with staleness already computed by
///   the server.
/// - [lastError] — a failure the surface should announce once (a snackbar) and
///   clear. It exists so the cubit does not have to know about `ScaffoldMessenger`.
class ArticleUserDataState extends Equatable {
  const ArticleUserDataState({
    this.bookmarked = false,
    this.bookmarkBusy = false,
    this.highlights = const ViewLoading<List<LegalHighlight>>(),
    this.lastError,
  });

  final bool bookmarked;
  final bool bookmarkBusy;
  final ViewState<List<LegalHighlight>> highlights;
  final AppError? lastError;

  /// Only the non-stale highlights, in document order — what the reader draws.
  List<LegalHighlight> get drawableHighlights => switch (highlights) {
    ViewSuccess<List<LegalHighlight>>(data: final List<LegalHighlight> all) =>
      all.where((LegalHighlight h) => !h.isStale).toList(growable: false),
    _ => const <LegalHighlight>[],
  };

  /// Stale highlights, surfaced as a notice rather than drawn at dead offsets.
  List<LegalHighlight> get staleHighlights => switch (highlights) {
    ViewSuccess<List<LegalHighlight>>(data: final List<LegalHighlight> all) =>
      all.where((LegalHighlight h) => h.isStale).toList(growable: false),
    _ => const <LegalHighlight>[],
  };

  ArticleUserDataState copyWith({
    bool? bookmarked,
    bool? bookmarkBusy,
    ViewState<List<LegalHighlight>>? highlights,
    AppError? lastError,
    bool clearError = false,
  }) {
    return ArticleUserDataState(
      bookmarked: bookmarked ?? this.bookmarked,
      bookmarkBusy: bookmarkBusy ?? this.bookmarkBusy,
      highlights: highlights ?? this.highlights,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    bookmarked,
    bookmarkBusy,
    highlights,
    lastError,
  ];
}
