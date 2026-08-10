import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../app/service_locator.dart';
import '../../../core/practice_area.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/attorney.dart';
import '../domain/attorney_gateway.dart';
import 'discovery_cubit.dart';
import 'discovery_state.dart';

/// Attorney-discovery search surface (Phase 6, slice 6.1).
///
/// A `/discovery` route that loads the profile list from the [AttorneyGateway]
/// seam (the dev fake in env-less runs, owner decision D-A2). Search is a
/// client-side filter over that list (D-A5): a free-text query plus
/// practice-area chips; no server search RPC exists. All copy is local-only —
/// the synthetic list must never read as a real directory (R1/D-A4). Profile
/// navigation lands in slice 6.2, so the list rows are not tappable yet; the
/// tile's tap affordance (and chevron) arrives with profile navigation.
class AttorneySearchScreen extends StatelessWidget {
  const AttorneySearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DiscoveryCubit>(
      create: (BuildContext context) =>
          DiscoveryCubit(serviceLocator<AttorneyGateway>()),
      child: const _SearchSurface(),
    );
  }
}

class _SearchSurface extends StatefulWidget {
  const _SearchSurface();

  @override
  State<_SearchSurface> createState() => _SearchSurfaceState();
}

class _SearchSurfaceState extends State<_SearchSurface> {
  @override
  void initState() {
    super.initState();
    // Load the synthetic list on open (matches the roster pattern): the
    // cubit's initial state is already loading, and the fake resolves
    // immediately, so the first frame settles straight into the list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<DiscoveryCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.discoveryTitle)),
      body: SafeArea(
        child: BlocBuilder<DiscoveryCubit, DiscoveryState>(
          builder: (BuildContext context, DiscoveryState state) {
            final DiscoveryCubit cubit = context.read<DiscoveryCubit>();
            return ListView(
              padding: const EdgeInsetsDirectional.all(
                LegalHubTheme.marginMobile,
              ),
              children: <Widget>[
                const _SearchField(),
                const SizedBox(height: LegalHubTheme.spaceMd),
                AppFilterChips<PracticeArea>(
                  values: PracticeArea.values,
                  selected: state.practiceArea,
                  allLabel: l10n.discoveryFilterAll,
                  labelOf: (PracticeArea area) => practiceAreaLabel(l10n, area),
                  onSelected: cubit.setPracticeArea,
                ),
                const SizedBox(height: LegalHubTheme.spaceLg),
                _resultsView(context, state, l10n, text, scheme),
                const SizedBox(height: LegalHubTheme.spaceLg),
                Text(
                  l10n.discoveryLocalOnlyNote,
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
    DiscoveryState state,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final DiscoveryCubit cubit = context.read<DiscoveryCubit>();
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.discoveryEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return ViewStateSwitch<List<Attorney>>(
      state: state.attorneys,
      onRetry: cubit.load,
      builder: (BuildContext context, List<Attorney> attorneys) =>
          state.visibleAttorneys.isEmpty
          ? empty
          : Column(
              children: <Widget>[
                for (final Attorney attorney
                    in state.visibleAttorneys) ...<Widget>[
                  _AttorneyTile(
                    attorney: attorney,
                    onTap: () =>
                        context.go(AppRoutes.attorneyProfile(attorney.id)),
                  ),
                  const SizedBox(height: LegalHubTheme.spaceSm),
                ],
              ],
            ),
      empty: empty,
      errorCopy: l10n.discoveryError,
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    context.read<DiscoveryCubit>().updateQuery(_controller.text);
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
      hint: l10n.discoverySearchHint,
      prefixIcon: Icons.search,
    );
  }
}

class _AttorneyTile extends StatelessWidget {
  const _AttorneyTile({required this.attorney, required this.onTap});

  final Attorney attorney;

  /// Phase 6 slice 6.2: tapping a row opens the attorney profile route.
  final VoidCallback onTap;

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
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  attorney.name.isEmpty
                      ? '?'
                      : attorney.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: LegalHubTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      attorney.name,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${practiceAreaLabel(l10n, attorney.practiceArea)} · ${attorney.locale}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
