import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/legalhub_theme.dart';
import '../../../../app/router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';

/// Step 2 — enter the 6-digit verification code.
///
/// No verification gateway exists yet; "Verify & Continue" routes to the reset
/// screen once 6 digits are entered. Real OTP verification is a later slice.
class ForgotPasswordOtpScreen extends StatefulWidget {
  const ForgotPasswordOtpScreen({super.key});

  @override
  State<ForgotPasswordOtpScreen> createState() =>
      _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  final ValueNotifier<bool> _complete = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _complete.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return AuthScaffold(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
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
          OtpFieldRow(completionNotifier: _complete),
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
          Center(
            child: TextButton(onPressed: () {}, child: Text(l10n.resendCode)),
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
    context.go(AppRoutes.forgotPasswordReset);
  }
}
