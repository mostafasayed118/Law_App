import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'package:legalhub/features/library/presentation/library_browse_cubit.dart';
import 'package:legalhub/features/library/presentation/library_browse_state.dart';
import 'package:legalhub/features/library/presentation/library_document_tile.dart';
import 'package:legalhub/features/library/presentation/library_labels.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

/// The Legal Library index: category chips, the document list and the entry to
/// search (ADR-0009).
///
/// Read-only. Every row is a document header — the articles are read on the
/// detail screen, so this list never pulls article bodies.
class LibraryHomeScreen extends StatelessWidget {
  const LibraryHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibraryBrowseCubit>(
      create: (BuildContext context) =>
          LibraryBrowseCubit(serviceLocator<LibraryGateway>())..load(),
      child: const _LibraryHomeSurface(),
    );
  }
}

class _LibraryHomeSurface extends StatelessWidget {
  const _LibraryHomeSurface();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.libraryTitle)),
      body: SafeArea(
        child: BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
          builder: (BuildContext context, LibraryBrowseState state) {
            return ViewStateList<LegalDocument>(
              state: state.documents,
              onRetry: () => context.read<LibraryBrowseCubit>().load(),
              errorCopy: l10n.libraryError,
              localOnlyNote: l10n.libraryLocalOnlyNote,
              header: <Widget>[
                _LibrarySearchEntry(),
                const SizedBox(height: LegalHubTheme.spaceSm),
                _CategoryChips(selected: state.category),
                const SizedBox(height: LegalHubTheme.spaceSm),
              ],
              empty: AppCenteredMessage(text: l10n.libraryEmpty),
              tileBuilder: (BuildContext context, LegalDocument document) =>
                  LibraryDocumentTile(
                    document: document,
                    onTap: () =>
                        context.push(AppRoutes.libraryDocumentFor(document.id)),
                  ),
            );
          },
        ),
      ),
    );
  }
}

/// A tap-through field: it looks like search, and opens the search surface
/// rather than filtering this list in place.
class _LibrarySearchEntry extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.librarySearchHint,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => context.push(AppRoutes.librarySearch),
          borderRadius: const BorderRadius.all(
            Radius.circular(LegalHubTheme.radiusMd),
          ),
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: l10n.librarySearchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected});

  final LegalCategory? selected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LibraryBrowseCubit cubit = context.read<LibraryBrowseCubit>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              end: LegalHubTheme.spaceXs,
            ),
            child: FilterChip(
              label: Text(l10n.libraryCategoryAll),
              selected: selected == null,
              onSelected: (_) => cubit.setCategory(null),
            ),
          ),
          for (final LegalCategory category in LegalCategory.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: LegalHubTheme.spaceXs,
              ),
              child: FilterChip(
                label: Text(libraryCategoryLabel(l10n, category)),
                selected: selected == category,
                onSelected: (_) => cubit.setCategory(category),
              ),
            ),
        ],
      ),
    );
  }
}
