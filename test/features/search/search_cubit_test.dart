import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_gateway.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/messaging/domain/message.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'package:legalhub/features/search/domain/search_results.dart';
import 'package:legalhub/features/search/presentation/search_cubit.dart';
import 'package:legalhub/features/search/presentation/search_state.dart';

void main() {
  late _StubMatterGateway matters;
  late _StubDocumentGateway documents;
  late _StubMessageGateway threads;
  late _StubAttorneyGateway attorneys;

  setUp(() {
    matters = _StubMatterGateway();
    documents = _StubDocumentGateway();
    threads = _StubMessageGateway();
    attorneys = _StubAttorneyGateway();
  });

  SearchCubit build() => SearchCubit(matters, documents, threads, attorneys);

  group('SearchCubit (Phase 11 slice 11.0)', () {
    test('starts idle: loading results with no query', () {
      final SearchCubit cubit = build();
      addTearDown(cubit.close);

      expect(cubit.state.results, const ViewLoading<SearchResults>());
      expect(cubit.state.query, isEmpty);
      expect(cubit.state.isNoQuery, isTrue);
    });

    blocTest<SearchCubit, SearchState>(
      'blank query emits the no-query state without touching any gateway '
      '(AC-1 empty query)',
      build: build,
      act: (SearchCubit cubit) => cubit.search('   '),
      expect: () => <SearchState>[
        const SearchState(query: '   '),
        const SearchState(query: '   ', results: ViewEmpty<SearchResults>()),
      ],
      verify: (_) {
        expect(matters.calls, 0);
        expect(documents.calls, 0);
        expect(threads.calls, 0);
        expect(attorneys.calls, 0);
      },
    );

    blocTest<SearchCubit, SearchState>(
      'query groups the D-S1 matching subsets by kind (AC-1 query)',
      build: build,
      act: (SearchCubit cubit) => cubit.search('Demo'),
      expect: () => <SearchState>[
        const SearchState(query: 'Demo'),
        SearchState(
          query: 'Demo',
          results: ViewSuccess<SearchResults>(
            SearchResults(
              matters: <Matter>[_m1],
              documents: <Document>[_d1, _d2],
              threads: <MessageThread>[_t1, _t2],
              attorneys: <Attorney>[],
            ),
          ),
        ),
      ],
      verify: (_) {
        expect(matters.calls, 1);
        expect(documents.calls, 1);
        expect(threads.calls, 1);
        expect(attorneys.calls, 1);
      },
    );

    blocTest<SearchCubit, SearchState>(
      'matching is case-insensitive (AC-1)',
      build: build,
      act: (SearchCubit cubit) => cubit.search('DEMO'),
      expect: () => <SearchState>[
        const SearchState(query: 'DEMO'),
        SearchState(
          query: 'DEMO',
          results: ViewSuccess<SearchResults>(
            SearchResults(
              matters: <Matter>[_m1],
              documents: <Document>[_d1, _d2],
              threads: <MessageThread>[_t1, _t2],
              attorneys: <Attorney>[],
            ),
          ),
        ),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'practice-area token matches matters and attorneys (D-S1 field set)',
      build: build,
      act: (SearchCubit cubit) => cubit.search('corporate'),
      expect: () => <SearchState>[
        const SearchState(query: 'corporate'),
        SearchState(
          query: 'corporate',
          results: ViewSuccess<SearchResults>(
            SearchResults(
              matters: <Matter>[_m1],
              documents: <Document>[],
              threads: <MessageThread>[],
              attorneys: <Attorney>[_a1],
            ),
          ),
        ),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'document type token matches documents (D-S1 field set)',
      build: build,
      act: (SearchCubit cubit) => cubit.search('contract'),
      expect: () => <SearchState>[
        const SearchState(query: 'contract'),
        SearchState(
          query: 'contract',
          results: ViewSuccess<SearchResults>(
            SearchResults(
              matters: <Matter>[],
              documents: <Document>[_d1],
              threads: <MessageThread>[],
              attorneys: <Attorney>[],
            ),
          ),
        ),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'matter status token matches matters (D-S1 field set)',
      build: build,
      act: (SearchCubit cubit) => cubit.search('open'),
      expect: () => <SearchState>[
        const SearchState(query: 'open'),
        SearchState(
          query: 'open',
          results: ViewSuccess<SearchResults>(
            SearchResults(
              matters: <Matter>[_m2],
              documents: <Document>[],
              threads: <MessageThread>[],
              attorneys: <Attorney>[],
            ),
          ),
        ),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'matterRef matches documents and threads (D-S1 field set)',
      build: build,
      act: (SearchCubit cubit) => cubit.search('Demo acquisition'),
      expect: () => <SearchState>[
        const SearchState(query: 'Demo acquisition'),
        SearchState(
          query: 'Demo acquisition',
          results: ViewSuccess<SearchResults>(
            SearchResults(
              matters: <Matter>[_m1],
              documents: <Document>[_d1],
              threads: <MessageThread>[_t1],
              attorneys: <Attorney>[],
            ),
          ),
        ),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'participants match threads and names match attorneys; the matter '
      'assigned attorney name is NOT a match field (D-S1 field set, no '
      'scope creep)',
      build: build,
      act: (SearchCubit cubit) => cubit.search('Layla'),
      expect: () => <SearchState>[
        const SearchState(query: 'Layla'),
        SearchState(
          query: 'Layla',
          results: ViewSuccess<SearchResults>(
            SearchResults(
              matters: <Matter>[],
              documents: <Document>[],
              threads: <MessageThread>[_t1],
              attorneys: <Attorney>[_a1],
            ),
          ),
        ),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'no match in any group emits ViewEmpty (AC-1 no match)',
      build: build,
      act: (SearchCubit cubit) => cubit.search('zzz'),
      expect: () => <SearchState>[
        const SearchState(query: 'zzz'),
        const SearchState(query: 'zzz', results: ViewEmpty<SearchResults>()),
      ],
      verify: (_) {
        expect(matters.calls, 1);
        expect(documents.calls, 1);
        expect(threads.calls, 1);
        expect(attorneys.calls, 1);
      },
    );

    group('any single gateway failure maps to ViewError', () {
      for (final _GatewayKind kind in _GatewayKind.values) {
        blocTest<SearchCubit, SearchState>(
          '${kind.name} fails',
          setUp: () {
            switch (kind) {
              case _GatewayKind.matters:
                matters = _StubMatterGateway(
                  results: <Result<List<Matter>>>[
                    Result<List<Matter>>.failure(_loadFailure),
                  ],
                );
              case _GatewayKind.documents:
                documents = _StubDocumentGateway(<Result<List<Document>>>[
                  Result<List<Document>>.failure(_loadFailure),
                ]);
              case _GatewayKind.threads:
                threads = _StubMessageGateway(<Result<List<MessageThread>>>[
                  Result<List<MessageThread>>.failure(_loadFailure),
                ]);
              case _GatewayKind.attorneys:
                attorneys = _StubAttorneyGateway(<Result<List<Attorney>>>[
                  Result<List<Attorney>>.failure(_loadFailure),
                ]);
            }
          },
          build: build,
          act: (SearchCubit cubit) => cubit.search('Demo'),
          expect: () => <SearchState>[
            const SearchState(query: 'Demo'),
            SearchState(
              query: 'Demo',
              results: ViewError<SearchResults>(_loadFailure),
            ),
          ],
        );
      }
    });

    blocTest<SearchCubit, SearchState>(
      'a stale in-flight search cannot overwrite a newer one (latest wins)',
      setUp: () {
        matters = _StubMatterGateway.withCompleter();
        // The second matters call resolves; the stale first call stays
        // pending until the test completes it.
        matters.results.add(Result<List<Matter>>.success(_matters));
        documents = _StubDocumentGateway(<Result<List<Document>>>[
          Result<List<Document>>.success(_documents),
          Result<List<Document>>.success(_documents),
        ]);
        threads = _StubMessageGateway(<Result<List<MessageThread>>>[
          Result<List<MessageThread>>.success(_threads),
          Result<List<MessageThread>>.success(_threads),
        ]);
        attorneys = _StubAttorneyGateway(<Result<List<Attorney>>>[
          Result<List<Attorney>>.success(_attorneys),
          Result<List<Attorney>>.success(_attorneys),
        ]);
      },
      build: build,
      act: (SearchCubit cubit) async {
        final Future<void> first = cubit.search('first');
        await cubit.search('Demo');
        // The stale 'first' search completes only now — with a failure — and
        // must be discarded by the request token.
        matters.completer!.complete(Result<List<Matter>>.failure(_loadFailure));
        await first;
      },
      expect: () => <SearchState>[
        const SearchState(query: 'first'),
        // 'Demo' loads (results were idle, so no loading frame is needed),
        // completes first, and its results win over the stale 'first'.
        const SearchState(query: 'Demo'),
        SearchState(
          query: 'Demo',
          results: ViewSuccess<SearchResults>(
            SearchResults(
              matters: <Matter>[_m1],
              documents: <Document>[_d1, _d2],
              threads: <MessageThread>[_t1, _t2],
              attorneys: <Attorney>[],
            ),
          ),
        ),
      ],
      verify: (_) {
        expect(matters.calls, 2);
        expect(documents.calls, 2);
        expect(threads.calls, 2);
        expect(attorneys.calls, 2);
      },
    );
  });
}

// --- Synthetic D-S1 test fixtures (subsets of the fake-domain lists) -------

final List<Matter> _matters = <Matter>[_m1, _m2];

final Matter _m1 = Matter(
  id: 'matter-1',
  title: 'Demo acquisition review',
  practiceArea: PracticeArea.corporate,
  status: MatterStatus.active,
  assignedAttorneyName: 'Layla Mansour',
  createdAt: _jul12,
);

final Matter _m2 = Matter(
  id: 'matter-2',
  title: 'Commercial lease consultation',
  practiceArea: PracticeArea.civil,
  status: MatterStatus.open,
  assignedAttorneyName: 'Omar Farouk',
  createdAt: _jul18,
);

final List<Document> _documents = <Document>[_d1, _d2];

final Document _d1 = Document(
  id: 'doc-1',
  title: 'Demo engagement letter',
  matterRef: 'Demo acquisition review',
  type: DocumentType.contract,
  createdAt: _jul10,
);

final Document _d2 = Document(
  id: 'doc-2',
  title: 'Sample matter brief — demo',
  matterRef: 'Commercial lease consultation',
  type: DocumentType.brief,
  createdAt: _jul15,
);

final List<MessageThread> _threads = <MessageThread>[_t1, _t2];

final MessageThread _t1 = MessageThread(
  id: 'thread-1',
  title: 'Demo matter updates',
  matterRef: 'Demo acquisition review',
  participants: <String>['Layla Mansour', 'Demo client'],
  lastActivityAt: _jul28,
  messageCount: 12,
);

final MessageThread _t2 = MessageThread(
  id: 'thread-2',
  title: 'Consultation follow-up — demo',
  matterRef: 'Commercial lease consultation',
  participants: <String>['Omar Farouk', 'Demo client'],
  lastActivityAt: _jul25,
  messageCount: 8,
);

final List<Attorney> _attorneys = <Attorney>[_a1, _a2];

final Attorney _a1 = Attorney(
  id: 'atty-1',
  name: 'Layla Mansour',
  practiceArea: PracticeArea.corporate,
  locale: 'EN / AR',
  bio: 'Corporate transactions and governance counsel.',
);

final Attorney _a2 = Attorney(
  id: 'atty-2',
  name: 'Omar Farouk',
  practiceArea: PracticeArea.civil,
  locale: 'EN / AR',
  bio: 'Civil litigation and contracts.',
);

final DateTime _jul10 = DateTime.utc(2026, 7, 10);
final DateTime _jul12 = DateTime.utc(2026, 7, 12);
final DateTime _jul15 = DateTime.utc(2026, 7, 15);
final DateTime _jul18 = DateTime.utc(2026, 7, 18);
final DateTime _jul25 = DateTime.utc(2026, 7, 25);
final DateTime _jul28 = DateTime.utc(2026, 7, 28);

final AppError _loadFailure = AppError(
  code: 'search_failed',
  userMessage: 'Could not run the search',
);

/// The four gateway seams [SearchCubit] composes; the failure group pins
/// that ANY single failure fails the whole search.
enum _GatewayKind { matters, documents, threads, attorneys }

/// Hand-rolled gateway stubs: queue of results (the vault/messaging stub
/// discipline). Only the matter stub supports a pending [Completer] for
/// in-flight tests.
class _StubMatterGateway implements MatterGateway {
  _StubMatterGateway({List<Result<List<Matter>>>? results})
    : results = results == null
          ? <Result<List<Matter>>>[Result<List<Matter>>.success(_matters)]
          : List<Result<List<Matter>>>.of(results),
      completer = null;

  _StubMatterGateway.withCompleter()
    : results = <Result<List<Matter>>>[],
      completer = Completer<Result<List<Matter>>>();

  final List<Result<List<Matter>>> results;
  final Completer<Result<List<Matter>>>? completer;
  int calls = 0;

  @override
  Future<Result<List<Matter>>> fetchMatters() {
    calls += 1;
    if (completer != null && calls == 1) {
      return completer!.future;
    }
    return Future<Result<List<Matter>>>.value(results.removeAt(0));
  }
}

class _StubDocumentGateway implements DocumentGateway {
  _StubDocumentGateway([List<Result<List<Document>>>? results])
    : results = results == null
          ? <Result<List<Document>>>[Result<List<Document>>.success(_documents)]
          : List<Result<List<Document>>>.of(results);

  final List<Result<List<Document>>> results;
  int calls = 0;

  @override
  Future<Result<List<Document>>> fetchDocuments() {
    calls += 1;
    return Future<Result<List<Document>>>.value(results.removeAt(0));
  }
}

class _StubMessageGateway implements MessageGateway {
  _StubMessageGateway([List<Result<List<MessageThread>>>? results])
    : results = results == null
          ? <Result<List<MessageThread>>>[
              Result<List<MessageThread>>.success(_threads),
            ]
          : List<Result<List<MessageThread>>>.of(results);

  final List<Result<List<MessageThread>>> results;
  int calls = 0;

  @override
  Future<Result<List<MessageThread>>> fetchThreads() {
    calls += 1;
    return Future<Result<List<MessageThread>>>.value(results.removeAt(0));
  }

  @override
  Future<Result<List<Message>>> fetchMessages(String threadId) async {
    // Not exercised by the search cubit tests; an honest empty success
    // keeps the seam implementable.
    return const Result<List<Message>>.success(<Message>[]);
  }
}

class _StubAttorneyGateway implements AttorneyGateway {
  _StubAttorneyGateway([List<Result<List<Attorney>>>? results])
    : results = results == null
          ? <Result<List<Attorney>>>[Result<List<Attorney>>.success(_attorneys)]
          : List<Result<List<Attorney>>>.of(results);

  final List<Result<List<Attorney>>> results;
  int calls = 0;

  @override
  Future<Result<List<Attorney>>> fetchAttorneys() {
    calls += 1;
    return Future<Result<List<Attorney>>>.value(results.removeAt(0));
  }
}
