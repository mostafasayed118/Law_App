import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/checkout_launcher.dart';
import '../domain/invoice.dart';
import '../domain/payment_gateway.dart';
import '../domain/payment_status.dart';
import 'invoice_labels.dart';
import 'payment_cubit.dart';
import 'payment_state.dart';

/// Opens the payment sheet for [invoice].
///
/// The cubit is created here and provided with `BlocProvider.value`, so the
/// sheet shares exactly one attempt and the cubit is closed when the sheet
/// disappears (cancelling any live poll timer).
Future<void> showInvoicePaymentSheet({
  required BuildContext context,
  required Invoice invoice,
  required PaymentGateway gateway,
  required CheckoutLauncher launcher,
  required Future<void> Function() onSettled,
}) async {
  final PaymentCubit cubit = PaymentCubit(gateway);
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => BlocProvider<PaymentCubit>.value(
        value: cubit,
        child: InvoicePaymentSheet(
          invoice: invoice,
          gateway: gateway,
          launcher: launcher,
          onSettled: onSettled,
        ),
      ),
    );
  } finally {
    await cubit.close();
  }
}

/// Modal sheet body: initiates on open, then renders the attempt lifecycle.
///
/// No card fields exist anywhere: the provider-hosted checkout owns all card
/// data. The sheet only opens a checkout URL (live) or simulates a terminal
/// state (demo).
class InvoicePaymentSheet extends StatefulWidget {
  const InvoicePaymentSheet({
    required this.invoice,
    required this.gateway,
    required this.launcher,
    required this.onSettled,
    super.key,
  });

  final Invoice invoice;
  final PaymentGateway gateway;
  final CheckoutLauncher launcher;
  final Future<void> Function() onSettled;

  @override
  State<InvoicePaymentSheet> createState() => _InvoicePaymentSheetState();
}

class _InvoicePaymentSheetState extends State<InvoicePaymentSheet>
    with WidgetsBindingObserver {
  bool _settledNotified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !mounted ||
        !widget.gateway.isLive) {
      return;
    }
    final PaymentCubit cubit = context.read<PaymentCubit>();
    if (cubit.state.phase == PaymentPhase.pending) {
      unawaited(cubit.checkStatus(widget.invoice.id));
    }
  }

  Future<void> _start() async {
    if (!mounted) {
      return;
    }
    final PaymentCubit cubit = context.read<PaymentCubit>();
    await cubit.pay(widget.invoice.id);
    if (!mounted) {
      return;
    }
    if (cubit.isLive && cubit.state.phase == PaymentPhase.pending) {
      cubit.startPolling(widget.invoice.id);
    }
  }

  Future<void> _openCheckout() async {
    final String? url = context.read<PaymentCubit>().state.session?.checkoutUrl;
    if (url == null) {
      return;
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await widget.launcher.open(uri);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          LegalHubTheme.marginMobile,
          LegalHubTheme.spaceMd,
          LegalHubTheme.marginMobile,
          LegalHubTheme.spaceLg,
        ),
        child: BlocConsumer<PaymentCubit, PaymentState>(
          listenWhen: (PaymentState previous, PaymentState current) =>
              previous.phase != current.phase,
          listener: (BuildContext context, PaymentState state) {
            if (state.phase == PaymentPhase.succeeded && !_settledNotified) {
              _settledNotified = true;
              unawaited(widget.onSettled());
            }
          },
          builder: (BuildContext context, PaymentState state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.paymentSheetTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: LegalHubTheme.spaceXs),
                Text(
                  '${widget.invoice.invoiceNumber} · '
                  '${widget.invoice.currency} '
                  '${invoiceAmountLabel(widget.invoice.amountCents)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: LegalHubTheme.spaceMd),
                ..._content(context, l10n, state),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    AppLocalizations l10n,
    PaymentState state,
  ) {
    final PaymentCubit cubit = context.read<PaymentCubit>();
    switch (state.phase) {
      case PaymentPhase.idle:
      case PaymentPhase.initiating:
        return <Widget>[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(l10n.paymentPreparing, textAlign: TextAlign.center),
          const SizedBox(height: LegalHubTheme.spaceMd),
          _closeButton(context, l10n),
        ];
      case PaymentPhase.pending:
        return <Widget>[
          Text(l10n.paymentWaiting, textAlign: TextAlign.center),
          if (widget.gateway.supportsDemoSimulation &&
              !widget.gateway.isLive) ...<Widget>[
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              l10n.paymentDemoNote,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: LegalHubTheme.spaceSm,
              children: <Widget>[
                TextButton(
                  onPressed: () => cubit.simulate(PaymentStatus.succeeded),
                  child: Text(l10n.paymentDemoSuccess),
                ),
                TextButton(
                  onPressed: () => cubit.simulate(PaymentStatus.failed),
                  child: Text(l10n.paymentDemoFailure),
                ),
                TextButton(
                  onPressed: () => cubit.simulate(PaymentStatus.cancelled),
                  child: Text(l10n.paymentDemoCancel),
                ),
              ],
            ),
          ] else ...<Widget>[
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              l10n.paymentHostedCheckoutNote,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: LegalHubTheme.spaceSm,
              children: <Widget>[
                if (state.session?.checkoutUrl != null)
                  FilledButton.tonal(
                    onPressed: _openCheckout,
                    child: Text(l10n.paymentOpenCheckout),
                  ),
                TextButton(
                  onPressed: () => cubit.checkStatus(widget.invoice.id),
                  child: Text(l10n.paymentCheckStatus),
                ),
              ],
            ),
          ],
          if (state.error != null) ...<Widget>[
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              l10n.paymentUnavailable,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: LegalHubTheme.spaceMd),
          _closeButton(context, l10n),
        ];
      case PaymentPhase.succeeded:
        return <Widget>[
          Icon(
            Icons.check_circle_outline,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(
            l10n.paymentSuccessTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: LegalHubTheme.spaceXs),
          Text(
            widget.gateway.isLive
                ? l10n.paymentSuccessBody
                : l10n.paymentDemoSuccessBody,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          _closeButton(context, l10n),
        ];
      case PaymentPhase.failed:
        return _terminal(
          context,
          l10n,
          title: l10n.paymentFailedTitle,
          body: state.error != null
              ? l10n.paymentUnavailable
              : l10n.paymentFailedBody,
        );
      case PaymentPhase.cancelled:
        return _terminal(
          context,
          l10n,
          title: l10n.paymentCancelledTitle,
          body: l10n.paymentCancelledBody,
        );
      case PaymentPhase.expired:
        return _terminal(
          context,
          l10n,
          title: l10n.paymentExpiredTitle,
          body: l10n.paymentExpiredBody,
        );
    }
  }

  List<Widget> _terminal(
    BuildContext context,
    AppLocalizations l10n, {
    required String title,
    required String body,
  }) {
    return <Widget>[
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: LegalHubTheme.spaceXs),
      Text(body, textAlign: TextAlign.center),
      const SizedBox(height: LegalHubTheme.spaceMd),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: LegalHubTheme.spaceSm,
        children: <Widget>[
          FilledButton.tonal(onPressed: _start, child: Text(l10n.paymentRetry)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.paymentClose),
          ),
        ],
      ),
    ];
  }

  Widget _closeButton(BuildContext context, AppLocalizations l10n) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.paymentClose),
      ),
    );
  }
}
