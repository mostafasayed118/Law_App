import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/features/matters/domain/matter_write_gateway.dart';
import 'package:legalhub/features/matters/presentation/matter_create_cubit.dart';
import 'package:legalhub/features/matters/presentation/matter_create_state.dart';

void main() {
  late _StubMatterWriteGateway gateway;

  setUp(() {
    gateway = _StubMatterWriteGateway();
  });

  group('MatterCreateCubit (F-01 step 2 client swap, C-D6)', () {
    test('starts in the initial state', () {
      final MatterCreateCubit cubit = MatterCreateCubit(gateway);
      addTearDown(cubit.close);

      expect(cubit.state, const MatterCreateInitial());
    });

    blocTest<MatterCreateCubit, MatterCreateState>(
      'submit goes idle → submitting → success with the created matter',
      build: () => MatterCreateCubit(gateway),
      act: (MatterCreateCubit cubit) => cubit.submit(_request),
      expect: () => <MatterCreateState>[
        const MatterCreateSubmitting(),
        MatterCreateSuccess(_created),
      ],
      verify: (_) => expect(gateway.createCalls, 1),
    );

    blocTest<MatterCreateCubit, MatterCreateState>(
      'submit maps a failure to the typed error (never empty success, AC-7)',
      setUp: () => gateway = _StubMatterWriteGateway(
        results: <Result<CreatedMatter>>[
          Result<CreatedMatter>.failure(
            const AppError(
              code: 'matter_write_owner_forbidden',
              userMessage: 'The platform owner cannot be assigned to a matter.',
            ),
          ),
        ],
      ),
      build: () => MatterCreateCubit(gateway),
      act: (MatterCreateCubit cubit) => cubit.submit(_request),
      expect: () => <MatterCreateState>[
        const MatterCreateSubmitting(),
        const MatterCreateFailure(
          AppError(
            code: 'matter_write_owner_forbidden',
            userMessage: 'The platform owner cannot be assigned to a matter.',
          ),
        ),
      ],
    );

    blocTest<MatterCreateCubit, MatterCreateState>(
      'ignores a duplicate submit while one is in flight',
      build: () => MatterCreateCubit(gateway),
      act: (MatterCreateCubit cubit) async {
        await Future.wait(<Future<void>>[
          cubit.submit(_request),
          cubit.submit(_request),
        ]);
      },
      expect: () => <MatterCreateState>[
        const MatterCreateSubmitting(),
        MatterCreateSuccess(_created),
      ],
      verify: (_) => expect(gateway.createCalls, 1),
    );
  });
}

const CreateMatterRequest _request = CreateMatterRequest(
  organizationId: 'org-demo',
  title: 'Demo acquisition review',
  practiceArea: PracticeArea.corporate,
);

const CreatedMatter _created = CreatedMatter(
  id: 'created-1',
  title: 'Demo acquisition review',
  practiceArea: PracticeArea.corporate,
);

class _StubMatterWriteGateway implements MatterWriteGateway {
  _StubMatterWriteGateway({
    this.results = const <Result<CreatedMatter>>[
      Result<CreatedMatter>.success(_created),
    ],
  });

  final List<Result<CreatedMatter>> results;
  int createCalls = 0;

  @override
  Future<Result<CreatedMatter>> createMatter(
    CreateMatterRequest request,
  ) async {
    final Result<CreatedMatter> result =
        results[createCalls.clamp(0, results.length - 1)];
    createCalls += 1;
    return result;
  }
}
