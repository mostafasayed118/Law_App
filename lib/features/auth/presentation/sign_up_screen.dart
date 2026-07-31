import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/forms/validators.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/sign_up_gateway.dart';
import '../domain/sign_up_request.dart';
import '../presentation/sign_up_cubit.dart';
import 'widgets/auth_buttons.dart';

/// Sign-up screen matching `stitch_legalhub_mobile_app/sign_up`.
///
/// This is the second feature screen (after the password-recovery reset
/// screen) to consume the shared [ViewStateView] (ADR-0004): the submit
/// lifecycle renders loading/success/error through the canonical [ViewState]
/// vocabulary. A development-only [SignUpGateway] seam backs the
/// [SignUpCubit]; no real account creation, credential storage, or email
/// verification happens yet. Real sign-up is a later, approved data-layer
/// slice (P1, gated behind the P0 decisions in
/// `docs/auth_tenant_authorization_contract.md` §10).
///
/// On submit, the screen builds a redaction-safe [SignUpRequest] from the
/// validated form fields and hands it to the [SignUpCubit]. The redaction
/// contract on [SignUpRequest] guarantees that any diagnostic the gateway
/// builds from `toRedactedMap()` masks the password, email, and phone.
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
    return BlocProvider<SignUpCubit>(
      create: (_) => SignUpCubit(serviceLocator<SignUpGateway>()),
      child: BlocListener<SignUpCubit, ViewState<void>>(
        listenWhen: (ViewState<void> previous, ViewState<void> current) =>
            current is ViewSuccess<void> && previous is! ViewSuccess<void>,
        listener: (BuildContext context, ViewState<void> state) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).codeSentNotice),
            ),
          );
          context.go(AppRoutes.signIn);
        },
        child: AuthScaffold(
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
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
                    Expanded(
                      child: Text(l10n.agreeToTerms, style: text.bodySmall),
                    ),
                  ],
                ),
                const SizedBox(height: LegalHubTheme.spaceMd),
                BlocBuilder<SignUpCubit, ViewState<void>>(
                  builder: (BuildContext context, ViewState<void> state) {
                    final bool loading = state is ViewLoading<void>;
                    final bool error = state is ViewError<void>;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (error)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              bottom: LegalHubTheme.spaceMd,
                            ),
                            child: ViewStateView<void>(
                              state: state,
                              onRetry: () =>
                                  context.read<SignUpCubit>().resetToEmpty(),
                            ),
                          ),
                        LoadingElevatedButton(
                          onPressed: (_agreedToTerms && !loading)
                              ? () => _submit(context)
                              : null,
                          label: l10n.signUpButton,
                          loading: loading,
                          icon: Icons.lock_outline,
                        ),
                      ],
                    );
                  },
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
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      final SignUpRequest request = SignUpRequest.fromRaw(
        name: _fullName.text,
        email: _email.text,
        phone: _phone.text,
        password: _password.text,
      );
      context.read<SignUpCubit>().submit(request);
    }
  }
}
