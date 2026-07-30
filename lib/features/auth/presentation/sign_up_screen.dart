import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/forms/validators.dart';
import '../../../shared/widgets/widgets.dart';

/// Sign-up screen matching `stitch_legalhub_mobile_app/sign_up`.
///
/// No backend registration exists yet; submitting shows a snackbar and routes
/// back to sign-in. Real registration is a later data-layer slice.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
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
        onPressed: () => context.go(AppRoutes.signIn),
      ),
      maxWidth: 520,
      scrollPadding: const EdgeInsetsDirectional.fromSTEB(
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceLg,
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceXl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.signUpTitle, style: text.displaySmall),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(
              l10n.signUpSubtitle,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: LegalHubTheme.spaceXl),
            LegalHubTextField(
              controller: _fullName,
              label: l10n.fullNameLabel,
              hint: l10n.fullNamePlaceholder,
              prefixIcon: Icons.person_outline,
              validator: (v) => LegalHubValidators.required(l10n, v),
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            LegalHubTextField(
              controller: _email,
              label: l10n.emailLabel,
              hint: l10n.emailPlaceholder,
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => LegalHubValidators.email(l10n, v),
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            LegalHubTextField(
              controller: _phone,
              label: l10n.phoneLabel,
              hint: l10n.phonePlaceholder,
              prefixIcon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => LegalHubValidators.required(l10n, v),
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            PasswordField(
              controller: _password,
              label: l10n.passwordLabel,
              hint: l10n.passwordPlaceholder,
              prefixIcon: Icons.lock_outline,
              validator: LegalHubValidators.minLength(l10n, 8),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                top: LegalHubTheme.spaceXs,
                start: LegalHubTheme.spaceXs,
              ),
              child: Text(l10n.passwordHint, style: text.bodySmall),
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Checkbox(
                  value: _agreedToTerms,
                  onChanged: (bool? value) =>
                      setState(() => _agreedToTerms = value ?? false),
                ),
                Expanded(child: Text(l10n.agreeToTerms, style: text.bodySmall)),
              ],
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            ElevatedButton(
              onPressed: _agreedToTerms ? _submit : null,
              child: Text(l10n.signUpButton),
            ),
            const SizedBox(height: LegalHubTheme.spaceLg),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(l10n.alreadyHaveAccount, style: text.bodySmall),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.signIn),
                    child: Text(
                      l10n.signInLink,
                      style: text.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
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
      context.go(AppRoutes.signIn);
    }
  }
}
