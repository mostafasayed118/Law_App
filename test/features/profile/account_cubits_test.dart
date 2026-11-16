import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/features/profile/data/fake_account_gateway.dart';
import 'package:legalhub/features/profile/data/fake_password_gateway.dart';
import 'package:legalhub/features/profile/domain/account_errors.dart';
import 'package:legalhub/features/profile/presentation/account_deletion_cubit.dart';
import 'package:legalhub/features/profile/presentation/account_deletion_state.dart';
import 'package:legalhub/features/profile/presentation/password_change_cubit.dart';
import 'package:legalhub/features/profile/presentation/password_change_state.dart';
import 'package:legalhub/features/profile/presentation/profile_edit_cubit.dart';
import 'package:legalhub/features/profile/presentation/profile_edit_state.dart';

void main() {
  group('ProfileEditCubit', () {
    blocTest<ProfileEditCubit, ProfileEditState>(
      'save emits saving then saved',
      build: () => ProfileEditCubit(FakeAccountGateway(), initialName: 'اسم'),
      act: (ProfileEditCubit cubit) => cubit.save(),
      expect: () => <ProfileEditState>[
        const ProfileEditState(name: 'اسم', saving: true),
        const ProfileEditState(name: 'اسم', saved: true),
      ],
    );

    blocTest<ProfileEditCubit, ProfileEditState>(
      'a typed server refusal keeps the editable state and raises the error',
      build: () => ProfileEditCubit(
        FakeAccountGateway(rejectUpdates: true),
        initialName: 'اسم',
      ),
      act: (ProfileEditCubit cubit) => cubit.save(),
      expect: () => <ProfileEditState>[
        const ProfileEditState(name: 'اسم', saving: true),
        ProfileEditState(name: 'اسم', lastError: AccountErrors.invalidName),
      ],
    );
  });

  group('PasswordChangeCubit', () {
    blocTest<PasswordChangeCubit, PasswordChangeState>(
      'submit emits saving then changed and clears the fields',
      build: () => PasswordChangeCubit(FakePasswordGateway()),
      act: (PasswordChangeCubit cubit) async {
        cubit.newPasswordChanged('strong-password');
        cubit.confirmationChanged('strong-password');
        await cubit.submit();
      },
      skip: 2,
      expect: () => <PasswordChangeState>[
        const PasswordChangeState(
          newPassword: 'strong-password',
          confirmation: 'strong-password',
          saving: true,
        ),
        const PasswordChangeState(changed: true),
      ],
    );

    test('needsReauth is derived from the code, not a generic message', () {
      const PasswordChangeState state = PasswordChangeState(
        lastError: AppError(code: 'password_reauth_required', userMessage: 'x'),
      );
      expect(state.needsReauth, isTrue);
      expect(
        const PasswordChangeState(
          lastError: AppError(code: 'other', userMessage: 'x'),
        ).needsReauth,
        isFalse,
      );
    });

    test('a refused change leaves a typed failure', () async {
      final PasswordChangeCubit cubit = PasswordChangeCubit(
        FakePasswordGateway(reject: true),
      );
      addTearDown(cubit.close);
      final bool ok = await cubit.submit();
      expect(ok, isFalse);
      expect(cubit.state.lastError, isNotNull);
      expect(cubit.state.changed, isFalse);
    });
  });

  group('AccountDeletionCubit', () {
    test('an empty confirmation cannot trigger deletion', () async {
      final FakeAccountGateway gateway = FakeAccountGateway();
      final AccountDeletionCubit cubit = AccountDeletionCubit(gateway);
      addTearDown(cubit.close);

      await cubit.delete();

      expect(gateway.deleteCalls, 0);
      expect(cubit.state.stage, AccountDeletionStage.idle);
    });

    blocTest<AccountDeletionCubit, AccountDeletionState>(
      'done is only reached after the RPC succeeds',
      build: () => AccountDeletionCubit(FakeAccountGateway()),
      act: (AccountDeletionCubit cubit) async {
        cubit.confirmationChanged('DELETE');
        await cubit.delete();
      },
      skip: 1,
      expect: () => <AccountDeletionState>[
        const AccountDeletionState(
          confirmation: 'DELETE',
          stage: AccountDeletionStage.deleting,
        ),
        const AccountDeletionState(stage: AccountDeletionStage.done),
      ],
    );

    test(
      'last-partner refusal returns to confirming with the specific error',
      () async {
        final AccountDeletionCubit cubit = AccountDeletionCubit(
          FakeAccountGateway(lastActivePartner: true),
        );
        addTearDown(cubit.close);
        cubit.confirmationChanged('DELETE');

        final bool ok = await cubit.delete();

        expect(ok, isFalse);
        expect(cubit.state.stage, AccountDeletionStage.confirming);
        expect(cubit.state.isLastPartner, isTrue);
      },
    );

    test('platform-owner refusal is distinguishable', () async {
      final AccountDeletionCubit cubit = AccountDeletionCubit(
        FakeAccountGateway(platformOwner: true),
      );
      addTearDown(cubit.close);
      cubit.confirmationChanged('DELETE');

      final bool ok = await cubit.delete();

      expect(ok, isFalse);
      expect(cubit.state.isPlatformOwner, isTrue);
    });
  });
}
