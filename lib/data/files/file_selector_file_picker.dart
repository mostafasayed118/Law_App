import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'package:legalhub/features/storage/domain/file_picker.dart';
import 'package:legalhub/features/storage/domain/picked_file.dart';
import 'package:legalhub/features/storage/domain/storage_gateway.dart';

/// [FilePicker] backed by `package:file_selector`.
///
/// This is the only file that imports the plugin. The type group declares
/// extensions (desktop/web), MIME types (Android), and UTIs (iOS/macOS) for
/// the server's seven allowed types; the gateway still re-validates the MIME
/// it receives.
class FileSelectorFilePicker implements FilePicker {
  const FileSelectorFilePicker();

  static final XTypeGroup _matterFiles = XTypeGroup(
    label: 'Matter files',
    extensions: matterFileAllowedExtensions.toList(growable: false),
    mimeTypes: matterFileAllowedMimeTypes.toList(growable: false),
    uniformTypeIdentifiers: <String>[
      'com.adobe.pdf',
      'com.microsoft.word.doc',
      'org.openxmlformats.wordprocessingml.document',
      'public.plain-text',
      'public.comma-separated-values-text',
      'public.png',
      'public.jpeg',
    ],
  );

  @override
  Future<PickedFile?> pickFile() async {
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[_matterFiles],
      );
      if (file == null) {
        return null;
      }
      final int length = await file.length();
      // Size gate before the read: a 25 MiB+ file must never be allocated
      // just to be rejected (audit 2026-10-27, F9).
      if (length < 0 || length > matterFileMaxBytes) {
        throw const FileTooLargeException();
      }
      final Uint8List bytes = await file.readAsBytes();
      return PickedFile(
        name: file.name,
        mimeType: file.mimeType ?? 'application/octet-stream',
        sizeBytes: length,
        bytes: bytes,
      );
    } on FileTooLargeException {
      // A domain rejection, not a plugin failure: the cubit needs to tell the
      // user the file is too large.
      rethrow;
    } on Exception {
      // Plugin/OS failures are typed here; the message stays generic so no
      // file name or content can leak through the seam.
      throw const FilePickException();
    }
  }
}
