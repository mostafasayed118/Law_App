part of 'matter_files_section.dart';

class _FilesSectionBody extends StatefulWidget {
  const _FilesSectionBody({required this.matterRef});

  final String matterRef;

  @override
  State<_FilesSectionBody> createState() => _FilesSectionBodyState();
}

class _FilesSectionBodyState extends State<_FilesSectionBody> {
  @override
  void initState() {
    super.initState();
    // Load the list on open (same pattern as the standalone surfaces); the
    // per-matter subset is filtered client-side below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<StorageCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<StorageCubit, StorageState>(
      builder: (BuildContext context, StorageState state) {
        return WorkspaceSection<FileMetadata>(
          state: state.files,
          onRetry: () => context.read<StorageCubit>().load(),
          errorCopy: l10n.filesError,
          emptyCopy: l10n.matterWorkspaceFilesEmpty,
          matterRef: widget.matterRef,
          matterRefOf: (FileMetadata file) => file.matterRef,
          itemBuilder: (BuildContext context, FileMetadata file) => AppTile(
            title: file.name,
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
