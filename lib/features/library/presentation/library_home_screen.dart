import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'package:legalhub/features/library/presentation/library_browse_cubit.dart';
import 'package:legalhub/features/library/presentation/library_browse_state.dart';
import 'package:legalhub/features/library/presentation/library_document_screen.dart';
import 'package:legalhub/features/library/presentation/library_document_tile.dart';
import 'package:legalhub/features/library/presentation/library_labels.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/responsive/responsive.dart';
import 'package:legalhub/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// The Legal Library index: category chips, the document list and the entry to
/// search (ADR-0009).
///
/// Read-only. Every row is a document header; the articles are read on the
/// detail screen, so this list never pulls article bodies.
///
/// Above the expanded breakpoint the surface is a master/detail pair: the list
/// keeps its selection and the document renders in the second pane. Below it, a
/// tap pushes the standalone document route.
class LibraryHomeScreen extends StatelessWidget {
  const LibraryHomeScreen({this.initialSelectedDocumentId, super.key});

  /// Pre-selects a document in the detail pane on an expanded window. Ignored
  /// on a compact one, where the row pushes instead.
  final String? initialSelectedDocumentId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibraryBrowseCubit>(
      create: (BuildContext context) =>
          LibraryBrowseCubit(serviceLocator<LibraryGateway>())..load(),
      child: _LibraryHomeSurface(
        initialSelectedDocumentId: initialSelectedDocumentId,
      ),
    );
  }
}

class _LibraryHomeSurface extends StatefulWidget {
  const _LibraryHomeSurface({this.initialSelectedDocumentId});

  final String? initialSelectedDocumentId;

  @override
  State<_LibraryHomeSurface> createState() => _LibraryHomeSurfaceState();
}

class _LibraryHomeSurfaceState extends State<_LibraryHomeSurface> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedDocumentId;
  }

  void _select(String documentId) {
    if (_selectedId == documentId) {
      return;
    }
    setState(() => _selectedId = documentId);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.libraryTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.librarySavedTitle,
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => context.push(AppRoutes.librarySaved),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (constraints.maxWidth < AppBreakpoints.expanded) {
              return _LibraryList(
                onOpen: (String id) =>
                    context.push(AppRoutes.libraryDocumentFor(id)),
              );
            }
            // Selection defaults to the first document so an expanded window is
            // never half-empty. A deep link overrides it through
            // initialSelectedDocumentId.
            return BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
              builder: (BuildContext context, LibraryBrowseState state) {
                final String? effective =
                    _selectedId ?? _firstDocumentId(state);
                return TwoPane(
                  list: _LibraryList(onOpen: _select),
                  detail: effective == null
                      ? AppCenteredMessage(text: l10n.libraryEmpty)
                      : LibraryDocumentScreen(
                          documentId: effective,
                          embedded: true,
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String? _firstDocumentId(LibraryBrowseState state) {
    final ViewState<List<LegalDocument>> documents = state.documents;
    if (documents is ViewSuccess<List<LegalDocument>> &&
        documents.data.isNotEmpty) {
      return documents.data.first.id;
    }
    return null;
  }
}

class _LibraryList extends StatelessWidget {
  const _LibraryList({required this.onOpen});

  final void Function(String documentId) onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
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
                onTap: () => onOpen(document.id),
              ),
        );
      },
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
