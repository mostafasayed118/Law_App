import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/file_metadata.dart';

/// Immutable state of the matter-files surface (storage slice, D-STR7).
///
/// [files] holds the file-metadata load lifecycle using the shared
/// [ViewState] vocabulary (loading / success / empty / error+retry) — the
/// smallest surface that satisfies the metadata-only line (no download, no
/// per-file selection state; D-STR9).
class StorageState extends Equatable {
  const StorageState({this.files = const ViewLoading<List<FileMetadata>>()});

  final ViewState<List<FileMetadata>> files;

  StorageState copyWith({ViewState<List<FileMetadata>>? files}) {
    return StorageState(files: files ?? this.files);
  }

  @override
  List<Object?> get props => <Object?>[files];
}
