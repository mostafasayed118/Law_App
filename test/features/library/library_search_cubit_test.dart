import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/legal_search_hit.dart';
import 'package:legalhub/features/library/domain/library_errors.dart';
import 'package:legalhub/features/library/presentation/library_search_cubit.dart';
import 'package:legalhub/features/library/presentation/library_search_state.dart';

import '../../support/library_gateway_stub.dart';

/// The debounce is 300 ms; every wait below sits past it so the assertions are
/// about behaviour, not about racing the timer.
const Duration _pastDebounce = Duration(milliseconds: 400);

void main() {
  late StubLibraryGateway gateway;

  const LegalSearchHit hit = LegalSearchHit(
    articleId: 'legal-art-1-1',
    documentId: 'legal-doc-1',
    documentTitleAr: 'قانون تجريبي للإيجارات (نموذج)',
    category: LegalCategory.civil,
    status: LegalStatus.inForce,
    articleNumber: '1',
    snippet: 'نص [[الايجار]] هنا',
    articleSample: true,
    documentSample: true,
  );

  setUp(() {
    gateway = StubLibraryGateway(
      hits: const Success<List<LegalSearchHit>>(<LegalSearchHit>[hit]),
    );
  });

  group('LibrarySearchCubit', () {
    test('the initial state is the no-query arm, not a spinner', () {
      final LibrarySearchCubit cubit = LibrarySearchCubit(gateway);
      addTearDown(cubit.close);

      expect(cubit.state.results, isA<ViewEmpty<List<LegalSearchHit>>>());
      expect(cubit.state.hasQuery, isFalse);
    });

    test('an empty query never reaches the gateway', () async {
      final LibrarySearchCubit cubit = LibrarySearchCubit(gateway);
      addTearDown(cubit.close);

      cubit.updateQuery('   ');
      await Future<void>.delayed(_pastDebounce);

      expect(gateway.requestedQueries, isEmpty);
      expect(cubit.state.results, isA<ViewEmpty<List<LegalSearchHit>>>());
    });

    blocTest<LibrarySearchCubit, LibrarySearchState>(
      'typing schedules a debounced search that emits results',
      build: () => LibrarySearchCubit(gateway),
      act: (LibrarySearchCubit cubit) => cubit.updateQuery('ايجار'),
      wait: _pastDebounce,
      expect: () => <LibrarySearchState>[
        const LibrarySearchState(query: 'ايجار'),
        const LibrarySearchState(
          query: 'ايجار',
          results: ViewLoading<List<LegalSearchHit>>(),
        ),
        const LibrarySearchState(
          query: 'ايجار',
          results: ViewSuccess<List<LegalSearchHit>>(<LegalSearchHit>[hit]),
        ),
      ],
    );

    blocTest<LibrarySearchCubit, LibrarySearchState>(
      'submit runs immediately without waiting for the debounce',
      build: () => LibrarySearchCubit(gateway),
      act: (LibrarySearchCubit cubit) async {
        cubit.updateQuery('ايجار');
        await cubit.submit();
      },
      expect: () => <LibrarySearchState>[
        const LibrarySearchState(query: 'ايجار'),
        const LibrarySearchState(
          query: 'ايجار',
          results: ViewLoading<List<LegalSearchHit>>(),
        ),
        const LibrarySearchState(
          query: 'ايجار',
          results: ViewSuccess<List<LegalSearchHit>>(<LegalSearchHit>[hit]),
        ),
      ],
      verify: (LibrarySearchCubit cubit) {
        expect(gateway.requestedQueries, <String>['ايجار']);
      },
    );

    blocTest<LibrarySearchCubit, LibrarySearchState>(
      'no hits is the empty arm, not an empty success',
      build: () => LibrarySearchCubit(
        StubLibraryGateway(
          hits: const Success<List<LegalSearchHit>>(<LegalSearchHit>[]),
        ),
      ),
      act: (LibrarySearchCubit cubit) async {
        cubit.updateQuery('nothing');
        await cubit.submit();
      },
      skip: 2,
      expect: () => <LibrarySearchState>[
        const LibrarySearchState(
          query: 'nothing',
          results: ViewEmpty<List<LegalSearchHit>>(),
        ),
      ],
    );

    blocTest<LibrarySearchCubit, LibrarySearchState>(
      'a failure keeps its typed arm',
      build: () => LibrarySearchCubit(
        StubLibraryGateway(
          hits: const Failure<List<LegalSearchHit>>(
            AppError(
              code: LibraryErrors.unavailableCode,
              userMessage: 'down',
              kind: AppErrorKind.unavailable,
            ),
          ),
        ),
      ),
      act: (LibrarySearchCubit cubit) async {
        cubit.updateQuery('ايجار');
        await cubit.submit();
      },
      skip: 2,
      expect: () => <LibrarySearchState>[
        const LibrarySearchState(
          query: 'ايجار',
          results: ViewOffline<List<LegalSearchHit>>(),
        ),
      ],
    );

    blocTest<LibrarySearchCubit, LibrarySearchState>(
      'clearing the field returns to the no-query arm without a round trip',
      build: () => LibrarySearchCubit(gateway),
      act: (LibrarySearchCubit cubit) async {
        cubit.updateQuery('ايجار');
        await cubit.submit();
        cubit.updateQuery('');
      },
      skip: 3,
      expect: () => <LibrarySearchState>[
        // Clearing emits the field change, then the empty arm in the same
        // synchronous turn; only the second value ever reaches a frame.
        const LibrarySearchState(
          results: ViewSuccess<List<LegalSearchHit>>(<LegalSearchHit>[hit]),
        ),
        const LibrarySearchState(results: ViewEmpty<List<LegalSearchHit>>()),
      ],
      verify: (LibrarySearchCubit cubit) {
        expect(gateway.requestedQueries, hasLength(1));
      },
    );

    blocTest<LibrarySearchCubit, LibrarySearchState>(
      'the category filter travels with the query',
      build: () => LibrarySearchCubit(gateway),
      act: (LibrarySearchCubit cubit) async {
        cubit.updateQuery('ايجار');
        await cubit.setCategory(LegalCategory.labor);
      },
      skip: 2,
      expect: () => <LibrarySearchState>[
        const LibrarySearchState(
          query: 'ايجار',
          category: LegalCategory.labor,
          results: ViewLoading<List<LegalSearchHit>>(),
        ),
        const LibrarySearchState(
          query: 'ايجار',
          category: LegalCategory.labor,
          results: ViewSuccess<List<LegalSearchHit>>(<LegalSearchHit>[hit]),
        ),
      ],
      verify: (LibrarySearchCubit cubit) {
        expect(gateway.requestedSearchCategories, <LegalCategory?>[
          LegalCategory.labor,
        ]);
      },
    );
  });
}
