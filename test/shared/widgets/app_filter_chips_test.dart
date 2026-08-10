import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/shared/widgets/app_filter_chips.dart';

// AppFilterChips is the E7 extraction: the matter status filter
// (matter_list_screen.dart) and the practice-area filter
// (attorney_search_screen.dart) previously duplicated this horizontal
// "All + one chip per enum value" row. These tests pin the shared
// contract — the All chip, per-value chips, selection state, callback
// semantics, and the narrow/RTL no-overflow posture.
enum _TestFilter { first, second, third }

void main() {
  Widget pumpFilterChips({
    _TestFilter? selected,
    ValueChanged<_TestFilter?>? onSelected,
    TextDirection direction = TextDirection.ltr,
    double width = 800,
  }) {
    return MaterialApp(
      theme: LegalHubTheme.light,
      home: Scaffold(
        body: Directionality(
          textDirection: direction,
          child: SizedBox(
            width: width,
            child: AppFilterChips<_TestFilter>(
              values: _TestFilter.values,
              selected: selected,
              allLabel: 'All',
              labelOf: (_TestFilter value) => switch (value) {
                _TestFilter.first => 'First',
                _TestFilter.second => 'Second',
                _TestFilter.third => 'Third',
              },
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the All chip plus one chip per value', (tester) async {
    await tester.pumpWidget(pumpFilterChips());

    expect(find.byType(FilterChip), findsNWidgets(4));
    expect(find.text('All'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Third'), findsOneWidget);
  });

  testWidgets('renders All selected when no value is selected', (tester) async {
    await tester.pumpWidget(pumpFilterChips(selected: null));

    final Iterable<FilterChip> chips = tester.widgetList<FilterChip>(
      find.byType(FilterChip),
    );
    expect(chips.first.selected, isTrue);
    expect(chips.skip(1).every((FilterChip chip) => !chip.selected), isTrue);
  });

  testWidgets('renders the matching value chip selected', (tester) async {
    await tester.pumpWidget(pumpFilterChips(selected: _TestFilter.second));

    final Iterable<FilterChip> chips = tester.widgetList<FilterChip>(
      find.byType(FilterChip),
    );
    expect(chips.elementAt(0).selected, isFalse);
    expect(chips.elementAt(1).selected, isFalse);
    expect(chips.elementAt(2).selected, isTrue);
    expect(chips.elementAt(3).selected, isFalse);
  });

  testWidgets('tapping All reports null and tapping a value reports it', (
    tester,
  ) async {
    final List<_TestFilter?> calls = <_TestFilter?>[];
    await tester.pumpWidget(
      pumpFilterChips(selected: _TestFilter.second, onSelected: calls.add),
    );

    await tester.tap(find.text('All'));
    await tester.tap(find.text('Third'));

    expect(calls, <_TestFilter?>[null, _TestFilter.third]);
  });

  testWidgets('tapping a selected value chip reports null (toggle off)', (
    tester,
  ) async {
    final List<_TestFilter?> calls = <_TestFilter?>[];
    await tester.pumpWidget(
      pumpFilterChips(selected: _TestFilter.second, onSelected: calls.add),
    );

    await tester.tap(find.text('Second'));

    expect(calls, <_TestFilter?>[null]);
  });

  testWidgets('no horizontal overflow at 320px under RTL', (tester) async {
    await tester.pumpWidget(
      pumpFilterChips(direction: TextDirection.rtl, width: 320),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(FilterChip), findsNWidgets(4));
  });
}
