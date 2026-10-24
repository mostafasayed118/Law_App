import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
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
/// (an eager tile build) never renders more than 4 pages of tiles — and the
/// same bound caps the transfer: the three Supabase-backed gateways receive
/// it as their server-side title-prefilter page size, so a query moves at
/// most 4 pages of candidate rows, not four capped full lists (audit:
/// search fan-out). The exact full-matching pass below stays the arbiter
/// client-side, so the "top-N per group" contract is preserved.
///
/// Recall caveat callers must know: on a real backend the prefilter is
/// title-only, so a label-only match (e.g. a matter whose title does NOT
/// contain the query but whose localized status does) reaches the refiner
/// only when its title also matched the prefilter. Fakes (dev/tests) show
/// the ideal — full-list candidates, exact results.
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
  /// 4 × 30 tiles AND the server-side prefilter page per gateway).
  /// Mirrors the shared 30-row search page size without importing the data
  /// layer — presentation must never depend on `lib/data/` (layer rule).
  static const int searchPageSize = 30;

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
    int limit = searchPageSize,
  }) async {
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
    // Server-side prefilter + client-side refine (audit: search fan-out):
    // the three Supabase-backed gateways push a recall-oriented title
    // prefilter to the server (first page of ilike matches, newest-first)
    // bounded by the same effective limit that bounds the rendered groups;
    // in-memory backends return their full list at no transfer cost. The
    // exact full-matching pass below (raw needle AND localized
    // projections) stays the arbiter, so "top-N per group" semantics are
    // preserved.
    final int effectiveLimit = limit <= 0 ? searchPageSize : limit;
    final (
      Result<List<Matter>> matters,
      Result<List<Document>> documents,
      Result<List<MessageThread>> threads,
      Result<List<Attorney>> attorneys,
    ) = await (
      _matterGateway.searchMatters(trimmed, limit: effectiveLimit),
      _documentGateway.searchDocuments(trimmed, limit: effectiveLimit),
      _messageGateway.searchThreads(trimmed, limit: effectiveLimit),
      _attorneyGateway.fetchAttorneys(),
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
            .where((Matter m) => _matterMatches(m, needle, l10n))
            .take(effectiveLimit)
            .toList(growable: false);
      case Failure<List<Matter>>(error: final AppError error):
        failedGroups.add(SearchGroup.matters);
        firstError ??= error;
    }
    switch (documents) {
      case Success<List<Document>>(value: final List<Document> value):
        documentRows = value
            .where((Document d) => _documentMatches(d, needle, l10n))
            .take(effectiveLimit)
            .toList(growable: false);
      case Failure<List<Document>>(error: final AppError error):
        failedGroups.add(SearchGroup.documents);
        firstError ??= error;
    }
    switch (threads) {
      case Success<List<MessageThread>>(value: final List<MessageThread> value):
        threadRows = value
            .where((MessageThread t) => _threadMatches(t, needle, l10n))
            .take(effectiveLimit)
            .toList(growable: false);
      case Failure<List<MessageThread>>(error: final AppError error):
        failedGroups.add(SearchGroup.threads);
        firstError ??= error;
    }
    switch (attorneys) {
      case Success<List<Attorney>>(value: final List<Attorney> value):
        attorneyRows = value
            .where((Attorney a) => _attorneyMatches(a, needle, l10n))
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

  bool _matterMatches(Matter matter, String needle, AppLocalizations? l10n) {
    if (_contains(matter.title, needle) ||
        _contains(matter.status.name, needle) ||
        _contains(matter.practiceArea.name, needle)) {
      return true;
    }
    if (l10n == null) {
      return false;
    }
    return _contains(demoMatterTitle(l10n, matter.title), needle) ||
        _contains(matterStatusLabel(l10n, matter.status), needle) ||
        _contains(practiceAreaLabel(l10n, matter.practiceArea), needle);
  }

  bool _documentMatches(
    Document document,
    String needle,
    AppLocalizations? l10n,
  ) {
    if (_contains(document.title, needle) ||
        _contains(document.type.name, needle) ||
        _contains(document.matterRef, needle)) {
      return true;
    }
    if (l10n == null) {
      return false;
    }
    return _contains(demoDocumentTitle(l10n, document.title), needle) ||
        _contains(documentTypeLabel(l10n, document.type), needle) ||
        _contains(demoMatterTitle(l10n, document.matterRef), needle);
  }

  bool _threadMatches(
    MessageThread thread,
    String needle,
    AppLocalizations? l10n,
  ) {
    if (_contains(thread.title, needle) ||
        _contains(thread.matterRef, needle)) {
      return true;
    }
    if (thread.participants.any((String p) => _contains(p, needle))) {
      return true;
    }
    if (l10n == null) {
      return false;
    }
    if (_contains(demoThreadTitle(l10n, thread.title), needle) ||
        _contains(demoMatterTitle(l10n, thread.matterRef), needle)) {
      return true;
    }
    return thread.participants.any(
      (String p) => _contains(demoAuthorName(l10n, p), needle),
    );
  }

  bool _attorneyMatches(
    Attorney attorney,
    String needle,
    AppLocalizations? l10n,
  ) {
    final PracticeArea? area = attorney.practiceArea;
    if (_contains(attorney.name, needle) ||
        (area != null && _contains(area.name, needle))) {
      return true;
    }
    if (l10n == null || area == null) {
      return false;
    }
    return _contains(practiceAreaLabel(l10n, area), needle);
  }
}
