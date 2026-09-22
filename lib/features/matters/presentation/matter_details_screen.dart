import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/roles/user_role.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/matter.dart';
import '../domain/matter_gateway.dart';
import 'matter_cubit.dart';
import 'matter_documents_section.dart';
import 'matter_files_section.dart';
import 'matter_invoices_section.dart';
import 'matter_labels.dart';
import 'matter_messages_section.dart';
import 'matter_state.dart';
import 'matter_status_chip.dart';

part 'matter_detail_row.dart';
part 'matter_details_surface.dart';

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
