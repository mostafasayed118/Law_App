part of 'booking_screen.dart';

String _categoryLabel(AppLocalizations l10n, BookingCategory category) =>
    switch (category) {
      BookingCategory.general => l10n.bookingCategoryGeneral,
      BookingCategory.followUp => l10n.bookingCategoryFollowUp,
      BookingCategory.urgent => l10n.bookingCategoryUrgent,
    };

IconData _categoryIcon(BookingCategory category) => switch (category) {
  BookingCategory.general => Icons.forum_outlined,
  BookingCategory.followUp => Icons.replay_outlined,
  BookingCategory.urgent => Icons.priority_high_outlined,
};

class _CategoryStep extends StatelessWidget {
  const _CategoryStep({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BookingCubit cubit = context.read<BookingCubit>();
    final TextTheme text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        Text(l10n.bookingCategoryStepTitle, style: text.headlineSmall),
        const SizedBox(height: LegalHubTheme.spaceLg),
        for (final BookingCategory category in BookingCategory.values) ...[
          _SelectableTile(
            selected: state.draft.category == category,
            icon: _categoryIcon(category),
            label: _categoryLabel(l10n, category),
            onTap: () => cubit.selectCategory(category),
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
        ],
        const SizedBox(height: LegalHubTheme.spaceMd),
        _TopicField(),
        if (state.draft.attorneyDisplayName != null) ...[
          const SizedBox(height: LegalHubTheme.spaceMd),
          _PrefillNote(name: state.draft.attorneyDisplayName!),
        ],
        const SizedBox(height: LegalHubTheme.spaceLg),
        Text(
          l10n.bookingLocalOnlyNote,
          style: text.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: LegalHubTheme.spaceLg),
        ElevatedButton.icon(
          onPressed: state.draft.category == null
              ? null
              : cubit.continueFromCategory,
          icon: const Icon(Icons.arrow_forward_outlined),
          label: Text(l10n.bookingContinue),
        ),
      ],
    );
  }
}

class _TopicField extends StatefulWidget {
  const _TopicField();

  @override
  State<_TopicField> createState() => _TopicFieldState();
}

class _TopicFieldState extends State<_TopicField> {
  late final TextEditingController _controller = TextEditingController(
    text: context.read<BookingCubit>().state.draft.topic ?? '',
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    context.read<BookingCubit>().updateTopic(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return LegalHubTextField(
      controller: _controller,
      label: l10n.bookingTopicLabel,
      hint: l10n.bookingTopicPlaceholder,
      prefixIcon: Icons.subject_outlined,
    );
  }
}

class _PrefillNote extends StatelessWidget {
  const _PrefillNote({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
      ),
      child: Text(
        l10n.bookingAttorneyPrefill(name),
        style: text.bodySmall?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}
