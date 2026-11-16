import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/data/fake_library_gateway.dart';
import 'package:legalhub/features/library/domain/legal_article_detail.dart';
import 'package:legalhub/features/library/presentation/library_article_cubit.dart';
import 'package:legalhub/features/library/presentation/library_article_state.dart';

import '../../support/library_gateway_stub.dart';

void main() {
  late StubLibraryGateway gateway;

  LegalArticleDetail articleAt({String? previous, String? next}) {
    return LegalArticleDetail(
      article: FakeLibraryGateway.syntheticArticles[2],
      documentTitleAr: 'قانون تجريبي للإيجارات (نموذج)',
      documentSample: true,
      articleTotal: 6,
      previousArticleId: previous,
      nextArticleId: next,
    );
  }

  setUp(() {
    gateway = StubLibraryGateway();
  });

  group('LibraryArticleCubit', () {
    blocTest<LibraryArticleCubit, LibraryArticleState>(
      'load emits the article with its neighbours',
      build: () {
        gateway.articleDetail = Success<LegalArticleDetail>(
          articleAt(previous: 'legal-art-1-2', next: 'legal-art-1-4'),
        );
        return LibraryArticleCubit(gateway);
      },
      act: (LibraryArticleCubit cubit) => cubit.load('legal-art-1-3'),
      expect: () => <LibraryArticleState>[
        LibraryArticleState(
          detail: ViewSuccess<LegalArticleDetail>(
            articleAt(previous: 'legal-art-1-2', next: 'legal-art-1-4'),
          ),
        ),
      ],
      verify: (LibraryArticleCubit cubit) {
        expect(gateway.requestedArticleIds, <String>['legal-art-1-3']);
      },
    );

    blocTest<LibraryArticleCubit, LibraryArticleState>(
      'a not-found failure renders the empty arm',
      build: () => LibraryArticleCubit(
        StubLibraryGateway(
          articleDetail: const Failure<LegalArticleDetail>(
            AppError(code: 'legal_article_not_found', userMessage: 'missing'),
          ),
        ),
      ),
      act: (LibraryArticleCubit cubit) => cubit.load('nope'),
      expect: () => <LibraryArticleState>[
        const LibraryArticleState(detail: ViewEmpty<LegalArticleDetail>()),
      ],
    );

    blocTest<LibraryArticleCubit, LibraryArticleState>(
      'openNext loads the neighbour the server reported',
      build: () {
        gateway.articleDetail = Success<LegalArticleDetail>(
          articleAt(previous: 'legal-art-1-2', next: 'legal-art-1-4'),
        );
        return LibraryArticleCubit(gateway);
      },
      act: (LibraryArticleCubit cubit) async {
        await cubit.load('legal-art-1-3');
        await cubit.openNext();
      },
      skip: 1,
      expect: () => <LibraryArticleState>[
        const LibraryArticleState(detail: ViewLoading<LegalArticleDetail>()),
        LibraryArticleState(
          detail: ViewSuccess<LegalArticleDetail>(
            articleAt(previous: 'legal-art-1-2', next: 'legal-art-1-4'),
          ),
        ),
      ],
      verify: (LibraryArticleCubit cubit) {
        expect(gateway.requestedArticleIds, <String>[
          'legal-art-1-3',
          'legal-art-1-4',
        ]);
      },
    );

    blocTest<LibraryArticleCubit, LibraryArticleState>(
      'openPrevious is a no-op on the first article',
      build: () {
        gateway.articleDetail = Success<LegalArticleDetail>(
          articleAt(next: 'legal-art-1-2'),
        );
        return LibraryArticleCubit(gateway);
      },
      act: (LibraryArticleCubit cubit) async {
        await cubit.load('legal-art-1-1');
        await cubit.openPrevious();
      },
      skip: 1,
      expect: () => <LibraryArticleState>[],
      verify: (LibraryArticleCubit cubit) {
        expect(gateway.requestedArticleIds, <String>['legal-art-1-1']);
      },
    );
  });
}
