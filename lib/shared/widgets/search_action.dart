import 'package:go_router/go_router.dart';
import 'package:legalhub/app/router.dart';
import 'package:material_ui/material_ui.dart';

/// A single, accessible way into the existing `/search` surface from list
/// screens that do not own a search field (D-S4 quick win).
///
/// There is no new search logic here — the button is a navigation hint to the
/// already-wired unified search screen. A tooltip doubles as the Semantics
/// label, so the icon-only control is announced correctly.
class SearchAction extends StatelessWidget {
  const SearchAction({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      icon: const Icon(Icons.search),
      onPressed: () => context.push(AppRoutes.search),
    );
  }
}
