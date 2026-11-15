part of 'booking_screen.dart';

/// Persistent draft summary shown beside the step on expanded windows.
///
/// On a landscape/tablet booking flow the step column stays readable and the
/// user can see what they have chosen so far without walking to the review
/// step. Values reuse the review step's exact labels and formatting.
class _DraftSummaryPanel extends StatelessWidget {
  const _DraftSummaryPanel({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final BookingDraft draft = state.draft;
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        Text(l10n.bookingReviewStep, style: text.titleMedium),
        const SizedBox(height: LegalHubTheme.spaceLg),
        _SummaryRow(
          label: l10n.bookingSummaryType,
          value: draft.category == null
              ? l10n.bookingSummaryNotSet
              : _categoryLabel(l10n, draft.category!),
        ),
        _SummaryRow(
          label: l10n.bookingSummaryTopic,
          value: (draft.topic == null || draft.topic!.isEmpty)
              ? l10n.bookingSummaryNotSet
              : draft.topic!,
        ),
        if (draft.attorneyDisplayName != null)
          _SummaryRow(
            label: l10n.bookingSummaryAttorney,
            value: draft.attorneyDisplayName!,
          ),
        _SummaryRow(
          label: l10n.bookingSummaryTime,
          value: draft.slot == null
              ? l10n.bookingSummaryNotSet
              : '${_slotDateTime(context, draft.slot!)} '
                    '(${l10n.bookingDurationMinutes(draft.slot!.durationMinutes)})',
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
        Text(
          state.isLocalOnly
              ? l10n.bookingLocalOnlyNote
              : l10n.bookingNoPaymentNote,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
