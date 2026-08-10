part of 'booking_screen.dart';

String _slotTime(BuildContext context, BookingSlot slot) =>
    TimeOfDay.fromDateTime(slot.startsAt).format(context);

class _DateTimeStep extends StatelessWidget {
  const _DateTimeStep({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BookingCubit cubit = context.read<BookingCubit>();
    final TextTheme text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        Text(l10n.bookingSelectDateTimeStep, style: text.headlineSmall),
        const SizedBox(height: LegalHubTheme.spaceLg),
        _slotsView(context, cubit, l10n, text),
        const SizedBox(height: LegalHubTheme.spaceLg),
        ElevatedButton.icon(
          onPressed: state.draft.slot == null
              ? null
              : cubit.continueFromDateTime,
          icon: const Icon(Icons.arrow_forward_outlined),
          label: Text(l10n.bookingContinue),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        TextButton(onPressed: cubit.back, child: Text(l10n.back)),
      ],
    );
  }

  Widget _slotsView(
    BuildContext context,
    BookingCubit cubit,
    AppLocalizations l10n,
    TextTheme text,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return switch (state.slots) {
      ViewLoading() => const Padding(
        padding: EdgeInsetsDirectional.all(LegalHubTheme.spaceXl),
        child: Center(child: CircularProgressIndicator()),
      ),
      ViewEmpty() => Text(
        l10n.bookingSlotsEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      ViewError() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.bookingSlotsError,
            style: text.bodyMedium?.copyWith(color: scheme.error),
          ),
          TextButton(onPressed: cubit.retryLoadSlots, child: Text(l10n.retry)),
        ],
      ),
      // The sealed ViewState set also carries offline/unauthorized variants
      // (shared vocabulary); a synthetic slot list has neither state, so both
      // render the same empty copy rather than a distinct offline surface.
      ViewOffline() => Text(
        l10n.bookingSlotsEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      ViewUnauthorized() => Text(
        l10n.bookingSlotsEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      ViewSuccess(data: final List<BookingSlot> slots) => Column(
        children: <Widget>[
          for (final BookingSlot slot in slots) ...[
            _SelectableTile(
              selected: state.draft.slot?.id == slot.id,
              icon: Icons.schedule_outlined,
              label: _slotTime(context, slot),
              trailingLabel: l10n.bookingDurationMinutes(slot.durationMinutes),
              onTap: () => cubit.selectSlot(slot),
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
          ],
        ],
      ),
    };
  }
}
