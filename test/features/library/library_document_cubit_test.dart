import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/data/fake_library_gateway.dart';
import 'package:legalhub/features/library/domain/legal_document_detail.dart';
import 'package:legalhub/features/library/presentation/library_document_cubit.dart';
import 'package:legalhub/features/library/presentation/library_document_state.dart';

import '../../support/library_gateway_stub.dart';

void main() {
  late StubLibraryGateway gateway;
  late LegalDocumentDetail detail;

  setUp(() {
    detail = LegalDocumentDetail(
      document: FakeLibraryGateway.syntheticDocuments.first,
      articles: FakeLibraryGateway.syntheticArticles
          .where((article) => article.documentId == 'legal-doc-1')
          .toList(growable: false),
      articleTotal: 6,
    );
    gateway = StubLibraryGateway(
      documentDetail: Success<LegalDocumentDetail>(detail),
    );
  });

  group('LibraryDocumentCubit', () {
    blocTest<LibraryDocumentCubit, LibraryDocumentState>(
      'load emits the header and its articles',
      build: () => LibraryDocumentCubit(gateway),
      act: (LibraryDocumentCubit cubit) => cubit.load('legal-doc-1'),
      expect: () => <LibraryDocumentState>[
        LibraryDocumentState(detail: ViewSuccess<LegalDocumentDetail>(detail)),
      ],
      verify: (LibraryDocumentCubit cubit) {
        expect(gateway.requestedDocumentIds, <String>['legal-doc-1']);
      },
    );

    blocTest<LibraryDocumentCubit, LibraryDocumentState>(
      'a not-found failure renders the empty arm, not an error with a retry',
      build: () => LibraryDocumentCubit(
        StubLibraryGateway(
          documentDetail: const Failure<LegalDocumentDetail>(
            AppError(code: 'legal_document_not_found', userMessage: 'missing'),
          ),
        ),
      ),
      act: (LibraryDocumentCubit cubit) => cubit.load('nope'),
      expect: () => <LibraryDocumentState>[
        const LibraryDocumentState(detail: ViewEmpty<LegalDocumentDetail>()),
      ],
    );

    blocTest<LibraryDocumentCubit, LibraryDocumentState>(
      'an outage keeps the retryable offline arm',
      build: () => LibraryDocumentCubit(
        StubLibraryGateway(
          documentDetail: const Failure<LegalDocumentDetail>(
            AppError(
              code: 'legal_library_unavailable',
              userMessage: 'down',
              kind: AppErrorKind.unavailable,
            ),
          ),
        ),
      ),
      act: (LibraryDocumentCubit cubit) => cubit.load('legal-doc-1'),
      expect: () => <LibraryDocumentState>[
        const LibraryDocumentState(detail: ViewOffline<LegalDocumentDetail>()),
      ],
    );

    test('a second load while one is in flight is ignored', () async {
      final LibraryDocumentCubit cubit = LibraryDocumentCubit(gateway);
      addTearDown(cubit.close);

      final Completer<void> gate = Completer<void>();
      gateway.gate = gate;

      final Future<void> first = cubit.load('legal-doc-1');
      final Future<void> second = cubit.load('legal-doc-2');
      gate.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(gateway.requestedDocumentIds, <String>['legal-doc-1']);
    });
  });
}
