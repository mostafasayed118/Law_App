import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../features/storage/domain/file_metadata.dart';
import '../../../features/storage/domain/storage_gateway.dart';
import '../../../features/storage/presentation/storage_cubit.dart';
import '../../../features/storage/presentation/storage_state.dart';
import '../../../l10n/app_localizations.dart';

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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return BlocBuilder<StorageCubit, StorageState>(
      builder: (BuildContext context, StorageState state) {
        return switch (state.files) {
          ViewLoading() => const Padding(
            padding: EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
            child: Center(child: CircularProgressIndicator()),
          ),
          ViewEmpty() => _empty(l10n, text, scheme),
          ViewError() => _error(context, l10n, text, scheme),
          // A synthetic list has neither state; both render the same empty
          // copy rather than a distinct offline surface.
          ViewOffline() || ViewUnauthorized() => _empty(l10n, text, scheme),
          ViewSuccess<List<FileMetadata>>(
            data: final List<FileMetadata> files,
          ) =>
            _rows(context, files, l10n, text, scheme),
        };
      },
    );
  }

  Widget _rows(
    BuildContext context,
    List<FileMetadata> files,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final List<FileMetadata> matched = files
        .where((FileMetadata f) => f.matterRef == widget.matterRef)
        .toList();
    if (matched.isEmpty) {
      return _empty(l10n, text, scheme);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final FileMetadata file in matched) ...<Widget>[
          _FileRow(file: file),
          const SizedBox(height: LegalHubTheme.spaceSm),
        ],
      ],
    );
  }

  Widget _empty(AppLocalizations l10n, TextTheme text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceXs),
      child: Text(
        l10n.matterWorkspaceFilesEmpty,
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _error(
    BuildContext context,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.filesError,
          style: text.bodySmall?.copyWith(color: scheme.error),
        ),
        TextButton(
          onPressed: () => context.read<StorageCubit>().load(),
          child: Text(l10n.retry),
        ),
      ],
    );
  }
}

/// A read-only metadata row. Carries **no onTap, no InkWell, no chevron,
/// and no trailing action** — the per-matter view keeps the D-STR3
/// metadata-only line (D-STR9), so rows must not read as tappable and no
/// download affordance exists.
class _FileRow extends StatelessWidget {
  const _FileRow({required this.file});

  final FileMetadata file;

  /// Formats a byte count as a compact human label (240 KB / 1.5 MB / 512 B).
  /// Deterministic, locale-independent — the row's only secondary field. A
  /// whole value drops its trailing `.0` (240 KB, not 240.0 KB).
  static String sizeLabel(int bytes) {
    if (bytes >= 1048576) {
      return '${_trimOne(bytes / 1048576)} MB';
    }
    if (bytes >= 1024) {
      return '${_trimOne(bytes / 1024)} KB';
    }
    return '$bytes B';
  }

  /// Renders [value] with one decimal, dropping a trailing `.0`.
  static String _trimOne(double value) {
    final String fixed = value.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              file.name,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              sizeLabel(file.sizeBytes),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
