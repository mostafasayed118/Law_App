import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_bookmark.dart';
import 'package:legalhub/features/library/domain/library_user_data_errors.dart';
import 'package:legalhub/features/library/presentation/library_bookmarks_cubit.dart';
import 'package:legalhub/features/library/presentation/library_bookmarks_state.dart';

import '../../support/library_user_data_stub.dart';

void main() {
  LegalBookmark row(String id) => LegalBookmark(
    id: id,
    articleId: 'art-$id',
    documentId: 'doc-1',
    documentTitleAr: 'عنوان',
    articleNumber: '1',
    articleSample: true,
    documentSample: true,
    createdAt: DateTime.utc(2026, 11, 16),
  );

  group('LibraryBookmarksCubit', () {
    blocTest<LibraryBookmarksCubit, LibraryBookmarksState>(
      'load emits the saved rows',
      build: () => LibraryBookmarksCubit(
        StubLibraryUserDataGateway(
          bookmarks: Success<List<LegalBookmark>>(<LegalBookmark>[
            row('1'),
            row('2'),
          ]),
        ),
      ),
      act: (LibraryBookmarksCubit cubit) => cubit.load(),
      expect: () => <LibraryBookmarksState>[
        LibraryBookmarksState(
          bookmarks: ViewSuccess<List<LegalBookmark>>(<LegalBookmark>[
            row('1'),
            row('2'),
          ]),
        ),
      ],
    );

    blocTest<LibraryBookmarksCubit, LibraryBookmarksState>(
      'no rows is the empty arm, not an empty success',
      build: () => LibraryBookmarksCubit(StubLibraryUserDataGateway()),
      act: (LibraryBookmarksCubit cubit) => cubit.load(),
      expect: () => <LibraryBookmarksState>[
        const LibraryBookmarksState(
          bookmarks: ViewEmpty<List<LegalBookmark>>(),
        ),
      ],
    );

    blocTest<LibraryBookmarksCubit, LibraryBookmarksState>(
      'a denial keeps the unauthorized arm so no retry is offered',
      build: () => LibraryBookmarksCubit(
        StubLibraryUserDataGateway(
          bookmarks: const Failure<List<LegalBookmark>>(
            AppError(
              code: LibraryUserDataErrors.unavailableCode,
              userMessage: 'no',
              kind: AppErrorKind.denied,
            ),
          ),
        ),
      ),
      act: (LibraryBookmarksCubit cubit) => cubit.load(),
      expect: () => <LibraryBookmarksState>[
        const LibraryBookmarksState(
          bookmarks: ViewUnauthorized<List<LegalBookmark>>(),
        ),
      ],
    );
  });
}
