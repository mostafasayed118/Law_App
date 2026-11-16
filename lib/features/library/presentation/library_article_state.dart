import 'package:equatable/equatable.dart';

import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_article_detail.dart';

/// Immutable state of the article reader (ADR-0009).
///
/// [detail] carries the article, its document context and its neighbours, so
/// the previous/next controls can render without a second read.
class LibraryArticleState extends Equatable {
  const LibraryArticleState({
    this.detail = const ViewLoading<LegalArticleDetail>(),
  });

  final ViewState<LegalArticleDetail> detail;

  LibraryArticleState copyWith({ViewState<LegalArticleDetail>? detail}) {
    return LibraryArticleState(detail: detail ?? this.detail);
  }

  @override
  List<Object?> get props => <Object?>[detail];
}
