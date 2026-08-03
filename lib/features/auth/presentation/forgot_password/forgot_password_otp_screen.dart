import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/legalhub_theme.dart';
import '../../../../app/router.dart';
import '../../../../app/service_locator.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/password_recovery_gateway.dart';
import 'otp_field_row.dart';
import 'recovery_routing_context.dart';

/// Step 2 — enter the 6-digit verification code.
///
/// Reads the email threaded from step 1 via [RecoveryRoutingContext] (GoRouter
/// `extra`). "Verify & Continue" calls the [PasswordRecoveryGateway] seam: in
/// configured builds the Supabase-backed implementation really verifies the
/// emailed code (2026-08-03, D1 revised); only a correct, unexpired code
/// advances to the reset step. On success the email and the entered code are
/// threaded onward via [RecoveryRoutingContext] so [PasswordRecoveryRequest]
/// is built with real values, not placeholders.
///
/// "Resend code" repeats the step-1 request for the same email.
class ForgotPasswordOtpScreen extends StatefulWidget {
  const ForgotPasswordOtpScreen({super.key});

  @override
  State<ForgotPasswordOtpScreen> createState() =>
      _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  final ValueNotifier<bool> _complete = ValueNotifier<bool>(false);
  final GlobalKey<OtpFieldRowState> _otpKey = GlobalKey<OtpFieldRowState>();
  bool _verifying = false;
  bool _resending = false;

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
                onPressed: complete && !_verifying ? _verify : null,
                child: _verifying
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.verifyAndContinueButton),
              );
            },
          ),
          const SizedBox(height: LegalHubTheme.spaceLg),
          // Real resend: repeats the step-1 request for the threaded email
          // (2026-08-03, D1 revised).
          Center(
            child: TextButton(
              onPressed: _resending ? null : _resend,
              child: Text(
                _resending ? l10n.resendCodeUnavailable : l10n.resendCode,
              ),
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

  Future<void> _verify() async {
    final RecoveryRoutingContext incoming = _contextFrom(
      GoRouterState.of(context),
    );
    final String otp = _otpKey.currentState?.code ?? '';
    setState(() => _verifying = true);
    final Result<void> result = await serviceLocator<PasswordRecoveryGateway>()
        .verifyCode(email: incoming.email, otp: otp);
    if (!mounted) {
      return;
    }
    setState(() => _verifying = false);
    switch (result) {
      case Success<void>():
        // Thread both the email from step 1 and the verified OTP to the reset
        // step. In-memory `extra` only — the OTP is a short-lived credential
        // and must not appear in the URL.
        context.go(
          AppRoutes.forgotPasswordReset,
          extra: RecoveryRoutingContext(email: incoming.email, otp: otp),
        );
        return;
      case Failure<void>(error: final AppError error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }

  Future<void> _resend() async {
    final RecoveryRoutingContext incoming = _contextFrom(
      GoRouterState.of(context),
    );
    setState(() => _resending = true);
    final Result<void> result = await serviceLocator<PasswordRecoveryGateway>()
        .requestCode(email: incoming.email);
    if (!mounted) {
      return;
    }
    setState(() => _resending = false);
    switch (result) {
      case Success<void>():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).codeSentNotice)),
        );
        return;
      case Failure<void>(error: final AppError error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }
}
