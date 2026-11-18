import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_gateway.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'package:legalhub/features/search/domain/search_results.dart';
import 'package:legalhub/features/search/presentation/search_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Which real [SearchGroup]s a Stitch filter chip maps to. No new result type.
enum ConflictFilter { client, adverse, related }

class ConflictRecent extends Object {
  const ConflictRecent({
    required this.query,
    required this.resultCount,
    required this.at,
  });

  final String query;
  final int resultCount;
  final DateTime at;
}

class ConflictWatchEntry extends Object {
  const ConflictWatchEntry({required this.name, required this.lastChecked});

  final String name;
  final DateTime lastChecked;
}

/// Session-only state for `/conflicts/check`. Recents and watchlist are held
/// in memory for this Cubit's lifetime only — never pre-seeded, never sent to
/// a gateway, never persisted. Search itself is the existing [SearchCubit].
class ConflictCheckCubit extends Cubit<ConflictCheckState> {
  ConflictCheckCubit({
    required MatterGateway matters,
    required DocumentGateway documents,
    required MessageGateway messages,
    required AttorneyGateway attorneys,
    required this.localOnly,
  }) : _search = SearchCubit(matters, documents, messages, attorneys),
       super(const ConflictCheckState());

  final SearchCubit _search;
  final bool localOnly;

  /// Mapping to the real search result groups:
  /// Client → matters, Adverse Party → attorneys,
  /// Related Entity → documents + messages (associations via matterRef).
  static const Map<ConflictFilter, Set<SearchGroup>> filterGroups =
      <ConflictFilter, Set<SearchGroup>>{
        ConflictFilter.client: <SearchGroup>{SearchGroup.matters},
        ConflictFilter.adverse: <SearchGroup>{SearchGroup.attorneys},
        ConflictFilter.related: <SearchGroup>{
          SearchGroup.documents,
          SearchGroup.threads,
        },
      };

  Future<void> search(String query, {required AppLocalizations l10n}) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    emit(
      state.copyWith(
        query: trimmed,
        results: const ViewLoading<SearchResults>(),
      ),
    );
    await _search.search(trimmed, l10n: l10n, localOnly: localOnly);
    if (isClosed) {
      return;
    }
    final ViewState<SearchResults> results = _search.state.results;
    final int count = switch (results) {
      ViewSuccess<SearchResults>(data: final SearchResults data) =>
        data.matters.length +
            data.documents.length +
            data.threads.length +
            data.attorneys.length,
      _ => 0,
    };
    emit(
      state.copyWith(
        results: results,
        recents: <ConflictRecent>[
          ConflictRecent(
            query: trimmed,
            resultCount: count,
            at: DateTime.now(),
          ),
          ...state.recents.where((ConflictRecent r) => r.query != trimmed),
        ].take(20).toList(growable: false),
      ),
    );
  }

  void toggleFilter(ConflictFilter filter) {
    final Set<ConflictFilter> filters = Set<ConflictFilter>.from(state.filters);
    if (!filters.remove(filter)) {
      filters.add(filter);
    }
    emit(state.copyWith(filters: filters));
  }

  /// Returns only the groups selected by the active chips (all when none).
  SearchResults? visibleResults() {
    final ViewState<SearchResults> results = state.results;
    if (results case ViewSuccess<SearchResults>(
      data: final SearchResults data,
    )) {
      if (state.filters.isEmpty) {
        return data;
      }
      final Set<SearchGroup> groups = <SearchGroup>{
        for (final ConflictFilter filter in state.filters)
          ...filterGroups[filter] ?? const <SearchGroup>{},
      };
      return SearchResults(
        matters: groups.contains(SearchGroup.matters)
            ? data.matters
            : const <Matter>[],
        documents: groups.contains(SearchGroup.documents)
            ? data.documents
            : const <Document>[],
        threads: groups.contains(SearchGroup.threads)
            ? data.threads
            : const <MessageThread>[],
        attorneys: groups.contains(SearchGroup.attorneys)
            ? data.attorneys
            : const <Attorney>[],
        failedGroups: data.failedGroups,
      );
    }
    return null;
  }

  void addToWatchlist(String name) {
    if (state.watchlist.any((ConflictWatchEntry e) => e.name == name)) {
      return;
    }
    emit(
      state.copyWith(
        watchlist: <ConflictWatchEntry>[
          ConflictWatchEntry(name: name, lastChecked: DateTime.now()),
          ...state.watchlist,
        ],
      ),
    );
  }

  void clearHistory() =>
      emit(state.copyWith(recents: const <ConflictRecent>[]));

  @override
  Future<void> close() {
    _search.close();
    return super.close();
  }
}

/// Immutable state of the conflict-check screen.
class ConflictCheckState extends Object {
  const ConflictCheckState({
    this.query = '',
    this.results = const ViewEmpty<SearchResults>(),
    this.filters = const <ConflictFilter>{},
    this.recents = const <ConflictRecent>[],
    this.watchlist = const <ConflictWatchEntry>[],
  });

  final String query;
  final ViewState<SearchResults> results;
  final Set<ConflictFilter> filters;
  final List<ConflictRecent> recents;
  final List<ConflictWatchEntry> watchlist;

  ConflictCheckState copyWith({
    String? query,
    ViewState<SearchResults>? results,
    Set<ConflictFilter>? filters,
    List<ConflictRecent>? recents,
    List<ConflictWatchEntry>? watchlist,
  }) {
    return ConflictCheckState(
      query: query ?? this.query,
      results: results ?? this.results,
      filters: filters ?? this.filters,
      recents: recents ?? this.recents,
      watchlist: watchlist ?? this.watchlist,
    );
  }
}
