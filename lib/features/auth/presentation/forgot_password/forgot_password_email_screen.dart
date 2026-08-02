import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/legalhub_theme.dart';
import '../../../../app/router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/forms/validators.dart';
import '../../../../shared/widgets/widgets.dart';
import 'recovery_routing_context.dart';

/// Step 1 — request a recovery code by email.
///
/// No recovery gateway exists yet; "Send Code" routes to the OTP screen after
/// a confirmation snackbar. A real `PasswordRecoveryCubit` + recovery gateway
/// is a later data-layer slice.
class ForgotPasswordEmailScreen extends StatefulWidget {
  const ForgotPasswordEmailScreen({super.key});

  @override
  State<ForgotPasswordEmailScreen> createState() =>
      _ForgotPasswordEmailScreenState();
}

class _ForgotPasswordEmailScreenState extends State<ForgotPasswordEmailScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
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
        onPressed: () => context.go(AppRoutes.signIn),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: LegalHubTheme.spaceXl,
                ),
                child: const IconHeroBadge(
                  icon: Icons.lock_reset_outlined,
                  iconSize: 48,
                ),
              ),
            ),
            Text(
              l10n.recoverPasswordTitle,
              textAlign: TextAlign.center,
              style: text.displaySmall,
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              l10n.recoverPasswordBody,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: LegalHubTheme.spaceXl),
            LegalHubTextField(
              controller: _email,
              hint: l10n.emailPlaceholder,
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => LegalHubValidators.email(l10n, v),
            ),
            const SizedBox(height: LegalHubTheme.spaceLg),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const DirectionalIcon(
                icon: Icons.arrow_forward,
                mirroredIcon: Icons.arrow_back,
                size: 18,
              ),
              label: Text(l10n.sendCodeButton),
            ),
            const SizedBox(height: LegalHubTheme.spaceXl),
            Center(
              child: TextButton.icon(
                onPressed: () => context.go(AppRoutes.signIn),
                icon: const DirectionalIcon(
                  icon: Icons.arrow_back,
                  mirroredIcon: Icons.arrow_forward,
                  size: 18,
                ),
                label: Text(l10n.backToSignIn),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).codeSentNotice)),
      );
      // Thread the entered email to the OTP step via in-memory `extra` (never
      // via the URL — email is PII and must not appear in history/logs). The
      // OTP is unknown at this step and filled in by the OTP screen.
      context.go(
        AppRoutes.forgotPasswordOtp,
        extra: RecoveryRoutingContext(email: _email.text.trim(), otp: ''),
      );
    }
  }
}
