import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_auth_api.dart';

/// Initializes the app-level Supabase client with build-time config.
///
/// Lives in the data layer so `main.dart` (app bootstrap) never imports
/// provider types. The URL + anon public key come from `SupabaseEnv`
/// (`--dart-define-from-file=.env`); the anon-key guard in [SupabaseEnv]
/// must have run before this is called so a service-role key is refused
/// before any provider is wired (Batch 3.3).
Future<void> initializeSupabase({
  required String url,
  required String anonKey,
}) {
  // supabase_flutter ^2.16 renamed the param to publishableKey (the anon
  // public key); the env var keeps the dashboard's "anon public" naming.
  //
  // The auth options are stated explicitly (they are already the defaults)
  // to pin the deep-link contract that Phase 4.1 depends on: PKCE flow +
  // `detectSessionInUri: true` (the observer that turns an auth-callback
  // URI into a session). `AuthFlowType.implicit` would be the legacy flow
  // and must not be introduced here.
  return Supabase.initialize(
    url: url,
    publishableKey: anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUri: true,
    ),
  );
}

/// [SupabaseAuthApi] backed by the GoTrue auth client.
///
/// This is the **only** file that imports provider types. It maps
/// [Session] → [SupabaseAuthSnapshot], deliberately dropping access tokens,
/// refresh tokens, and provider objects at the seam (contract §5, §2.6).
/// Every provider call resolves to a typed [SupabaseAuthResult] /
/// [SupabaseSignUpResult]; a GoTrue [AuthException] never crosses this seam.
class SupabaseAuthApiImpl implements SupabaseAuthApi {
  SupabaseAuthApiImpl(this._client) {
    _subscription = _client.onAuthStateChange.listen((AuthState state) {
      _changes.add(
        _toSnapshot(
          state.session,
          // GoTrue fires `passwordRecovery` (not `signedIn`) when the PKCE
          // exchange completes for a recovery link (gotrue
          // `exchangeCodeForSession`). It is the live deep-link signal; the
          // stored `recovery_sent_at` covers the cold-restore case where no
          // event replays.
          recoveredViaLink:
              state.event == AuthChangeEvent.passwordRecovery ||
              state.session?.user.recoverySentAt != null,
        ),
      );
    });
  }

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any client-shaped stub.
  factory SupabaseAuthApiImpl.bind() =>
      SupabaseAuthApiImpl(Supabase.instance.client.auth);

  final GoTrueClient _client;

  /// The app's registered deep-link URI (Phase 4.1): the recovery email's
  /// link target. Must match the Android/iOS intent filters
  /// (`com.legalhub.app` scheme in the Android manifest and
  /// iOS Info.plist).
  static const String _recoveryDeepLinkUri =
      'com.legalhub.app://auth/v1/callback';

  final StreamController<SupabaseAuthSnapshot?> _changes =
      StreamController<SupabaseAuthSnapshot?>.broadcast();
  late final StreamSubscription<AuthState> _subscription;

  @override
  SupabaseAuthSnapshot? get currentSnapshot =>
      _toSnapshot(_client.currentSession);

  @override
  Stream<SupabaseAuthSnapshot?> get snapshotChanges => _changes.stream;

  @override
  Future<SupabaseAuthSnapshot?> restore() async =>
      _toSnapshot(_client.currentSession);

