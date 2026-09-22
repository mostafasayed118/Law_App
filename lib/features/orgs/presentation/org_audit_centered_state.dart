part of 'org_audit_screen.dart';

/// The centered icon-state shell shared by the empty / denied / failed
/// arms — Candidate B consolidation (the three previously duplicated this
/// exact `Center` → `Padding(marginMobile)` → `Column(min)` → `Icon(40)` +
/// `spaceMd` → centered `Text` shape). The optional [action] renders after
/// another `spaceMd` gap (the failed arm's retry button).
class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: LegalHubTheme.spaceMd),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...<Widget>[
              const SizedBox(height: LegalHubTheme.spaceMd),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
