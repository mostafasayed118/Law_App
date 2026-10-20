import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../domain/file_metadata.dart';
import '../domain/file_picker.dart';
import '../domain/picked_file.dart';
import '../domain/storage_gateway.dart';
import '../domain/uri_opener.dart';
import 'file_transfer_state.dart';

/// Owns the pick → upload and open-signed-URL flows for a matter's files.
///
/// The cubit pre-checks MIME/size (the gateway re-checks), guards duplicate
/// transfers, and never renders raw plugin/provider text. A picker cancel is
/// a no-op.
class FileTransferCubit extends Cubit<FileTransferState> {
  FileTransferCubit(this._gateway, this._picker, this._opener)
    : super(const FileTransferState());

  final StorageGateway _gateway;
  final FilePicker _picker;
  final UriOpener _opener;

  bool _uploading = false;
  bool _opening = false;

  /// Picks one file and uploads it to [matterId].
  ///
  /// Emits [FileTransferState.success] after the gateway persists the row;
  /// the section listens and reloads the list. Failure states stay retryable.
  Future<void> pickAndUpload(String matterId) async {
    if (isClosed || _uploading) {
      return;
    }
    _uploading = true;
    try {
      final PickedFile? picked = await _picker.pickFile();
      if (isClosed || picked == null) {
        return;
      }
      if (!matterFileAllowedMimeTypes.contains(picked.mimeType)) {
        emit(
          FileTransferState.failure(
            const AppError(
              code: 'file_upload_unsupported_type',
              userMessage: 'This file type is not supported.',
            ),
            fileName: picked.name,
          ),
        );
        return;
      }
      if (picked.sizeBytes < 0 || picked.sizeBytes > matterFileMaxBytes) {
        emit(
          FileTransferState.failure(
            const AppError(
              code: 'file_upload_too_large',
              userMessage: 'This file is too large.',
            ),
            fileName: picked.name,
          ),
        );
        return;
      }

      emit(FileTransferState.uploading(picked.name));
      final Result<FileMetadata> result = await _gateway.uploadFile(
        matterId: matterId,
        name: picked.name,
        mimeType: picked.mimeType,
        sizeBytes: picked.sizeBytes,
        bytes: picked.bytes,
      );
      if (isClosed) {
        return;
      }
      switch (result) {
        case Success<FileMetadata>():
          emit(FileTransferState.success(picked.name));
        case Failure<FileMetadata>(error: final AppError error):
          emit(FileTransferState.failure(error, fileName: picked.name));
      }
    } on FilePickException {
      if (!isClosed) {
        emit(const FileTransferState.failure(_pickFailedError));
      }
    } finally {
      _uploading = false;
    }
  }

  /// Resolves a short-lived signed URL for [file] and opens it externally.
  Future<void> openFile(FileMetadata file) async {
    if (isClosed || _opening) {
      return;
    }
    _opening = true;
    try {
      emit(FileTransferState.opening(file.name));
      final Result<Uri> result = await _gateway.createDownloadUrl(file);
      if (isClosed) {
        return;
      }
      switch (result) {
        case Failure<Uri>(error: final AppError error):
          emit(FileTransferState.failure(error, fileName: file.name));
        case Success<Uri>(value: final Uri uri):
          final bool opened = await _opener.open(uri);
          if (isClosed) {
            return;
          }
          emit(
            opened
                ? const FileTransferState()
                : FileTransferState.failure(
                    _openFailedError,
                    fileName: file.name,
                  ),
          );
      }
    } on Object {
      if (!isClosed) {
        emit(FileTransferState.failure(_openFailedError, fileName: file.name));
      }
    } finally {
      _opening = false;
    }
  }
}

const AppError _pickFailedError = AppError(
  code: 'file_upload_failed',
  userMessage: 'Unable to upload the file. Please try again.',
);

const AppError _openFailedError = AppError(
  code: 'file_open_failed',
  userMessage: 'Unable to open the file. Please try again.',
);
