import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../core/roles/user_role.dart';
import '../../../features/auth/presentation/auth_cubit.dart' show AuthCubit;
import '../../../features/billing/presentation/billing_invoices_entry_card.dart';
import '../../../features/booking/presentation/booking_entry_card.dart';
import '../../../features/discovery/presentation/discovery_entry_card.dart';
import '../../../features/documents/presentation/document_entry_card.dart';
import '../../../features/matters/presentation/matter_entry_card.dart';
import '../../../features/messaging/presentation/message_entry_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import 'widgets/home_cards.dart';

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
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    size: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
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
                  if (capabilities.canBookConsultation) ...[
                    const SizedBox(height: LegalHubTheme.spaceLg),
                    BookingEntryCard(onTap: () => context.go(AppRoutes.book)),
                  ],
                  if (capabilities.canViewAttorneyDiscovery) ...[
                    const SizedBox(height: LegalHubTheme.spaceMd),
                    DiscoveryEntryCard(
                      onTap: () => context.go(AppRoutes.discovery),
                    ),
                  ],
                  if (capabilities.canViewMatters) ...[
                    const SizedBox(height: LegalHubTheme.spaceMd),
                    MatterEntryCard(onTap: () => context.go(AppRoutes.matters)),
                  ],
                  if (capabilities.canViewDocuments) ...[
                    const SizedBox(height: LegalHubTheme.spaceMd),
                    DocumentEntryCard(onTap: () => context.go(AppRoutes.vault)),
                  ],
                  if (capabilities.canViewMessages) ...[
                    const SizedBox(height: LegalHubTheme.spaceMd),
                    MessageEntryCard(
                      onTap: () => context.go(AppRoutes.messages),
                    ),
                  ],
                  // Billing slice (D-BI5): the standalone invoices list rides
                  // the same canViewDocuments gate as the per-matter invoices
                  // section — no new role flag (matrix §4: invoices are
                  // matter-scoped content with client/attorney SHIP, same as
                  // documents). Visibility hint only; the RLS gate is
                  // server-side.
                  if (capabilities.canViewDocuments) ...[
                    const SizedBox(height: LegalHubTheme.spaceMd),
                    BillingInvoicesEntryCard(
                      onTap: () => context.go(AppRoutes.invoices),
                    ),
                  ],
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
                      onTap: () {},
                    ),
                    const SizedBox(width: LegalHubTheme.spaceMd),
                    PracticeAreaCard(
                      icon: Icons.balance,
                      label: l10n.areaCivil,
                      onTap: () {},
                    ),
                    const SizedBox(width: LegalHubTheme.spaceMd),
                    PracticeAreaCard(
                      icon: Icons.domain_outlined,
                      label: l10n.areaCorporate,
                      onTap: () {},
                    ),
                    const SizedBox(width: LegalHubTheme.spaceMd),
                    PracticeAreaCard(
                      icon: Icons.family_restroom,
                      label: l10n.areaFamily,
                      onTap: () {},
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
                delegate: SliverChildListDelegate(_activityCards(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _activityCards(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return <Widget>[
      IdentityCard(
        accentColor: scheme.secondary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                StatusChip(label: l10n.activeCaseChip),
                Text(
                  l10n.activeCaseTime,
                  style: text.bodySmall?.copyWith(color: scheme.outline),
                ),
              ],
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(l10n.activeCaseTitle, style: text.headlineMedium),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(
              l10n.activeCaseBody,
              style: text.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        size: 14,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: LegalHubTheme.spaceSm),
                    Text(l10n.activeCaseAttorney, style: text.bodySmall),
                  ],
                ),
                DirectionalIcon(
                  icon: Icons.chevron_right,
                  mirroredIcon: Icons.chevron_left,
                  color: scheme.outline,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: LegalHubTheme.spaceMd),
      _InfoRow(
        icon: Icons.description_outlined,
        iconColor: scheme.onErrorContainer,
        iconBg: scheme.errorContainer,
        title: l10n.actionRequiredTitle,
        body: l10n.actionRequiredBody,
      ),
      const SizedBox(height: LegalHubTheme.spaceMd),
      _InfoRow(
        icon: Icons.event_outlined,
        iconColor: scheme.primary,
        iconBg: scheme.surfaceContainerHighest,
        title: l10n.consultationTitle,
        body: l10n.consultationBody,
      ),
    ];
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusXl),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: iconColor, fill: 1),
            ),
            const SizedBox(width: LegalHubTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(body, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
