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
/// vocabulary. The [SignUpCubit] is backed by the [SignUpGateway] seam — the
/// Supabase-backed implementation in configured builds, the dev fake
/// otherwise (the DI flip pattern; see `service_locator.dart`).
///
/// On submit, the screen builds a redaction-safe [SignUpRequest] from the
/// validated form fields and hands it to the [SignUpCubit]. The redaction
/// contract on [SignUpRequest] guarantees that any diagnostic the gateway
/// builds from `toRedactedMap()` masks the password, email, and phone.
///
/// On success (Phase 4.2) the form is replaced by a "check your inbox"
/// confirmation instead of a silent route to sign-in: email verification is
/// enabled server-side in configured builds, so the user must verify before
/// their first sign-in — the confirmation closes the false-assurance gap.
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
      child: BlocBuilder<SignUpCubit, ViewState<void>>(
        builder: (BuildContext context, ViewState<void> state) {
          final bool signedUp = state is ViewSuccess<void>;
          return AuthScaffold(
            leading: IconButton(
              icon: const DirectionalIcon(
                icon: Icons.arrow_back,
                mirroredIcon: Icons.arrow_forward,
              ),
              onPressed: () => context.go(AppRoutes.signIn),
            ),
            maxWidth: 520,
            scrollPadding: const EdgeInsetsDirectional.fromSTEB(
              LegalHubTheme.marginMobile,
              LegalHubTheme.spaceLg,
              LegalHubTheme.marginMobile,
              LegalHubTheme.spaceXl,
            ),
            child: signedUp
                ? _CheckInboxSuccess(
                    onContinue: () => context.go(AppRoutes.signIn),
                  )
                : _buildForm(context, l10n, scheme, text),
          );
        },
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    TextTheme text,
  ) {
    return Form(
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

/// The post-submit success surface (Phase 4.2).
///
/// Replaces the form once the [SignUpCubit] reports success: a hero badge,
/// the "check your inbox" message, and a single action that routes to
/// sign-in. The user is never silently routed away — verification is enabled
/// server-side, so the confirmation states what happens next instead of
/// implying the account is immediately usable.
class _CheckInboxSuccess extends StatelessWidget {
  const _CheckInboxSuccess({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(
            bottom: LegalHubTheme.spaceXl,
          ),
          child: Center(
            child: IconHeroBadge(
              icon: Icons.mark_email_read_outlined,
              background: scheme.secondaryContainer,
              iconColor: scheme.onSecondary,
            ),
          ),
        ),
        Text(
          l10n.signUpCheckInboxTitle,
          textAlign: TextAlign.center,
          style: text.displayMedium,
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        Text(
          l10n.signUpCheckInboxBody,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: LegalHubTheme.spaceXl * 1.5),
        ElevatedButton(
          onPressed: onContinue,
          child: Text(l10n.signUpCheckInboxAction),
        ),
      ],
    );
  }
}
