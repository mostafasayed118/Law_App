import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/storage/domain/file_metadata.dart';
import 'package:legalhub/features/storage/domain/storage_gateway.dart';
import 'package:legalhub/features/storage/presentation/storage_cubit.dart';
import 'package:legalhub/features/storage/presentation/storage_state.dart';

void main() {
  late _StubStorageGateway gateway;

  setUp(() {
    gateway = _StubStorageGateway();
  });

  group('StorageCubit (storage slice D-STR7)', () {
    test('starts loading with no rows', () {
      final StorageCubit cubit = StorageCubit(gateway);
      addTearDown(cubit.close);

      expect(cubit.state.files, const ViewLoading<List<FileMetadata>>());
    });

    blocTest<StorageCubit, StorageState>(
      'load resolves to the file-metadata list',
      build: () => StorageCubit(gateway),
      act: (StorageCubit cubit) => cubit.load(),
      expect: () => <StorageState>[
        StorageState(files: ViewSuccess<List<FileMetadata>>(_files)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<StorageCubit, StorageState>(
      'load maps an empty list to ViewEmpty',
      setUp: () => gateway = _StubStorageGateway(
        results: <Result<List<FileMetadata>>>[
          Result<List<FileMetadata>>.success(const <FileMetadata>[]),
        ],
      ),
      build: () => StorageCubit(gateway),
      act: (StorageCubit cubit) => cubit.load(),
      expect: () => <StorageState>[
        const StorageState(files: ViewEmpty<List<FileMetadata>>()),
      ],
    );

    blocTest<StorageCubit, StorageState>(
      'load maps a failure to ViewError',
      setUp: () => gateway = _StubStorageGateway(
        results: <Result<List<FileMetadata>>>[
          Result<List<FileMetadata>>.failure(_loadFailure),
        ],
      ),
      build: () => StorageCubit(gateway),
      act: (StorageCubit cubit) => cubit.load(),
      expect: () => <StorageState>[
        StorageState(files: ViewError<List<FileMetadata>>(_loadFailure)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<StorageCubit, StorageState>(
      'duplicate load while in flight is ignored',
      setUp: () => gateway = _StubStorageGateway.withCompleter(),
      build: () => StorageCubit(gateway),
      act: (StorageCubit cubit) async {
        final Future<void> first = cubit.load();
        await cubit.load();
        gateway.completer!.complete(Result<List<FileMetadata>>.success(_files));
        await first;
      },
      expect: () => <StorageState>[
        StorageState(files: ViewSuccess<List<FileMetadata>>(_files)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<StorageCubit, StorageState>(
      'load after an error retries into a fresh success',
      setUp: () => gateway = _StubStorageGateway(
        results: <Result<List<FileMetadata>>>[
          Result<List<FileMetadata>>.failure(_loadFailure),
          Result<List<FileMetadata>>.success(_files),
        ],
      ),
      build: () => StorageCubit(gateway),
      act: (StorageCubit cubit) async {
        await cubit.load();
        await cubit.load();
      },
      expect: () => <StorageState>[
        StorageState(files: ViewError<List<FileMetadata>>(_loadFailure)),
        const StorageState(files: ViewLoading<List<FileMetadata>>()),
        StorageState(files: ViewSuccess<List<FileMetadata>>(_files)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 2),
    );
  });
}

final List<FileMetadata> _files = <FileMetadata>[
  FileMetadata(
    id: 'file-1',
    name: 'Demo retainer scan',
    matterRef: 'Demo acquisition review',
    mimeType: 'application/pdf',
    sizeBytes: 245760,
    storagePath: 'org-demo/matter-1/demo-retainer-scan.pdf',
  ),
  FileMetadata(
    id: 'file-2',
    name: 'Demo lease annex',
    matterRef: 'Commercial lease consultation',
    mimeType: 'application/pdf',
    sizeBytes: 184320,
    storagePath: 'org-demo/matter-2/demo-lease-annex.pdf',
  ),
];

final AppError _loadFailure = AppError(
  code: 'files_failed',
  userMessage: 'Could not load files',
);

/// Hand-rolled gateway stub: queue of results (like the matter/discovery
/// stubs), or a Completer for in-flight tests.
class _StubStorageGateway implements StorageGateway {
  _StubStorageGateway({List<Result<List<FileMetadata>>>? results})
    : _queue = results == null
          ? <Result<List<FileMetadata>>>[
              Result<List<FileMetadata>>.success(_files),
            ]
          : List<Result<List<FileMetadata>>>.of(results),
      completer = null;

  _StubStorageGateway.withCompleter()
    : _queue = const <Result<List<FileMetadata>>>[],
      completer = Completer<Result<List<FileMetadata>>>();

  final List<Result<List<FileMetadata>>> _queue;
  final Completer<Result<List<FileMetadata>>>? completer;
  int fetchCalls = 0;

  @override
  Future<Result<List<FileMetadata>>> fetchFiles() {
    fetchCalls += 1;
    if (completer != null) {
      return completer!.future;
    }
    return Future<Result<List<FileMetadata>>>.value(_queue.removeAt(0));
  }
}
