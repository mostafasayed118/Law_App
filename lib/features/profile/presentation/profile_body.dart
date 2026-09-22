part of 'profile_screen.dart';

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.session});

  final Session session;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  bool _deleting = false;

  /// Deletes the caller's identity (Phase 2 slice 2.2): a redaction-safe
  /// confirm first, then `delete_my_account` (the only removal path — D-05)
  /// and a session sign-out. Every failure surfaces as a localized,
  /// non-sensitive message; the session stays alive until success.
  Future<void> _deleteAccount() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteAccountConfirmTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.deleteAccountConfirmBody),
          const SizedBox(height: LegalHubTheme.spaceSm),
          // P3.4: audit-survives semantics stated in copy — retained by
          // law, never promised as data recovery.
          Text(
            l10n.deleteAccountAuditNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      confirmLabel: l10n.deleteAccountConfirmAction,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    // The destructive call AND the session-ending sign-out live on AuthCubit
    // (audit 2026-09-21, H-4; owner decision OI-D1) — this screen no longer
    // touches OrganizationGateway. On success the cubit ends the session, so
    // the auth gate redirects to sign-in instead of showing a stale identity.
    final OrgFailureKind? failureKind = await context
        .read<AuthCubit>()
        .deleteAccount();
    if (!mounted) {
      return;
    }
    setState(() => _deleting = false);
    if (failureKind != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(orgErrorMessage(l10n, failureKind))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Session session = widget.session;
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(session.displayName),
          subtitle: Text(l10n.profileNameLabel),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.badge_outlined),
          title: Text(session.userId),
          subtitle: Text(l10n.profileAccountIdLabel),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.work_outline),
          title: RoleLabel(role: session.primaryRole),
          subtitle: Text(l10n.profileRoleLabel),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_outlined),
          title: Text(formatMediumDateTime(l10n, session.expiresAt)),
          subtitle: Text(l10n.profileExpiresLabel),
        ),
        const SizedBox(height: LegalHubTheme.spaceLg),
        const Divider(),
        const SizedBox(height: LegalHubTheme.spaceSm),
        // Account deletion is irreversible and scoped out of the read-only
        // identity surface above; the error-tinted row makes it unmistakable.
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: !_deleting,
          leading: _deleting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
          title: Text(
            l10n.deleteAccountAction,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: _deleting ? null : _deleteAccount,
        ),
      ],
    );
  }
}
