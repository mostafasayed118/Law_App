import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/view_state_list.dart';

void main() {
  Widget pumpViewState<T>(ViewState<List<T>> state, {VoidCallback? onRetry}) {
    // The error arm's retry label reads `AppLocalizations.of(context)`
    // (view_state_list.dart), so the harness must install the delegates —
    // the same pump contract as every other widget test in the repo.
    // Without them `AppLocalizations.of` returns null and the widget's
    // `!` throws before the assertions run.
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ViewStateList<T>(
          state: state,
          onRetry: onRetry ?? () {},
          tileBuilder: (BuildContext context, T item) => Text('item:$item'),
          empty: const Text('empty copy'),
          errorCopy: 'Error copy',
          localOnlyNote: 'Local-only note',
        ),
      ),
    );
  }

  testWidgets('loading branch renders the centered spinner', (tester) async {
    await tester.pumpWidget(
      pumpViewState<String>(const ViewLoading<List<String>>()),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('empty copy'), findsNothing);
    expect(find.text('Local-only note'), findsNothing);
  });

  testWidgets('empty branch renders the note-wrapped empty copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpViewState<String>(const ViewEmpty<List<String>>()),
    );

    expect(find.text('empty copy'), findsOneWidget);
    expect(find.text('Local-only note'), findsOneWidget);
  });

  testWidgets('offline and unauthorized render the note-wrapped empty arm '
      '(owner-normalized)', (tester) async {
    await tester.pumpWidget(
      pumpViewState<String>(const ViewOffline<List<String>>()),
    );
    expect(find.text('empty copy'), findsOneWidget);
    expect(find.text('Local-only note'), findsOneWidget);

    await tester.pumpWidget(
      pumpViewState<String>(const ViewUnauthorized<List<String>>()),
    );
    expect(find.text('empty copy'), findsOneWidget);
    expect(find.text('Local-only note'), findsOneWidget);
  });

  testWidgets('error branch renders the error copy and fires retry', (
    tester,
  ) async {
    int retries = 0;
    await tester.pumpWidget(
      pumpViewState<String>(
        const ViewError<List<String>>(
          AppError(code: 'stub', userMessage: 'stub'),
        ),
        onRetry: () => retries++,
      ),
    );

    expect(find.text('Error copy'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('success branch appends the note after the items', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpViewState<String>(const ViewSuccess<List<String>>(<String>['a'])),
    );

    expect(find.text('item:a'), findsOneWidget);
    expect(find.text('Local-only note'), findsOneWidget);
  });

  testWidgets('success branch lazily builds every row with the footer', (
    tester,
  ) async {
    // A list longer than the test viewport: ListView.builder builds lazily,
    // so rows outside the viewport are never constructed — the pre-fix
    // eager arm built all of them up front.
    final List<String> items = List<String>.generate(80, (int i) => 'i$i');
    await tester.pumpWidget(
      pumpViewState<String>(ViewSuccess<List<String>>(items)),
    );

    expect(find.text('item:i0'), findsOneWidget);
    // The footer is the builder's last row (index items.length + 1), so a
    // genuinely lazy arm does not CONSTRUCT it until it is scrolled near —
    // asserting it absent here is the lazy proof. Finding it immediately
    // would mean the arm still builds eagerly (the pre-fix behavior).
    expect(find.text('Local-only note'), findsNothing);
    expect(find.text('item:i0', skipOffstage: false), findsOneWidget);

    // Scrolling to the tail builds the last tile + the footer, proving the
    // lazy builder covers the whole range.
    await tester.scrollUntilVisible(
      find.text('Local-only note'),
      400,
      scrollable: find.descendant(
        of: find.byType(ViewStateList<String>),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Local-only note'), findsOneWidget);
    expect(find.text('item:i79'), findsOneWidget);
  });

  testWidgets('renders under RTL without overflow', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: pumpViewState<String>(
          const ViewError<List<String>>(
            AppError(code: 'stub', userMessage: 'stub'),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Error copy'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
