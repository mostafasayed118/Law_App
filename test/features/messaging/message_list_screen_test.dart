import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/matters/presentation/matter_link_chip.dart';
import 'package:legalhub/features/messaging/data/fake_message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_realtime_event.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'package:legalhub/features/messaging/presentation/message_list_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpMessages(
    WidgetTester tester, {
    RoleCapability? capabilities,
  }) async {
    // Default to the client's real capability map (the D-C4 posture: the
    // chip renders under canViewMatters, true for every bootstrap role).
    final RoleCapability effectiveCapabilities =
        capabilities ?? roleCapabilities[UserRole.client]!;
    // MessageListScreen resolves MessageGateway/MatterGateway from the
    // locator (the dev fakes in env-less runs).
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
        home: MessageListScreen(capabilities: effectiveCapabilities),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The tiles render the last-activity date through the same locale-aware
  // shape as the vault/details surfaces (DateFormat.yMMMd(l10n.localeName));
  // the test re-computes the expected string so the assertion survives
  // locale changes.
  String dateLabel(DateTime date) => DateFormat.yMMMd('en').format(date);

  group('message thread list surface (Phase 9 slice 9.1; Phase 12 slice 12.1)', () {
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
      'renders metadata only — no message text or composer, with the '
      'thread-open row affordance (AC-2 body-less line pin, D-RT5 re-scope)',
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

        // No message body text on the LIST surface: no preview copy and no
        // body-like probe string anywhere (D-MSG1 — bodies live only on the
        // thread-detail surface, D-RT5).
        expect(find.textContaining('Preview'), findsNothing);
        expect(find.textContaining('message body'), findsNothing);

        // D-MSG3 re-scoped twice: Phase 12 D-C2 kept rows chevron-less and
        // made the chip the cross-link target; the realtime slice (D-RT5)
        // adds the thread-open affordance — the whole row is now an InkWell
        // (tap → the read-only thread-detail surface). Every resolved row
        // therefore carries TWO InkWells: the row's thread-open + its
        // "View matter" chip.
        expect(find.byIcon(Icons.chevron_right), findsNothing);
        final Finder listInkWells = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(InkWell),
        );
        final Finder chipInkWells = find.descendant(
          of: find.byType(MatterLinkChip),
          matching: find.byType(InkWell),
        );
        // Every synthetic thread's matterRef resolves to a known matter, so
        // every row carries exactly one chip + one thread-open row InkWell
        // (5 rows × 2 = 10 InkWells in the list).
        expect(chipInkWells, findsNWidgets(5));
        expect(listInkWells, findsNWidgets(10));

        // The thread list carries the metadata-only, local-only note
        // (R1/D-MSG1/D-MSG4).
        expect(
          find.textContaining('synthetic thread metadata only'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a resolved thread row renders the View matter chip; an unresolved '
      'matterRef renders none (D-C2/D-C3)',
      (tester) async {
        // Gateway stub whose only thread carries an unknown matterRef (not
        // one of the 5 known synthetic matter titles) — registered before
        // configureDependencies so the fake registration is skipped.
        await resetServiceLocator();
        serviceLocator.registerLazySingleton<MessageGateway>(
          _UnresolvedRefMessageGateway.new,
        );

        await pumpMessages(tester);

        // The row renders its metadata but NO chip: the title-keyed
        // resolution found no matter (D-C3), so the reverse cross-link
        // stays absent — but the row STILL carries its thread-open
        // affordance (D-RT5: every listed row is tappable, chip or not).
        expect(find.text('Unlinked demo thread'), findsOneWidget);
        expect(find.byType(MatterLinkChip), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(InkWell),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.chevron_right), findsNothing);
      },
    );

    testWidgets(
      'the View matter chip is gated by canViewMatters — no chip without the '
      'nav hint (D-C4)',
      (tester) async {
        // A capability projection without canViewMatters: every thread row
        // still resolves, but the reverse cross-link must not render (the
        // D-W5 posture — navigation hints only).
        await pumpMessages(
          tester,
          capabilities: const RoleCapability(
            canViewHome: true,
            canViewSettings: true,
            canBookConsultation: true,
            canViewAttorneyDiscovery: true,
            canViewMatters: false,
            canViewDocuments: true,
            canViewMessages: true,
            canViewFiles: true,
            canViewAudit: false,
            canViewNotifications: true,
            canViewAlerts: true,
            canViewTasks: true,
            canViewApprovals: true,
          ),
        );

        expect(find.text('Demo matter updates'), findsOneWidget);
        expect(find.byType(MatterLinkChip), findsNothing);
        // The thread-open affordance is NOT gated by canViewMatters — every
        // row stays tappable into the read-only thread-detail surface (D-RT5);
        // only the cross-link chip disappears.
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(InkWell),
          ),
          findsNWidgets(5),
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

/// Gateway stub whose single thread carries an UNKNOWN matterRef — the
/// D-C3 unresolved-row case (no synthetic matter title matches, so the row
/// must render no reverse cross-link chip).
class _UnresolvedRefMessageGateway implements MessageGateway {
  @override
  Future<Result<List<MessageThread>>> fetchThreads() async {
    return Result<List<MessageThread>>.success(<MessageThread>[
      MessageThread(
        id: 'thread-x',
        title: 'Unlinked demo thread',
        matterRef: 'No such synthetic matter',
        participants: const <String>['Demo client'],
        lastActivityAt: DateTime.utc(2026, 7, 1),
        messageCount: 3,
      ),
    ]);
  }

  @override
  Future<Result<List<Message>>> fetchMessages(String threadId) async {
    return const Result<List<Message>>.success(<Message>[]);
  }

  @override
  Future<Result<Message>> sendMessage(
    String threadId,
    String body, {
    String? authorDisplayName,
  }) async {
    // Not exercised by these tests; an honest failure keeps the seam
    // implementable.
    return Result<Message>.failure(
      const AppError(code: 'not_exercised', userMessage: ''),
    );
  }

  @override
  Stream<MessageRealtimeEvent> watchMessages(String threadId) {
    return const Stream<MessageRealtimeEvent>.empty();
  }
}

/// Gateway stub that yields an empty thread list (empty-state widget pin).
class _EmptyMessageGateway implements MessageGateway {
  @override
  Future<Result<List<MessageThread>>> fetchThreads() async {
    return Result<List<MessageThread>>.success(const <MessageThread>[]);
  }

  @override
  Future<Result<List<Message>>> fetchMessages(String threadId) async {
    return const Result<List<Message>>.success(<Message>[]);
  }

  @override
  Future<Result<Message>> sendMessage(
    String threadId,
    String body, {
    String? authorDisplayName,
  }) async {
    // Not exercised by these tests; an honest failure keeps the seam
    // implementable.
    return Result<Message>.failure(
      const AppError(code: 'not_exercised', userMessage: ''),
    );
  }

  @override
  Stream<MessageRealtimeEvent> watchMessages(String threadId) {
    return const Stream<MessageRealtimeEvent>.empty();
  }
}
