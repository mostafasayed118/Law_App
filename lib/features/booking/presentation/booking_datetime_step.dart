part of 'booking_screen.dart';

String _slotDateTime(BuildContext context, BookingSlot slot) {
  final MaterialLocalizations localizations = MaterialLocalizations.of(context);
  final String date = localizations.formatMediumDate(slot.startsAt);
  final String time = TimeOfDay.fromDateTime(slot.startsAt).format(context);
  return '$date · $time';
}

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
          icon: const DirectionalIcon(
            icon: Icons.arrow_forward_outlined,
            mirroredIcon: Icons.arrow_back_outlined,
          ),
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
    return ViewStateSwitch<List<BookingSlot>>(
      state: state.slots,
      onRetry: cubit.retryLoadSlots,
      empty: Text(
        l10n.bookingSlotsEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      errorCopy: l10n.bookingSlotsError,
      builder: (BuildContext context, List<BookingSlot> slots) => Column(
        children: <Widget>[
          for (final BookingSlot slot in slots) ...[
            _SelectableTile(
              selected: state.draft.slot?.id == slot.id,
              icon: Icons.schedule_outlined,
              label: _slotDateTime(context, slot),
              trailingLabel: l10n.bookingDurationMinutes(slot.durationMinutes),
              onTap: () => cubit.selectSlot(slot),
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
          ],
        ],
      ),
    );
  }
}
