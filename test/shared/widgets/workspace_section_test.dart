import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/app_tile.dart';
import 'package:legalhub/shared/widgets/workspace_section.dart';

// WorkspaceSection is the E10 extraction: the four matter workspace
// sections (documents/files/invoices/messages) previously duplicated the
// ViewStateSwitch arm config (spaceMd loading padding, zero error padding,
// bodySmall error text), the filter-by-matterRef rows column, and the
// inline empty copy. These tests pin the shared shell — the state arms, the
// matterRef filter, the spaceSm row gaps, the inline empty hint, and RTL at
// narrow width.
void main() {
  const List<String> items = <String>['Alpha · m1', 'Beta · m1', 'Gamma · m2'];

  Widget pumpWorkspaceSection({
    ViewState<List<String>> state = const ViewSuccess<List<String>>(items),
    String matterRef = 'm1',
    VoidCallback? onRetry,
  }) {
    return MaterialApp(
      theme: LegalHubTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: WorkspaceSection<String>(
          state: state,
          onRetry: onRetry ?? () {},
          errorCopy: 'Load error',
          emptyCopy: 'No rows for this matter',
          matterRef: matterRef,
          matterRefOf: (String item) => item.split(' · ')[1],
          itemBuilder: (BuildContext context, String item) =>
              AppTile(title: item, subtitles: const <String>['Row']),
        ),
      ),
    );
  }

  testWidgets('success renders only the rows matching the matterRef', (
    tester,
  ) async {
    await tester.pumpWidget(pumpWorkspaceSection(matterRef: 'm1'));

    expect(find.text('Alpha · m1'), findsOneWidget);
    expect(find.text('Beta · m1'), findsOneWidget);
    expect(find.text('Gamma · m2'), findsNothing);
    expect(find.text('No rows for this matter'), findsNothing);
  });

  testWidgets('success with no matching rows renders the inline empty copy', (
    tester,
  ) async {
    await tester.pumpWidget(pumpWorkspaceSection(matterRef: 'missing'));

    expect(find.text('No rows for this matter'), findsOneWidget);
    expect(find.byType(AppTile), findsNothing);
  });

  testWidgets('empty state renders the empty copy', (tester) async {
    await tester.pumpWidget(
      pumpWorkspaceSection(state: const ViewEmpty<List<String>>()),
    );

    expect(find.text('No rows for this matter'), findsOneWidget);
  });

  testWidgets('error state renders the error copy and fires onRetry', (
    tester,
  ) async {
    int retries = 0;
    await tester.pumpWidget(
      pumpWorkspaceSection(
        state: const ViewError<List<String>>(
          AppError(code: 'stub', userMessage: 'stub'),
        ),
        onRetry: () => retries++,
      ),
    );

    expect(find.text('Load error'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('loading state renders the spinner', (tester) async {
    await tester.pumpWidget(
      pumpWorkspaceSection(state: const ViewLoading<List<String>>()),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('offline and unauthorized render the empty copy', (tester) async {
    await tester.pumpWidget(
      pumpWorkspaceSection(state: const ViewOffline<List<String>>()),
    );
    expect(find.text('No rows for this matter'), findsOneWidget);

    await tester.pumpWidget(
      pumpWorkspaceSection(state: const ViewUnauthorized<List<String>>()),
    );
    expect(find.text('No rows for this matter'), findsOneWidget);
  });

  testWidgets('no overflow at 320px under RTL with a long row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LegalHubTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: 320,
              child: WorkspaceSection<String>(
                state: const ViewSuccess<List<String>>(<String>[
                  'A very long row title that should wrap · m1',
                ]),
                onRetry: () {},
                errorCopy: 'Load error',
                emptyCopy: 'No rows for this matter',
                matterRef: 'm1',
                matterRefOf: (String item) => item.split(' · ')[1],
                itemBuilder: (BuildContext context, String item) =>
                    AppTile(title: item),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('A very long row title'), findsOneWidget);
  });
}
