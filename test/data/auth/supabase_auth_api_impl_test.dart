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
  String? recoverySentAt,
}) => User(
  id: id,
  appMetadata: const <String, dynamic>{},
  userMetadata: userMetadata,
  aud: 'authenticated',
  createdAt: '2026-07-25T00:00:00Z',
  email: email,
  recoverySentAt: recoverySentAt,
);

Session _session({required int exp, required User user}) => Session(
  accessToken: _jwtWithExp(exp),
  tokenType: 'bearer',
  refreshToken: 'rt-secret-value',
  user: user,
);

void main() {
  // Non-nullable parameter types on the GoTrue seam need registered fallback
  // values before `any`/`captureAny` matchers can be used (mocktail).
  setUpAll(() {
    registerFallbackValue(UserAttributes());
    registerFallbackValue(OtpType.magiclink);
  });

  group('SupabaseAuthApiImpl', () {
    late _MockGoTrueClient client;
    late StreamController<AuthState> events;
    late SupabaseAuthApiImpl api;

    setUp(() {
      client = _MockGoTrueClient();
      events = StreamController<AuthState>.broadcast();
      when(() => client.onAuthStateChange).thenAnswer((_) => events.stream);
      when(() => client.currentSession).thenReturn(null);
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

      // Exactly [userId, displayName, expiresAt, recoveredViaLink] — adding
      // accessToken or refreshToken to the seam breaks this pin (contract
      // §2.6). recoveredViaLink is the Phase 4.1 recovery marker (false for a
      // normal sign-in snapshot).
      expect(snapshot.props, <Object?>[
        'u-1',
        'Amira Hassan',
        DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
        false,
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

    group('recoveredViaLink (Phase 4.1)', () {
      test('marks a snapshot from a passwordRecovery event', () async {
        const int exp = 1893456000;
        final List<SupabaseAuthSnapshot?> seen = <SupabaseAuthSnapshot?>[];
        final StreamSubscription<SupabaseAuthSnapshot?> subscription = api
            .snapshotChanges
            .listen(seen.add);
        addTearDown(() => subscription.cancel());

        events.add(
          AuthState(
            AuthChangeEvent.passwordRecovery,
            _session(exp: exp, user: _user()),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        // The PKCE exchange for a recovery link fires `passwordRecovery`
        // (gotrue exchangeCodeForSession) — the live deep-link signal.
        expect(seen.single?.recoveredViaLink, isTrue);
      });

      test('leaves the marker false for a normal signed-in event', () async {
        const int exp = 1893456000;
        final List<SupabaseAuthSnapshot?> seen = <SupabaseAuthSnapshot?>[];
        final StreamSubscription<SupabaseAuthSnapshot?> subscription = api
            .snapshotChanges
            .listen(seen.add);
        addTearDown(() => subscription.cancel());

        events.add(
          AuthState(
            AuthChangeEvent.signedIn,
            _session(exp: exp, user: _user()),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(seen.single?.recoveredViaLink, isFalse);
      });

      test('marks a cold-restored session via recovery_sent_at', () async {
        const int exp = 1893456000;
        // No `passwordRecovery` event replays (cold restore), but the user
        // record still carries a pending recovery marker.
        when(() => client.currentSession).thenReturn(
          _session(
            exp: exp,
            user: _user(recoverySentAt: '2026-08-03T00:00:00Z'),
          ),
        );

        final SupabaseAuthSnapshot? snapshot = await api.restore();

        expect(snapshot?.recoveredViaLink, isTrue);
      });

      test('leaves the marker false without a recovery signal', () async {
        const int exp = 1893456000;
        when(
          () => client.currentSession,
        ).thenReturn(_session(exp: exp, user: _user()));

        final SupabaseAuthSnapshot? snapshot = await api.restore();

        expect(snapshot?.recoveredViaLink, isFalse);
      });
    });

    group('signInWithPassword (P3.1)', () {
      test('maps a provider session to a token-free snapshot', () async {
        const int exp = 1893456000;
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

        final SupabaseAuthResult result = await api.signInWithPassword(
          email: 'amira@example.com',
          password: 'any-password',
        );

        expect(result, isA<SupabaseAuthSuccess>());
        final SupabaseAuthSnapshot? snapshot =
            (result as SupabaseAuthSuccess).snapshot;
        expect(snapshot?.userId, 'u-1');
        expect(snapshot?.displayName, 'Amira Hassan');
        expect(
          snapshot?.expiresAt,
          DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
        );
        verify(
          () => client.signInWithPassword(
            email: 'amira@example.com',
            password: 'any-password',
          ),
        ).called(1);
      });

      test('maps invalid-credentials to the typed failure', () async {
        when(
          () => client.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const AuthException('Invalid login credentials'));

        final SupabaseAuthResult result = await api.signInWithPassword(
          email: 'amira@example.com',
          password: 'wrong-password',
        );

        expect(result, isA<SupabaseAuthFailed>());
        final SupabaseAuthFailure failure =
            (result as SupabaseAuthFailed).failure;
        expect(failure.kind, SupabaseAuthFailureKind.invalidCredentials);
        expect(failure.message, 'Invalid login credentials');
      });

      test('maps email-not-confirmed to the typed failure', () async {
        when(
          () => client.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const AuthException('Email not confirmed'));

        final SupabaseAuthResult result = await api.signInWithPassword(
          email: 'amira@example.com',
          password: 'any-password',
        );

        expect(
          (result as SupabaseAuthFailed).failure.kind,
          SupabaseAuthFailureKind.emailNotConfirmed,
        );
      });

      test('maps a 429 status to the rate-limited failure', () async {
        when(
          () => client.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const AuthException('Rate limit exceeded', statusCode: '429'),
        );

        final SupabaseAuthResult result = await api.signInWithPassword(
          email: 'amira@example.com',
          password: 'any-password',
        );

        expect(
          (result as SupabaseAuthFailed).failure.kind,
          SupabaseAuthFailureKind.rateLimited,
        );
      });

      test('maps a disabled account to the userDisabled failure', () async {
        when(
          () => client.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const AuthException('User is disabled'));

        final SupabaseAuthResult result = await api.signInWithPassword(
          email: 'amira@example.com',
          password: 'any-password',
        );

        expect(
          (result as SupabaseAuthFailed).failure.kind,
          SupabaseAuthFailureKind.userDisabled,
        );
      });

      test('maps an unknown provider error to the unknown failure', () async {
        when(
          () => client.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const AuthException('Something unexpected'));

        final SupabaseAuthResult result = await api.signInWithPassword(
          email: 'amira@example.com',
          password: 'any-password',
        );

        expect(
          (result as SupabaseAuthFailed).failure.kind,
          SupabaseAuthFailureKind.unknown,
        );
      });

      test('maps a non-AuthException to provider-unavailable', () async {
        when(
          () => client.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(StateError('network down'));

        final SupabaseAuthResult result = await api.signInWithPassword(
          email: 'amira@example.com',
          password: 'any-password',
        );

        expect(
          (result as SupabaseAuthFailed).failure.kind,
          SupabaseAuthFailureKind.providerUnavailable,
        );
      });
    });

    group('signUp (P3.1)', () {
      test('resolves to pending when email confirmation is required', () async {
        when(
          () => client.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => AuthResponse(session: null));

        final SupabaseSignUpResult result = await api.signUp(
          email: 'amira@example.com',
          password: 'any-password',
          displayName: 'Amira Hassan',
        );

        expect(result, isA<SupabaseSignUpPending>());
        // The display name travels as raw_user_meta_data.display_name so the
        // applied handle_new_user trigger creates the profile row with it.
        verify(
          () => client.signUp(
            email: 'amira@example.com',
            password: 'any-password',
            data: <String, dynamic>{
              'display_name': 'Amira Hassan',
              'full_name': 'Amira Hassan',
              'name': 'Amira Hassan',
            },
          ),
        ).called(1);
      });

      test('resolves to authenticated when a session is minted', () async {
        const int exp = 1893456000;
        when(
          () => client.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
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

        final SupabaseSignUpResult result = await api.signUp(
          email: 'amira@example.com',
          password: 'any-password',
          displayName: 'Amira Hassan',
        );

        expect(result, isA<SupabaseSignUpAuthenticated>());
        expect((result as SupabaseSignUpAuthenticated).snapshot.userId, 'u-1');
      });

      test('maps an already-registered email to the typed failure', () async {
        when(
          () => client.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          ),
        ).thenThrow(const AuthException('User already registered'));

        final SupabaseSignUpResult result = await api.signUp(
          email: 'amira@example.com',
          password: 'any-password',
          displayName: 'Amira Hassan',
        );

        expect(
          (result as SupabaseSignUpFailed).failure.kind,
          SupabaseAuthFailureKind.emailInUse,
        );
      });
    });

    group('resetPasswordForEmail (P3.1)', () {
      test('delegates via signInWithOtp with the Phase 4.1 deep-link redirect '
          'and resolves to a generic success with no snapshot', () async {
        when(
          () => client.signInWithOtp(
            email: any(named: 'email'),
            shouldCreateUser: any(named: 'shouldCreateUser'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          ),
        ).thenAnswer((_) async => AuthResponse(session: null));

        final SupabaseAuthResult result = await api.resetPasswordForEmail(
          'amira@example.com',
        );

        expect(result, isA<SupabaseAuthSuccess>());
        expect((result as SupabaseAuthSuccess).snapshot, isNull);
        verify(
          () => client.signInWithOtp(
            email: 'amira@example.com',
            shouldCreateUser: false,
            // Phase 4.1: the recovery email's link is the app deep link
            // (never a browser URL), so the PKCE exchange lands in-app.
            emailRedirectTo: 'com.legalhub.app://auth/v1/callback',
          ),
        ).called(1);
      });

      test('maps a provider failure to the typed failure', () async {
        when(
          () => client.signInWithOtp(
            email: any(named: 'email'),
            shouldCreateUser: any(named: 'shouldCreateUser'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          ),
        ).thenThrow(const AuthException('Email not confirmed'));

        final SupabaseAuthResult result = await api.resetPasswordForEmail(
          'amira@example.com',
        );

        expect(
          (result as SupabaseAuthFailed).failure.kind,
          SupabaseAuthFailureKind.emailNotConfirmed,
        );
      });
    });

    group('verifyOtp (P3.1)', () {
      test(
        'delegates with the magiclink OTP type and maps the minted session',
        () async {
          const int exp = 1893456000;
          when(
            () => client.verifyOTP(
              email: any(named: 'email'),
              token: any(named: 'token'),
              type: any(named: 'type'),
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

          final SupabaseAuthResult result = await api.verifyOtp(
            email: 'amira@example.com',
            code: '123456',
          );

          expect(result, isA<SupabaseAuthSuccess>());
          expect((result as SupabaseAuthSuccess).snapshot?.userId, 'u-1');
          verify(
            () => client.verifyOTP(
              email: 'amira@example.com',
              token: '123456',
              // The dart client has no 'email' OtpType; the provider accepts
              // magiclink for the code-based recovery emails (D1 revised,
              // verified live 2026-08-03).
              type: OtpType.magiclink,
            ),
          ).called(1);
        },
      );

      test('maps a wrong-code provider error to the typed failure', () async {
        when(
          () => client.verifyOTP(
            email: any(named: 'email'),
            token: any(named: 'token'),
            type: any(named: 'type'),
          ),
        ).thenThrow(const AuthException('Invalid OTP'));

        final SupabaseAuthResult result = await api.verifyOtp(
          email: 'amira@example.com',
          code: '000000',
        );

        expect(
          (result as SupabaseAuthFailed).failure.kind,
          SupabaseAuthFailureKind.unknown,
        );
      });
    });

    group('updateUserPassword (P3.1)', () {
      test(
        'delegates the new password to updateUser, signs out, and succeeds',
        () async {
          when(() => client.updateUser(captureAny())).thenAnswer(
            (_) async => UserResponse.fromJson(<String, dynamic>{'id': 'u-1'}),
          );
          when(() => client.signOut()).thenAnswer((_) async {});

          final SupabaseAuthResult result = await api.updateUserPassword(
            'new-password-1',
          );

          expect(result, isA<SupabaseAuthSuccess>());
          expect((result as SupabaseAuthSuccess).snapshot, isNull);
          final List<dynamic> captured = verify(
            () => client.updateUser(captureAny()),
          ).captured;
          expect(captured.single, isA<UserAttributes>());
          expect(
            (captured.single as UserAttributes).password,
            'new-password-1',
          );
          // Recovery must not leave the app authenticated on the next
          // launch: the verify session is a means to an end (4.1 discipline).
          verify(() => client.signOut()).called(1);
        },
      );

      test('maps a provider failure to the typed failure', () async {
        when(() => client.updateUser(any())).thenThrow(
          const AuthException('Rate limit exceeded', statusCode: '429'),
        );

        final SupabaseAuthResult result = await api.updateUserPassword(
          'new-password-1',
        );

        expect(
          (result as SupabaseAuthFailed).failure.kind,
          SupabaseAuthFailureKind.rateLimited,
        );
      });
    });
  });
}
