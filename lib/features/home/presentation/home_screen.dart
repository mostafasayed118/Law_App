import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../core/practice_area.dart';
import '../../../core/roles/user_role.dart';
import '../../../features/approvals/presentation/approvals_entry_card.dart';
import '../../../features/auth/presentation/auth_cubit.dart' show AuthCubit;
import '../../../features/billing/presentation/billing_invoices_entry_card.dart';
import '../../../features/booking/presentation/booking_entry_card.dart';
import '../../../features/compliance/presentation/compliance_alerts_entry_card.dart';
import '../../../features/discovery/presentation/discovery_entry_card.dart';
import '../../../features/documents/presentation/document_entry_card.dart';
import '../../../features/matters/presentation/matter_entry_card.dart';
import '../../../features/messaging/presentation/message_entry_card.dart';
import '../../../features/notifications/presentation/notification_feed_entry_card.dart';
import '../../../features/research/presentation/ai_research_entry_card.dart';
import '../../../features/tasks/presentation/task_board_entry_card.dart';
import '../../../features/video/presentation/video_entry_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import 'widgets/home_cards.dart';
part 'home_entry_cards.dart';
part 'home_activity_cards.dart';
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final AuthCubit authCubit = context.watch<AuthCubit>();
    final String name =
        authCubit.state.session?.displayName ?? l10n.homeFallbackName;
    // UX-only projection of the active membership's role (mirrors the shell);
    // the booking entry is a navigation hint, never an authorization grant.
    final UserRole role =
        authCubit.state.session?.primaryRole ?? UserRole.client;
    final RoleCapability capabilities = widget.capabilitiesForRole[role]!;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              backgroundColor: scheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Text(
                l10n.appTitle,
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
              leading: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: LegalHubTheme.spaceSm,
                ),
                child: IconButton(
                  // The avatar opens the profile surface. A navigation hint
                  // only — no new capability is granted.
                  tooltip: l10n.profileNavigation,
                  onPressed: () => context.go(AppRoutes.profile),
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
                  // The bell opens the org-scoped notification feed — the
                  // same surface the home entry card reaches (D-N1). A
                  // navigation hint only, never an authorization grant.
                  tooltip: l10n.notificationsFeedTitle,
                  onPressed: () => context.go(AppRoutes.notificationsFeed),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                LegalHubTheme.marginMobile,
                LegalHubTheme.spaceMd,
                LegalHubTheme.marginMobile,
                LegalHubTheme.spaceXl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  Text(l10n.homeGreeting(name), style: text.displaySmall),
                  const SizedBox(height: LegalHubTheme.spaceXs),
                  Text(
                    l10n.homeSubtitle,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: LegalHubTheme.spaceLg),
                  LegalHubTextField(
                    controller: _searchController,
                    hint: l10n.searchPlaceholder,
                    prefixIcon: Icons.search,
                    textInputAction: TextInputAction.search,
                    // Phase 11 wiring (D-S4): submitting the field opens the
                    // unified search surface; a blank submission stays put.
                    onSubmitted: (String value) {
                      final String query = value.trim();
                      if (query.isEmpty) {
                        return;
                      }
                      context.go(AppRoutes.searchQuery(query));
                    },
                  ),
                  ..._homeEntryCards(context, capabilities),
                ]),
              ),
            ),
            SliverToBoxAdapter(
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
                ),
              ),
            ),
            SliverToBoxAdapter(
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
                      // D-S4 wiring: a practice-area card opens discovery
                      // pre-narrowed to that area (`/discovery?area=…`). A
                      // navigation hint only, never an authorization grant.
                      onTap: () =>
                          context.go(AppRoutes.discoveryArea(PracticeArea.criminal)),
                    ),
                    const SizedBox(width: LegalHubTheme.spaceMd),
                    PracticeAreaCard(
                      icon: Icons.balance,
                      label: l10n.areaCivil,
                      onTap: () =>
                          context.go(AppRoutes.discoveryArea(PracticeArea.civil)),
                    ),
                    const SizedBox(width: LegalHubTheme.spaceMd),
                    PracticeAreaCard(
                      icon: Icons.domain_outlined,
                      label: l10n.areaCorporate,
                      onTap: () => context.go(
                        AppRoutes.discoveryArea(PracticeArea.corporate),
                      ),
                    ),
                    const SizedBox(width: LegalHubTheme.spaceMd),
                    PracticeAreaCard(
                      icon: Icons.family_restroom,
                      label: l10n.areaFamily,
                      onTap: () =>
                          context.go(AppRoutes.discoveryArea(PracticeArea.family)),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  LegalHubTheme.marginMobile,
                  LegalHubTheme.spaceLg,
                  LegalHubTheme.marginMobile,
                  LegalHubTheme.spaceXs,
                ),
                child: SectionHeader(title: l10n.recentActivity),
              ),
            ),
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
