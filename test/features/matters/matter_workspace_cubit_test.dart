import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/billing/domain/billing_gateway.dart';
import 'package:legalhub/features/billing/domain/invoice.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/matters/presentation/matter_workspace_cubit.dart';
import 'package:legalhub/features/matters/presentation/matter_workspace_state.dart';
import 'package:legalhub/features/messaging/domain/message.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_realtime_event.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'package:legalhub/features/storage/domain/file_metadata.dart';
import 'package:legalhub/features/storage/domain/storage_gateway.dart';

void main() {
  group('MatterWorkspaceCubit (audit: matters god-feature)', () {
    test('starts with all four lists loading', () {
      final MatterWorkspaceCubit cubit = MatterWorkspaceCubit(
        _StubMessageGateway(),
        _StubDocumentGateway(),
        _StubBillingGateway(),
        _StubStorageGateway(),
      );
      addTearDown(cubit.close);

      expect(cubit.state.threads, const ViewLoading<List<MessageThread>>());
      expect(cubit.state.documents, const ViewLoading<List<Document>>());
      expect(cubit.state.invoices, const ViewLoading<List<Invoice>>());
      expect(cubit.state.files, const ViewLoading<List<FileMetadata>>());
    });

    blocTest<MatterWorkspaceCubit, MatterWorkspaceState>(
      'load resolves all four lists in parallel',
      build: () => MatterWorkspaceCubit(
        _StubMessageGateway(),
        _StubDocumentGateway(),
        _StubBillingGateway(),
        _StubStorageGateway(),
      ),
      act: (MatterWorkspaceCubit cubit) => cubit.load(),
      // Each per-list loader emits as its gateway resolves (started in
      // order, so the sequence is deterministic with immediate stubs);
      // the final state carries all four lists.
      expect: () => <MatterWorkspaceState>[
        MatterWorkspaceState(
          threads: ViewSuccess<List<MessageThread>>(_threads),
        ),
        MatterWorkspaceState(
          threads: ViewSuccess<List<MessageThread>>(_threads),
          documents: ViewSuccess<List<Document>>(_documents),
        ),
        MatterWorkspaceState(
          threads: ViewSuccess<List<MessageThread>>(_threads),
          documents: ViewSuccess<List<Document>>(_documents),
          invoices: ViewSuccess<List<Invoice>>(_invoices),
        ),
        MatterWorkspaceState(
          threads: ViewSuccess<List<MessageThread>>(_threads),
          documents: ViewSuccess<List<Document>>(_documents),
          invoices: ViewSuccess<List<Invoice>>(_invoices),
          files: ViewSuccess<List<FileMetadata>>(_files),
        ),
      ],
    );

    blocTest<MatterWorkspaceCubit, MatterWorkspaceState>(
      'loadThreads reloads only the threads slice',
      build: () => MatterWorkspaceCubit(
        _StubMessageGateway(),
        _StubDocumentGateway(),
        _StubBillingGateway(),
        _StubStorageGateway(),
      ),
      act: (MatterWorkspaceCubit cubit) => cubit.loadThreads(),
      expect: () => <MatterWorkspaceState>[
        MatterWorkspaceState(
          threads: ViewSuccess<List<MessageThread>>(_threads),
        ),
      ],
    );

    blocTest<MatterWorkspaceCubit, MatterWorkspaceState>(
      'a failed list maps to ViewError while siblings stay loading',
      build: () => MatterWorkspaceCubit(
        _StubMessageGateway(
          result: Result<List<MessageThread>>.failure(_loadFailure),
        ),
        _StubDocumentGateway(),
        _StubBillingGateway(),
        _StubStorageGateway(),
      ),
      act: (MatterWorkspaceCubit cubit) => cubit.load(),
      expect: () => <MatterWorkspaceState>[
        MatterWorkspaceState(
          threads: ViewError<List<MessageThread>>(_loadFailure),
        ),
        MatterWorkspaceState(
          threads: ViewError<List<MessageThread>>(_loadFailure),
          documents: ViewSuccess<List<Document>>(_documents),
        ),
        MatterWorkspaceState(
          threads: ViewError<List<MessageThread>>(_loadFailure),
          documents: ViewSuccess<List<Document>>(_documents),
          invoices: ViewSuccess<List<Invoice>>(_invoices),
        ),
        MatterWorkspaceState(
          threads: ViewError<List<MessageThread>>(_loadFailure),
          documents: ViewSuccess<List<Document>>(_documents),
          invoices: ViewSuccess<List<Invoice>>(_invoices),
          files: ViewSuccess<List<FileMetadata>>(_files),
        ),
      ],
    );

    blocTest<MatterWorkspaceCubit, MatterWorkspaceState>(
      'an empty list maps to ViewEmpty',
      build: () => MatterWorkspaceCubit(
        _StubMessageGateway(
          result: Result<List<MessageThread>>.success(const <MessageThread>[]),
        ),
        _StubDocumentGateway(),
        _StubBillingGateway(),
        _StubStorageGateway(),
      ),
      act: (MatterWorkspaceCubit cubit) => cubit.loadThreads(),
      expect: () => <MatterWorkspaceState>[
        const MatterWorkspaceState(threads: ViewEmpty<List<MessageThread>>()),
      ],
    );

    blocTest<MatterWorkspaceCubit, MatterWorkspaceState>(
      'a retry re-enters the loading state before the re-read',
      build: () => MatterWorkspaceCubit(
        _StubMessageGateway(
          results: <Result<List<MessageThread>>>[
            Result<List<MessageThread>>.failure(_loadFailure),
            Result<List<MessageThread>>.success(_threads),
          ],
        ),
        _StubDocumentGateway(),
        _StubBillingGateway(),
        _StubStorageGateway(),
      ),
      act: (MatterWorkspaceCubit cubit) async {
        await cubit.loadThreads();
        await cubit.loadThreads();
      },
      expect: () => <MatterWorkspaceState>[
        MatterWorkspaceState(
          threads: ViewError<List<MessageThread>>(_loadFailure),
        ),
        const MatterWorkspaceState(threads: ViewLoading<List<MessageThread>>()),
        MatterWorkspaceState(
          threads: ViewSuccess<List<MessageThread>>(_threads),
        ),
      ],
    );
  });
}

