import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/messaging/data/fake_message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'package:legalhub/features/messaging/presentation/message_list_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpMessages(WidgetTester tester) async {
    // MessageListScreen resolves MessageGateway from the locator (the dev
    // fake in env-less runs).
    configureDependencies();
    // A tall surface so the full synthetic list builds inside the ListView.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MessageListScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The tiles render the last-activity date through the same locale-aware
  // shape as the vault/details surfaces (DateFormat.yMMMd(l10n.localeName));
  // the test re-computes the expected string so the assertion survives
  // locale changes.
  String dateLabel(DateTime date) => DateFormat.yMMMd('en').format(date);

  group('message thread list surface (Phase 9 slice 9.1)', () {
    testWidgets('lists the synthetic thread metadata from the fake (AC-1)', (
      tester,
    ) async {
      await pumpMessages(tester);

      expect(find.text('Messages'), findsOneWidget);
      for (final MessageThread thread in FakeMessageGateway.syntheticThreads) {
        expect(find.text(thread.title), findsOneWidget);
      }
      // The secondary line pairs participants with the last-activity date
      // (two of the D-MSG4 metadata fields).
      expect(
        find.text(
          'Layla Mansour, Demo client · ${dateLabel(DateTime.utc(2026, 7, 28))}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Sara Khalil, Demo client · ${dateLabel(DateTime.utc(2026, 7, 15))}',
        ),
        findsOneWidget,
      );
      // The message-count chip renders the count label — a number, never
      // message content (D-MSG1).
      expect(find.text('12 messages'), findsOneWidget);
      expect(find.text('15 messages'), findsOneWidget);
    });

    testWidgets(
      'renders metadata only — no message text, composer, or row affordance '
      '(AC-2 body-less line pin)',
      (tester) async {
        await pumpMessages(tester);

        // No composer or send/reply affordances anywhere in the surface: no
        // send/reply/edit/attach icons and no text input fields (D-MSG6 —
        // there is no composer, and sending/reply copy is out of scope).
        expect(find.byIcon(Icons.send), findsNothing);
        expect(find.byIcon(Icons.reply), findsNothing);
        expect(find.byIcon(Icons.reply_all), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byIcon(Icons.add_comment), findsNothing);
        expect(find.byIcon(Icons.attach_file), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(TextFormField), findsNothing);

        // No message body text: no preview copy, no body-like probe string,
        // and no thread-open action label anywhere (D-MSG1).
        expect(find.textContaining('Preview'), findsNothing);
        expect(find.textContaining('message body'), findsNothing);

        // Rows are not tap targets: no chevron (contrast the matter list,
        // where every row carries the details affordance) and no InkWell
        // anywhere in the list (D-MSG3 — there is no thread-detail route).
        expect(find.byIcon(Icons.chevron_right), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(InkWell),
          ),
          findsNothing,
        );

        // The thread list carries the metadata-only, local-only note
        // (R1/D-MSG1/D-MSG4).
        expect(
          find.textContaining('synthetic thread metadata only'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'an empty result set renders the localized empty state (AC-3)',
      (tester) async {
        // Stub gateway returning an empty list, registered before
        // configureDependencies so the fake registration is skipped.
        await resetServiceLocator();
        serviceLocator.registerLazySingleton<MessageGateway>(
          _EmptyMessageGateway.new,
        );

        await pumpMessages(tester);

        expect(find.text('No message threads are available.'), findsOneWidget);
        expect(find.text('Demo matter updates'), findsNothing);
      },
    );
  });
}

/// Gateway stub that yields an empty thread list (empty-state widget pin).
class _EmptyMessageGateway implements MessageGateway {
  @override
  Future<Result<List<MessageThread>>> fetchThreads() async {
    return Result<List<MessageThread>>.success(const <MessageThread>[]);
  }
}
