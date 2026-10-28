import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/features/auth/data/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/domain/auth_state.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/orgs/data/fake_membership_repository.dart';
import 'package:legalhub/features/orgs/data/fake_organization_gateway.dart';

/// R10 — session/token clearing on sign-out and account deletion
/// (2026-09-24).
///
/// No test pinned that sign-out or account deletion actually ends the
/// session at the layer the app owns. Token-payload clearing inside the
/// SDK store is covered by `secure_session_storage_test.dart`
/// (`removePersistedSession clears the payload`); these tests pin the
/// app-owned half: after [AuthCubit.signOut] and after a successful
/// [AuthCubit.deleteAccount], the gateway holds no session, the recovery
/// marker is cleared, and the cubit state is unauthenticated.
void main() {
  late FakeAuthGateway gateway;
  late AuthCubit cubit;

  setUp(() {
    gateway = FakeAuthGateway();
    cubit = AuthCubit(
      gateway,
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
      FakeOrganizationGateway(),
    );
  });

  tearDown(() async {
    await cubit.close();
    await gateway.dispose();
  });

  test('signOut clears the gateway session and the recovery marker', () async {
    gateway.markAsRecoverySession();
    await cubit.startDemoSession();
    expect(gateway.currentSession, isNotNull);
    expect(cubit.recoveryPending, isTrue);

    await cubit.signOut();

    expect(gateway.currentSession, isNull);
    expect(cubit.recoveryPending, isFalse);
    expect(cubit.state.status, AuthStatus.unauthenticated);
  });

  test('signOut emits null on the session stream', () async {
    final List<dynamic> events = <dynamic>[];
    final Stream<dynamic> sub = gateway.sessionChanges.map((s) => s);
    final subscription = sub.listen(events.add);

    await cubit.startDemoSession();
    await cubit.signOut();
    await subscription.cancel();

    expect(events.last, isNull);
  });

  test('deleteAccount success ends the session (no stale identity)', () async {
    await cubit.startDemoSession();
    expect(gateway.currentSession, isNotNull);

    // The fake organization gateway's deleteMyAccount succeeds, so the
    // cubit must end the session for the auth gate to redirect to sign-in
    // instead of showing a stale identity.
    expect(await cubit.deleteAccount(), isNull);

    expect(gateway.currentSession, isNull);
    expect(cubit.state.status, AuthStatus.unauthenticated);
  });
}