  @override
  Future<SupabaseAuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _client.signInWithPassword(
        email: email,
        password: password,
      );
      return SupabaseAuthSuccess(_toSnapshot(response.session));
    } on AuthException catch (error) {
      return SupabaseAuthFailed(
        SupabaseAuthFailure(
          kind: _failureKindFor(error),
          message: error.message,
        ),
      );
    } on Object {
      return const SupabaseAuthFailed(
        SupabaseAuthFailure(kind: SupabaseAuthFailureKind.providerUnavailable),
      );
    }
  }

  @override
  Future<SupabaseSignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final AuthResponse response = await _client.signUp(
        email: email,
        password: password,
        // The applied handle_new_user trigger reads raw_user_meta_data
        // .display_name to create the profile row, falling back to the full
        // email (02_rls_functions.sql). Send the real name so rosters and
        // greetings resolve it (plan §4); full_name/name mirror it for the
        // client-side session display-name resolution.
        data: <String, dynamic>{
          'display_name': displayName,
          'full_name': displayName,
          'name': displayName,
        },
      );
      final Session? session = response.session;
      final SupabaseAuthSnapshot? snapshot = _toSnapshot(session);
      if (snapshot == null) {
        // Email confirmation is enabled on the dev project: sign-up ends in
        // the pending state — no session is minted until the email confirms.
        return const SupabaseSignUpPending();
      }
      return SupabaseSignUpAuthenticated(snapshot);
    } on AuthException catch (error) {
      return SupabaseSignUpFailed(
        SupabaseAuthFailure(
          kind: _failureKindFor(error),
          message: error.message,
        ),
      );
    } on Object {
      return const SupabaseSignUpFailed(
        SupabaseAuthFailure(kind: SupabaseAuthFailureKind.providerUnavailable),
      );
    }
  }

  @override
  Future<SupabaseAuthResult> resetPasswordForEmail(String email) async {
    try {
      // Phase 4.1: the emailed recovery link is a deep link into the app
      // (`com.legalhub.app://auth/v1/callback`, which must be registered as
      // a Redirect URL on the Supabase dashboard). The dashboard Magic Link
      // template also renders `{{ .Token }}`, so the 6-digit OTP keeps
      // arriving alongside the link and the in-app OTP flow is unchanged
      // (D1 revised, verified live 2026-08-03).
      await _client.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: _recoveryDeepLinkUri,
      );
      // Success carries no session; the provider acknowledges generically
      // (non-enumerating — the client must not reveal whether the account
      // exists).
      return const SupabaseAuthSuccess(null);
    } on AuthException catch (error) {
      return SupabaseAuthFailed(
        SupabaseAuthFailure(
          kind: _failureKindFor(error),
          message: error.message,
        ),
      );
    } on Object {
      return const SupabaseAuthFailed(
        SupabaseAuthFailure(kind: SupabaseAuthFailureKind.providerUnavailable),
      );
    }
  }

  @override
  Future<SupabaseAuthResult> verifyOtp({
    required String email,
    required String code,
  }) async {
    try {
      // Email OTPs are verified with the magiclink type (the provider's
      // "email" OTP path); the dart client's OtpType enum has no 'email'
      // member, and the live provider accepts magiclink for these codes
      // (verified live 2026-08-03).
      final AuthResponse response = await _client.verifyOTP(
        email: email,
        token: code,
        type: OtpType.magiclink,
      );
      // A recovery session is minted on success; the reset step reuses it.
      return SupabaseAuthSuccess(_toSnapshot(response.session));
    } on AuthException catch (error) {
      return SupabaseAuthFailed(
        SupabaseAuthFailure(
          kind: _failureKindFor(error),
          message: error.message,
        ),
      );
    } on Object {
      return const SupabaseAuthFailed(
        SupabaseAuthFailure(kind: SupabaseAuthFailureKind.providerUnavailable),
      );
    }
  }

  @override
  Future<SupabaseAuthResult> updateUserPassword(String newPassword) async {
    try {
      await _client.updateUser(UserAttributes(password: newPassword));
      // Recovery must not leave the app authenticated on the next launch:
      // the verify session is a means to an end, not a sign-in.
      await _client.signOut();
      return const SupabaseAuthSuccess(null);
    } on AuthException catch (error) {
      return SupabaseAuthFailed(
        SupabaseAuthFailure(
          kind: _failureKindFor(error),
          message: error.message,
        ),
      );
    } on Object {
      return const SupabaseAuthFailed(
        SupabaseAuthFailure(kind: SupabaseAuthFailureKind.providerUnavailable),
      );
    }
  }

  @override
  Future<void> signOut() => _client.signOut();

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _changes.close();
  }

  /// Maps a GoTrue [AuthException] to the DTO-free [SupabaseAuthFailureKind]
  /// vocabulary, strictly below the seam. Status codes and message fragments
  /// are the stable GoTrue surface; everything else is
  /// [SupabaseAuthFailureKind.unknown] with the message preserved for
  /// diagnostics.
  SupabaseAuthFailureKind _failureKindFor(AuthException e) {
    // GoTrue reports the status code as a String (gotrue >= 2.26).
    if (e.statusCode == '429') {
      return SupabaseAuthFailureKind.rateLimited;
    }
    final String message = e.message.toLowerCase();
    if (message.contains('email not confirmed')) {
      return SupabaseAuthFailureKind.emailNotConfirmed;
    }
    if (message.contains('invalid login credentials') ||
        message.contains('token has expired') ||
        message.contains('token is invalid') ||
        message.contains('otp expired') ||
        message.contains('invalid token')) {
      return SupabaseAuthFailureKind.invalidCredentials;
    }
    if (message.contains('already registered')) {
      return SupabaseAuthFailureKind.emailInUse;
    }
    if (message.contains('disabled')) {
      return SupabaseAuthFailureKind.userDisabled;
    }
    return SupabaseAuthFailureKind.unknown;
  }

  SupabaseAuthSnapshot? _toSnapshot(
    Session? session, {
    bool recoveredViaLink = false,
  }) {
    final User? user = session?.user;
    if (user == null) {
      return null;
    }
    // A non-null user implies a non-null session (a Session always carries
    // its user), so the bang is sound and reads better than a double-bang.
    final int? expiresAt = session!.expiresAt;
    return SupabaseAuthSnapshot(
      userId: user.id,
      displayName: _displayNameFrom(user),
      expiresAt: expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              expiresAt * Duration.millisecondsPerSecond,
              isUtc: true,
            ),
      // Cold-restore signal: a pending recovery on the user record (the
      // `recovery_sent_at` claim) means the session is a recovery session
      // even when no `passwordRecovery` event replays (e.g. the app was
      // killed between link-open and password change).
      recoveredViaLink: recoveredViaLink || user.recoverySentAt != null,
    );
  }

  /// Display-safe name: `full_name` metadata, then `name`, then the email
  /// local-part. Never the raw email (contract §3.1 privacy note).
  String? _displayNameFrom(User user) {
    final Object? fullName = user.userMetadata?['full_name'];
    if (fullName is String && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    final Object? name = user.userMetadata?['name'];
    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }
    final String? email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return null;
  }
}
