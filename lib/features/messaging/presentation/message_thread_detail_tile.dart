part of 'message_thread_detail_screen.dart';

/// A read-only message row: author + sent date + body. **No tap affordance
/// and no trailing action** — the surface is read-only (D-RT5: no reply, no
/// forward, no delete in this slice).
class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    // Same localized date shape as the list/vault surfaces (yMMMd,
    // locale-aware via l10n.localeName).
    final String date = formatMediumDate(l10n, message.sentAt);
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    message.authorDisplayName,
                    style: text.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  date,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(message.body, style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}
