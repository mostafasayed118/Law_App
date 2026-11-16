import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/responsive/breakpoints.dart';
import 'package:legalhub/shared/widgets/search_action.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'matter_cubit.dart';
import 'matter_details_screen.dart';
import 'matter_labels.dart';
import 'matter_state.dart';
import 'matter_status_chip.dart';

part 'matter_list_surface.dart';

/// Matter-dashboard list surface (Phase 7, slice 7.1).
///
/// A `/matters` route that loads the matter list from the [MatterGateway]
/// seam (the dev fake in env-less runs, owner decision D-M2). The status
/// filter is a client-side projection over that list (D-M5); no server
/// search RPC exists. All copy is local-only — the synthetic list must never
/// read as real cases (R1/D-M4). Tapping a row (slice 7.2) navigates to the
/// read-only details surface (`/matters/:id`, AC-3).
///
/// On expanded windows (≥840dp) the screen is a two-pane master/detail: the
/// list stays on the left and the selected matter renders on the right, so a
/// tablet/desktop user does not lose the list on every tap. Compact/medium
/// windows keep the push-navigation behavior byte-for-byte.
///
/// The list RE-READS itself when the create screen closes (W4, 2026-10-21):
/// the create screen runs its own cubit, so without that re-read a matter
/// created from the FAB never appeared in the list.
class MatterListScreen extends StatefulWidget {
  const MatterListScreen({
    super.key,
    this.canCreateMatter = false,
    this.capabilities = const RoleCapability(),
    this.initialSelectedMatterId,
  });

  /// F-01 step 2 client swap (C-D6/Q5): whether the create-matter entry is
  /// offered. A UX-only partner gate resolved by the router (the shell's
  /// capability pattern); `create_matter` re-asserts F2-D1 server-side, so
  /// this is a navigation hint, never an authorization grant.
  final bool canCreateMatter;

  /// UX-only capability projection used by the embedded details pane on
  /// expanded windows (the workspace sections, D-W5). Navigation hints only.
  final RoleCapability capabilities;

  /// Deep-link projection: `/matters/:id` on an expanded window opens the
  /// two-pane with this matter selected instead of a standalone details page.
  final String? initialSelectedMatterId;

  @override
  State<MatterListScreen> createState() => _MatterListScreenState();
}

class _MatterListScreenState extends State<MatterListScreen> {
  String? _selectedMatterId;

  @override
  void initState() {
    super.initState();
    _selectedMatterId = widget.initialSelectedMatterId;
  }

  @override
  void didUpdateWidget(MatterListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedMatterId != oldWidget.initialSelectedMatterId) {
      _selectedMatterId = widget.initialSelectedMatterId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Device-class decision on the WINDOW width, not the capped content
    // width: at 1024 with a text-scaled rail the content column is ~812,
    // which would otherwise flip the two-pane off on a desktop window.
    final bool twoPane =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    return BlocProvider<MatterCubit>(
      create: (BuildContext context) =>
          MatterCubit(serviceLocator<MatterGateway>()),
      child: twoPane
          ? _buildTwoPane(context, l10n)
          : _ListSurface(canCreateMatter: widget.canCreateMatter),
    );
  }

  Widget _buildTwoPane(BuildContext context, AppLocalizations l10n) {
    final String? selectedId = _selectedMatterId;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.matterTitle),
        actions: <Widget>[SearchAction(label: l10n.searchTitle)],
      ),
      floatingActionButton: widget.canCreateMatter
          ? FloatingActionButton.extended(
              onPressed: () => _openMatterCreate(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.matterCreateFab),
            )
          : null,
      body: SafeArea(
        child: TwoPane(
          list: _ListSurface(
            embedded: true,
            canCreateMatter: widget.canCreateMatter,
            selectedMatterId: selectedId,
            onSelectMatter: (String id) =>
                setState(() => _selectedMatterId = id),
          ),
          detail: selectedId == null
              ? AppCenteredMessage(text: l10n.matterDetailsTitle)
              : MatterDetailsScreen(
                  // A new selection must rebuild the matter-scoped workspace
                  // cubit, so the key carries the id.
                  key: ValueKey<String>(selectedId),
                  matterId: selectedId,
                  capabilities: widget.capabilities,
                  embedded: true,
                ),
        ),
      ),
    );
  }
}

/// Opens the create screen and RE-READS the list when it closes (W4,
/// 2026-10-21). Shared by the standalone list scaffold and the two-pane FAB.
Future<void> _openMatterCreate(BuildContext context) async {
  await context.push(AppRoutes.matterCreate);
  if (!context.mounted) {
    return;
  }
  await context.read<MatterCubit>().load();
}
