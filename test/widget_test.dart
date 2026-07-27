import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/main.dart';

void main() {
  testWidgets('boots into the safe access screen', (WidgetTester tester) async {
    final AuthCubit authCubit = AuthCubit(
      FakeAuthGateway(),
      InMemoryErrorReporter(),
    );
    final LocaleCubit localeCubit = LocaleCubit(InMemoryLocaleStore());
    final router = createAppRouter(authCubit);

    await tester.pumpWidget(
      LegalHubApp(
        router: router,
        authCubit: authCubit,
        localeCubit: localeCubit,
      ),
    );

    expect(find.text('Access the foundation'), findsOneWidget);
    expect(find.text('Continue with demo session'), findsOneWidget);

    router.dispose();
    await authCubit.close();
    await localeCubit.close();
  });

  testWidgets('demo flow reaches the placeholder shell and changes locale', (
    WidgetTester tester,
  ) async {
    final AuthCubit authCubit = AuthCubit(
      FakeAuthGateway(),
      InMemoryErrorReporter(),
    );
    final LocaleCubit localeCubit = LocaleCubit(InMemoryLocaleStore());
    final router = createAppRouter(authCubit);

    await tester.pumpWidget(
      LegalHubApp(
        router: router,
        authCubit: authCubit,
        localeCubit: localeCubit,
      ),
    );
    await tester.tap(find.text('Continue with demo session'));
    await tester.pumpAndSettle();

    expect(find.text('Foundation workspace'), findsOneWidget);
    expect(find.text('Foundation ready'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsWidgets);

    await tester.tap(find.byType(DropdownButton<Locale>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AR').last);
    await tester.pumpAndSettle();

    expect(find.text('الإعدادات'), findsNWidgets(2));
    expect(find.text('اللغة'), findsWidgets);

    router.dispose();
    await authCubit.close();
    await localeCubit.close();
  });
}
