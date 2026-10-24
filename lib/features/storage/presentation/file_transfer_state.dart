import 'package:equatable/equatable.dart';

import 'package:legalhub/core/errors/app_error.dart';

/// The transfer surface's lifecycle.
enum FileTransferPhase { idle, uploading, success, failure, opening }

/// Immutable state of the matter-file transfer affordances.
///
/// One transfer at a time: the file name is carried for the progress copy,
/// and [error] carries the typed failure so the section renders the matching
/// localized line.
class FileTransferState extends Equatable {
  const FileTransferState._({
    this.phase = FileTransferPhase.idle,
    this.fileName,
    this.error,
  });

  const FileTransferState() : this._();

  const FileTransferState.uploading(String fileName)
    : this._(phase: FileTransferPhase.uploading, fileName: fileName);

  const FileTransferState.success(String fileName)
    : this._(phase: FileTransferPhase.success, fileName: fileName);

  const FileTransferState.failure(AppError error, {String? fileName})
    : this._(
        phase: FileTransferPhase.failure,
        fileName: fileName,
        error: error,
      );

  const FileTransferState.opening(String fileName)
    : this._(phase: FileTransferPhase.opening, fileName: fileName);

  final FileTransferPhase phase;
  final String? fileName;
  final AppError? error;

  bool get isBusy =>
      phase == FileTransferPhase.uploading ||
      phase == FileTransferPhase.opening;

  @override
  List<Object?> get props => <Object?>[phase, fileName, error];
}
