import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/auth/session.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_gateway.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'package:legalhub/features/search/domain/search_results.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'conflict_check_cubit.dart';

/// One top-level route, same pattern as /search. All rows come from the
/// existing unified-search gateways; recents/watchlist are session-only.
class ConflictCheckScreen extends StatelessWidget {
  const ConflictCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConflictCheckCubit>(
      create: (BuildContext context) => ConflictCheckCubit(
        matters: serviceLocator<MatterGateway>(),
        documents: serviceLocator<DocumentGateway>(),
        messages: serviceLocator<MessageGateway>(),
        attorneys: serviceLocator<AttorneyGateway>(),
        localOnly: backendIsLocalOnly,
      ),
      child: const _ConflictCheckSurface(),
    );
  }
}

class _ConflictCheckSurface extends StatefulWidget {
  const _ConflictCheckSurface();

  @override
  State<_ConflictCheckSurface> createState() => _ConflictCheckSurfaceState();
}

class _ConflictCheckSurfaceState extends State<_ConflictCheckSurface> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Session? session = context.read<AuthCubit>().state.session;
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.menu),
        title: Text(l10n.conflictsCheckTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: l10n.conflictsFilterClient,
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
          children: <Widget>[
            Text(
              l10n.conflictsCheckHeading,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              l10n.conflictsCheckBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            LegalHubTextField(
              controller: _query,
              hint: l10n.conflictsCheckPlaceholder,
              prefixIcon: Icons.search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(context),
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            BlocBuilder<ConflictCheckCubit, ConflictCheckState>(
              builder: (BuildContext context, ConflictCheckState state) => Wrap(
                spacing: LegalHubTheme.spaceSm,
                children: <Widget>[
                  for (final ConflictFilter filter in ConflictFilter.values)
                    FilterChip(
                      label: Text(switch (filter) {
                        ConflictFilter.client => l10n.conflictsFilterClient,
                        ConflictFilter.adverse => l10n.conflictsFilterAdverse,
                        ConflictFilter.related => l10n.conflictsFilterRelated,
                      }),
                      selected: state.filters.contains(filter),
                      onSelected: (_) => context
                          .read<ConflictCheckCubit>()
                          .toggleFilter(filter),
                    ),
                ],
              ),
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            FilledButton.icon(
              onPressed: () => _runSearch(context),
              icon: const Icon(Icons.search),
              label: Text(l10n.conflictsStartSearch),
            ),
            const SizedBox(height: LegalHubTheme.spaceLg),
            BlocBuilder<ConflictCheckCubit, ConflictCheckState>(
              builder: (BuildContext context, ConflictCheckState state) {
                final SearchResults? results = context
                    .read<ConflictCheckCubit>()
                    .visibleResults();
                if (state.results is ViewLoading<SearchResults>) {
                  return const LinearProgressIndicator();
                }
                if (results == null || results.isEmpty) {
                  return Text(l10n.conflictsNoResults);
                }
                final DemoLabels labels = DemoLabels(
                  l10n,
                  localOnly: backendIsLocalOnly,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final Matter matter in results.matters)
                      _resultTile(
                        title: labels.matterTitle(matter.title),
                        subtitle: matter.id,
                        conflict:
                            session != null &&
                            matter.assignedAttorneyName.toLowerCase() !=
                                session.displayName.toLowerCase(),
                        l10n: l10n,
                        onWatch: () => context
                            .read<ConflictCheckCubit>()
                            .addToWatchlist(matter.title),
                      ),
                    for (final Document document in results.documents)
                      _resultTile(
                        title: labels.documentTitle(document.title),
                        subtitle: document.matterRef,
                        conflict: false,
                        l10n: l10n,
                        onWatch: () => context
                            .read<ConflictCheckCubit>()
                            .addToWatchlist(document.title),
                      ),
                    for (final MessageThread thread in results.threads)
                      _resultTile(
                        title: labels.threadTitle(thread.title),
                        subtitle: thread.matterRef,
                        conflict: false,
                        l10n: l10n,
                        onWatch: () => context
                            .read<ConflictCheckCubit>()
                            .addToWatchlist(thread.title),
                      ),
                    for (final Attorney attorney in results.attorneys)
                      _resultTile(
                        title: attorney.name,
                        subtitle: attorney.practiceArea?.name ?? '',
                        conflict: false,
                        l10n: l10n,
                        onWatch: () => context
                            .read<ConflictCheckCubit>()
                            .addToWatchlist(attorney.name),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: LegalHubTheme.spaceLg),
            Text(
              l10n.conflictsWatchlist,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            BlocBuilder<ConflictCheckCubit, ConflictCheckState>(
              builder: (BuildContext context, ConflictCheckState state) =>
                  Column(
                    children: <Widget>[
                      for (final ConflictWatchEntry entry in state.watchlist)
                        ListTile(
                          title: Text(entry.name),
                          subtitle: Text(
                            _relative(entry.lastChecked, l10n, DateTime.now()),
                          ),
                        ),
                    ],
                  ),
            ),
            const SizedBox(height: LegalHubTheme.spaceLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.conflictsRecentSearches,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: context.read<ConflictCheckCubit>().clearHistory,
                  child: Text(l10n.conflictsClearHistory),
                ),
              ],
            ),
            BlocBuilder<ConflictCheckCubit, ConflictCheckState>(
              builder: (BuildContext context, ConflictCheckState state) => Column(
                children: <Widget>[
                  for (final ConflictRecent recent in state.recents)
                    ListTile(
                      title: Text(recent.query),
                      subtitle: Text(
                        '${recent.resultCount} · ${_relative(recent.at, l10n, DateTime.now())}',
                      ),
                      onTap: () {
                        _query.text = recent.query;
                        _runSearch(context, query: recent.query);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _runSearch(BuildContext context, {String? query}) {
    final String text = (query ?? _query.text).trim();
    if (text.isEmpty) {
      return;
    }
    context.read<ConflictCheckCubit>().search(
      text,
      l10n: AppLocalizations.of(context),
    );
  }

  Widget _resultTile({
    required String title,
    required String subtitle,
    required bool conflict,
    required AppLocalizations l10n,
    required VoidCallback onWatch,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        conflict ? '$subtitle · ${l10n.conflictsConflictMarker}' : subtitle,
      ),
      trailing: TextButton(
        onPressed: onWatch,
        child: Text(l10n.conflictsAddWatchlist),
      ),
    );
  }

  String _relative(DateTime at, AppLocalizations l10n, DateTime now) {
    final int seconds = now.difference(at).inSeconds;
    if (seconds < 60) {
      return l10n.conflictsJustNow;
    }
    if (seconds < 3600) {
      return l10n.conflictsMinutesAgo(seconds ~/ 60);
    }
    return l10n.conflictsHoursAgo(seconds ~/ 3600);
  }
}
