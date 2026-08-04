import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/documents/presentation/document_cubit.dart';
import 'package:legalhub/features/documents/presentation/document_state.dart';

void main() {
  late _StubDocumentGateway gateway;

  setUp(() {
    gateway = _StubDocumentGateway();
  });

  group('DocumentCubit (Phase 8 slice 8.1)', () {
    test('starts loading with no rows', () {
      final DocumentCubit cubit = DocumentCubit(gateway);
      addTearDown(cubit.close);

      expect(cubit.state.documents, const ViewLoading<List<Document>>());
    });

    blocTest<DocumentCubit, DocumentState>(
      'load resolves to the synthetic metadata list (AC-1)',
      build: () => DocumentCubit(gateway),
      act: (DocumentCubit cubit) => cubit.load(),
      expect: () => <DocumentState>[
        DocumentState(documents: ViewSuccess<List<Document>>(_documents)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<DocumentCubit, DocumentState>(
      'load maps an empty list to ViewEmpty',
      setUp: () => gateway = _StubDocumentGateway(
        results: <Result<List<Document>>>[
          Result<List<Document>>.success(const <Document>[]),
        ],
      ),
      build: () => DocumentCubit(gateway),
      act: (DocumentCubit cubit) => cubit.load(),
      expect: () => <DocumentState>[
        const DocumentState(documents: ViewEmpty<List<Document>>()),
      ],
    );

    blocTest<DocumentCubit, DocumentState>(
      'load maps a failure to ViewError',
      setUp: () => gateway = _StubDocumentGateway(
        results: <Result<List<Document>>>[
          Result<List<Document>>.failure(_loadFailure),
        ],
      ),
      build: () => DocumentCubit(gateway),
      act: (DocumentCubit cubit) => cubit.load(),
      expect: () => <DocumentState>[
        DocumentState(documents: ViewError<List<Document>>(_loadFailure)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<DocumentCubit, DocumentState>(
      'duplicate load while in flight is ignored',
      setUp: () => gateway = _StubDocumentGateway.withCompleter(),
      build: () => DocumentCubit(gateway),
      act: (DocumentCubit cubit) async {
        final Future<void> first = cubit.load();
        await cubit.load();
        gateway.completer!.complete(Result<List<Document>>.success(_documents));
        await first;
      },
      expect: () => <DocumentState>[
        DocumentState(documents: ViewSuccess<List<Document>>(_documents)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<DocumentCubit, DocumentState>(
      'load after an error retries into a fresh success (AC-3)',
      setUp: () => gateway = _StubDocumentGateway(
        results: <Result<List<Document>>>[
          Result<List<Document>>.failure(_loadFailure),
          Result<List<Document>>.success(_documents),
        ],
      ),
      build: () => DocumentCubit(gateway),
      act: (DocumentCubit cubit) async {
        await cubit.load();
        await cubit.load();
      },
      expect: () => <DocumentState>[
        DocumentState(documents: ViewError<List<Document>>(_loadFailure)),
        const DocumentState(documents: ViewLoading<List<Document>>()),
        DocumentState(documents: ViewSuccess<List<Document>>(_documents)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 2),
    );
  });
}

final List<Document> _documents = <Document>[
  Document(
    id: 'doc-1',
    title: 'Demo engagement letter',
    matterRef: 'Demo acquisition review',
    type: DocumentType.contract,
    createdAt: DateTime.utc(2026, 7, 10),
  ),
  Document(
    id: 'doc-2',
    title: 'Sample matter brief — demo',
    matterRef: 'Commercial lease consultation',
    type: DocumentType.brief,
    createdAt: DateTime.utc(2026, 7, 15),
  ),
];

final AppError _loadFailure = AppError(
  code: 'documents_failed',
  userMessage: 'Could not load documents',
);

/// Hand-rolled gateway stub: queue of results (like the matter/discovery
/// stubs), or a Completer for in-flight tests.
class _StubDocumentGateway implements DocumentGateway {
  _StubDocumentGateway({List<Result<List<Document>>>? results})
    : _queue = results == null
          ? <Result<List<Document>>>[Result<List<Document>>.success(_documents)]
          : List<Result<List<Document>>>.of(results),
      completer = null;

  _StubDocumentGateway.withCompleter()
    : _queue = const <Result<List<Document>>>[],
      completer = Completer<Result<List<Document>>>();

  final List<Result<List<Document>>> _queue;
  final Completer<Result<List<Document>>>? completer;
  int fetchCalls = 0;

  @override
  Future<Result<List<Document>>> fetchDocuments() {
    fetchCalls += 1;
    if (completer != null) {
      return completer!.future;
    }
    return Future<Result<List<Document>>>.value(_queue.removeAt(0));
  }
}
