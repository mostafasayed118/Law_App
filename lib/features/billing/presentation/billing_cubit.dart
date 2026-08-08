import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/billing_gateway.dart';
import '../domain/invoice.dart';
import 'billing_state.dart';

/// Owns the matter-invoices list surface (billing slice, D-BI5).
///
/// [load] fetches the invoice-metadata list on section open (the section
/// wires it after first frame, matching the roster/discovery/matters
/// pattern). Metadata only — nothing but the D-BI1 surface ever crosses the
/// [BillingGateway] boundary (D-11: no payment capability). Widgets render
/// [BillingState] and dispatch intents; they never call the gateway
/// directly.
class BillingCubit extends Cubit<BillingState> {
  BillingCubit(this._gateway) : super(const BillingState());

  final BillingGateway _gateway;

  /// In-flight guard. The initial state IS loading (like
  /// [DocumentCubit.load]'s contract), so the flag — not a state check —
  /// distinguishes "loading in flight" from "not loaded yet"; duplicate
  /// calls while a load is in flight are ignored.
  bool _loading = false;

  /// Loads the invoice-metadata list. The initial state is already loading,
  /// so the first open never re-emits a redundant loading frame; a retry
  /// after an error re-enters loading. An empty list maps to [ViewEmpty]; a
  /// failure to [ViewError].
  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.invoices is! ViewLoading<List<Invoice>>) {
      emit(state.copyWith(invoices: const ViewLoading<List<Invoice>>()));
    }
    final Result<List<Invoice>> result = await _gateway.fetchInvoices();
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<Invoice>>(value: final List<Invoice> invoices):
        emit(
          state.copyWith(
            invoices: invoices.isEmpty
                ? const ViewEmpty<List<Invoice>>()
                : ViewSuccess<List<Invoice>>(invoices),
          ),
        );
      case Failure<List<Invoice>>(error: final AppError error):
        emit(state.copyWith(invoices: ViewError<List<Invoice>>(error)));
    }
  }
}
