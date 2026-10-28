import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/auth/session.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart'
    show AuthCubit;
import 'package:legalhub/features/home/domain/home_entries.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'widgets/home_cards.dart';

part 'home_activity_cards.dart';
part 'home_entry_cards.dart';
part 'home_info_row.dart';

/// Home dashboard matching `stitch_legalhub_mobile_app/home_dashboard`.
///
/// Practice areas and recent activity are deterministic sample fixtures; real
/// repositories come with a later data-layer slice. The greeting uses the
/// authenticated session's display name, falling back to the localized
/// `homeFallbackName` (D-T3) when no session is present.
class HomeScreen extends StatefulWidget {
  const HomeScreen({this.capabilitiesForRole = roleCapabilities, super.key});

  /// Test seam mirroring the router's capability injection: home entry
  /// visibility derives from the session role's capabilities (nav hint only).
  final Map<UserRole, RoleCapability> capabilitiesForRole;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Island rebuild: only a session change rebuilds the home scroll view —
    // auth status/error transitions (restore failures, reauth prompts)
    // don't touch it.
    final Session? session = context.select<AuthCubit, Session?>(
      (AuthCubit cubit) => cubit.state.session,
    );
    final String name = session?.displayName ?? l10n.homeFallbackName;
    // UX-only projection of the active membership's role (mirrors the shell);
    // the booking entry is a navigation hint, never an authorization grant.
    final UserRole role = session?.primaryRole ?? UserRole.client;
    final RoleCapability capabilities = capabilityForRole(
      widget.capabilitiesForRole,
      role,
    );
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            const _HomeAppBar(),
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                LegalHubTheme.marginMobile,
                LegalHubTheme.spaceMd,
                LegalHubTheme.marginMobile,
                LegalHubTheme.spaceXl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  _HomeIntro(name: name, searchController: _searchController),
                  ..._homeEntryCards(context, capabilities),
                ]),
              ),
            ),
            const _PracticeAreasHeader(),
            const _PracticeAreasRow(),
            const _RecentActivityHeader(),
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                LegalHubTheme.marginMobile,
                LegalHubTheme.spaceMd,
                LegalHubTheme.marginMobile,
                LegalHubTheme.spaceXl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(_homeActivityCards(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return SliverAppBar(
      pinned: true,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(
        l10n.appTitle,
        style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: LegalHubTheme.spaceSm),
        child: IconButton(
          // The avatar opens the profile surface. A navigation hint only — no
          // new capability is granted.
          tooltip: l10n.profileNavigation,
          onPressed: () => context.push(AppRoutes.profile),
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          // The bell opens the org-scoped notification feed — the same surface
          // the home entry card reaches (D-N1). A navigation hint only, never
          // an authorization grant.
          tooltip: l10n.notificationsFeedTitle,
          onPressed: () => context.push(AppRoutes.notificationsFeed),
        ),
      ],
    );
  }
}

class _HomeIntro extends StatelessWidget {
  const _HomeIntro({required this.name, required this.searchController});

  final String name;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.homeGreeting(name), style: text.displaySmall),
        const SizedBox(height: LegalHubTheme.spaceXs),
        Text(
          l10n.homeSubtitle,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: LegalHubTheme.spaceLg),
        LegalHubTextField(
          controller: searchController,
          hint: l10n.searchPlaceholder,
          prefixIcon: Icons.search,
          textInputAction: TextInputAction.search,
          // Phase 11 wiring (D-S4): submitting the field opens the unified
          // search surface; a blank submission stays put.
          onSubmitted: (String value) {
            final String query = value.trim();
            if (query.isEmpty) {
              return;
            }
            context.push(AppRoutes.searchQuery(query));
          },
        ),
      ],
    );
  }
}

class _PracticeAreasHeader extends StatelessWidget {
  const _PracticeAreasHeader();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          LegalHubTheme.marginMobile,
          0,
          LegalHubTheme.marginMobile,
          LegalHubTheme.spaceXs,
        ),
        child: SectionHeader(
          title: l10n.practiceAreas,
          actionLabel: l10n.viewAll,
          // D-S4 wiring: the label used to render with no `onAction`, so it
          // read as a disabled "VIEW ALL" link. It now opens the discovery
          // surface (a navigation hint only, never an authorization grant).
          onAction: () => context.push(AppRoutes.discovery),
        ),
      ),
    );
  }
}

class _PracticeAreasRow extends StatelessWidget {
  const _PracticeAreasRow();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 200,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: LegalHubTheme.marginMobile,
          ),
          children: <Widget>[
            PracticeAreaCard(
              icon: Icons.gavel,
              label: l10n.areaCriminal,
              // D-S4 wiring: a practice-area card opens discovery pre-narrowed
              // to that area (`/discovery?area=…`). A navigation hint only,
              // never an authorization grant.
              onTap: () =>
                  context.push(AppRoutes.discoveryArea(PracticeArea.criminal)),
            ),
            const SizedBox(width: LegalHubTheme.spaceMd),
            PracticeAreaCard(
              icon: Icons.balance,
              label: l10n.areaCivil,
              onTap: () =>
                  context.push(AppRoutes.discoveryArea(PracticeArea.civil)),
            ),
            const SizedBox(width: LegalHubTheme.spaceMd),
            PracticeAreaCard(
              icon: Icons.domain_outlined,
              label: l10n.areaCorporate,
              onTap: () =>
                  context.push(AppRoutes.discoveryArea(PracticeArea.corporate)),
            ),
            const SizedBox(width: LegalHubTheme.spaceMd),
            PracticeAreaCard(
              icon: Icons.family_restroom,
              label: l10n.areaFamily,
              onTap: () =>
                  context.push(AppRoutes.discoveryArea(PracticeArea.family)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityHeader extends StatelessWidget {
  const _RecentActivityHeader();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          LegalHubTheme.marginMobile,
          LegalHubTheme.spaceLg,
          LegalHubTheme.marginMobile,
          LegalHubTheme.spaceXs,
        ),
        child: SectionHeader(title: l10n.recentActivity),
      ),
    );
  }
}
