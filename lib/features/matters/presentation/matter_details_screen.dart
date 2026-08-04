import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/roles/user_role.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/matter.dart';
import '../domain/matter_gateway.dart';
import 'matter_cubit.dart';
import 'matter_documents_section.dart';
import 'matter_labels.dart';
import 'matter_messages_section.dart';
import 'matter_state.dart';
import 'matter_status_chip.dart';

/// Read-only matter details surface (Phase 7, slice 7.2).
///
/// Mirrors the attorney-profile pattern (Phase 6, 6.2): the screen provides
/// its own [MatterCubit], loads the synthetic list on open, and resolves the
/// matter by id from the loaded list — the D-M2 seam stays a single-method
/// gateway (no per-id fetch exists). The projection is read-only (AC-3,
/// D-M1): title, status chip, practice area, assigned attorney, created
/// date, and the local-only demo note (R1). There are **no action buttons**
/// anywhere on the surface — create/edit/close/upload are outside the
/// read-first line and stay deferred (§14). Phase 10 adds the per-matter
/// workspace sections (Documents + Messages, D-W1), each gated by its
/// capability flag (D-W5).
class MatterDetailsScreen extends StatelessWidget {
  const MatterDetailsScreen({
    required this.matterId,
    required this.capabilities,
    super.key,
  });

  final String matterId;

  /// UX-only capability projection for the workspace sections (D-W5): the
  /// Documents section renders only under [RoleCapability.canViewDocuments]
  /// and the Messages section under [RoleCapability.canViewMessages].
  /// Navigation hints only — never authorization.
  final RoleCapability capabilities;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MatterCubit>(
      create: (BuildContext context) =>
          MatterCubit(serviceLocator<MatterGateway>()),
      child: _DetailsSurface(matterId: matterId, capabilities: capabilities),
    );
  }
}

class _DetailsSurface extends StatefulWidget {
  const _DetailsSurface({required this.matterId, required this.capabilities});

  final String matterId;
  final RoleCapability capabilities;

  @override
  State<_DetailsSurface> createState() => _DetailsSurfaceState();
}

class _DetailsSurfaceState extends State<_DetailsSurface> {
  @override
  void initState() {
    super.initState();
    // Load the synthetic list on open (same pattern as the list surface);
    // the details are resolved from the loaded list by id.
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.matterDetailsTitle)),
      body: SafeArea(
        child: BlocBuilder<MatterCubit, MatterState>(
          builder: (BuildContext context, MatterState state) {
            return switch (state.matters) {
              ViewLoading() => const Center(child: CircularProgressIndicator()),
              ViewEmpty() => _message(l10n, l10n.matterDetailsNotFound),
              ViewError() => _error(context, l10n),
              // The sealed ViewState set also carries offline/unauthorized
              // variants (shared vocabulary); a synthetic list has neither
              // state, so both render the not-found copy.
              ViewOffline() ||
              ViewUnauthorized() => _message(l10n, l10n.matterDetailsNotFound),
              ViewSuccess(data: final List<Matter> matters) => _details(
                context,
                l10n,
                _findById(matters, widget.matterId),
              ),
            };
          },
        ),
      ),
    );
  }

  Matter? _findById(List<Matter> matters, String id) {
    for (final Matter matter in matters) {
      if (matter.id == id) {
        return matter;
      }
    }
    return null;
  }

  Widget _message(AppLocalizations l10n, String text) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceLg),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _error(BuildContext context, AppLocalizations l10n) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.matterError,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.error),
          ),
          TextButton(
            onPressed: () => context.read<MatterCubit>().load(),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _details(BuildContext context, AppLocalizations l10n, Matter? matter) {
    if (matter == null) {
      return _message(l10n, l10n.matterDetailsNotFound);
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    // Same localized date shape as the profile surface (yMMMd, locale-aware).
    final DateFormat createdFormat = DateFormat.yMMMd(l10n.localeName);
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        Text(matter.title, style: text.headlineSmall),
        const SizedBox(height: LegalHubTheme.spaceMd),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MatterStatusChip(
            label: matterStatusLabel(l10n, matter.status),
          ),
        ),
        const SizedBox(height: LegalHubTheme.spaceXl),
        _DetailRow(
          label: l10n.matterDetailsPracticeArea,
          value: practiceAreaLabel(l10n, matter.practiceArea),
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
        _DetailRow(
          label: l10n.matterDetailsAssignedAttorney,
          value: matter.assignedAttorneyName,
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
        _DetailRow(
          label: l10n.matterDetailsCreated,
          value: createdFormat.format(matter.createdAt),
        ),
        const SizedBox(height: LegalHubTheme.spaceLg),
        if (widget.capabilities.canViewDocuments) ...<Widget>[
          Text(
            l10n.matterWorkspaceDocumentsTitle,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          MatterDocumentsSection(matterRef: matter.title),
          const SizedBox(height: LegalHubTheme.spaceXl),
        ],
        if (widget.capabilities.canViewMessages) ...<Widget>[
          Text(
            l10n.matterWorkspaceMessagesTitle,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          MatterMessagesSection(matterRef: matter.title),
          const SizedBox(height: LegalHubTheme.spaceXl),
        ],
        Text(
          l10n.matterLocalOnlyNote,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// A labeled read-only value row (label above, value below) — the details
/// projection is display-only; there is no edit affordance on the row (AC-3).
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: text.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: text.bodyMedium),
      ],
    );
  }
}
