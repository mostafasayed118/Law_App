import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/legalhub_theme.dart';
import '../../../../app/router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/forms/validators.dart';
import '../../../../shared/widgets/widgets.dart';

/// Step 3 — set a new password and confirm it.
///
/// No reset gateway exists yet; "Reset Password" routes back to sign-in after
/// a success snackbar. Real password persistence is a later data-layer slice.
class ForgotPasswordResetScreen extends StatefulWidget {
  const ForgotPasswordResetScreen({super.key});

  @override
  State<ForgotPasswordResetScreen> createState() =>
      _ForgotPasswordResetScreenState();
}

class _ForgotPasswordResetScreenState extends State<ForgotPasswordResetScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return AuthScaffold(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go(AppRoutes.forgotPasswordOtp),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.resetPasswordTitle, style: text.displaySmall),
            const SizedBox(height: LegalHubTheme.spaceXl),
            PasswordField(
              controller: _password,
              label: l10n.newPasswordLabel,
              hint: l10n.passwordPlaceholder,
              validator: LegalHubValidators.minLength(l10n, 8),
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            PasswordField(
              controller: _confirm,
              label: l10n.confirmPasswordLabel,
              hint: l10n.passwordPlaceholder,
              validator: (value) =>
                  LegalHubValidators.matches(l10n, _password.text)(value),
            ),
            const SizedBox(height: LegalHubTheme.spaceXl),
            ElevatedButton(
              onPressed: _submit,
              child: Text(l10n.resetPasswordButton),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).resetSuccessNotice),
        ),
      );
      context.go(AppRoutes.signIn);
    }
  }
}
