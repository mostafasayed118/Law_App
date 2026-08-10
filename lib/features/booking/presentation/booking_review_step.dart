part of 'booking_screen.dart';

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BookingCubit cubit = context.read<BookingCubit>();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final BookingDraft draft = state.draft;
    final bool submitting =
        state.submitStatus == BookingSubmitStatus.submitting;
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        Text(l10n.bookingReviewStep, style: text.headlineSmall),
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
              : '${_slotTime(context, draft.slot!)} (${l10n.bookingDurationMinutes(draft.slot!.durationMinutes)})',
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
        Text(
          l10n.bookingLocalOnlyNote,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: LegalHubTheme.spaceLg),
        if (state.submitStatus == BookingSubmitStatus.error) ...[
          Text(
            l10n.bookingConfirmFailed,
            style: text.bodyMedium?.copyWith(color: scheme.error),
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
        ],
        ElevatedButton.icon(
          onPressed: submitting ? null : cubit.confirm,
          icon: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(l10n.bookingConfirm),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        TextButton(
          onPressed: cubit.editCategory,
          child: Text(l10n.bookingEditCategory),
        ),
        TextButton(onPressed: cubit.back, child: Text(l10n.back)),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: LegalHubTheme.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Flexible label (wraps instead of overflowing at narrow widths or
          // large text scales) with the value taking the remaining space.
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: LegalHubTheme.spaceMd),
          Expanded(flex: 3, child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}
