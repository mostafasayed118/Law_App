import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/storage/domain/file_metadata.dart';
import 'package:legalhub/features/storage/domain/file_picker.dart';
import 'package:legalhub/features/storage/domain/picked_file.dart';
import 'package:legalhub/features/storage/domain/storage_gateway.dart';
import 'package:legalhub/features/storage/domain/uri_opener.dart';
import 'package:legalhub/features/storage/presentation/file_transfer_cubit.dart';
import 'package:legalhub/features/storage/presentation/file_transfer_state.dart';

void main() {
  late _StubStorageGateway gateway;
  late _FakePicker picker;
  late _FakeOpener opener;

  setUp(() {
    gateway = _StubStorageGateway();
    picker = _FakePicker();
    opener = _FakeOpener();
  });

  final PickedFile picked = PickedFile(
    name: 'brief.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 12,
    bytes: _bytes,
  );

  group('FileTransferCubit.pickAndUpload', () {
    blocTest<FileTransferCubit, FileTransferState>(
      'a picker cancel is a no-op',
      build: () => FileTransferCubit(gateway, picker, opener),
      act: (FileTransferCubit cubit) => cubit.pickAndUpload('m-1'),
      expect: () => <FileTransferState>[],
      verify: (_) {
        expect(gateway.uploads, isEmpty);
        expect(picker.calls, 1);
      },
    );

    blocTest<FileTransferCubit, FileTransferState>(
      'an unsupported MIME type fails before upload',
      build: () => FileTransferCubit(gateway, picker, opener),
      setUp: () => picker.picked = PickedFile(
        name: 'archive.zip',
        mimeType: 'application/zip',
        sizeBytes: 10,
        bytes: _bytes,
      ),
      act: (FileTransferCubit cubit) => cubit.pickAndUpload('m-1'),
      expect: () => <FileTransferState>[
        const FileTransferState.failure(
          AppError(
            code: 'file_upload_unsupported_type',
            userMessage: 'This file type is not supported.',
          ),
          fileName: 'archive.zip',
        ),
      ],
      verify: (_) => expect(gateway.uploads, isEmpty),
    );

    blocTest<FileTransferCubit, FileTransferState>(
      'an oversize file fails before upload',
      build: () => FileTransferCubit(gateway, picker, opener),
      setUp: () => picker.picked = PickedFile(
        name: 'huge.pdf',
        mimeType: 'application/pdf',
        sizeBytes: matterFileMaxBytes + 1,
        bytes: _bytes,
      ),
      act: (FileTransferCubit cubit) => cubit.pickAndUpload('m-1'),
      expect: () => <FileTransferState>[
        const FileTransferState.failure(
          AppError(
            code: 'file_upload_too_large',
            userMessage: 'This file is too large.',
          ),
          fileName: 'huge.pdf',
        ),
      ],
      verify: (_) => expect(gateway.uploads, isEmpty),
    );

    blocTest<FileTransferCubit, FileTransferState>(
      'a successful upload emits uploading then success',
      build: () => FileTransferCubit(gateway, picker, opener),
      setUp: () => picker.picked = picked,
      act: (FileTransferCubit cubit) => cubit.pickAndUpload('m-1'),
      expect: () => <FileTransferState>[
        const FileTransferState.uploading('brief.pdf'),
        const FileTransferState.success('brief.pdf'),
      ],
      verify: (_) {
        expect(gateway.uploads, hasLength(1));
        expect(gateway.uploads.single.matterId, 'm-1');
        expect(gateway.uploads.single.name, 'brief.pdf');
        expect(gateway.uploads.single.mimeType, 'application/pdf');
        expect(gateway.uploads.single.sizeBytes, 12);
      },
    );

    blocTest<FileTransferCubit, FileTransferState>(
      'a gateway failure is retryable',
      build: () => FileTransferCubit(gateway, picker, opener),
      setUp: () {
        picker.picked = picked;
        gateway.uploadResults = <Result<FileMetadata>>[
          Result<FileMetadata>.failure(_denied),
          Result<FileMetadata>.success(_file),
        ];
      },
      act: (FileTransferCubit cubit) async {
        await cubit.pickAndUpload('m-1');
        await cubit.pickAndUpload('m-1');
      },
      expect: () => <FileTransferState>[
        const FileTransferState.uploading('brief.pdf'),
        const FileTransferState.failure(_denied, fileName: 'brief.pdf'),
        const FileTransferState.uploading('brief.pdf'),
        const FileTransferState.success('brief.pdf'),
      ],
      verify: (_) => expect(gateway.uploadCalls, 2),
    );

    test('duplicate pickAndUpload while in flight is ignored', () async {
      final Completer<PickedFile?> completer = Completer<PickedFile?>();
      picker = _FakePicker(completer: completer);
      final FileTransferCubit cubit = FileTransferCubit(
        gateway,
        picker,
        opener,
      );
      addTearDown(cubit.close);

      final Future<void> first = cubit.pickAndUpload('m-1');
      final Future<void> second = cubit.pickAndUpload('m-1');
      completer.complete(picked);
      await first;
      await second;

      expect(picker.calls, 1);
      expect(gateway.uploadCalls, 1);
    });

    blocTest<FileTransferCubit, FileTransferState>(
      'the picker can reject an oversize file before reading bytes',
      build: () => FileTransferCubit(gateway, _TooLargePicker(), opener),
      act: (FileTransferCubit cubit) => cubit.pickAndUpload('m-1'),
      expect: () => <FileTransferState>[
        const FileTransferState.failure(
          AppError(
            code: 'file_upload_too_large',
            userMessage: 'This file is too large.',
          ),
        ),
      ],
      verify: (_) => expect(gateway.uploads, isEmpty),
    );

    test(
      'a raw upload timeout fails the state instead of stranding it',
      () async {
        picker.picked = picked;
        gateway.uploadThrow = TimeoutException('upload stalled');
        final FileTransferCubit cubit = FileTransferCubit(
          gateway,
          picker,
          opener,
        );
        addTearDown(cubit.close);

        await cubit.pickAndUpload('m-1');

        expect(cubit.state.phase, FileTransferPhase.failure);
        expect(cubit.state.error?.code, 'file_upload_unavailable');
        expect(cubit.state.error?.kind, AppErrorKind.unavailable);

        // The in-flight guard released, so the user can retry immediately.
        gateway.uploadThrow = null;
        await cubit.pickAndUpload('m-1');
        expect(cubit.state.phase, FileTransferPhase.success);
      },
    );

    blocTest<FileTransferCubit, FileTransferState>(
      'a picker exception maps to the generic upload failure',
      build: () => FileTransferCubit(gateway, picker, opener),
      setUp: () => picker.error = const FilePickException(),
      act: (FileTransferCubit cubit) => cubit.pickAndUpload('m-1'),
      expect: () => <FileTransferState>[
        const FileTransferState.failure(
          AppError(
            code: 'file_upload_failed',
            userMessage: 'Unable to upload the file. Please try again.',
          ),
        ),
      ],
      verify: (_) => expect(gateway.uploads, isEmpty),
    );
  });

  group('FileTransferCubit.openFile', () {
    blocTest<FileTransferCubit, FileTransferState>(
      'resolves a signed URL and opens it externally',
      build: () => FileTransferCubit(gateway, picker, opener),
      act: (FileTransferCubit cubit) => cubit.openFile(_file),
      expect: () => <FileTransferState>[
        const FileTransferState.opening('Demo retainer scan'),
        const FileTransferState(),
      ],
      verify: (_) {
        expect(gateway.downloadCalls, 1);
        expect(opener.opened.single.host, 'files.example.com');
      },
    );

    blocTest<FileTransferCubit, FileTransferState>(
      'a signed-URL failure emits the gateway error and never opens',
      build: () => FileTransferCubit(gateway, picker, opener),
      setUp: () => gateway.downloadResult = Result<Uri>.failure(_openDenied),
      act: (FileTransferCubit cubit) => cubit.openFile(_file),
      expect: () => <FileTransferState>[
        const FileTransferState.opening('Demo retainer scan'),
        const FileTransferState.failure(
          _openDenied,
          fileName: 'Demo retainer scan',
        ),
      ],
      verify: (_) => expect(opener.opened, isEmpty),
    );

    blocTest<FileTransferCubit, FileTransferState>(
      'a refused external launch maps to file_open_failed',
      build: () => FileTransferCubit(gateway, picker, opener),
      setUp: () => opener.result = false,
      act: (FileTransferCubit cubit) => cubit.openFile(_file),
      expect: () => <FileTransferState>[
        const FileTransferState.opening('Demo retainer scan'),
        const FileTransferState.failure(
          AppError(
            code: 'file_open_failed',
            userMessage: 'Unable to open the file. Please try again.',
          ),
          fileName: 'Demo retainer scan',
        ),
      ],
    );
  });
}

