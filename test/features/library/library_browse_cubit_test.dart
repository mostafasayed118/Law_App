import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/data/fake_library_gateway.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/library_errors.dart';
import 'package:legalhub/features/library/presentation/library_browse_cubit.dart';
import 'package:legalhub/features/library/presentation/library_browse_state.dart';

import '../../support/library_gateway_stub.dart';

void main() {
  late StubLibraryGateway gateway;
  final List<LegalDocument> corpus = FakeLibraryGateway.syntheticDocuments;

  setUp(() {
    gateway = StubLibraryGateway(
      documents: Success<List<LegalDocument>>(corpus),
    );
  });

  group('LibraryBrowseCubit', () {
    blocTest<LibraryBrowseCubit, LibraryBrowseState>(
      'load emits the documents on success',
      build: () => LibraryBrowseCubit(gateway),
      act: (LibraryBrowseCubit cubit) => cubit.load(),
      expect: () => <LibraryBrowseState>[
        LibraryBrowseState(documents: ViewSuccess<List<LegalDocument>>(corpus)),
      ],
    );

    blocTest<LibraryBrowseCubit, LibraryBrowseState>(
      'an empty page is ViewEmpty, not an empty success',
      build: () => LibraryBrowseCubit(
        StubLibraryGateway(
          documents: const Success<List<LegalDocument>>(<LegalDocument>[]),
        ),
      ),
      act: (LibraryBrowseCubit cubit) => cubit.load(),
      expect: () => <LibraryBrowseState>[
        const LibraryBrowseState(documents: ViewEmpty<List<LegalDocument>>()),
      ],
    );

    blocTest<LibraryBrowseCubit, LibraryBrowseState>(
      'a denial keeps the denied arm so the UI does not offer a retry',
      build: () => LibraryBrowseCubit(
        StubLibraryGateway(
          documents: const Failure<List<LegalDocument>>(
            AppError(
              code: LibraryErrors.unavailableCode,
              userMessage: 'nope',
              kind: AppErrorKind.denied,
            ),
          ),
        ),
      ),
      act: (LibraryBrowseCubit cubit) => cubit.load(),
      expect: () => <LibraryBrowseState>[
        const LibraryBrowseState(
          documents: ViewUnauthorized<List<LegalDocument>>(),
        ),
      ],
    );

    blocTest<LibraryBrowseCubit, LibraryBrowseState>(
      'an outage maps to the retryable offline arm',
      build: () => LibraryBrowseCubit(
        StubLibraryGateway(
          documents: const Failure<List<LegalDocument>>(
            AppError(
              code: LibraryErrors.unavailableCode,
              userMessage: 'down',
              kind: AppErrorKind.unavailable,
            ),
          ),
        ),
      ),
      act: (LibraryBrowseCubit cubit) => cubit.load(),
      expect: () => <LibraryBrowseState>[
        const LibraryBrowseState(documents: ViewOffline<List<LegalDocument>>()),
      ],
    );

    blocTest<LibraryBrowseCubit, LibraryBrowseState>(
      'changing the category reloads with the new filter',
      build: () => LibraryBrowseCubit(gateway),
      act: (LibraryBrowseCubit cubit) async {
        await cubit.load();
        await cubit.setCategory(LegalCategory.labor);
      },
      skip: 1,
      expect: () => <LibraryBrowseState>[
        LibraryBrowseState(
          documents: ViewSuccess<List<LegalDocument>>(corpus),
          category: LegalCategory.labor,
        ),
        const LibraryBrowseState(
          documents: ViewLoading<List<LegalDocument>>(),
          category: LegalCategory.labor,
        ),
        LibraryBrowseState(
          documents: ViewSuccess<List<LegalDocument>>(corpus),
          category: LegalCategory.labor,
        ),
      ],
      verify: (LibraryBrowseCubit cubit) {
        expect(gateway.requestedCategories, <LegalCategory?>[
          null,
          LegalCategory.labor,
        ]);
      },
    );

    blocTest<LibraryBrowseCubit, LibraryBrowseState>(
      're-tapping the active chip does not reload',
      build: () => LibraryBrowseCubit(gateway),
      act: (LibraryBrowseCubit cubit) async {
        await cubit.load();
        await cubit.setCategory(null);
      },
      skip: 1,
      expect: () => <LibraryBrowseState>[],
      verify: (LibraryBrowseCubit cubit) {
        expect(gateway.requestedCategories, hasLength(1));
      },
    );

    test('a second load while one is in flight is ignored', () async {
      final LibraryBrowseCubit cubit = LibraryBrowseCubit(gateway);
      addTearDown(cubit.close);

      final Completer<void> gate = Completer<void>();
      gateway.gate = gate;

      final Future<void> first = cubit.load();
      final Future<void> second = cubit.load();
      gate.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(gateway.requestedCategories, hasLength(1));
    });
  });
}
