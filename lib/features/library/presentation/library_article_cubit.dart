import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_article_detail.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'library_article_state.dart';

/// Owns one article and its previous/next navigation.
///
/// [openPrevious] and [openNext] read the neighbour id the server already
/// resolved; the surface only enables those controls when the id is present, so
/// this cubit never has to guess at document boundaries.
class LibraryArticleCubit extends Cubit<LibraryArticleState> {
  LibraryArticleCubit(this._gateway) : super(const LibraryArticleState());

  final LibraryGateway _gateway;

  bool _loading = false;

  Future<void> load(String articleId) async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.detail is! ViewLoading<LegalArticleDetail>) {
      emit(state.copyWith(detail: const ViewLoading<LegalArticleDetail>()));
    }
    final Result<LegalArticleDetail> result;
    try {
      result = await _gateway.getArticle(articleId);
    } finally {
      _loading = false;
    }
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<LegalArticleDetail>(value: final LegalArticleDetail detail):
        emit(state.copyWith(detail: ViewSuccess<LegalArticleDetail>(detail)));
      case Failure<LegalArticleDetail>(error: final AppError error):
        emit(
          state.copyWith(
            detail: error.code == 'legal_article_not_found'
                ? const ViewEmpty<LegalArticleDetail>()
                : viewStateForFailure<LegalArticleDetail>(error),
          ),
        );
    }
  }

  /// Opens the previous article when the server reported one.
  Future<void> openPrevious() => _openNeighbour(previous: true);

  /// Opens the next article when the server reported one.
  Future<void> openNext() => _openNeighbour(previous: false);

  Future<void> _openNeighbour({required bool previous}) async {
    final ViewState<LegalArticleDetail> current = state.detail;
    if (current is! ViewSuccess<LegalArticleDetail>) {
      return;
    }
    final String? id = previous
        ? current.data.previousArticleId
        : current.data.nextArticleId;
    if (id == null) {
      return;
    }
    await load(id);
  }
}
