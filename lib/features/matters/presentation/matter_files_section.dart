import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/service_locator.dart';
import '../../../features/storage/domain/file_metadata.dart';
import '../../../features/storage/domain/storage_gateway.dart';
import '../../../features/storage/presentation/storage_cubit.dart';
import '../../../features/storage/presentation/storage_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';

part 'matter_files_section_body.dart';

/// Per-matter Files section on the matter details surface (storage slice,
/// D-STR7).
///
/// Provides its own [StorageCubit] (feature-scoped, per-section
/// `BlocProvider`) and renders the subset of the file-metadata list whose
/// [FileMetadata.matterRef] equals [matterRef] — a client-side view over the
/// gateway list (the D-M5 pattern; there is no per-matter fetch). **Metadata
/// only**: each row renders the name and the byte size and nothing else — no
/// download, no open action, no tap affordance (D-STR9 — the download UX is
/// a flagged follow-up). An empty per-matter subset renders the localized
/// empty copy.
class MatterFilesSection extends StatelessWidget {
  const MatterFilesSection({required this.matterRef, super.key});

  /// The matter title to filter by (matches [FileMetadata.matterRef],
  /// D-STR5/D-W2).
  final String matterRef;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StorageCubit>(
      create: (BuildContext context) =>
          StorageCubit(serviceLocator<StorageGateway>()),
      child: _FilesSectionBody(matterRef: matterRef),
    );
  }
}
