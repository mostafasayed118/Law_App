part of 'booking_screen.dart';

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