final Uint8List _bytes = Uint8List.fromList(<int>[1, 2, 3]);

final FileMetadata _file = const FileMetadata(
  id: 'file-1',
  name: 'Demo retainer scan',
  matterRef: 'Demo acquisition review',
  mimeType: 'application/pdf',
  sizeBytes: 12,
  storagePath: 'org-demo/matter-1/demo-retainer-scan.pdf',
);

const AppError _denied = AppError(
  code: 'file_upload_denied',
  userMessage: 'You do not have permission to upload files to this matter.',
  kind: AppErrorKind.denied,
);

const AppError _openDenied = AppError(
  code: 'file_open_denied',
  userMessage: 'You do not have permission to open this file.',
  kind: AppErrorKind.denied,
);

class _RecordedUpload {
  const _RecordedUpload({
    required this.matterId,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.bytes,
  });

  final String matterId;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final Uint8List bytes;
}

class _StubStorageGateway implements StorageGateway {
  final List<_RecordedUpload> uploads = <_RecordedUpload>[];
  List<Result<FileMetadata>> uploadResults = <Result<FileMetadata>>[
    Result<FileMetadata>.success(_file),
  ];
  Result<Uri> downloadResult = Result<Uri>.success(
    Uri.parse('https://files.example.com/signed/file-1?token=demo'),
  );
  int uploadCalls = 0;
  int downloadCalls = 0;
  Object? uploadThrow;

