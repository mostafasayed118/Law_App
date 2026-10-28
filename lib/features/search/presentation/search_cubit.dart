import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/pagination.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_gateway.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/documents/presentation/document_labels.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/matters/presentation/matter_labels.dart'
    show matterStatusLabel;
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'package:legalhub/features/search/domain/search_results.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/widgets/practice_area_label.dart';

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
/// Each group is truncated to [searchPageSize] rows so the results surface
/// (an eager tile build) never renders more than 4 pages of tiles. The
/// Supabase-backed gateways fetch their bounded newest-first page (the
/// shared 200-row cap) and the exact full-matching pass below refines it
/// client-side — the title-only SQL prefilter was deliberately dropped
/// because it discarded status/practice-area/localized-label matches.
///
/// Recall caveat callers must know: on a real backend a match outside the
/// bounded page is not seen (the page, not the query, is the recall bound).
/// Fakes (dev/tests) show the ideal — full-list candidates, exact results.
///
/// The attorney directory is query-independent, so [search] reads it once per
/// cubit lifetime and re-filters it locally for every query (audit
/// 2026-10-27, F10). A failed read is not cached, so the next search retries.
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

  /// Maximum rows kept per result group (bounds the eager tile build to
  /// 4 × 30 tiles). Mirrors the shared 30-row search page size without
  /// importing the data layer — presentation must never depend on
  /// `lib/data/` (layer rule). The server reads the shared 200-row page.
  static const int searchPageSize = kSearchPageSize;

  final MatterGateway _matterGateway;
  final DocumentGateway _documentGateway;
  final MessageGateway _messageGateway;
  final AttorneyGateway _attorneyGateway;

  /// Monotonic request token so a stale in-flight search can never overwrite
  /// a newer one (last-submitted wins, regardless of completion order).
  int _requestSeq = 0;

  /// The query-independent attorney directory, read once per cubit lifetime
  /// and re-filtered client-side for every query (audit 2026-10-27, F10).
  /// Only successful reads are cached, so a failed read is retried by the
  /// next search instead of pinning an empty group for the session.
  List<Attorney>? _attorneyCache;

  /// Runs a unified search for [query].
  ///
  /// A blank/whitespace-only query emits the no-query state ([ViewEmpty])
  /// **without touching any gateway** (D-S4). A non-blank query loads all
  /// four lists in parallel, and:
  /// - every gateway fails → [ViewError] (total outage; first failure in
  ///   record order wins, preserving the retry path);
  /// - at least one gateway answers → [ViewSuccess] with the grouped D-S1
  ///   subsets; failed groups contribute an empty subset and are recorded
  ///   in [SearchResults.failedGroups] so the surface renders the
  ///   partial-results notice (audit: fail-fast search — the old
  ///   any-failure-fails-all contract dropped good rows on a single flaky
  ///   seam);
  /// - no matches in any answering group (and no failures) → [ViewEmpty].
  ///   Failures with zero matches still return [ViewSuccess] (empty groups
  ///   + [SearchResults.failedGroups]) rather than a clean empty, so the
  ///   surface can say "no results AND a source was down" instead of
  ///   silently hiding the outage.
  ///
  /// When [l10n] is provided, matching additionally runs against the
  /// localized demo labels, so an Arabic query finds the Arabic titles the
  /// surfaces render (demo localization, 2026-09-24). Raw matching always
  /// applies, so existing callers and tests that omit [l10n] behave exactly
  /// as before.
  ///
  /// [limit] bounds each result group to its first N matches (top-N per
  /// group, default [searchPageSize]). Synthetic corpora are small enough
  /// that the default never truncates them — existing tests pin the full
  /// subsets — while large real corpora stay bounded on the surface.
  Future<void> search(
    String query, {
    AppLocalizations? l10n,
    bool localOnly = true,
    int limit = searchPageSize,
  }) async {
    if (isClosed) {
      return;
    }
    final DemoLabels? labels = l10n == null
        ? null
        : DemoLabels(l10n, localOnly: localOnly);
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
    // Bounded page + client-side refine (audit: search fan-out): the three
    // Supabase-backed gateways read the shared bounded newest-first page
    // (cap 200); the title-only SQL prefilter was deliberately dropped
    // because it discarded the status/practice-area/localized-label
    // matches this matcher covers. The exact full-matching pass below
    // stays the arbiter and the requested limit bounds the rendered groups.
    final int effectiveLimit = limit <= 0 ? searchPageSize : limit;
    // The attorney directory does not depend on the query: serve the cached
    // one when present so a debounced search never re-reads the listing.
    final Future<Result<List<Attorney>>> attorneyFuture = _attorneyCache != null
        ? Future<Result<List<Attorney>>>.value(
            Result<List<Attorney>>.success(_attorneyCache!),
          )
        : _attorneyGateway.fetchAttorneys();
    final (
      Result<List<Matter>> matters,
      Result<List<Document>> documents,
      Result<List<MessageThread>> threads,
      Result<List<Attorney>> attorneys,
    ) = await (
      _matterGateway.searchMatters(trimmed, limit: effectiveLimit),
      _documentGateway.searchDocuments(trimmed, limit: effectiveLimit),
      _messageGateway.searchThreads(trimmed, limit: effectiveLimit),
      attorneyFuture,
    ).wait;
    if (isClosed || seq != _requestSeq) {
      return;
    }
    // Partial-results composition: each group is collected independently; a
    // failed group contributes an empty subset and is recorded instead of
    // failing the whole search. Matches are filtered per group exactly as
    // before, so "top-N per group" semantics are preserved on the good
    // groups while a flaky seam degrades one section, not the surface.
    final Set<SearchGroup> failedGroups = <SearchGroup>{};
    AppError? firstError;
    List<Matter> matterRows = const <Matter>[];
    List<Document> documentRows = const <Document>[];
    List<MessageThread> threadRows = const <MessageThread>[];
    List<Attorney> attorneyRows = const <Attorney>[];
    final String needle = trimmed.toLowerCase();
    switch (matters) {
      case Success<List<Matter>>(value: final List<Matter> value):
        matterRows = value
            .where((Matter m) => _matterMatches(m, needle, labels))
            .take(effectiveLimit)
            .toList(growable: false);
      case Failure<List<Matter>>(error: final AppError error):
        failedGroups.add(SearchGroup.matters);
        firstError ??= error;
    }
    switch (documents) {
      case Success<List<Document>>(value: final List<Document> value):
        documentRows = value
            .where((Document d) => _documentMatches(d, needle, labels))
            .take(effectiveLimit)
            .toList(growable: false);
      case Failure<List<Document>>(error: final AppError error):
        failedGroups.add(SearchGroup.documents);
        firstError ??= error;
    }
    switch (threads) {
      case Success<List<MessageThread>>(value: final List<MessageThread> value):
        threadRows = value
            .where((MessageThread t) => _threadMatches(t, needle, labels))
            .take(effectiveLimit)
            .toList(growable: false);
      case Failure<List<MessageThread>>(error: final AppError error):
        failedGroups.add(SearchGroup.threads);
        firstError ??= error;
    }
    switch (attorneys) {
      case Success<List<Attorney>>(value: final List<Attorney> value):
        _attorneyCache = value;
        attorneyRows = value
            .where((Attorney a) => _attorneyMatches(a, needle, labels))
            .take(effectiveLimit)
            .toList(growable: false);
      case Failure<List<Attorney>>(error: final AppError error):
        failedGroups.add(SearchGroup.attorneys);
        firstError ??= error;
    }
    if (failedGroups.length == SearchGroup.values.length) {
      emit(
        state.copyWith(
          results: viewStateForFailure<SearchResults>(firstError!),
        ),
      );
      return;
    }
    final SearchResults grouped = SearchResults(
      matters: matterRows,
      documents: documentRows,
      threads: threadRows,
      attorneys: attorneyRows,
      failedGroups: failedGroups,
    );
    emit(
      state.copyWith(
        results: grouped.isEmpty && failedGroups.isEmpty
            ? const ViewEmpty<SearchResults>()
            : ViewSuccess<SearchResults>(grouped),
      ),
    );
  }

  bool _contains(String field, String needle) =>
      field.toLowerCase().contains(needle);

  bool _matterMatches(Matter matter, String needle, DemoLabels? labels) {
    if (_contains(matter.title, needle) ||
        _contains(matter.status.name, needle) ||
        _contains(matter.practiceArea.name, needle)) {
      return true;
    }
    if (labels == null) {
      return false;
    }
    return _contains(labels.matterTitle(matter.title), needle) ||
        _contains(matterStatusLabel(labels.l10n, matter.status), needle) ||
        _contains(practiceAreaLabel(labels.l10n, matter.practiceArea), needle);
  }

  bool _documentMatches(Document document, String needle, DemoLabels? labels) {
    if (_contains(document.title, needle) ||
        _contains(document.type.name, needle) ||
        _contains(document.matterRef, needle)) {
      return true;
    }
    if (labels == null) {
      return false;
    }
    return _contains(labels.documentTitle(document.title), needle) ||
        _contains(documentTypeLabel(labels.l10n, document.type), needle) ||
        _contains(labels.matterTitle(document.matterRef), needle);
  }

  bool _threadMatches(MessageThread thread, String needle, DemoLabels? labels) {
    if (_contains(thread.title, needle) ||
        _contains(thread.matterRef, needle)) {
      return true;
    }
    if (thread.participants.any((String p) => _contains(p, needle))) {
      return true;
    }
    if (labels == null) {
      return false;
    }
    if (_contains(labels.threadTitle(thread.title), needle) ||
        _contains(labels.matterTitle(thread.matterRef), needle)) {
      return true;
    }
    return thread.participants.any(
      (String p) => _contains(labels.authorName(p), needle),
    );
  }

  bool _attorneyMatches(Attorney attorney, String needle, DemoLabels? labels) {
    final PracticeArea? area = attorney.practiceArea;
    if (_contains(attorney.name, needle) ||
        (area != null && _contains(area.name, needle))) {
      return true;
    }
    if (labels == null || area == null) {
      return false;
    }
    return _contains(practiceAreaLabel(labels.l10n, area), needle);
  }
}