const AppError _loadFailure = AppError(
  code: 'workspace_load_failed',
  userMessage: 'Unable to load.',
);

final List<MessageThread> _threads = <MessageThread>[
  MessageThread(
    id: 't1',
    title: 'Thread',
    matterRef: 'Matter',
    participants: const <String>['A'],
    lastActivityAt: DateTime.utc(2026, 1, 1),
    messageCount: 1,
  ),
];

final List<Document> _documents = <Document>[
  Document(
    id: 'd1',
    title: 'Doc',
    matterRef: 'Matter',
    type: DocumentType.contract,
    createdAt: DateTime.utc(2026, 1, 1),
  ),
];

final List<Invoice> _invoices = <Invoice>[
  Invoice(
    id: 'i1',
    matterRef: 'Matter',
    invoiceNumber: 'INV-1',
    amountCents: 100,
    currency: 'USD',
    status: InvoiceStatus.issued,
    issuedAt: DateTime.utc(2026, 1, 1),
    dueAt: DateTime.utc(2026, 2, 1),
  ),
];

final List<FileMetadata> _files = <FileMetadata>[
  const FileMetadata(
    id: 'f1',
    name: 'file.pdf',
    matterRef: 'Matter',
    mimeType: 'application/pdf',
    sizeBytes: 10,
    storagePath: 'matter/file.pdf',
  ),
];

class _StubMessageGateway implements MessageGateway {
  _StubMessageGateway({
    Result<List<MessageThread>>? result,
    List<Result<List<MessageThread>>>? results,
  }) : _results =
           results ??
           <Result<List<MessageThread>>>[
             result ?? Result<List<MessageThread>>.success(_threads),
           ];

  final List<Result<List<MessageThread>>> _results;
  int _cursor = 0;

  Result<List<MessageThread>> get _next {
    final Result<List<MessageThread>> result = _results[_cursor];
    if (_cursor < _results.length - 1) {
      _cursor++;
    }
    return result;
  }

  @override
  Future<Result<List<MessageThread>>> fetchThreads() async => _next;

  @override
  Future<Result<List<MessageThread>>> searchThreads(
    String query, {
    int limit = 30,
  }) async => _next;

  @override
  Future<Result<List<Message>>> fetchMessages(String threadId) async =>
      const Result<List<Message>>.success(<Message>[]);

  @override
  Future<Result<Message>> sendMessage(
    String threadId,
    String body, {
    String? authorDisplayName,
  }) async => Result<Message>.failure(_loadFailure);

  @override
  Stream<MessageRealtimeEvent> watchMessages(String threadId) =>
      const Stream<MessageRealtimeEvent>.empty();
}

class _StubDocumentGateway implements DocumentGateway {
  @override
  Future<Result<List<Document>>> fetchDocuments() async =>
      Result<List<Document>>.success(_documents);

  @override
  Future<Result<List<Document>>> searchDocuments(
    String query, {
    int limit = 30,
  }) => fetchDocuments();
}

class _StubBillingGateway implements BillingGateway {
  @override
  Future<Result<List<Invoice>>> fetchInvoices() async =>
      Result<List<Invoice>>.success(_invoices);
}

class _StubStorageGateway implements StorageGateway {
  @override
  Future<Result<List<FileMetadata>>> fetchFiles() async =>
      Result<List<FileMetadata>>.success(_files);

  @override
  Future<Result<FileMetadata>> uploadFile({
    required String matterId,
    required String name,
    required String mimeType,
    required int sizeBytes,
    required Uint8List bytes,
  }) async => Result<FileMetadata>.failure(_loadFailure);

  @override
  Future<Result<Uri>> createDownloadUrl(
    FileMetadata file, {
    Duration ttl = const Duration(seconds: 60),
  }) async => Result<Uri>.failure(_loadFailure);
}
