import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/legalhub_theme.dart';
import '../../../../app/router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import 'otp_field_row.dart';
import 'recovery_routing_context.dart';

/// Step 2 — enter the 6-digit verification code.
///
/// Reads the email threaded from step 1 via [RecoveryRoutingContext] (GoRouter
/// `extra`) and, on verify, threads the entered 6-digit code onward to the
/// reset screen so [PasswordRecoveryRequest] is built with real values, not
/// placeholders. Real OTP verification is a later, backend-gated slice; the
/// "Verify & Continue" action here only validates that 6 digits are present.
///
/// The "Resend code" control is intentionally **disabled** in this demo: no
/// gateway exists, so it must not imply a code was sent (INSTRUCTIONS §4.4 —
/// no false assurance). When a real recovery gateway lands, this control is
/// the single place to wire the resend action.
class ForgotPasswordOtpScreen extends StatefulWidget {
  const ForgotPasswordOtpScreen({super.key});

  @override
  State<ForgotPasswordOtpScreen> createState() =>
      _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  final ValueNotifier<bool> _complete = ValueNotifier<bool>(false);
  final GlobalKey<OtpFieldRowState> _otpKey = GlobalKey<OtpFieldRowState>();

  @override
  void dispose() {
    _complete.dispose();
    super.dispose();
  }

  /// Email threaded from step 1. Null on deep-link/refresh (no `extra`); the
  /// empty-context fallback reproduces the prior placeholder behavior.
  RecoveryRoutingContext _contextFrom(GoRouterState state) {
    final Object? extra = state.extra;
    return extra is RecoveryRoutingContext
        ? extra
        : RecoveryRoutingContext.empty;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return AuthScaffold(
      leading: IconButton(
        icon: const DirectionalIcon(
          icon: Icons.arrow_back,
          mirroredIcon: Icons.arrow_forward,
        ),
        onPressed: () => context.go(AppRoutes.forgotPassword),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.verifyEmailTitle,
            textAlign: TextAlign.center,
            style: text.displaySmall,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(
            l10n.verifyEmailBody,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: LegalHubTheme.spaceXl * 1.5),
          OtpFieldRow(key: _otpKey, completionNotifier: _complete),
          const SizedBox(height: LegalHubTheme.spaceXl * 1.5),
          ValueListenableBuilder<bool>(
            valueListenable: _complete,
            builder: (BuildContext context, bool complete, Widget? _) {
              return ElevatedButton(
                onPressed: complete ? _verify : null,
                child: Text(l10n.verifyAndContinueButton),
              );
            },
          ),
          const SizedBox(height: LegalHubTheme.spaceLg),
          // Disabled by design: no resend gateway exists. A disabled control is
          // honest; a tappable no-op would imply a code was sent (§4.4).
          Center(
            child: TextButton(
              onPressed: null,
              child: Text(l10n.resendCodeUnavailable),
            ),
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          Center(
            child: Text(
              l10n.resendHelp,
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  void _verify() {
    final RecoveryRoutingContext incoming = _contextFrom(
      GoRouterState.of(context),
    );
    final String otp = _otpKey.currentState?.code ?? '';
    // Thread both the email from step 1 and the entered OTP to the reset step.
    // In-memory `extra` only — the OTP is a short-lived credential and must
    // not appear in the URL.
    context.go(
      AppRoutes.forgotPasswordReset,
      extra: RecoveryRoutingContext(email: incoming.email, otp: otp),
    );
  }
}
