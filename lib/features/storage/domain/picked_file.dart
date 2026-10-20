import 'dart:typed_data';

/// A file chosen by the user, before any upload begins.
///
/// Carrier only: the bytes live in [bytes] and never enter logs or error
/// messages. The MIME/size values are the picker's best declaration; the
/// gateway re-validates both against the server contract.
class PickedFile {
  const PickedFile({
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final int sizeBytes;
  final Uint8List bytes;
}
