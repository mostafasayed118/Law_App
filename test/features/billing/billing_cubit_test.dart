import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/billing/domain/billing_gateway.dart';
import 'package:legalhub/features/billing/domain/invoice.dart';
import 'package:legalhub/features/billing/presentation/billing_cubit.dart';
import 'package:legalhub/features/billing/presentation/billing_state.dart';

void main() {
  late _StubBillingGateway gateway;

  setUp(() {
    gateway = _StubBillingGateway();
  });

  group('BillingCubit (billing slice D-BI5)', () {
    test('starts loading with no rows', () {
      final BillingCubit cubit = BillingCubit(gateway);
      addTearDown(cubit.close);

      expect(cubit.state.invoices, const ViewLoading<List<Invoice>>());
    });

    blocTest<BillingCubit, BillingState>(
      'load resolves to the invoice-metadata list',
      build: () => BillingCubit(gateway),
      act: (BillingCubit cubit) => cubit.load(),
      expect: () => <BillingState>[
        BillingState(invoices: ViewSuccess<List<Invoice>>(_invoices)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<BillingCubit, BillingState>(
      'load maps an empty list to ViewEmpty',
      setUp: () => gateway = _StubBillingGateway(
        results: <Result<List<Invoice>>>[
          Result<List<Invoice>>.success(const <Invoice>[]),
        ],
      ),
      build: () => BillingCubit(gateway),
      act: (BillingCubit cubit) => cubit.load(),
      expect: () => <BillingState>[
        const BillingState(invoices: ViewEmpty<List<Invoice>>()),
      ],
    );

    blocTest<BillingCubit, BillingState>(
      'load maps a failure to ViewError',
      setUp: () => gateway = _StubBillingGateway(
        results: <Result<List<Invoice>>>[
          Result<List<Invoice>>.failure(_loadFailure),
        ],
      ),
      build: () => BillingCubit(gateway),
      act: (BillingCubit cubit) => cubit.load(),
      expect: () => <BillingState>[
        BillingState(invoices: ViewError<List<Invoice>>(_loadFailure)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<BillingCubit, BillingState>(
      'duplicate load while in flight is ignored',
      setUp: () => gateway = _StubBillingGateway.withCompleter(),
      build: () => BillingCubit(gateway),
      act: (BillingCubit cubit) async {
        final Future<void> first = cubit.load();
        await cubit.load();
        gateway.completer!.complete(Result<List<Invoice>>.success(_invoices));
        await first;
      },
      expect: () => <BillingState>[
        BillingState(invoices: ViewSuccess<List<Invoice>>(_invoices)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<BillingCubit, BillingState>(
      'load after an error retries into a fresh success',
      setUp: () => gateway = _StubBillingGateway(
        results: <Result<List<Invoice>>>[
          Result<List<Invoice>>.failure(_loadFailure),
          Result<List<Invoice>>.success(_invoices),
        ],
      ),
      build: () => BillingCubit(gateway),
      act: (BillingCubit cubit) async {
        await cubit.load();
        await cubit.load();
      },
      expect: () => <BillingState>[
        BillingState(invoices: ViewError<List<Invoice>>(_loadFailure)),
        const BillingState(invoices: ViewLoading<List<Invoice>>()),
        BillingState(invoices: ViewSuccess<List<Invoice>>(_invoices)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 2),
    );
  });
}

final List<Invoice> _invoices = <Invoice>[
  Invoice(
    id: 'invoice-1',
    matterRef: 'Demo acquisition review',
    invoiceNumber: 'INV-2026-0001',
    amountCents: 125000,
    currency: 'EGP',
    status: InvoiceStatus.issued,
    issuedAt: DateTime(2026, 7, 1),
    dueAt: DateTime(2026, 7, 31),
  ),
  Invoice(
    id: 'invoice-2',
    matterRef: 'Commercial lease consultation',
    invoiceNumber: 'INV-2026-0002',
    amountCents: 87500,
    currency: 'EGP',
    status: InvoiceStatus.paid,
    issuedAt: DateTime(2026, 6, 15),
    dueAt: DateTime(2026, 7, 15),
  ),
];

final AppError _loadFailure = AppError(
  code: 'invoices_failed',
  userMessage: 'Could not load invoices',
);

/// Hand-rolled gateway stub: queue of results (like the matter/discovery
/// stubs), or a Completer for in-flight tests.
class _StubBillingGateway implements BillingGateway {
  _StubBillingGateway({List<Result<List<Invoice>>>? results})
    : _queue = results == null
          ? <Result<List<Invoice>>>[Result<List<Invoice>>.success(_invoices)]
          : List<Result<List<Invoice>>>.of(results),
      completer = null;

  _StubBillingGateway.withCompleter()
    : _queue = const <Result<List<Invoice>>>[],
      completer = Completer<Result<List<Invoice>>>();

  final List<Result<List<Invoice>>> _queue;
  final Completer<Result<List<Invoice>>>? completer;
  int fetchCalls = 0;

  @override
  Future<Result<List<Invoice>>> fetchInvoices() {
    fetchCalls += 1;
    if (completer != null) {
      return completer!.future;
    }
    return Future<Result<List<Invoice>>>.value(_queue.removeAt(0));
  }
}
