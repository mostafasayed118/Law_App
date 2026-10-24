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
import 'package:legalhub/shared/widgets/widgets.dart';

import 'otp_field_row.dart';
import 'recovery_error_localizer.dart';
import 'recovery_routing_context.dart';

/// Which action initiated the current recovery operation on this screen, so
/// the success listener can distinguish "verify → advance" from "resend →
/// stay with a generic ack".
enum _OtpAction { verify, resend }

/// Step 2 — enter the 6-digit verification code.
///
/// P3.1 wires both actions through [PasswordRecoveryCubit]:
/// - "Verify & Continue" calls [PasswordRecoveryCubit.verifyCode]; success
///   threads email + OTP onward to the reset step.
/// - "Resend code" calls [PasswordRecoveryCubit.sendCode]; success stays on
///   this screen with the generic acknowledgement.
///
/// Responses are generic and non-enumerating (plan §7): a wrong/expired/revoked
/// code renders one generic denial, never a per-failure hint.
class ForgotPasswordOtpScreen extends StatefulWidget {
  const ForgotPasswordOtpScreen({super.key});

  @override
  State<ForgotPasswordOtpScreen> createState() =>
      _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  final ValueNotifier<bool> _complete = ValueNotifier<bool>(false);
  final GlobalKey<OtpFieldRowState> _otpKey = GlobalKey<OtpFieldRowState>();
  _OtpAction _lastAction = _OtpAction.verify;

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
    final RecoveryRoutingContext incoming = _contextFrom(
      GoRouterState.of(context),
    );
    return BlocProvider<PasswordRecoveryCubit>(
      create: (_) =>
          PasswordRecoveryCubit(serviceLocator<PasswordRecoveryGateway>()),
      child: BlocListener<PasswordRecoveryCubit, ViewState<void>>(
        listenWhen: (ViewState<void> previous, ViewState<void> current) =>
            current is ViewSuccess<void> && previous is! ViewSuccess<void>,
        listener: (BuildContext context, ViewState<void> state) {
          if (_lastAction == _OtpAction.verify) {
            // Thread email + OTP onward. In-memory `extra` only —
            // the OTP is a short-lived credential and must not appear in the
            // URL.
            // E2E BUG-1 fix: forward step of the recovery wizard — push so
            // BACK steps back to the OTP screen instead of exiting the app.
            context.push(
              AppRoutes.forgotPasswordReset,
              extra: RecoveryRoutingContext(
                email: incoming.email,
                otp: _otpKey.currentState?.code ?? '',
              ),
            );
          } else {
            // Resend: generic acknowledgement; stay on this screen.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).codeSentNotice),
              ),
            );
          }
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
                context.go(AppRoutes.forgotPassword);
              }
            },
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
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: LegalHubTheme.spaceXl * 1.5),
              OtpFieldRow(key: _otpKey, completionNotifier: _complete),
              const SizedBox(height: LegalHubTheme.spaceXl * 1.5),
              ValueListenableBuilder<bool>(
                valueListenable: _complete,
                builder: (BuildContext context, bool complete, Widget? _) {
                  return BlocBuilder<PasswordRecoveryCubit, ViewState<void>>(
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
                                state: localizeRecoveryError(state, l10n),
                                onRetry: () => context
                                    .read<PasswordRecoveryCubit>()
                                    .resetToEmpty(),
                              ),
                            ),
                          ElevatedButton(
                            onPressed: (complete && !loading)
                                ? () => _verify(context, incoming)
                                : null,
                            child: loading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(l10n.verifyAndContinueButton),
                          ),
                          // R2 (2026-09-24): the disabled state is
                          // intentional (no partial-code submit) — make the
                          // intent visible instead of a silent dead button.
                          if (!complete && !loading)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                top: LegalHubTheme.spaceXs,
                              ),
                              child: Text(
                                l10n.otpIncompleteHint,
                                textAlign: TextAlign.center,
                                style: text.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: LegalHubTheme.spaceLg),
              // P3.1: the resend action is wired to sendCode (the single place
              // the plan reserved for it). Generic acknowledgement only.
              // Builder scopes the context below the [BlocProvider] so
              // `_resend` can resolve the cubit (the State's own context
              // sits above it).
              Center(
                child: Builder(
                  builder: (BuildContext builderContext) => TextButton(
                    onPressed: () => _resend(builderContext, incoming),
                    child: Text(l10n.resendCode),
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
        ),
      ),
    );
  }

  /// [context] must be a builder context below the [BlocProvider] so the
  /// [PasswordRecoveryCubit] resolves (the State's own context sits above it).
  void _verify(BuildContext context, RecoveryRoutingContext incoming) {
    _lastAction = _OtpAction.verify;
    context.read<PasswordRecoveryCubit>().verifyCode(
      email: incoming.email,
      code: _otpKey.currentState?.code ?? '',
    );
  }

  void _resend(BuildContext context, RecoveryRoutingContext incoming) {
    _lastAction = _OtpAction.resend;
    context.read<PasswordRecoveryCubit>().sendCode(incoming.email);
  }
}
