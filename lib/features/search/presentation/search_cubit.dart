import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../../discovery/domain/attorney.dart';
import '../../discovery/domain/attorney_gateway.dart';
import '../../documents/domain/document.dart';
import '../../documents/domain/document_gateway.dart';
import '../../matters/domain/matter.dart';
import '../../matters/domain/matter_gateway.dart';
import '../../messaging/domain/message_gateway.dart';
import '../../messaging/domain/message_thread.dart';
import '../domain/search_results.dart';
import 'search_state.dart';

/// Owns the unified search surface (Phase 11, slice 11.0, owner decision D-S1).
///
/// [search] composes the four existing read-first gateway seams (matters,
/// documents, threads, attorneys) in parallel, filters each list
/// case-insensitively on the D-S1 field set, and groups the matching subsets
/// into a [SearchResults] view. It is a **pure client-side projection over
/// the same synthetic lists the standalone surfaces render** — no new gateway
/// seam, no server search RPC, no ranking/history/fuzzy matching (the D-M5
/// discipline extended). Widgets render [SearchState] and dispatch intents;
/// they never call the gateways directly.
///
/// Metadata only: matching fields are matter title/status/practice-area,
/// document title/type/`matterRef`, thread title/participants/`matterRef`,
/// and attorney name/practice-area (enum tokens, same as D-A5). No body,
/// no message text, no attorney bio/contact ever participates (D-S3).
class SearchCubit extends Cubit<SearchState> {
  SearchCubit(
    this._matterGateway,
    this._documentGateway,
    this._messageGateway,
    this._attorneyGateway,
  ) : super(const SearchState());

  final MatterGateway _matterGateway;
  final DocumentGateway _documentGateway;
  final MessageGateway _messageGateway;
  final AttorneyGateway _attorneyGateway;

  /// Monotonic request token so a stale in-flight search can never overwrite
  /// a newer one (last-submitted wins, regardless of completion order).
  int _requestSeq = 0;

  /// Runs a unified search for [query].
  ///
  /// A blank/whitespace-only query emits the no-query state ([ViewEmpty])
  /// **without touching any gateway** (D-S4). A non-blank query loads all
  /// four lists in parallel, and:
  /// - any gateway failure → [ViewError];
  /// - no matches in any group → [ViewEmpty];
  /// - otherwise → [ViewSuccess] with the grouped D-S1 subsets.
  Future<void> search(String query) async {
    if (isClosed) {
      return;
    }
    final int seq = ++_requestSeq;
    final String trimmed = query.trim();
    emit(state.copyWith(query: query));
    if (trimmed.isEmpty) {
      emit(state.copyWith(results: const ViewEmpty<SearchResults>()));
      return;
    }
    if (state.results is! ViewLoading<SearchResults>) {
      emit(state.copyWith(results: const ViewLoading<SearchResults>()));
    }
    final (
      Result<List<Matter>> matters,
      Result<List<Document>> documents,
      Result<List<MessageThread>> threads,
      Result<List<Attorney>> attorneys,
    ) = await (
      _matterGateway.fetchMatters(),
      _documentGateway.fetchDocuments(),
      _messageGateway.fetchThreads(),
      _attorneyGateway.fetchAttorneys(),
    ).wait;
    if (isClosed || seq != _requestSeq) {
      return;
    }
    // Any single gateway failure fails the whole search (fail-fast
    // composition): the first Failure in record order wins.
    final AppError? error = switch ((matters, documents, threads, attorneys)) {
      (Failure<List<Matter>>(error: final AppError e), _, _, _) => e,
      (_, Failure<List<Document>>(error: final AppError e), _, _) => e,
      (_, _, Failure<List<MessageThread>>(error: final AppError e), _) => e,
      (_, _, _, Failure<List<Attorney>>(error: final AppError e)) => e,
      _ => null,
    };
    if (error != null) {
      emit(state.copyWith(results: ViewError<SearchResults>(error)));
      return;
    }
    final String needle = trimmed.toLowerCase();
    final SearchResults grouped = SearchResults(
      matters: (matters as Success<List<Matter>>).value
          .where((Matter m) => _matterMatches(m, needle))
          .toList(growable: false),
      documents: (documents as Success<List<Document>>).value
          .where((Document d) => _documentMatches(d, needle))
          .toList(growable: false),
      threads: (threads as Success<List<MessageThread>>).value
          .where((MessageThread t) => _threadMatches(t, needle))
          .toList(growable: false),
      attorneys: (attorneys as Success<List<Attorney>>).value
          .where((Attorney a) => _attorneyMatches(a, needle))
          .toList(growable: false),
    );
    emit(
      state.copyWith(
        results: grouped.isEmpty
            ? const ViewEmpty<SearchResults>()
            : ViewSuccess<SearchResults>(grouped),
      ),
    );
  }

  bool _contains(String field, String needle) =>
      field.toLowerCase().contains(needle);

  bool _matterMatches(Matter matter, String needle) {
    return _contains(matter.title, needle) ||
        _contains(matter.status.name, needle) ||
        _contains(matter.practiceArea.name, needle);
  }

  bool _documentMatches(Document document, String needle) {
    return _contains(document.title, needle) ||
        _contains(document.type.name, needle) ||
        _contains(document.matterRef, needle);
  }

  bool _threadMatches(MessageThread thread, String needle) {
    if (_contains(thread.title, needle) ||
        _contains(thread.matterRef, needle)) {
      return true;
    }
    return thread.participants.any((String p) => _contains(p, needle));
  }

  bool _attorneyMatches(Attorney attorney, String needle) {
    return _contains(attorney.name, needle) ||
        _contains(attorney.practiceArea.name, needle);
  }
}
