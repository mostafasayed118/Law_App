part of 'view_state_view.dart';

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.label,
    this.child,
    this.action,
  });

  final IconData icon;
  final String label;
  final Widget? child;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center),
          if (child != null) ...<Widget>[const SizedBox(height: 12), child!],
          if (action != null) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              onPressed: action,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ],
      ),
    );
  }
}
