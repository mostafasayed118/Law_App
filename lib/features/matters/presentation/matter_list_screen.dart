import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../app/service_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/matter.dart';
import '../domain/matter_gateway.dart';
import 'matter_cubit.dart';
import 'matter_labels.dart';
import 'matter_state.dart';
import 'matter_status_chip.dart';

/// Matter-dashboard list surface (Phase 7, slice 7.1).
///
/// A `/matters` route that loads the matter list from the [MatterGateway]
/// seam (the dev fake in env-less runs, owner decision D-M2). The status
/// filter is a client-side projection over that list (D-M5); no server
/// search RPC exists. All copy is local-only — the synthetic list must never
/// read as real cases (R1/D-M4). Tapping a row (slice 7.2) navigates to the
/// read-only details surface (`/matters/:id`, AC-3).
class MatterListScreen extends StatelessWidget {
  const MatterListScreen({super.key, this.canCreateMatter = false});

  /// F-01 step 2 client swap (C-D6/Q5): whether the create-matter entry is
  /// offered. A UX-only partner gate resolved by the router (the shell's
  /// capability pattern); `create_matter` re-asserts F2-D1 server-side, so
  /// this is a navigation hint, never an authorization grant.
  final bool canCreateMatter;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MatterCubit>(
      create: (BuildContext context) =>
          MatterCubit(serviceLocator<MatterGateway>()),
      child: _ListSurface(canCreateMatter: canCreateMatter),
    );
  }
}

class _ListSurface extends StatefulWidget {
  const _ListSurface({required this.canCreateMatter});

  final bool canCreateMatter;

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
      // F-01 step 2 client swap: the partner-gated create entry (C-D6/Q5) —
      // a FAB over the read-first list. The server re-asserts F2-D1.
      floatingActionButton: widget.canCreateMatter
          ? FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.matterCreate),
              icon: const Icon(Icons.add),
              label: Text(l10n.matterCreateFab),
            )
          : null,
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
    return ViewStateSwitch<List<Matter>>(
      state: state.matters,
      onRetry: cubit.load,
      builder: (BuildContext context, List<Matter> matters) =>
          state.visibleMatters.isEmpty
          ? empty
          : Column(
              children: <Widget>[
                for (final Matter matter in state.visibleMatters) ...<Widget>[
                  AppTile(
                    icon: Icons.folder_outlined,
                    title: matter.title,
                    subtitles: <String>[
                      '${practiceAreaLabel(l10n, matter.practiceArea)} · ${matter.assignedAttorneyName}',
                    ],
                    trailing: Wrap(
                      spacing: LegalHubTheme.spaceSm,
                      runSpacing: LegalHubTheme.spaceSm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        MatterStatusChip(
                          label: matterStatusLabel(l10n, matter.status),
                        ),
                      ],
                    ),
                    onTap: () => context.go(AppRoutes.matterDetail(matter.id)),
                  ),
                  const SizedBox(height: LegalHubTheme.spaceSm),
                ],
              ],
            ),
      empty: empty,
      errorCopy: l10n.matterError,
    );
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
