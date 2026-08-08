import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/billing/domain/billing_gateway.dart';
import 'package:legalhub/features/billing/domain/invoice.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/matters/presentation/matter_details_screen.dart';
import 'package:legalhub/features/messaging/domain/message.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_realtime_event.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'package:legalhub/features/storage/domain/file_metadata.dart';
import 'package:legalhub/features/storage/domain/storage_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpDetails(WidgetTester tester, String matterId) async {
    // MatterDetailsScreen resolves MatterGateway from the locator (the dev
    // fake in env-less runs).
    configureDependencies();
    // A tall surface so the full details projection builds inside the
    // ListView (children below the fold are not built).
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        // Pin the locale so l10n.localeName == 'en' and the date assertion
        // below is exact rather than coincidental (same harness choice as
        // router_test).
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MatterDetailsScreen(
          matterId: matterId,
          capabilities: roleCapabilities[UserRole.client]!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('matter details (Phase 7 slice 7.2)', () {
    testWidgets(
      'renders the read-only projection — status, practice area, attorney, '
      'created date (AC-3)',
      (tester) async {
        await pumpDetails(tester, 'matter-1');

        final Matter matter = FakeMatterGateway.syntheticMatters.firstWhere(
          (Matter m) => m.id == 'matter-1',
        );

        expect(find.text('Matter details'), findsOneWidget);
        expect(find.text(matter.title), findsOneWidget);
        expect(find.text('Active'), findsOneWidget); // status chip
        expect(find.text('Corporate'), findsOneWidget); // practice area
        expect(find.text('Layla Mansour'), findsOneWidget); // attorney
        // Created date renders locale-aware (same shape as the profile
        // surface's date rows).
        final DateFormat createdFormat = DateFormat.yMMMd('en');
        expect(
          find.text(createdFormat.format(matter.createdAt)),
          findsOneWidget,
        );
      },
    );

    testWidgets('read-only line pin: no action buttons on the surface (AC-3)', (
      tester,
    ) async {
      await pumpDetails(tester, 'matter-1');

      // D-M1: the details projection is display-only — no create/edit/close/
      // upload affordances anywhere. The pin targets the action-button types
      // only: an AppBar back button (an IconButton, present only when the
      // route is push-navigated) is navigation, not a matter action, so it
      // must never trip this line.
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('an unknown id renders the localized not-found state', (
      tester,
    ) async {
      await pumpDetails(tester, 'no-such-id');

      expect(find.text('Matter not found.'), findsOneWidget);
      expect(find.text('Active'), findsNothing);
    });

    testWidgets('carries the local-only demo note (R1)', (tester) async {
      await pumpDetails(tester, 'matter-1');

      // The synthetic matter must never read as a real case.
      expect(find.textContaining('synthetic matters only'), findsOneWidget);
    });

    testWidgets(
      'workspace sections render only this matter’s documents, files, '
      'threads, and invoices (Phase 10 AC-1; storage D-STR7; billing '
      'D-BI5)',
      (tester) async {
        await pumpDetails(tester, 'matter-1');

        // Section headers render (D-W1).
        expect(find.text('Documents'), findsOneWidget);
        expect(find.text('Files'), findsOneWidget);
        expect(find.text('Messages'), findsOneWidget);
        expect(find.text('Invoices'), findsOneWidget);

        // matter-1 owns doc-1 + file-1 + thread-1 + invoice-1 only — the
        // per-matter filter is a client-side view over the fake lists
        // (D-M5/D-W1/D-W2/D-STR5/D-BI5).
        expect(find.text('Demo engagement letter'), findsOneWidget);
        expect(find.text('Demo retainer scan'), findsOneWidget);
        // The file row's secondary line is the byte-size label (245760 bytes
        // → exactly '240 KB') — the KB branch of the formatter, pinned
        // through the widget (D-STR3 metadata surface).
        expect(find.text('240 KB'), findsOneWidget);
        expect(find.text('Demo matter updates'), findsOneWidget);
        expect(find.text('INV-2026-0001'), findsOneWidget);
        expect(find.text('Sample matter brief — demo'), findsNothing);
        expect(find.text('Demo lease annex'), findsNothing);
        expect(find.text('Consultation follow-up — demo'), findsNothing);
        expect(find.text('INV-2026-0002'), findsNothing);
      },
    );

    testWidgets('workspace sections stay body-less — no preview, send, or row '
        'affordance (Phase 10 AC-2)', (tester) async {
      await pumpDetails(tester, 'matter-1');

      // D-W4 body-less/read-only line: no content affordances anywhere on
      // the surface, and no row is a tap target (no chevron, no InkWell
      // inside the details list — contrast the matter list rows).
      expect(find.byIcon(Icons.preview), findsNothing);
      expect(find.byIcon(Icons.download), findsNothing);
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.byIcon(Icons.reply), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('an empty per-matter subset renders the localized empty copy '
        '(Phase 10 AC-3)', (tester) async {
      // Stub gateways returning empty lists, registered before
      // configureDependencies so the fake registrations are skipped.
      await resetServiceLocator();
      serviceLocator.registerLazySingleton<DocumentGateway>(
        _EmptyDocumentGateway.new,
      );
      serviceLocator.registerLazySingleton<MessageGateway>(
        _EmptyMessageGateway.new,
      );
      serviceLocator.registerLazySingleton<StorageGateway>(
        _EmptyStorageGateway.new,
      );
      serviceLocator.registerLazySingleton<BillingGateway>(
        _EmptyBillingGateway.new,
      );

      await pumpDetails(tester, 'matter-1');

      expect(
        find.text('No documents are available for this matter.'),
        findsOneWidget,
      );
      expect(
        find.text('No files are available for this matter.'),
        findsOneWidget,
      );
      expect(
        find.text('No message threads are available for this matter.'),
        findsOneWidget,
      );
      expect(
        find.text('No invoices are available for this matter.'),
        findsOneWidget,
      );
      expect(find.text('Demo engagement letter'), findsNothing);
      expect(find.text('Demo retainer scan'), findsNothing);
      expect(find.text('Demo matter updates'), findsNothing);
      expect(find.text('INV-2026-0001'), findsNothing);
    });

    testWidgets(
      'workspace sections honor the capability flags (Phase 10 AC-4)',
      (tester) async {
        configureDependencies();
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MatterDetailsScreen(
              matterId: 'matter-1',
              capabilities: const RoleCapability(
                canViewHome: true,
                canViewSettings: true,
                canBookConsultation: true,
                canViewAttorneyDiscovery: true,
                canViewMatters: true,
                canViewDocuments: false,
                canViewMessages: false,
                canViewFiles: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // All three sections are hidden when their capability flags are not
        // granted (nav hints only, D-W5); the projection still renders.
        expect(find.text('Documents'), findsNothing);
        expect(find.text('Files'), findsNothing);
        expect(find.text('Messages'), findsNothing);
        expect(find.text('Demo acquisition review'), findsOneWidget);
      },
    );

    testWidgets('a load failure renders the error state and retry reloads', (
      tester,
    ) async {
      // Stub gateway: first call fails, retry succeeds — registered before
      // configureDependencies so the fake registration is skipped.
      await resetServiceLocator();
      serviceLocator.registerLazySingleton<MatterGateway>(
        _RetryMatterGateway.new,
      );

      await pumpDetails(tester, 'matter-1');

      expect(find.text('Unable to load matters.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // The retry resolved into the real details projection.
      expect(find.text('Demo acquisition review'), findsOneWidget);
      expect(find.text('Unable to load matters.'), findsNothing);
    });
  });
}

/// Gateway stub that yields an empty document list (workspace empty pin).
class _EmptyDocumentGateway implements DocumentGateway {
  @override
  Future<Result<List<Document>>> fetchDocuments() async {
    return Result<List<Document>>.success(const <Document>[]);
  }
}

/// Gateway stub that yields an empty thread list (workspace empty pin).
class _EmptyMessageGateway implements MessageGateway {
  @override
  Future<Result<List<MessageThread>>> fetchThreads() async {
    return Result<List<MessageThread>>.success(const <MessageThread>[]);
  }

  @override
  Future<Result<List<Message>>> fetchMessages(String threadId) async {
    return Result<List<Message>>.success(const <Message>[]);
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

/// Gateway stub that yields an empty file list (workspace empty pin).
class _EmptyStorageGateway implements StorageGateway {
  @override
  Future<Result<List<FileMetadata>>> fetchFiles() async {
    return Result<List<FileMetadata>>.success(const <FileMetadata>[]);
  }
}

/// Gateway stub that yields an empty invoice list (workspace empty pin,
/// billing D-BI5).
class _EmptyBillingGateway implements BillingGateway {
  @override
  Future<Result<List<Invoice>>> fetchInvoices() async {
    return Result<List<Invoice>>.success(const <Invoice>[]);
  }
}

/// Gateway stub that fails once then succeeds (retry round-trip pin).
class _RetryMatterGateway implements MatterGateway {
  int _calls = 0;

  @override
  Future<Result<List<Matter>>> fetchMatters() async {
    _calls++;
    if (_calls == 1) {
      return Result<List<Matter>>.failure(
        const AppError(code: 'matters_failed', userMessage: 'failed'),
      );
    }
    return Result<List<Matter>>.success(FakeMatterGateway.syntheticMatters);
  }
}
