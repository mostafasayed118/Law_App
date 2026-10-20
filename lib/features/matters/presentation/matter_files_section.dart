import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/errors/app_error.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/demo_labels.dart';
import '../../../shared/widgets/widgets.dart';
import '../../storage/domain/file_metadata.dart';
import '../../storage/domain/file_picker.dart';
import '../../storage/domain/storage_gateway.dart';
import '../../storage/domain/uri_opener.dart';
import '../../storage/presentation/file_transfer_cubit.dart';
import '../../storage/presentation/file_transfer_state.dart';
import 'matter_workspace_cubit.dart';
import 'matter_workspace_state.dart';

/// Per-matter Files section on the matter details surface (storage slice,
/// D-STR7; write/preview slice).
///
/// Consumes the matter-scoped [MatterWorkspaceCubit] (provided by the
/// details screen) and renders the subset of the file-metadata list whose
/// [FileMetadata.matterRef] equals [matterRef]. The upload button and the
/// per-row open action are owned by a section-scoped
/// [FileTransferCubit]: the picker/opener/platform seams resolve from the
/// service locator, uploads land in the private bucket through the gateway,
/// and a successful upload reloads the workspace list. An empty per-matter
/// subset renders the localized empty copy.
class MatterFilesSection extends StatefulWidget {
  const MatterFilesSection({
    required this.matterRef,
    required this.matterId,
    super.key,
  });

  /// The matter title to filter by (matches [FileMetadata.matterRef],
  /// D-STR5/D-W2).
  final String matterRef;

  /// The matter id used by the upload gateway (the title is display-only).
  final String matterId;

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
    return BlocProvider<FileTransferCubit>(
      create: (BuildContext context) => FileTransferCubit(
        serviceLocator<StorageGateway>(),
        serviceLocator<FilePicker>(),
        serviceLocator<UriOpener>(),
      ),
      child: BlocConsumer<FileTransferCubit, FileTransferState>(
        listenWhen: (FileTransferState previous, FileTransferState current) =>
            previous.phase != current.phase,
        listener: (BuildContext context, FileTransferState transfer) {
          if (transfer.phase != FileTransferPhase.success) {
            return;
          }
          // The persisted row is server-side; re-read the list so the new
          // file appears without a manual refresh.
          context.read<MatterWorkspaceCubit>().loadFiles();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.fileUploadSuccess)));
        },
        builder: (BuildContext context, FileTransferState transfer) {
          final ColorScheme scheme = Theme.of(context).colorScheme;
          final TextTheme text = Theme.of(context).textTheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: transfer.isBusy
                    ? null
                    : () => context.read<FileTransferCubit>().pickAndUpload(
                        widget.matterId,
                      ),
                icon: const Icon(Icons.upload_file),
                label: Text(l10n.fileUploadAction),
              ),
              if (transfer.phase == FileTransferPhase.uploading) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceSm),
                LinearProgressIndicator(
                  semanticsLabel: l10n.fileUploading(transfer.fileName ?? ''),
                ),
                const SizedBox(height: LegalHubTheme.spaceXs),
                Text(
                  l10n.fileUploading(transfer.fileName ?? ''),
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (transfer.phase == FileTransferPhase.failure) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceXs),
                Text(
                  _transferErrorCopy(l10n, transfer.error!),
                  style: text.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
              const SizedBox(height: LegalHubTheme.spaceMd),
              BlocBuilder<MatterWorkspaceCubit, MatterWorkspaceState>(
                buildWhen:
                    (
                      MatterWorkspaceState previous,
                      MatterWorkspaceState current,
                    ) => previous.files != current.files,
                builder: (BuildContext context, MatterWorkspaceState state) {
                  return WorkspaceSection<FileMetadata>(
                    state: state.files,
                    onRetry: () =>
                        context.read<MatterWorkspaceCubit>().loadFiles(),
                    errorCopy: l10n.filesError,
                    emptyCopy: l10n.matterWorkspaceFilesEmpty,
                    matterRef: widget.matterRef,
                    matterRefOf: (FileMetadata file) => file.matterRef,
                    itemBuilder: (BuildContext context, FileMetadata file) =>
                        Tooltip(
                          message: l10n.fileOpenAction,
                          child: AppTile(
                            title: demoFileName(l10n, file.name),
                            subtitles: <String>[fileSizeLabel(file.sizeBytes)],
                            icon: Icons.description_outlined,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.open_in_new,
                                  size: 16,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: LegalHubTheme.spaceXs),
                                Text(
                                  l10n.fileOpenAction,
                                  style: text.bodySmall?.copyWith(
                                    color: scheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            onTap: transfer.isBusy
                                ? null
                                : () => context
                                      .read<FileTransferCubit>()
                                      .openFile(file),
                          ),
                        ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Maps the typed transfer failure to the localized inline line.
String _transferErrorCopy(AppLocalizations l10n, AppError error) {
  return switch (error.code) {
    'file_upload_too_large' => l10n.fileUploadTooLarge,
    'file_upload_unsupported_type' => l10n.fileUploadUnsupportedType,
    'file_upload_denied' => l10n.fileUploadDenied,
    'file_open_denied' ||
    'file_open_unavailable' ||
    'file_open_failed' => l10n.fileOpenFailed,
    _ => l10n.fileUploadFailed,
  };
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
