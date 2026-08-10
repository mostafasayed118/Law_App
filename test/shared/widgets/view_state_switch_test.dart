import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/view_state_switch.dart';

// ViewStateSwitch is the E3 extraction: the list screens (matters,
// documents, messaging, search, billing, discovery, and the matter workspace
// sections) previously duplicated this switch — loading spinner, feature
// empty copy for empty/offline/unauthorized, error text + retry — and now
// delegate to it. These tests pin the shared contract so the re-pointed
// screens keep their exact rendering.
void main() {
  Widget pumpViewState<T>(
    ViewState<T> state, {
    VoidCallback? onRetry,
    Widget? empty,
    String errorCopy = 'Error copy',
    EdgeInsetsGeometry loadingPadding = const EdgeInsetsDirectional.all(24),
    EdgeInsetsGeometry errorPadding = const EdgeInsetsDirectional.only(top: 16),
    TextStyle? errorTextStyle,
    TextDirection direction = TextDirection.ltr,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: ViewStateSwitch<T>(
            state: state,
            onRetry: onRetry ?? () {},
            builder: (BuildContext context, T data) => Text('success:$data'),
            empty: empty ?? const Text('empty copy'),
            errorCopy: errorCopy,
            loadingPadding: loadingPadding,
            errorPadding: errorPadding,
            errorTextStyle: errorTextStyle,
          ),
        ),
      ),
    );
  }

  testWidgets('loading branch renders the centered spinner', (tester) async {
    await tester.pumpWidget(pumpViewState<String>(const ViewLoading<String>()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('empty copy'), findsNothing);
  });

  testWidgets('empty branch renders the feature empty widget', (tester) async {
    await tester.pumpWidget(pumpViewState<String>(const ViewEmpty<String>()));

    expect(find.text('empty copy'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('offline and unauthorized branches render the empty widget', (
    tester,
  ) async {
    await tester.pumpWidget(pumpViewState<String>(const ViewOffline<String>()));
    expect(find.text('empty copy'), findsOneWidget);

    await tester.pumpWidget(
      pumpViewState<String>(const ViewUnauthorized<String>()),
    );
    expect(find.text('empty copy'), findsOneWidget);
  });

  testWidgets('error branch renders the error copy and fires retry', (
    tester,
  ) async {
    int retries = 0;
    await tester.pumpWidget(
      pumpViewState<String>(
        const ViewError<String>(AppError(code: 'stub', userMessage: 'stub')),
        onRetry: () => retries++,
      ),
    );

    expect(find.text('Error copy'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('success branch delegates to the builder with the data', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpViewState<String>(const ViewSuccess<String>('payload')),
    );

    expect(find.text('success:payload'), findsOneWidget);
    expect(find.text('empty copy'), findsNothing);
  });

  testWidgets('applies the loading, error padding, and error style overrides', (
    tester,
  ) async {
    const EdgeInsetsGeometry tight = EdgeInsets.all(4);
    await tester.pumpWidget(
      pumpViewState<String>(
        const ViewError<String>(AppError(code: 'stub', userMessage: 'stub')),
        loadingPadding: tight,
        errorPadding: tight,
        errorTextStyle: const TextStyle(fontSize: 12),
      ),
    );

    final Padding errorPadding = tester.widget<Padding>(
      find
          .ancestor(of: find.text('Error copy'), matching: find.byType(Padding))
          .first,
    );
    expect(errorPadding.padding, tight);

    final Text errorText = tester.widget<Text>(find.text('Error copy'));
    expect(errorText.style?.fontSize, 12);
  });

  testWidgets('renders under RTL without overflow', (tester) async {
    await tester.pumpWidget(
      pumpViewState<String>(
        const ViewError<String>(AppError(code: 'stub', userMessage: 'stub')),
        direction: TextDirection.rtl,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Error copy'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
