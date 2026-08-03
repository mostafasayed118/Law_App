import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/matters/presentation/matter_cubit.dart';
import 'package:legalhub/features/matters/presentation/matter_state.dart';

void main() {
  late _StubMatterGateway gateway;

  setUp(() {
    gateway = _StubMatterGateway();
  });

  group('MatterCubit (Phase 7 slice 7.1)', () {
    test('starts loading with no status filter', () {
      final MatterCubit cubit = MatterCubit(gateway);
      addTearDown(cubit.close);

      expect(cubit.state.matters, const ViewLoading<List<Matter>>());
      expect(cubit.state.status, isNull);
      expect(cubit.state.visibleMatters, isEmpty);
    });

    blocTest<MatterCubit, MatterState>(
      'load resolves to the synthetic list (AC-1)',
      build: () => MatterCubit(gateway),
      act: (MatterCubit cubit) => cubit.load(),
      expect: () => <MatterState>[
        MatterState(matters: ViewSuccess<List<Matter>>(_matters)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<MatterCubit, MatterState>(
      'load maps an empty list to ViewEmpty',
      setUp: () => gateway = _StubMatterGateway(
        results: <Result<List<Matter>>>[
          Result<List<Matter>>.success(const <Matter>[]),
        ],
      ),
      build: () => MatterCubit(gateway),
      act: (MatterCubit cubit) => cubit.load(),
      expect: () => <MatterState>[
        const MatterState(matters: ViewEmpty<List<Matter>>()),
      ],
    );

    blocTest<MatterCubit, MatterState>(
      'load maps a failure to ViewError with no visible rows',
      setUp: () => gateway = _StubMatterGateway(
        results: <Result<List<Matter>>>[
          Result<List<Matter>>.failure(_loadFailure),
        ],
      ),
      build: () => MatterCubit(gateway),
      act: (MatterCubit cubit) => cubit.load(),
      expect: () => <MatterState>[
        MatterState(matters: ViewError<List<Matter>>(_loadFailure)),
      ],
      verify: (MatterCubit cubit) {
        expect(gateway.fetchCalls, 1);
        expect(cubit.state.visibleMatters, isEmpty);
      },
    );

    blocTest<MatterCubit, MatterState>(
      'duplicate load while in flight is ignored',
      setUp: () => gateway = _StubMatterGateway.withCompleter(),
      build: () => MatterCubit(gateway),
      act: (MatterCubit cubit) async {
        final Future<void> first = cubit.load();
        await cubit.load();
        gateway.completer!.complete(Result<List<Matter>>.success(_matters));
        await first;
      },
      expect: () => <MatterState>[
        MatterState(matters: ViewSuccess<List<Matter>>(_matters)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<MatterCubit, MatterState>(
      'load after an error retries into a fresh success',
      setUp: () => gateway = _StubMatterGateway(
        results: <Result<List<Matter>>>[
          Result<List<Matter>>.failure(_loadFailure),
          Result<List<Matter>>.success(_matters),
        ],
      ),
      build: () => MatterCubit(gateway),
      act: (MatterCubit cubit) async {
        await cubit.load();
        await cubit.load();
      },
      expect: () => <MatterState>[
        MatterState(matters: ViewError<List<Matter>>(_loadFailure)),
        const MatterState(matters: ViewLoading<List<Matter>>()),
        MatterState(matters: ViewSuccess<List<Matter>>(_matters)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 2),
    );

    test('setStatus narrows; All restores the full list (AC-2)', () async {
      final MatterCubit cubit = MatterCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load();

      cubit.setStatus(MatterStatus.active);
      expect(cubit.state.visibleMatters, <Matter>[_matter('matter-1')]);

      cubit.setStatus(null);
      expect(cubit.state.visibleMatters, hasLength(_matters.length));
    });

    test(
      'a status filter with no matches yields an empty visible list (AC-2)',
      () async {
        final MatterCubit cubit = MatterCubit(gateway);
        addTearDown(cubit.close);
        await cubit.load();

        // The stub list has no closed matters — the filter dead-ends empty.
        cubit.setStatus(MatterStatus.closed);
        expect(cubit.state.visibleMatters, isEmpty);
      },
    );
  });
}

final List<Matter> _matters = <Matter>[
  Matter(
    id: 'matter-1',
    title: 'Demo acquisition review',
    practiceArea: PracticeArea.corporate,
    status: MatterStatus.active,
    assignedAttorneyName: 'Layla Mansour',
    createdAt: DateTime.utc(2026, 7, 12),
  ),
  Matter(
    id: 'matter-2',
    title: 'Commercial lease consultation',
    practiceArea: PracticeArea.civil,
    status: MatterStatus.open,
    assignedAttorneyName: 'Omar Farouk',
    createdAt: DateTime.utc(2026, 7, 18),
  ),
];

Matter _matter(String id) => _matters.firstWhere((Matter m) => m.id == id);

final AppError _loadFailure = AppError(
  code: 'matters_failed',
  userMessage: 'Could not load matters',
);

/// Hand-rolled gateway stub: queue of results (like the discovery/booking
/// stubs), or a Completer for in-flight tests.
class _StubMatterGateway implements MatterGateway {
  _StubMatterGateway({List<Result<List<Matter>>>? results})
    : _queue = results == null
          ? <Result<List<Matter>>>[Result<List<Matter>>.success(_matters)]
          : List<Result<List<Matter>>>.of(results),
      completer = null;

  _StubMatterGateway.withCompleter()
    : _queue = const <Result<List<Matter>>>[],
      completer = Completer<Result<List<Matter>>>();

  final List<Result<List<Matter>>> _queue;
  final Completer<Result<List<Matter>>>? completer;
  int fetchCalls = 0;

  @override
  Future<Result<List<Matter>>> fetchMatters() {
    fetchCalls += 1;
    if (completer != null) {
      return completer!.future;
    }
    return Future<Result<List<Matter>>>.value(_queue.removeAt(0));
  }
}
