import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';

void main() {
  group('Result and shared view state boundaries', () {
    test('models success and failure explicitly', () {
      const Result<String> success = Result<String>.success('ready');
      const Result<String> failure = Result<String>.failure(
        AppError(code: 'offline', userMessage: 'Unavailable'),
      );

      expect(success.isSuccess, isTrue);
      expect(success.valueOrNull, 'ready');
      expect(failure.isSuccess, isFalse);
      expect(failure.errorOrNull?.code, 'offline');
    });

    test('view states remain equatable and typed', () {
      expect(const ViewLoading<String>(), const ViewLoading<String>());
      expect(const ViewEmpty<String>(), const ViewEmpty<String>());
      expect(
        const ViewUnauthorized<String>(),
        const ViewUnauthorized<String>(),
      );
      expect(
        const ViewSuccess<String>('value'),
        const ViewSuccess<String>('value'),
      );
    });
  });

  group('AuthCubit', () {
    blocTest<AuthCubit, AuthState>(
      'starts a local demo session without collecting credentials',
      build: () => AuthCubit(FakeAuthGateway(), InMemoryErrorReporter()),
      act: (AuthCubit cubit) => cubit.startDemoSession(),
      expect: () => <AuthState>[
        const AuthState(status: AuthStatus.loading),
        const AuthState(
          status: AuthStatus.authenticated,
          session: Session(
            id: 'demo-session',
            displayName: 'Demo user',
            role: UserRole.client,
          ),
        ),
      ],
    );

    test('reports a safe error when the gateway fails', () async {
      final InMemoryErrorReporter reporter = InMemoryErrorReporter();
      const AppError error = AppError(
        code: 'unavailable',
        userMessage: 'Unavailable',
        context: <String, Object?>{'email': 'person@example.com'},
      );
      final AuthCubit cubit = AuthCubit(_FailingAuthGateway(error), reporter);

      await cubit.startDemoSession();

      expect(cubit.state.status, AuthStatus.error);
      expect(reporter.reports.single['context'], <String, Object?>{
        'email': '[REDACTED]',
      });
      await cubit.close();
    });
  });

  group('LocaleCubit', () {
    test('persists only supported locale codes', () async {
      final InMemoryLocaleStore store = InMemoryLocaleStore();
      final LocaleCubit cubit = LocaleCubit(store);

      await cubit.setLocale(const Locale('ar'));
      expect(cubit.state.locale, const Locale('ar'));

      final LocaleCubit restored = LocaleCubit(store);
      await restored.load();
      expect(restored.state.locale, const Locale('ar'));

      await cubit.setLocale(const Locale('fr'));
      expect(cubit.state.locale, const Locale('ar'));
      await cubit.close();
      await restored.close();
    });
  });

  test(
    'redacts credential-shaped keys, email addresses, and bearer tokens',
    () {
      final Map<String, Object?> sanitized = Redactor.map(<String, Object?>{
        'password': 'secret',
        'message': 'Contact person@example.com',
        'authorization': 'Bearer abc123',
        'nested': <String, Object?>{'token': 'value'},
      });

      expect(sanitized['password'], '[REDACTED]');
      expect(sanitized['message'], 'Contact [REDACTED_EMAIL]');
      expect(sanitized['authorization'], '[REDACTED]');
      expect(
        (sanitized['nested']! as Map<String, Object?>)['token'],
        '[REDACTED]',
      );
    },
  );
}

class _FailingAuthGateway implements AuthGateway {
  _FailingAuthGateway(this.error);

  final AppError error;

  @override
  Session? get currentSession => null;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  Future<Result<Session>> startDemoSession() async =>
      Result<Session>.failure(error);

  @override
  Future<void> signOut() async {}
}
