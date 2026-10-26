import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_gateway.dart';
import 'discovery_state.dart';

/// Owns the attorney-discovery search and profile surfaces (design §2).
///
/// [load] reads the directory (server-side [query], debounced on typing);
/// [updateQuery] and [setPracticeArea] narrow the current page locally; and
/// [loadProfile] reads one profile by id. Widgets render [DiscoveryState] and
/// dispatch intents; they never call the gateway directly.
class DiscoveryCubit extends Cubit<DiscoveryState> {
  /// [initialPracticeArea] seeds the practice-area chip for a deep link from
  /// the home dashboard's practice-area cards (`/discovery?area=…`).
  DiscoveryCubit(this._gateway, {PracticeArea? initialPracticeArea})
    : super(DiscoveryState(practiceArea: initialPracticeArea));

  /// Typing pause before a server query runs. The local projection already
  /// filters the current page, so the debounce only controls re-fetching.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  final AttorneyGateway _gateway;

  /// In-flight guards. The initial list state IS loading, so a naive
  /// `if (loading) return` would abort the first load — these flags
  /// distinguish "request in flight" from "not loaded yet".
  bool _loading = false;
  bool _profileLoading = false;

  /// The query the current list was fetched with; used to decide whether a
  /// settled load needs a follow-up fetch for a newer query.
  String _loadedQuery = '';

  Timer? _debounce;

  /// Loads the directory for the current query. A retry after an error
  /// re-enters loading. Duplicate calls while in flight are ignored; if the
  /// query moved on meanwhile, the follow-up fetch is scheduled.
  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    final String query = state.query.trim();
    if (state.attorneys is! ViewLoading<List<Attorney>>) {
      emit(state.copyWith(attorneys: const ViewLoading<List<Attorney>>()));
    }
    final Result<List<Attorney>> result = await _gateway.fetchAttorneys(
      query: query,
    );
    _loading = false;
    if (isClosed) {
      return;
    }
    _loadedQuery = query;
    switch (result) {
      case Success<List<Attorney>>(value: final List<Attorney> attorneys):
        emit(
          state.copyWith(
            attorneys: attorneys.isEmpty
                ? const ViewEmpty<List<Attorney>>()
                : ViewSuccess<List<Attorney>>(attorneys),
          ),
        );
      case Failure<List<Attorney>>(error: final AppError error):
        emit(
          state.copyWith(attorneys: viewStateForFailure<List<Attorney>>(error)),
        );
    }
    if (state.query.trim() != _loadedQuery) {
      _scheduleSearch();
    }
  }

  /// Loads one profile by id for the detail surface. A `not_found` failure
  /// maps to [ViewEmpty] (the localized not-found copy); denials/outages keep
  /// their typed state.
  Future<void> loadProfile(String id) async {
    if (isClosed || _profileLoading) {
      return;
    }
    _profileLoading = true;
    if (state.profile is! ViewLoading<Attorney>) {
      emit(state.copyWith(profile: const ViewLoading<Attorney>()));
    }
    final Result<Attorney> result = await _gateway.fetchAttorney(id);
    _profileLoading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<Attorney>(value: final Attorney attorney):
        emit(state.copyWith(profile: ViewSuccess<Attorney>(attorney)));
      case Failure<Attorney>(error: final AppError error):
        emit(
          state.copyWith(
            profile: error.code == 'attorney_not_found'
                ? const ViewEmpty<Attorney>()
                : viewStateForFailure<Attorney>(error),
          ),
        );
    }
  }

  /// Stores the free-text search query verbatim (trimming happens at the
  /// gateway boundary) and schedules the debounced server query.
  void updateQuery(String query) {
    if (isClosed || query == state.query) {
      return;
    }
    emit(state.copyWith(query: query));
    _scheduleSearch();
  }

  /// Activates a practice-area filter chip, or null for "All".
  void setPracticeArea(PracticeArea? area) {
    if (isClosed) {
      return;
    }
    emit(state.copyWith(practiceArea: area));
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (isClosed || state.query.trim() == _loadedQuery) {
        return;
      }
      load();
    });
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
