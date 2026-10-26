import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/auth/domain/password_recovery_gateway.dart';
import 'package:legalhub/features/auth/presentation/password_recovery_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/forms/validators.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'recovery_error_localizer.dart';
import 'recovery_routing_context.dart';

/// Step 1 — request a recovery code by email.
///
/// P3.1 wires the submit through [PasswordRecoveryCubit.sendCode]. Responses
/// are **generic and non-enumerating** (plan §7): the provider never reveals
/// whether the account exists, and any failure renders one generic message
/// with a retry affordance — never a per-account hint.
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
    return BlocProvider<PasswordRecoveryCubit>(
      create: (_) =>
          PasswordRecoveryCubit(serviceLocator<PasswordRecoveryGateway>()),
      child: BlocListener<PasswordRecoveryCubit, ViewState<void>>(
        listenWhen: (ViewState<void> previous, ViewState<void> current) =>
            current is ViewSuccess<void> && previous is! ViewSuccess<void>,
        listener: (BuildContext context, ViewState<void> state) {
          // Generic acknowledgement only — never reveals whether the account
          // exists (non-enumerating, plan §7).
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).codeSentNotice),
            ),
          );
          // Thread the entered email to the OTP step via in-memory `extra`
          // (never via the URL — email is PII and must not appear in
          // history/logs). The OTP is unknown at this step.
          // E2E BUG-1 fix: forward step of the recovery wizard — push so
          // BACK steps back to this screen instead of exiting the app.
          context.push(
            AppRoutes.forgotPasswordOtp,
            extra: RecoveryRoutingContext(email: _email.text.trim(), otp: ''),
          );
        },
        child: AuthScaffold(
          leading: IconButton(
            icon: const DirectionalIcon(
              icon: Icons.arrow_back,
              mirroredIcon: Icons.arrow_forward,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.signIn);
              }
            },
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
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
                BlocBuilder<PasswordRecoveryCubit, ViewState<void>>(
                  builder: (BuildContext context, ViewState<void> state) {
                    final bool loading = state is ViewLoading<void>;
                    final bool error = state is ViewError<void>;
                    final ViewState<void> localized = localizeRecoveryError(
                      state,
                      l10n,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (error)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              bottom: LegalHubTheme.spaceMd,
                            ),
                            child: ViewStateView<void>(
                              state: localized,
                              errorFallback: localized is ViewError<void>
                                  ? localized.error.userMessage
                                  : null,
                              onRetry: () => context
                                  .read<PasswordRecoveryCubit>()
                                  .resetToEmpty(),
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: loading ? null : () => _submit(context),
                          icon: const DirectionalIcon(
                            icon: Icons.arrow_forward,
                            mirroredIcon: Icons.arrow_back,
                            size: 18,
                          ),
                          label: loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.sendCodeButton),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: LegalHubTheme.spaceXl),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.signIn);
                      }
                    },
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
        ),
      ),
    );
  }

  /// [context] must be a builder context below the [BlocProvider] so the
  /// [PasswordRecoveryCubit] resolves (the State's own context sits above it).
  void _submit(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<PasswordRecoveryCubit>().sendCode(_email.text.trim());
    }
  }
}
