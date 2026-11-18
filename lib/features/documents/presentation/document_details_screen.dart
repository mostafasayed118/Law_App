import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';
import 'package:legalhub/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'document_cubit.dart';
import 'document_labels.dart';
import 'document_state.dart';
import 'document_type_chip.dart';

part 'document_details_surface.dart';

/// Read-only metadata detail for one vault document.
///
/// **Metadata only** (D-V1): title, type, matter reference, created date and
/// the local-only note. There is deliberately no content viewer, no download,
/// no preview and no share action — the domain type carries no body or URL,
/// so the surface cannot render one. The new route turns the previously
/// inert row into a metadata reader; the D-V1 no-content line is unchanged.
class DocumentDetailsScreen extends StatelessWidget {
  const DocumentDetailsScreen({
    required this.documentId,
    required this.capabilities,
    this.embedded = false,
    super.key,
  });

  final String documentId;

  /// UX-only capability projection for the reverse cross-link (D-C4).
  final RoleCapability capabilities;

  /// True inside the two-pane detail slot (no Scaffold/AppBar).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // In the two-pane the parent list owns the cubit; sharing it avoids a
    // duplicate read and keeps one source of truth for the pane.
    if (embedded) {
      return _DocumentDetailsSurface(
        documentId: documentId,
        capabilities: capabilities,
        embedded: true,
        loadOnMount: false,
      );
    }
    return BlocProvider<DocumentCubit>(
      create: (BuildContext context) =>
          DocumentCubit(serviceLocator<DocumentGateway>()),
      child: _DocumentDetailsSurface(
        documentId: documentId,
        capabilities: capabilities,
        embedded: false,
        loadOnMount: true,
      ),
    );
  }
}
