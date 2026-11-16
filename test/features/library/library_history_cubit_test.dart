import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/reading_history_entry.dart';
import 'package:legalhub/features/library/presentation/library_history_cubit.dart';
import 'package:legalhub/features/library/presentation/library_history_state.dart';

import '../../support/library_user_data_stub.dart';

void main() {
  ReadingHistoryEntry row(String id, {int reads = 1}) => ReadingHistoryEntry(
    id: id,
    articleId: 'art-$id',
    documentId: 'doc-1',
    documentTitleAr: 'عنوان',
    articleNumber: '1',
    lastReadAt: DateTime.utc(2026, 11, 16),
    readCount: reads,
    articleSample: true,
    documentSample: true,
  );

  group('LibraryHistoryCubit', () {
    blocTest<LibraryHistoryCubit, LibraryHistoryState>(
      'load emits the recent rows',
      build: () => LibraryHistoryCubit(
        StubLibraryUserDataGateway(
          history: Success<List<ReadingHistoryEntry>>(<ReadingHistoryEntry>[
            row('1'),
            row('2', reads: 4),
          ]),
        ),
      ),
      act: (LibraryHistoryCubit cubit) => cubit.load(),
      expect: () => <LibraryHistoryState>[
        LibraryHistoryState(
          history: ViewSuccess<List<ReadingHistoryEntry>>(<ReadingHistoryEntry>[
            row('1'),
            row('2', reads: 4),
          ]),
        ),
      ],
    );

    blocTest<LibraryHistoryCubit, LibraryHistoryState>(
      'clear empties the list and reports no error',
      build: () => LibraryHistoryCubit(
        StubLibraryUserDataGateway(
          history: Success<List<ReadingHistoryEntry>>(<ReadingHistoryEntry>[
            row('1'),
          ]),
          clearResult: const Success<int>(1),
        ),
      ),
      act: (LibraryHistoryCubit cubit) async {
        await cubit.load();
        await cubit.clear();
      },
      skip: 1,
      expect: () => <LibraryHistoryState>[
        LibraryHistoryState(
          clearing: true,
          history: ViewSuccess<List<ReadingHistoryEntry>>(<ReadingHistoryEntry>[
            row('1'),
          ]),
        ),
        const LibraryHistoryState(
          history: ViewEmpty<List<ReadingHistoryEntry>>(),
        ),
      ],
    );

    blocTest<LibraryHistoryCubit, LibraryHistoryState>(
      'a failed clear keeps the rows and raises the error',
      build: () => LibraryHistoryCubit(
        StubLibraryUserDataGateway(
          history: Success<List<ReadingHistoryEntry>>(<ReadingHistoryEntry>[
            row('1'),
          ]),
          clearResult: const Failure<int>(
            AppError(
              code: 'x',
              userMessage: 'down',
              kind: AppErrorKind.unavailable,
            ),
          ),
        ),
      ),
      act: (LibraryHistoryCubit cubit) async {
        await cubit.load();
        await cubit.clear();
      },
      skip: 1,
      expect: () => <LibraryHistoryState>[
        LibraryHistoryState(
          clearing: true,
          history: ViewSuccess<List<ReadingHistoryEntry>>(<ReadingHistoryEntry>[
            row('1'),
          ]),
        ),
        LibraryHistoryState(
          clearing: false,
          history: ViewSuccess<List<ReadingHistoryEntry>>(<ReadingHistoryEntry>[
            row('1'),
          ]),
          lastError: const AppError(
            code: 'x',
            userMessage: 'down',
            kind: AppErrorKind.unavailable,
          ),
        ),
      ],
    );

    test('a second clear while one is in flight is ignored', () async {
      final StubLibraryUserDataGateway gateway = StubLibraryUserDataGateway();
      final LibraryHistoryCubit cubit = LibraryHistoryCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load();

      final Future<void> first = cubit.clear();
      final Future<void> second = cubit.clear();
      await Future.wait(<Future<void>>[first, second]);

      expect(gateway.clearCalls, 1);
    });
  });
}
