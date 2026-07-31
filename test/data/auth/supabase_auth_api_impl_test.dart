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
  });
}
