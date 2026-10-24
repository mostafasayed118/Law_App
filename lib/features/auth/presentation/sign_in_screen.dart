import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/forms/validators.dart';
import 'package:legalhub/shared/widgets/widgets.dart';
import 'auth_cubit.dart';
import 'widgets/auth_buttons.dart';

/// Sign-in screen matching `stitch_legalhub_mobile_app/sign_in`.
///
/// The primary "Sign In" action starts the local demo session via
/// [AuthCubit.startDemoSession] — no real credentials are sent. Social buttons
/// are presentational placeholders pending a provider integration (later
/// slice); they are disabled with an honest disclosure.
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
    return AuthScaffold(
      leading: const _SignInBackButton(),
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
              const _SignInHeading(),
              const SizedBox(height: LegalHubTheme.spaceXl),
              _SignInCredentials(email: _email, password: _password),
              const SizedBox(height: LegalHubTheme.spaceXl),
              if (context.read<AuthCubit>().supportsDemoSession) ...<Widget>[
                const _DemoSessionSection(),
                const SizedBox(height: LegalHubTheme.spaceXl),
              ],
              _SignInSubmitButton(onSubmit: _submit),
              const SizedBox(height: LegalHubTheme.spaceXl),
              const _SocialSignInSection(),
              const SizedBox(height: LegalHubTheme.spaceXl),
              const _SignUpPrompt(),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      // Real sign-in when a provider is configured; the dev fake resolves
      // the same path to the demo session (credentials never stored).
      context.read<AuthCubit>().signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
    }
  }
}

class _SignInBackButton extends StatelessWidget {
  const _SignInBackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const DirectionalIcon(
        icon: Icons.arrow_back,
        mirroredIcon: Icons.arrow_forward,
      ),
      onPressed: () =>
          context.canPop() ? context.pop() : context.go(AppRoutes.onboarding),
    );
  }
}

class _SignInHeading extends StatelessWidget {
  const _SignInHeading();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.signInWelcome, style: text.displaySmall),
        const SizedBox(height: LegalHubTheme.spaceXs),
        Text(
          l10n.signInSubtitle,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SignInCredentials extends StatelessWidget {
  const _SignInCredentials({required this.email, required this.password});

  final TextEditingController email;
  final TextEditingController password;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LabelledField(
          label: l10n.emailLabel,
          child: LegalHubTextField(
            controller: email,
            hint: l10n.emailPlaceholder,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) => LegalHubValidators.email(l10n, v),
          ),
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
        PasswordField(
          controller: password,
          label: l10n.passwordLabel,
          hint: l10n.passwordPlaceholder,
          textInputAction: TextInputAction.done,
          validator: (v) => LegalHubValidators.required(l10n, v),
          trailing: TextButton(
            onPressed: () => context.push(AppRoutes.forgotPassword),
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
      ],
    );
  }
}

/// Development-only shortcut (mirrors the widget-test `startDemoSession`
/// path): one tap enters the demo session with no credentials, matching how
/// env-less runs and tests drive the app. The demo notice stays explicit so
/// the shortcut never reads as a production sign-in.
///
/// Rendered only when the SEAM says the demo path exists
/// (`AuthCubit.supportsDemoSession` — true for the dev fake, false for the
/// real provider, whose startDemoSession always denies). A configured build
/// used to render a tappable button that could only ever fail (audit
/// 2026-09-21, H-5).
class _DemoSessionSection extends StatelessWidget {
  const _DemoSessionSection();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (BuildContext context, AuthState state) {
        final bool loading = state.status == AuthStatus.loading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: loading
                  ? null
                  : () => context.read<AuthCubit>().startDemoSession(),
              icon: const Icon(Icons.science_outlined, size: 18),
              label: Text(l10n.continueAsDemo),
            ),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(
              l10n.demoSessionNotice,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}

class _SignInSubmitButton extends StatelessWidget {
  const _SignInSubmitButton({required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (BuildContext context, AuthState state) {
        final bool loading = state.status == AuthStatus.loading;
        return LoadingElevatedButton(
          onPressed: loading ? null : onSubmit,
          label: l10n.signInButton,
          loading: loading,
          icon: Icons.lock_outline,
        );
      },
    );
  }
}

/// E2E BUG-2 fix: no social provider is wired yet, but both buttons used
/// `context.go(AppRoutes.signUp)` — tapping "Continue with Google/Apple"
/// silently opened the Create Account form, which misrepresents what
/// happened. They are now genuinely DISABLED (`onTap: null`) with an honest
/// disclosure beneath, mirroring the demo-session notice pattern used above.
/// Wiring a real provider is a separate slice; this keeps the surface
/// truthful until then.
class _SocialSignInSection extends StatelessWidget {
  const _SocialSignInSection();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        EditorialDivider(label: l10n.orContinueWith),
        const SizedBox(height: LegalHubTheme.spaceMd),
        Row(
          children: <Widget>[
            Expanded(
              child: SocialButton(
                label: l10n.continueWithGoogle,
                icon: Icons.g_mobiledata_outlined,
                onTap: null,
              ),
            ),
            const SizedBox(width: LegalHubTheme.spaceMd),
            Expanded(
              child: SocialButton(
                label: l10n.continueWithApple,
                icon: Icons.apple,
                onTap: null,
              ),
            ),
          ],
        ),
        const SizedBox(height: LegalHubTheme.spaceXs),
        Text(
          l10n.socialSignInUnavailable,
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SignUpPrompt extends StatelessWidget {
  const _SignUpPrompt();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(l10n.newToLegalHub, style: text.bodySmall),
          TextButton(
            onPressed: () => context.push(AppRoutes.signUp),
            child: Text(
              l10n.createAccount,
              style: text.bodySmall?.copyWith(
                color: scheme.secondary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: scheme.secondary.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
