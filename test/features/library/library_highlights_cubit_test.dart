import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/presentation/library_highlights_cubit.dart';
import 'package:legalhub/features/library/presentation/library_highlights_state.dart';

import '../../support/library_user_data_stub.dart';

void main() {
  LegalHighlight row(String id, {bool stale = false}) => LegalHighlight(
    id: id,
    articleId: 'art-1',
    documentId: 'doc-1',
    documentTitleAr: 'عنوان',
    articleNumber: '1',
    startOffset: 0,
    endOffset: 4,
    quote: 'نص',
    color: HighlightColorSlot.yellow,
    isStale: stale,
    articleSample: true,
    documentSample: true,
    createdAt: DateTime.utc(2026, 11, 16),
  );

  group('LibraryHighlightsCubit', () {
    blocTest<LibraryHighlightsCubit, LibraryHighlightsState>(
      'load keeps stale rows in the list rather than hiding them',
      build: () => LibraryHighlightsCubit(
        StubLibraryUserDataGateway(
          highlights: Success<List<LegalHighlight>>(<LegalHighlight>[
            row('1'),
            row('2', stale: true),
          ]),
        ),
      ),
      act: (LibraryHighlightsCubit cubit) => cubit.load(),
      expect: () => <LibraryHighlightsState>[
        LibraryHighlightsState(
          highlights: ViewSuccess<List<LegalHighlight>>(<LegalHighlight>[
            row('1'),
            row('2', stale: true),
          ]),
        ),
      ],
    );

    blocTest<LibraryHighlightsCubit, LibraryHighlightsState>(
      'no rows is the empty arm',
      build: () => LibraryHighlightsCubit(StubLibraryUserDataGateway()),
      act: (LibraryHighlightsCubit cubit) => cubit.load(),
      expect: () => <LibraryHighlightsState>[
        const LibraryHighlightsState(
          highlights: ViewEmpty<List<LegalHighlight>>(),
        ),
      ],
    );

    blocTest<LibraryHighlightsCubit, LibraryHighlightsState>(
      'an outage maps to the retryable arm',
      build: () => LibraryHighlightsCubit(
        StubLibraryUserDataGateway(
          highlights: const Failure<List<LegalHighlight>>(
            AppError(
              code: 'x',
              userMessage: 'down',
              kind: AppErrorKind.unavailable,
            ),
          ),
        ),
      ),
      act: (LibraryHighlightsCubit cubit) => cubit.load(),
      expect: () => <LibraryHighlightsState>[
        const LibraryHighlightsState(
          highlights: ViewOffline<List<LegalHighlight>>(),
        ),
      ],
    );
  });
}
