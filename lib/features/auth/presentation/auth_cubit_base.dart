part of 'auth_cubit.dart';

/// The cubit's shared seams + concurrency flags, split out so the
/// hydration and org-flow method groups can live in library-private
/// mixins reading the exact same instances.
class _AuthCubitBase extends Cubit<AuthState> {
  _AuthCubitBase(
    this._gateway,
    this._reporter,
    this._membershipRepository,
    this._organizationGateway,
  ) : super(_initialState(_gateway.currentSession));

  final AuthGateway _gateway;
  final ErrorReporter _reporter;

  /// RLS-scoped membership source for [Session.memberships] hydration
  /// (P3.2): called on every explicit authenticated outcome, never on a
  /// failure, never on an expired session (AC-3), and by [hydrate] for
  /// background refreshes (P3.3 Slice A).
  final MembershipRepository _membershipRepository;

  /// The organization seam, used by the two session-level account flows that
  /// used to be driven from the screens: [deleteAccount] and
  /// [acceptInvitation] (audit 2026-09-21, H-4).
  final OrganizationGateway _organizationGateway;
  late final StreamSubscription<Session?> _sessionSubscription;

  /// True while an explicit operation ([restore], [signIn], [startDemoSession],
  /// [signOut]) is awaiting its gateway outcome.
  ///
  /// The gateway stream replays the session during these calls, and the
  /// replay's emission would preempt the explicit outcome mapping. Letting
  /// the outcome mapping own the emission keeps the state change on the
  /// caller's zone (widget tests construct the cubit outside the FakeAsync
  /// zone; a replay emit there would be delivered to nobody). The listener
  /// therefore only applies provider-initiated changes (the deep-link PKCE
  /// exchange), which never go through an explicit call.
  bool _explicitOperationInFlight = false;

  /// True while a background [hydrate] refresh is awaiting the repository.
  ///
  /// Distinct from [_explicitOperationInFlight]: hydrate must not suppress
  /// the provider stream listener (a provider-initiated session must still
  /// land mid-refresh), but concurrent hydrate calls must not stack — the
  /// first one owns the emission.
  bool _hydrationInFlight = false;

  /// Bumped whenever an explicit authenticated operation runs its hydration
  /// or a sign-out completes (P3.3 Slice A review fix).
  ///
  /// [hydrate] captures the epoch when it starts and applies its refresh
  /// only if the epoch is unchanged: an explicit op that started (or
  /// completed) while the refresh was awaiting owns the emission — its
  /// hydration is fresher, so a same-user re-auth must never be clobbered by
  /// the late-resolving refresh. The provider stream path does not bump it
  /// (it never hydrates; a refresh enriching a stream session is desirable).
  int _hydrationEpoch = 0;

  /// True while the current session is a password-recovery session (Phase
  /// 4.1 deep-link variant). Mirrors the gateway's provider-derived signal
  /// (GoTrue `passwordRecovery` event or a pending `recovery_sent_at`), so
  /// the router can land a recovery session on the reset step instead of
  /// treating it as a normal sign-in. Clears on sign-out.
  bool get recoveryPending => _gateway.recoveryPending;

  /// Whether the sign-in screen should render the demo shortcut: derived
  /// from the gateway (dev fake → true, configured provider → false), so
  /// presentation never ships a demo button that can only fail
  /// (audit 2026-09-21, H-5). Static per seam — never changes per state.
  bool get supportsDemoSession => _gateway.supportsDemoSession;

  /// Bootstrap initial state is derived from the gateway's current session.
  /// There is no provider restore at boot (no session source exists yet), so
  /// a null current session is honestly `unauthenticated`, not `restoring`.
  /// An already-expired current session must not boot into `authenticated`
  /// (contract §5: expiry → re-authentication, never a misleading
  /// authenticated state).
  static AuthState _initialState(Session? session) {
    if (session == null) {
      return const AuthState.unauthenticated();
    }
    if (session.isExpired) {
      return const AuthState(status: AuthStatus.reauthRequired);
    }
    return AuthState(status: AuthStatus.authenticated, session: session);
  }
}
