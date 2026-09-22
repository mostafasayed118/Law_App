import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/service_locator.dart';
import '../../../features/documents/domain/document.dart';
import '../../../features/documents/domain/document_gateway.dart';
import '../../../features/documents/presentation/document_cubit.dart';
import '../../../features/documents/presentation/document_labels.dart';
import '../../../features/documents/presentation/document_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';

part 'matter_documents_section_body.dart';

/// Per-matter Documents section on the matter details surface (Phase 10,
/// slice 10.1, owner decisions D-W1/D-W3/D-W4).
///
/// Provides its own [DocumentCubit] (feature-scoped, per-section
/// `BlocProvider`) and renders the subset of the synthetic document list
/// whose [Document.matterRef] equals [matterRef] — a client-side view over
/// the fake list (the D-M5 pattern; there is no per-matter fetch). **Metadata
/// only**: each row renders the D-V4 title/type/date fields and nothing else
/// — no preview, no download, no open action, no tap affordance (D-W4). An
/// empty per-matter subset renders the localized empty copy (AC-3).
class MatterDocumentsSection extends StatelessWidget {
  const MatterDocumentsSection({required this.matterRef, super.key});

  /// The matter title to filter by (matches [Document.matterRef], D-W2).
  final String matterRef;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DocumentCubit>(
      create: (BuildContext context) =>
          DocumentCubit(serviceLocator<DocumentGateway>()),
      child: _DocumentsSectionBody(matterRef: matterRef),
    );
  }
}
