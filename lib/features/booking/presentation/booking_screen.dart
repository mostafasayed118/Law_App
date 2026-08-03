import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/booking_category.dart';
import '../domain/booking_gateway.dart';
import '../domain/booking_prefill.dart';
import '../domain/booking_slot.dart';
import 'booking_cubit.dart';
import 'booking_state.dart';

/// Consultation-booking wizard (Phase 5 slice 5.1).
///
/// A single `/book` route with an internal step switcher (scope note D-B4):
/// the draft lives in [BookingCubit] state and is never threaded through
/// route parameters or GoRouter `extra`. The cubit is feature-scoped and
/// created here via [BlocProvider]; it resolves the [BookingGateway] from the
/// service locator (the dev fake in env-less runs). All copy is local-only —
/// no live-payment wording and no backend promise (D-B3/D-B6).
class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BookingCubit>(
      create: (BuildContext context) {
        // Phase 6 D-A3: a discovery profile may pre-fill the booking with an
        // optional attorney before navigating here. The prefill is consumed
        // once at cubit creation and cleared, so a later standalone /book
        // visit starts fresh (AC-5). It never travels in route params or
        // GoRouter extra (D-B4).
        final BookingPrefill prefill = serviceLocator<BookingPrefill>();
        final BookingCubit cubit = BookingCubit(
          serviceLocator<BookingGateway>(),
          attorneyId: prefill.attorneyId,
          attorneyName: prefill.attorneyName,
        );
        prefill.clear();
        return cubit;
      },
      child: const _BookingWizard(),
    );
  }
}

class _BookingWizard extends StatelessWidget {
  const _BookingWizard();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bookingTitle),
        leading: BackButton(
          onPressed: () {
            final BookingState state = context.read<BookingCubit>().state;
            // The wizard shell's back button steps back one step; on the
            // first (category) step and the terminal (success) step it exits
            // to home (scope note D-B4, cubit `back()` semantics).
            if (state.step == BookingStep.category ||
                state.step == BookingStep.success) {
              context.go(AppRoutes.home);
            } else {
              context.read<BookingCubit>().back();
            }
          },
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<BookingCubit, BookingState>(
          builder: (BuildContext context, BookingState state) {
            return switch (state.step) {
              BookingStep.category => _CategoryStep(state: state),
              BookingStep.dateTime => _DateTimeStep(state: state),
              BookingStep.review => _ReviewStep(state: state),
              BookingStep.success => _SuccessStep(state: state),
            };
          },
        ),
      ),
    );
  }
}

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

String _slotTime(BuildContext context, BookingSlot slot) =>
    TimeOfDay.fromDateTime(slot.startsAt).format(context);

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
          TextButton(
            onPressed: cubit.continueFromCategory,
            child: Text(l10n.retry),
          ),
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
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
        children: <Widget>[
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: scheme.secondary,
            fill: 1,
          ),
          const SizedBox(height: LegalHubTheme.spaceLg),
          Text(
            l10n.bookingSuccessTitle,
            textAlign: TextAlign.center,
            style: text.headlineMedium,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(
            l10n.bookingSuccessBody(state.confirmation?.referenceId ?? '—'),
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          Text(
            l10n.bookingLocalOnlyNote,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.home),
            child: Text(l10n.bookingDone),
          ),
        ],
      ),
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

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.selected,
    required this.icon,
    required this.label,
    this.trailingLabel,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final String? trailingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: scheme.onSurfaceVariant, fill: 1),
              const SizedBox(width: LegalHubTheme.spaceMd),
              Expanded(
                child: Text(
                  label,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (trailingLabel != null)
                Text(
                  trailingLabel!,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (selected) const SizedBox(width: LegalHubTheme.spaceSm),
              if (selected)
                Icon(Icons.check_circle, size: 18, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
