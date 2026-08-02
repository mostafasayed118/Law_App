import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../core/auth/auth_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/forms/validators.dart';
import '../../../shared/widgets/widgets.dart';
import 'auth_cubit.dart';
import 'widgets/auth_buttons.dart';

/// Sign-in screen matching `stitch_legalhub_mobile_app/sign_in`.
///
/// The primary "Sign In" action starts the local demo session via
/// [AuthCubit.startDemoSession] — no real credentials are sent. Social buttons
/// are presentational placeholders pending a provider integration (later
/// slice); tapping them routes to sign-up for now.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
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
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.onboarding),
      ),
      maxWidth: 520,
      scrollPadding: const EdgeInsetsDirectional.fromSTEB(
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceLg,
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceXl,
      ),
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (AuthState previous, AuthState current) =>
            previous.status != current.status &&
            current.status == AuthStatus.error,
        listener: (BuildContext context, AuthState state) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.signInErrorNotice)));
        },
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.signInWelcome, style: text.displaySmall),
              const SizedBox(height: LegalHubTheme.spaceXs),
              Text(
                l10n.signInSubtitle,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: LegalHubTheme.spaceXl),
              LabelledField(
                label: l10n.emailLabel,
                child: LegalHubTextField(
                  controller: _email,
                  hint: l10n.emailPlaceholder,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => LegalHubValidators.email(l10n, v),
                ),
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              PasswordField(
                controller: _password,
                label: l10n.passwordLabel,
                hint: l10n.passwordPlaceholder,
                textInputAction: TextInputAction.done,
                validator: (v) => LegalHubValidators.required(l10n, v),
                trailing: TextButton(
                  onPressed: () => context.go(AppRoutes.forgotPassword),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.forgotPassword,
                    style: text.labelLarge?.copyWith(color: scheme.secondary),
                  ),
                ),
              ),
              const SizedBox(height: LegalHubTheme.spaceXl),
              BlocBuilder<AuthCubit, AuthState>(
                builder: (BuildContext context, AuthState state) {
                  final bool loading = state.status == AuthStatus.loading;
                  return LoadingElevatedButton(
                    onPressed: loading ? null : _submit,
                    label: l10n.signInButton,
                    loading: loading,
                    icon: Icons.lock_outline,
                  );
                },
              ),
              const SizedBox(height: LegalHubTheme.spaceXl),
              EditorialDivider(label: l10n.orContinueWith),
              const SizedBox(height: LegalHubTheme.spaceMd),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SocialButton(
                      label: l10n.continueWithGoogle,
                      icon: Icons.g_mobiledata_outlined,
                      onTap: () => context.go(AppRoutes.signUp),
                    ),
                  ),
                  const SizedBox(width: LegalHubTheme.spaceMd),
                  Expanded(
                    child: SocialButton(
                      label: l10n.continueWithApple,
                      icon: Icons.apple,
                      onTap: () => context.go(AppRoutes.signUp),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LegalHubTheme.spaceXl),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(l10n.newToLegalHub, style: text.bodySmall),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.signUp),
                      child: Text(
                        l10n.createAccount,
                        style: text.bodySmall?.copyWith(
                          color: scheme.secondary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: scheme.secondary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      // No real auth gateway exists yet; use the demo session seam.
      context.read<AuthCubit>().startDemoSession();
    }
  }
}
