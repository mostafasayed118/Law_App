import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_gateway.dart';
import 'package:legalhub/features/discovery/presentation/discovery_cubit.dart';
import 'package:legalhub/features/discovery/presentation/discovery_state.dart';

void main() {
  late _StubAttorneyGateway gateway;

  setUp(() {
    gateway = _StubAttorneyGateway();
  });

  group('DiscoveryCubit (Phase 6 slice 6.1)', () {
    test('starts loading with an empty query and no area filter', () {
      final DiscoveryCubit cubit = DiscoveryCubit(gateway);
      addTearDown(cubit.close);

      expect(cubit.state.attorneys, const ViewLoading<List<Attorney>>());
      expect(cubit.state.query, '');
      expect(cubit.state.practiceArea, isNull);
      expect(cubit.state.visibleAttorneys, isEmpty);
    });

    blocTest<DiscoveryCubit, DiscoveryState>(
      'load resolves to the synthetic list (AC-1)',
      build: () => DiscoveryCubit(gateway),
      act: (DiscoveryCubit cubit) => cubit.load(),
      expect: () => <DiscoveryState>[
        DiscoveryState(attorneys: ViewSuccess<List<Attorney>>(_attorneys)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<DiscoveryCubit, DiscoveryState>(
      'load maps an empty list to ViewEmpty',
      setUp: () => gateway = _StubAttorneyGateway(
        results: <Result<List<Attorney>>>[
          Result<List<Attorney>>.success(const <Attorney>[]),
        ],
      ),
      build: () => DiscoveryCubit(gateway),
      act: (DiscoveryCubit cubit) => cubit.load(),
      expect: () => <DiscoveryState>[
        const DiscoveryState(attorneys: ViewEmpty<List<Attorney>>()),
      ],
    );

    blocTest<DiscoveryCubit, DiscoveryState>(
      'load maps a failure to ViewError with no visible rows',
      setUp: () => gateway = _StubAttorneyGateway(
        results: <Result<List<Attorney>>>[
          Result<List<Attorney>>.failure(_loadFailure),
        ],
      ),
      build: () => DiscoveryCubit(gateway),
      act: (DiscoveryCubit cubit) => cubit.load(),
      expect: () => <DiscoveryState>[
        DiscoveryState(attorneys: ViewError<List<Attorney>>(_loadFailure)),
      ],
      verify: (DiscoveryCubit cubit) {
        expect(gateway.fetchCalls, 1);
        expect(cubit.state.visibleAttorneys, isEmpty);
      },
    );

    blocTest<DiscoveryCubit, DiscoveryState>(
      'duplicate load while in flight is ignored',
      setUp: () => gateway = _StubAttorneyGateway.withCompleter(),
      build: () => DiscoveryCubit(gateway),
      act: (DiscoveryCubit cubit) async {
        final Future<void> first = cubit.load();
        await cubit.load();
        gateway.completer!.complete(Result<List<Attorney>>.success(_attorneys));
        await first;
      },
      expect: () => <DiscoveryState>[
        DiscoveryState(attorneys: ViewSuccess<List<Attorney>>(_attorneys)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<DiscoveryCubit, DiscoveryState>(
      'load after an error retries into a fresh success',
      setUp: () => gateway = _StubAttorneyGateway(
        results: <Result<List<Attorney>>>[
          Result<List<Attorney>>.failure(_loadFailure),
          Result<List<Attorney>>.success(_attorneys),
        ],
      ),
      build: () => DiscoveryCubit(gateway),
      act: (DiscoveryCubit cubit) async {
        await cubit.load();
        await cubit.load();
      },
      expect: () => <DiscoveryState>[
        DiscoveryState(attorneys: ViewError<List<Attorney>>(_loadFailure)),
        const DiscoveryState(attorneys: ViewLoading<List<Attorney>>()),
        DiscoveryState(attorneys: ViewSuccess<List<Attorney>>(_attorneys)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 2),
    );

    test('updateQuery filters by name, case-insensitive (AC-2)', () async {
      final DiscoveryCubit cubit = DiscoveryCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load();

      cubit.updateQuery('layla');
      expect(cubit.state.visibleAttorneys, <Attorney>[_attorney('atty-1')]);

      cubit.updateQuery('LAYLA');
      expect(cubit.state.visibleAttorneys, <Attorney>[_attorney('atty-1')]);
    });

    test('query also matches the practice-area token (AC-2)', () async {
      final DiscoveryCubit cubit = DiscoveryCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load();

      // D-A5: the free-text query matches name OR practice area, so a user
      // can search "corporate" without touching the chips.
      cubit.updateQuery('corporate');
      expect(cubit.state.visibleAttorneys.map((Attorney a) => a.id), <String>[
        'atty-1',
        'atty-5',
      ]);
    });

    test(
      'setPracticeArea narrows; All restores the full list (AC-2)',
      () async {
        final DiscoveryCubit cubit = DiscoveryCubit(gateway);
        addTearDown(cubit.close);
        await cubit.load();

        cubit.setPracticeArea(PracticeArea.civil);
        expect(cubit.state.visibleAttorneys, <Attorney>[_attorney('atty-2')]);

        cubit.setPracticeArea(null);
        expect(cubit.state.visibleAttorneys, hasLength(_attorneys.length));
      },
    );

    test('query and area filter compose', () async {
      final DiscoveryCubit cubit = DiscoveryCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load();

      cubit.setPracticeArea(PracticeArea.corporate);
      cubit.updateQuery('maya');
      expect(cubit.state.visibleAttorneys, <Attorney>[_attorney('atty-5')]);
    });

    test(
      'a query with no matches yields an empty visible list (AC-2)',
      () async {
        final DiscoveryCubit cubit = DiscoveryCubit(gateway);
        addTearDown(cubit.close);
        await cubit.load();

        cubit.updateQuery('zzz-nobody');
        expect(cubit.state.visibleAttorneys, isEmpty);
      },
    );
  });
}

final List<Attorney> _attorneys = <Attorney>[
  Attorney(
    id: 'atty-1',
    name: 'Layla Mansour',
    practiceArea: PracticeArea.corporate,
    locale: 'EN / AR',
    bio: 'Corporate transactions and governance counsel.',
  ),
  Attorney(
    id: 'atty-2',
    name: 'Omar Farouk',
    practiceArea: PracticeArea.civil,
    locale: 'EN / AR',
    bio: 'Civil litigation and contracts.',
  ),
  Attorney(
    id: 'atty-5',
    name: 'Maya Adel',
    practiceArea: PracticeArea.corporate,
    locale: 'EN',
    bio: 'Startup formation and advisory work.',
  ),
];

Attorney _attorney(String id) =>
    _attorneys.firstWhere((Attorney a) => a.id == id);

final AppError _loadFailure = AppError(
  code: 'discovery_failed',
  userMessage: 'Could not load attorneys',
);

/// Hand-rolled gateway stub: queue of results (like the booking stub), or a
/// Completer for in-flight tests.
class _StubAttorneyGateway implements AttorneyGateway {
  _StubAttorneyGateway({List<Result<List<Attorney>>>? results})
    : _queue = results == null
          ? <Result<List<Attorney>>>[Result<List<Attorney>>.success(_attorneys)]
          : List<Result<List<Attorney>>>.of(results),
      completer = null;

  _StubAttorneyGateway.withCompleter()
    : _queue = const <Result<List<Attorney>>>[],
      completer = Completer<Result<List<Attorney>>>();

  final List<Result<List<Attorney>>> _queue;
  final Completer<Result<List<Attorney>>>? completer;
  int fetchCalls = 0;

  @override
  Future<Result<List<Attorney>>> fetchAttorneys() {
    fetchCalls += 1;
    if (completer != null) {
      return completer!.future;
    }
    return Future<Result<List<Attorney>>>.value(_queue.removeAt(0));
  }
}
