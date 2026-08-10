import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../features/messaging/domain/message_gateway.dart';
import '../../../features/messaging/domain/message_thread.dart';
import '../../../features/messaging/presentation/message_cubit.dart';
import '../../../features/messaging/presentation/message_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';

/// Per-matter Messages section on the matter details surface (Phase 10,
/// slice 10.1, owner decisions D-W1/D-W3/D-W4).
///
/// Provides its own [MessageCubit] (feature-scoped, per-section
/// `BlocProvider`) and renders the subset of the synthetic thread list whose
/// [MessageThread.matterRef] equals [matterRef] — a client-side view over the
/// fake list (the D-M5 pattern; there is no per-matter fetch). **Thread
/// metadata only**: each row renders the D-MSG4 title/participants/date
/// fields and nothing else — no message body, no preview, no thread-open
/// affordance, no composer (D-W4 body-less line). An empty per-matter subset
/// renders the localized empty copy (AC-3).
class MatterMessagesSection extends StatelessWidget {
  const MatterMessagesSection({required this.matterRef, super.key});

  /// The matter title to filter by (matches [MessageThread.matterRef],
  /// D-MSG4/D-W2).
  final String matterRef;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MessageCubit>(
      create: (BuildContext context) =>
          MessageCubit(serviceLocator<MessageGateway>()),
      child: _MessagesSectionBody(matterRef: matterRef),
    );
  }
}

class _MessagesSectionBody extends StatefulWidget {
  const _MessagesSectionBody({required this.matterRef});

  final String matterRef;

  @override
  State<_MessagesSectionBody> createState() => _MessagesSectionBodyState();
}

class _MessagesSectionBodyState extends State<_MessagesSectionBody> {
  @override
  void initState() {
    super.initState();
    // Load the synthetic list on open (same pattern as the standalone
    // messages surface); the per-matter subset is filtered client-side
    // below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MessageCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return BlocBuilder<MessageCubit, MessageState>(
      builder: (BuildContext context, MessageState state) {
        return ViewStateSwitch<List<MessageThread>>(
          state: state.threads,
          onRetry: () => context.read<MessageCubit>().load(),
          builder: (BuildContext context, List<MessageThread> threads) =>
              _rows(context, threads, l10n, text, scheme),
          empty: _empty(l10n, text, scheme),
          errorCopy: l10n.messagesError,
          loadingPadding: const EdgeInsetsDirectional.all(
            LegalHubTheme.spaceMd,
          ),
          errorPadding: EdgeInsets.zero,
          errorTextStyle: text.bodySmall?.copyWith(color: scheme.error),
        );
      },
    );
  }

  Widget _rows(
    BuildContext context,
    List<MessageThread> threads,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final List<MessageThread> matched = threads
        .where((MessageThread t) => t.matterRef == widget.matterRef)
        .toList();
    if (matched.isEmpty) {
      return _empty(l10n, text, scheme);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final MessageThread thread in matched) ...<Widget>[
          _ThreadRow(thread: thread),
          const SizedBox(height: LegalHubTheme.spaceSm),
        ],
      ],
    );
  }

  Widget _empty(AppLocalizations l10n, TextTheme text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceXs),
      child: Text(
        l10n.matterWorkspaceMessagesEmpty,
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// A read-only metadata row. Carries **no onTap, no InkWell, no chevron,
/// and no trailing action** — the per-matter view keeps the D-MSG1 body-less
/// line (D-W4), so rows must not read as tappable.
class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread});

  final MessageThread thread;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String date = formatMediumDate(l10n, thread.lastActivityAt);
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
            Text(
              thread.title,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${thread.participants.join(', ')} · $date',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
