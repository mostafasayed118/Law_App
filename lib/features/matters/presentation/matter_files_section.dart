import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/demo_labels.dart';
import '../../../shared/widgets/widgets.dart';
import '../../storage/domain/file_metadata.dart';
import 'matter_workspace_cubit.dart';
import 'matter_workspace_state.dart';

/// Per-matter Files section on the matter details surface (storage slice,
/// D-STR7).
///
/// Consumes the matter-scoped [MatterWorkspaceCubit] (provided by the
/// details screen) instead of a foreign feature's presentation cubit
/// (audit: matters god-feature) and renders the subset of the file-metadata
/// list whose [FileMetadata.matterRef] equals [matterRef] — a client-side
/// view over the gateway list (the D-M5 pattern; there is no per-matter
/// fetch). **Metadata only**: each row renders the name and the byte size
/// and nothing else — no download, no open action, no tap affordance
/// (D-STR9 — the download UX is a flagged follow-up). An empty per-matter
/// subset renders the localized empty copy.
class MatterFilesSection extends StatefulWidget {
  const MatterFilesSection({required this.matterRef, super.key});

  /// The matter title to filter by (matches [FileMetadata.matterRef],
  /// D-STR5/D-W2).
  final String matterRef;

  @override
  State<MatterFilesSection> createState() => _MatterFilesSectionState();
}

class _MatterFilesSectionState extends State<MatterFilesSection> {
  @override
  void initState() {
    super.initState();
    // Load the list on open (same pattern as the standalone surfaces); the
    // per-matter subset is filtered client-side below. Only this list
    // loads — sibling sections trigger their own.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MatterWorkspaceCubit>().loadFiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<MatterWorkspaceCubit, MatterWorkspaceState>(
      buildWhen:
          (MatterWorkspaceState previous, MatterWorkspaceState current) =>
              previous.files != current.files,
      builder: (BuildContext context, MatterWorkspaceState state) {
        return WorkspaceSection<FileMetadata>(
          state: state.files,
          onRetry: () => context.read<MatterWorkspaceCubit>().loadFiles(),
          errorCopy: l10n.filesError,
          emptyCopy: l10n.matterWorkspaceFilesEmpty,
          matterRef: widget.matterRef,
          matterRefOf: (FileMetadata file) => file.matterRef,
          itemBuilder: (BuildContext context, FileMetadata file) => AppTile(
            title: demoFileName(l10n, file.name),
            subtitles: <String>[fileSizeLabel(file.sizeBytes)],
          ),
        );
      },
    );
  }
}

/// Formats a byte count as a compact human label (240 KB / 1.5 MB / 512 B).
/// Deterministic, locale-independent — the row's only secondary field. A
/// whole value drops its trailing `.0` (240 KB, not 240.0 KB). Kept in the
/// storage feature (domain formatting, not UI) after the E8 row extraction.
String fileSizeLabel(int bytes) {
  if (bytes >= 1048576) {
    return '${_trimOne(bytes / 1048576)} MB';
  }
  if (bytes >= 1024) {
    return '${_trimOne(bytes / 1024)} KB';
  }
  return '$bytes B';
}

/// Renders [value] with one decimal, dropping a trailing `.0`.
String _trimOne(double value) {
  final String fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}
