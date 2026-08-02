import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/notifications/domain/notification_prefs.dart';
import 'package:legalhub/features/notifications/domain/notification_prefs_store.dart';
import 'package:legalhub/features/notifications/presentation/notification_settings_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

// NotificationSettingsScreen creates its NotificationPrefsCubit from the
// service locator (mirroring SignUpScreen), so the locator is configured with
// an in-memory store before each pump. These tests pin: persisted values
// render on open, toggling writes through the store and updates the UI, and
// AR localization resolves.
void main() {
  setUp(() async {
    await resetServiceLocator();
    configureDependencies();
  });

  tearDown(() async {
    await resetServiceLocator();
  });

  Widget pumpScreen({Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const NotificationSettingsScreen(),
    );
  }

  testWidgets('renders the title, note, and three toggles with defaults', (
    tester,
  ) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(
      find.text(
        'Preferences are stored on this device. Notification delivery is '
        'planned for a later release.',
      ),
      findsOneWidget,
    );
    expect(find.text('Appointment reminders'), findsOneWidget);
    expect(find.text('Activity updates'), findsOneWidget);
    expect(find.text('System alerts'), findsOneWidget);

    final Iterable<SwitchListTile> tiles = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(tiles.length, 3);
    expect(tiles.every((SwitchListTile tile) => tile.value), isTrue);
  });

  testWidgets('persisted preferences render on open', (tester) async {
    await serviceLocator<NotificationPrefsStore>().write(
      const NotificationPrefs(
        appointmentReminders: false,
        activityUpdates: true,
        systemAlerts: false,
      ),
    );

    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    final Iterable<SwitchListTile> tiles = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(tiles.elementAt(0).value, isFalse);
    expect(tiles.elementAt(1).value, isTrue);
    expect(tiles.elementAt(2).value, isFalse);
  });

  testWidgets('toggling a switch persists through the store and updates UI', (
    tester,
  ) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile).at(0));
    await tester.pumpAndSettle();

    final NotificationPrefs? persisted =
        await serviceLocator<NotificationPrefsStore>().read();
    expect(persisted, isNotNull);
    expect(persisted!.appointmentReminders, isFalse);
    expect(persisted.activityUpdates, isTrue);
    expect(persisted.systemAlerts, isTrue);

    final Iterable<SwitchListTile> tiles = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(tiles.elementAt(0).value, isFalse);
  });

  testWidgets('resolves Arabic localization', (tester) async {
    await tester.pumpWidget(pumpScreen(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الإشعارات'), findsOneWidget);
    expect(find.text('تذكيرات المواعيد'), findsOneWidget);
    expect(find.text('تحديثات النشاط'), findsOneWidget);
    expect(find.text('تنبيهات النظام'), findsOneWidget);
  });
}
