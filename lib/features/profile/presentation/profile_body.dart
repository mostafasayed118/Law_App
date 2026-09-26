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

  /// One grouped section card (design review P1b, 2026-09-24): the flat
  /// row list read as ungrouped rows with dead space below. Identity,
  /// session, and danger-zone rows now sit in matching cards in the
  /// AppTile surface language — every existing text is preserved.
  Widget _sectionCard(BuildContext context, List<Widget> children) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: LegalHubTheme.spaceSm),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Session session = widget.session;
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        _sectionCard(context, <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(session.displayName),
            subtitle: Text(l10n.profileNameLabel),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.badge_outlined),
            title: Text(session.userId),
            subtitle: Text(l10n.profileAccountIdLabel),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.work_outline),
            title: RoleLabel(role: session.primaryRole),
            subtitle: Text(l10n.profileRoleLabel),
          ),
        ]),
        const SizedBox(height: LegalHubTheme.spaceMd),
        _sectionCard(context, <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: Text(formatMediumDateTime(l10n, session.expiresAt)),
            subtitle: Text(l10n.profileExpiresLabel),
          ),
        ]),
        const SizedBox(height: LegalHubTheme.spaceMd),
        // Account deletion is irreversible and scoped out of the read-only
        // identity surface above; the error-tinted row makes it unmistakable.
        _sectionCard(context, <Widget>[
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
        ]),
      ],
    );
  }
}
