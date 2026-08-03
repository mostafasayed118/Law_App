import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/auth/supabase_auth_api.dart';
import 'package:legalhub/data/auth/supabase_auth_api_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockGoTrueClient extends Mock implements GoTrueClient {}

/// Builds a real GoTrue `Session.expiresAt` deterministically: the gotrue
/// client derives it from the JWT `exp` claim of the access token.
String _jwtWithExp(int exp) {
  final String header = base64Url
      .encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'))
      .replaceAll('=', '');
  final String payload = base64Url
      .encode(utf8.encode(jsonEncode(<String, Object>{'exp': exp})))
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

User _user({
  String id = 'u-1',
  Map<String, dynamic>? userMetadata,
  String? email,
}) => User(
  id: id,
  appMetadata: const <String, dynamic>{},
  userMetadata: userMetadata,
  aud: 'authenticated',
  createdAt: '2026-07-25T00:00:00Z',
  email: email,
);

Session _session({required int exp, required User user}) => Session(
  accessToken: _jwtWithExp(exp),
  tokenType: 'bearer',
  refreshToken: 'rt-secret-value',
  user: user,
);

void main() {
  group('SupabaseAuthApiImpl', () {
    late _MockGoTrueClient client;
    late StreamController<AuthState> events;
    late SupabaseAuthApiImpl api;

    setUp(() {
      client = _MockGoTrueClient();
      events = StreamController<AuthState>.broadcast();
      when(() => client.onAuthStateChange).thenAnswer((_) => events.stream);
      when(() => client.currentSession).thenReturn(null);
      // mocktail cannot synthesize enum/class instances for `any()` matchers;
      // the fallbacks are dummy values that are never interacted with.
      registerFallbackValue(OtpType.magiclink);
      registerFallbackValue(UserAttributes());
      api = SupabaseAuthApiImpl(client);
      addTearDown(() async {
        await events.close();
        await api.dispose();
      });
    });

    test('maps a provider session to a token-free snapshot', () async {
      const int exp = 1893456000; // 2030-01-01 UTC
      when(() => client.currentSession).thenReturn(
        _session(
          exp: exp,
          user: _user(
            userMetadata: const <String, dynamic>{'full_name': 'Amira Hassan'},
          ),
        ),
      );

      final SupabaseAuthSnapshot? snapshot = await api.restore();

      expect(snapshot, isNotNull);
      expect(snapshot!.userId, 'u-1');
      expect(snapshot.displayName, 'Amira Hassan');
      expect(
        snapshot.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
      );
    });

    test('pins the snapshot surface: no token field can appear', () async {
      const int exp = 1893456000;
      when(() => client.currentSession).thenReturn(
        _session(
          exp: exp,
          user: _user(
            userMetadata: const <String, dynamic>{'full_name': 'Amira Hassan'},
          ),
        ),
      );

      final SupabaseAuthSnapshot snapshot = (await api.restore())!;

      // Exactly [userId, displayName, expiresAt] — adding accessToken or
      // refreshToken to the seam breaks this pin (contract §2.6).
      expect(snapshot.props, <Object?>[
        'u-1',
        'Amira Hassan',
        DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
      ]);
    });

    test('falls back to the email local-part for the display name', () async {
      const int exp = 1893456000;
      when(() => client.currentSession).thenReturn(
        _session(
          exp: exp,
          user: _user(email: 'amira@example.com'),
        ),
      );

      final SupabaseAuthSnapshot? snapshot = api.currentSnapshot;

      expect(snapshot?.displayName, 'amira');
    });

    test('returns null when the provider has no session', () async {
      when(() => client.currentSession).thenReturn(null);

      final SupabaseAuthSnapshot? snapshot = await api.restore();

      expect(snapshot, isNull);
    });

    test('delegates signOut to the provider client', () async {
      when(() => client.signOut()).thenAnswer((_) async {});

      await api.signOut();

      verify(() => client.signOut()).called(1);
    });

    test(
      'signs in with the credentials and maps the session to a snapshot',
      () async {
        const int exp = 1893456000; // 2030-01-01 UTC
        when(
          () => client.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async => AuthResponse(
            session: _session(
              exp: exp,
              user: _user(
                userMetadata: const <String, dynamic>{
                  'full_name': 'Amira Hassan',
                },
              ),
            ),
          ),
        );

        final SupabaseAuthSnapshot? snapshot = await api.signInWithPassword(
          email: 'amira@example.com',
          password: 'secret-pass',
        );

        verify(
          () => client.signInWithPassword(
            email: 'amira@example.com',
            password: 'secret-pass',
          ),
        ).called(1);
        expect(snapshot?.userId, 'u-1');
        expect(snapshot?.displayName, 'Amira Hassan');
      },
    );

    test('maps invalid-credentials rejection to a typed exception', () async {
      when(
        () => client.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const AuthException('Invalid login credentials', statusCode: '400'),
      );

      await expectLater(
        api.signInWithPassword(
          email: 'amira@example.com',
          password: 'wrong-pass',
        ),
        throwsA(
          isA<SupabaseAuthException>()
              .having(
                (SupabaseAuthException e) => e.kind,
                'kind',
                SupabaseAuthFailureKind.invalidCredentials,
              )
              .having(
                (SupabaseAuthException e) => e.message,
                'message',
                'Invalid login credentials',
              ),
        ),
      );
    });

    test('maps a rate-limited rejection to rateLimited', () async {
      when(
        () => client.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const AuthException('Rate limit exceeded', statusCode: '429'),
      );

      await expectLater(
        api.signInWithPassword(
          email: 'amira@example.com',
          password: 'secret-pass',
        ),
        throwsA(
          isA<SupabaseAuthException>().having(
            (SupabaseAuthException e) => e.kind,
            'kind',
            SupabaseAuthFailureKind.rateLimited,
          ),
        ),
      );
    });

    test('creates the account with metadata via the provider client', () async {
      when(
        () => client.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => AuthResponse(
          user: _user(
            userMetadata: const <String, dynamic>{'full_name': 'Amira'},
          ),
        ),
      );

      await api.signUp(
        email: 'amira@example.com',
        password: 'secret-pass',
        metadata: const <String, String>{'full_name': 'Amira'},
      );

      verify(
        () => client.signUp(
          email: 'amira@example.com',
          password: 'secret-pass',
          data: const <String, dynamic>{'full_name': 'Amira'},
        ),
      ).called(1);
    });

    test('maps a duplicate-email sign-up to a typed exception', () async {
      when(
        () => client.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        const AuthException('User already registered', statusCode: '422'),
      );

      await expectLater(
        api.signUp(
          email: 'amira@example.com',
          password: 'secret-pass',
          metadata: const <String, String>{'full_name': 'Amira'},
        ),
        throwsA(
          isA<SupabaseAuthException>().having(
            (SupabaseAuthException e) => e.kind,
            'kind',
            SupabaseAuthFailureKind.emailInUse,
          ),
        ),
      );
    });

    test('forwards provider auth-state changes as snapshots', () async {
      const int exp = 1893456000;
      final List<SupabaseAuthSnapshot?> seen = <SupabaseAuthSnapshot?>[];
      final StreamSubscription<SupabaseAuthSnapshot?> subscription = api
          .snapshotChanges
          .listen(seen.add);
      addTearDown(() => subscription.cancel());

      events.add(
        AuthState(
          AuthChangeEvent.signedIn,
          _session(
            exp: exp,
            user: _user(
              userMetadata: const <String, dynamic>{'full_name': 'Mona'},
            ),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(seen.single?.userId, 'u-1');
      expect(seen.single?.displayName, 'Mona');

      events.add(const AuthState(AuthChangeEvent.signedOut, null));
      await Future<void>.delayed(Duration.zero);

      expect(seen.last, isNull);
    });

    group('recovery OTP', () {
      test(
        'sends the OTP without creating a user or redirect target',
        () async {
          when(
            () => client.signInWithOtp(
              email: any(named: 'email'),
              shouldCreateUser: any(named: 'shouldCreateUser'),
              emailRedirectTo: any(named: 'emailRedirectTo'),
            ),
          ).thenAnswer((_) async {});

          await api.sendRecoveryOtp(email: 'amira@example.com');

          // No redirect -> the provider mails a 6-digit code, not a link; no
          // user may be created by a recovery request.
          verify(
            () => client.signInWithOtp(
              email: 'amira@example.com',
              shouldCreateUser: false,
              emailRedirectTo: null,
            ),
          ).called(1);
        },
      );

      test('verifies the emailed code via the magiclink OTP path', () async {
        when(
          () => client.verifyOTP(
            email: any(named: 'email'),
            token: any(named: 'token'),
            type: any(named: 'type'),
          ),
        ).thenAnswer(
          (_) async => AuthResponse(user: _user(email: 'amira@example.com')),
        );

        await api.verifyRecoveryOtp(
          email: 'amira@example.com',
          token: '123456',
        );

        // The dart client has no 'email' OtpType; the provider accepts
        // magiclink for email OTP codes (verified live, 2026-08-03).
        verify(
          () => client.verifyOTP(
            email: 'amira@example.com',
            token: '123456',
            type: OtpType.magiclink,
          ),
        ).called(1);
      });

      test('maps a wrong or expired code to invalidCredentials', () async {
        when(
          () => client.verifyOTP(
            email: any(named: 'email'),
            token: any(named: 'token'),
            type: any(named: 'type'),
          ),
        ).thenThrow(
          const AuthException(
            'Token has expired or is invalid',
            statusCode: '403',
          ),
        );

        await expectLater(
          api.verifyRecoveryOtp(email: 'amira@example.com', token: '000000'),
          throwsA(
            isA<SupabaseAuthException>().having(
              (SupabaseAuthException e) => e.kind,
              'kind',
              SupabaseAuthFailureKind.invalidCredentials,
            ),
          ),
        );
      });

      test('updates the password then clears the recovery session', () async {
        when(() => client.updateUser(any())).thenAnswer(
          (_) async => UserResponse.fromJson(<String, dynamic>{
            'id': 'u-1',
            'aud': 'authenticated',
            'email': 'amira@example.com',
            'created_at': '2026-07-25T00:00:00Z',
          }),
        );
        when(() => client.signOut()).thenAnswer((_) async {});

        await api.updatePassword(newPassword: 'new-secret-pass');

        verify(() => client.updateUser(any())).called(1);
        // Recovery must not leave the app authenticated on next launch.
        verify(() => client.signOut()).called(1);
      });
    });
  });
}
