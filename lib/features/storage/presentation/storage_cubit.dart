import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/file_metadata.dart';
import '../domain/storage_gateway.dart';
import 'storage_state.dart';

/// Owns the matter-files list surface (storage slice, D-STR7).
///
/// [load] fetches the file-metadata list on section open (the section wires
/// it after first frame, matching the roster/discovery/matters pattern).
/// Metadata only — nothing but the D-STR3 surface ever crosses the
/// [StorageGateway] boundary (D-STR9: no download affordance). Widgets
/// render [StorageState] and dispatch intents; they never call the gateway
/// directly.
class StorageCubit extends Cubit<StorageState> {
  StorageCubit(this._gateway) : super(const StorageState());

  final StorageGateway _gateway;

  /// In-flight guard. The initial state IS loading (like
  /// [DocumentCubit.load]'s contract), so the flag — not a state check —
  /// distinguishes "loading in flight" from "not loaded yet"; duplicate
  /// calls while a load is in flight are ignored.
  bool _loading = false;

  /// Loads the file-metadata list. The initial state is already loading, so
  /// the first open never re-emits a redundant loading frame; a retry after
  /// an error re-enters loading. An empty list maps to [ViewEmpty]; a
  /// failure to [ViewError].
  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.files is! ViewLoading<List<FileMetadata>>) {
      emit(state.copyWith(files: const ViewLoading<List<FileMetadata>>()));
    }
    final Result<List<FileMetadata>> result = await _gateway.fetchFiles();
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<FileMetadata>>(value: final List<FileMetadata> files):
        emit(
          state.copyWith(
            files: files.isEmpty
                ? const ViewEmpty<List<FileMetadata>>()
                : ViewSuccess<List<FileMetadata>>(files),
          ),
        );
      case Failure<List<FileMetadata>>(error: final AppError error):
        emit(state.copyWith(files: ViewError<List<FileMetadata>>(error)));
    }
  }
}
