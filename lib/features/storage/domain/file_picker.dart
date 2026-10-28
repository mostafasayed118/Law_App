import 'picked_file.dart';

/// Typed picker failure crossing the [FilePicker] seam.
///
/// Carries no plugin detail, file name, or content — presentation maps it to
/// a generic localized failure.
class FilePickException implements Exception {
  const FilePickException();

  @override
  String toString() => 'FilePickException';
}

/// The picked file exceeds the bucket cap. The picker raises this before
/// reading bytes so a huge file is never allocated just to be rejected.
class FileTooLargeException implements Exception {
  const FileTooLargeException();

  @override
  String toString() => 'FileTooLargeException';
}

/// Platform seam for choosing one file to upload.
///
/// The implementation is the only thing that knows about the picker plugin;
/// domain and presentation code depend on this interface. Returns null when
/// the user cancels.
abstract interface class FilePicker {
  Future<PickedFile?> pickFile();
}
