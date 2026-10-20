import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../../features/storage/domain/file_picker.dart';
import '../../features/storage/domain/picked_file.dart';

/// [FilePicker] backed by `package:file_selector`.
///
/// This is the only file that imports the plugin. The type group declares
/// extensions (desktop/web), MIME types (Android), and UTIs (iOS/macOS) for
/// the server's seven allowed types; the gateway still re-validates the MIME
/// it receives.
class FileSelectorFilePicker implements FilePicker {
  const FileSelectorFilePicker();

  static const XTypeGroup _matterFiles = XTypeGroup(
    label: 'Matter files',
    extensions: <String>[
      'pdf',
      'doc',
      'docx',
      'txt',
      'csv',
      'png',
      'jpg',
      'jpeg',
    ],
    mimeTypes: <String>[
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'text/plain',
      'text/csv',
      'image/png',
      'image/jpeg',
    ],
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
        acceptedTypeGroups: const <XTypeGroup>[_matterFiles],
      );
      if (file == null) {
        return null;
      }
      final int length = await file.length();
      final Uint8List bytes = await file.readAsBytes();
      return PickedFile(
        name: file.name,
        mimeType: file.mimeType ?? 'application/octet-stream',
        sizeBytes: length,
        bytes: bytes,
      );
    } on Object {
      // Plugin/OS failures are typed here; the message stays generic so no
      // file name or content can leak through the seam.
      throw const FilePickException();
    }
  }
}
