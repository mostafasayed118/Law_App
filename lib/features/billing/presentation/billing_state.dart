import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/invoice.dart';

/// Immutable state of the matter-invoices surface (billing slice, D-BI5).
///
/// [invoices] holds the invoice-metadata load lifecycle using the shared
/// [ViewState] vocabulary (loading / success / empty / error+retry) — the
/// smallest surface that satisfies the metadata-only line (no payment
/// capability, no per-invoice selection state; D-11).
class BillingState extends Equatable {
  const BillingState({this.invoices = const ViewLoading<List<Invoice>>()});

  final ViewState<List<Invoice>> invoices;

  BillingState copyWith({ViewState<List<Invoice>>? invoices}) {
    return BillingState(invoices: invoices ?? this.invoices);
  }

  @override
  List<Object?> get props => <Object?>[invoices];
}