  @override
  Future<Result<List<FileMetadata>>> fetchFiles({String? matterId}) async =>
      Result<List<FileMetadata>>.success(<FileMetadata>[_file]);

  @override
  Future<Result<FileMetadata>> uploadFile({
    required String matterId,
    required String name,
    required String mimeType,
    required int sizeBytes,
    required Uint8List bytes,
  }) async {
    uploadCalls += 1;
    uploads.add(
      _RecordedUpload(
        matterId: matterId,
        name: name,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        bytes: bytes,
      ),
    );
    final Object? throwable = uploadThrow;
    if (throwable != null) {
      throw throwable;
    }
    return uploadResults.removeAt(0);
  }

  @override
  Future<Result<Uri>> createDownloadUrl(
    FileMetadata file, {
    Duration ttl = const Duration(seconds: 60),
  }) async {
    downloadCalls += 1;
    return downloadResult;
  }
}

class _FakePicker implements FilePicker {
  _FakePicker({this.completer});

  final Completer<PickedFile?>? completer;
  PickedFile? picked;
  FilePickException? error;
  int calls = 0;

  @override
  Future<PickedFile?> pickFile() async {
    calls += 1;
    if (error != null) {
      throw error!;
    }
    if (completer != null) {
      return completer!.future;
    }
    return picked;
  }
}

class _FakeOpener implements UriOpener {
  final List<Uri> opened = <Uri>[];
  bool result = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

class _TooLargePicker implements FilePicker {
  @override
  Future<PickedFile?> pickFile() async => throw const FileTooLargeException();
}
