import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/matter.dart';
import '../domain/matter_gateway.dart';
import 'matter_cubit.dart';
import 'matter_labels.dart';
import 'matter_state.dart';

/// Matter-dashboard list surface (Phase 7, slice 7.1).
///
/// A `/matters` route that loads the matter list from the [MatterGateway]
/// seam (the dev fake in env-less runs, owner decision D-M2). The status
/// filter is a client-side projection over that list (D-M5); no server
/// search RPC exists. All copy is local-only — the synthetic list must never
/// read as real cases (R1/D-M4). Slice 7.2 adds the read-only details
/// surface, so the list rows are not tappable yet; the tile's tap
/// affordance (and chevron) arrives with details navigation.
class MatterListScreen extends StatelessWidget {
  const MatterListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MatterCubit>(
      create: (BuildContext context) =>
          MatterCubit(serviceLocator<MatterGateway>()),
      child: const _ListSurface(),
    );
  }
}

class _ListSurface extends StatefulWidget {
  const _ListSurface();

  @override
  State<_ListSurface> createState() => _ListSurfaceState();
}

class _ListSurfaceState extends State<_ListSurface> {
  @override
  void initState() {
    super.initState();
    // Load the synthetic list on open (matches the discovery pattern): the
    // cubit's initial state is already loading, and the fake resolves
    // immediately, so the first frame settles straight into the list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MatterCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.matterTitle)),
      body: SafeArea(
        child: BlocBuilder<MatterCubit, MatterState>(
          builder: (BuildContext context, MatterState state) {
            return ListView(
              padding: const EdgeInsetsDirectional.all(
                LegalHubTheme.marginMobile,
              ),
              children: <Widget>[
                _StatusFilterChips(selected: state.status),
                const SizedBox(height: LegalHubTheme.spaceLg),
                _resultsView(context, state, l10n, text, scheme),
                const SizedBox(height: LegalHubTheme.spaceLg),
                Text(
                  l10n.matterLocalOnlyNote,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _resultsView(
    BuildContext context,
    MatterState state,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final MatterCubit cubit = context.read<MatterCubit>();
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.matterEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return switch (state.matters) {
      ViewLoading() => const Padding(
        padding: EdgeInsetsDirectional.all(LegalHubTheme.spaceXl),
        child: Center(child: CircularProgressIndicator()),
      ),
      ViewEmpty() => empty,
      ViewError() => Padding(
        padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.matterError,
              style: text.bodyMedium?.copyWith(color: scheme.error),
            ),
            TextButton(onPressed: cubit.load, child: Text(l10n.retry)),
          ],
        ),
      ),
      // The sealed ViewState set also carries offline/unauthorized variants
      // (shared vocabulary); a synthetic list has neither state, so both
      // render the same empty copy rather than a distinct offline surface.
      ViewOffline() || ViewUnauthorized() => empty,
      ViewSuccess<List<Matter>>() =>
        state.visibleMatters.isEmpty
            ? empty
            : Column(
                children: <Widget>[
                  for (final Matter matter in state.visibleMatters) ...<Widget>[
                    _MatterTile(matter: matter),
                    const SizedBox(height: LegalHubTheme.spaceSm),
                  ],
                ],
              ),
    };
  }
}

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({required this.selected});

  final MatterStatus? selected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MatterCubit cubit = context.read<MatterCubit>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          FilterChip(
            label: Text(l10n.matterFilterAll),
            selected: selected == null,
            onSelected: (_) => cubit.setStatus(null),
          ),
          for (final MatterStatus status in MatterStatus.values) ...<Widget>[
            const SizedBox(width: LegalHubTheme.spaceSm),
            FilterChip(
              label: Text(matterStatusLabel(l10n, status)),
              selected: selected == status,
              onSelected: (bool value) =>
                  cubit.setStatus(value ? status : null),
            ),
          ],
        ],
      ),
    );
  }
}

class _MatterTile extends StatelessWidget {
  const _MatterTile({required this.matter});

  final Matter matter;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.folder_outlined,
                size: 20,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: LegalHubTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    matter.title,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${practiceAreaLabel(l10n, matter.practiceArea)} · ${matter.assignedAttorneyName}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: LegalHubTheme.spaceSm),
            _MatterStatusChip(label: matterStatusLabel(l10n, matter.status)),
          ],
        ),
      ),
    );
  }
}

/// Small colored chip rendering a matter's lifecycle status (the roster's
/// private-chip pattern — feature-local, never a home import).
class _MatterStatusChip extends StatelessWidget {
  const _MatterStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: LegalHubTheme.spaceSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusSm),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}
