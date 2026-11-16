import 'package:equatable/equatable.dart';

import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_bookmark.dart';

/// State of the saved-bookmarks list (ADR-0010).
class LibraryBookmarksState extends Equatable {
  const LibraryBookmarksState({
    this.bookmarks = const ViewLoading<List<LegalBookmark>>(),
  });

  final ViewState<List<LegalBookmark>> bookmarks;

  LibraryBookmarksState copyWith({ViewState<List<LegalBookmark>>? bookmarks}) {
    return LibraryBookmarksState(bookmarks: bookmarks ?? this.bookmarks);
  }

  @override
  List<Object?> get props => <Object?>[bookmarks];
}
