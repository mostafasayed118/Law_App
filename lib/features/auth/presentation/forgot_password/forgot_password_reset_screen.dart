import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/legalhub_theme.dart';
import '../../../../app/router.dart';
import '../../../../app/service_locator.dart';
import '../../../../core/state/view_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/forms/validators.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/password_recovery_gateway.dart';
import '../../domain/password_recovery_request.dart';
import '../password_recovery_cubit.dart';
import '../widgets/auth_buttons.dart';
import 'recovery_routing_context.dart';

/// Step 3 — set a new password and confirm it.
///
/// This is the first feature screen to consume the shared [ViewStateView]
/// (ADR-0004): the submit lifecycle renders loading/success/error through the
/// canonical [ViewState] vocabulary. A development-only
/// [PasswordRecoveryGateway] seam backs the [PasswordRecoveryCubit]; no real
/// password persistence or OTP verification happens yet. Real recovery is a
/// later, approved data-layer slice (P1, gated behind the P0 decisions in
/// `docs/auth_tenant_authorization_contract.md` §10).
///
/// The email and OTP captured in steps 1–2 are threaded to this screen via
/// [RecoveryRoutingContext] (GoRouter in-memory `extra`, never the URL), so the
/// [PasswordRecoveryRequest] built here carries real values — closing the
/// recovery half of D-T2. On deep-link/refresh `extra` is null and the screen
/// falls back to [RecoveryRoutingContext.empty], reproducing the prior
/// placeholder behavior. The redaction contract on [PasswordRecoveryRequest]
/// guarantees these values are safe in any diagnostic.
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
    // Capture the threaded email/OTP once at build time, when a GoRouterState
    // is guaranteed to exist above this screen in the normal flow. Outside a
    // router (e.g. direct unit-test pumps) GoRouterState.of throws; guard so
    // the screen stays reachable and falls back to the empty context — the
    // same behavior as a deep-link/refresh with no `extra`.
    RecoveryRoutingContext routing = RecoveryRoutingContext.empty;
    try {
      final Object? extra = GoRouterState.of(context).extra;
      routing = extra is RecoveryRoutingContext
          ? extra
          : RecoveryRoutingContext.empty;
    } on Object catch (_) {
      routing = RecoveryRoutingContext.empty;
    }
    return BlocProvider<PasswordRecoveryCubit>(
      create: (_) =>
          PasswordRecoveryCubit(serviceLocator<PasswordRecoveryGateway>()),
      child: Builder(
        builder: (BuildContext context) {
          return AuthScaffold(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go(AppRoutes.forgotPasswordOtp),
            ),
            child: BlocListener<PasswordRecoveryCubit, ViewState<void>>(
              listenWhen: (ViewState<void> previous, ViewState<void> current) =>
                  current is ViewSuccess<void> &&
                  previous is! ViewSuccess<void>,
              listener: (BuildContext context, ViewState<void> state) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.resetSuccessNotice)),
                );
                context.go(AppRoutes.signIn);
              },
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
                      validator: (value) => LegalHubValidators.matches(
                        l10n,
                        _password.text,
                      )(value),
                    ),
                    const SizedBox(height: LegalHubTheme.spaceXl),
                    BlocBuilder<PasswordRecoveryCubit, ViewState<void>>(
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
                                  onRetry: () => context
                                      .read<PasswordRecoveryCubit>()
                                      .resetToEmpty(),
                                ),
                              ),
                            LoadingElevatedButton(
                              onPressed: loading
                                  ? null
                                  : () => _submit(context, routing),
                              label: l10n.resetPasswordButton,
                              loading: loading,
                              icon: Icons.lock_outline,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _submit(BuildContext context, RecoveryRoutingContext routing) {
    if (_formKey.currentState?.validate() ?? false) {
      final PasswordRecoveryRequest request = PasswordRecoveryRequest.fromRaw(
        // Email from step 1 and OTP from step 2, threaded via in-memory `extra`.
        // Empty fallback on deep-link/refresh reproduces prior placeholder
        // behavior so the screen stays reachable without a backend.
        email: routing.email,
        otp: routing.otp,
        newPassword: _password.text,
      );
      context.read<PasswordRecoveryCubit>().submit(request);
    }
  }
}
