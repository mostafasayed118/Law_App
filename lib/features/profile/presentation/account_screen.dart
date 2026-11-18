import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/profile/domain/account_gateway.dart';
import 'package:legalhub/features/profile/domain/password_gateway.dart';
import 'package:legalhub/features/profile/presentation/delete_account_sheet.dart';
import 'package:legalhub/features/profile/presentation/password_change_cubit.dart';
import 'package:legalhub/features/profile/presentation/password_change_state.dart';
import 'package:legalhub/features/profile/presentation/profile_edit_cubit.dart';
import 'package:legalhub/features/profile/presentation/profile_edit_state.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/forms/validators.dart';
import 'package:legalhub/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Account settings: display name, password, and the deletion danger zone
/// (ADR-0011).
///
/// Reachable while signed in via Settings → Account. The profile route stays
/// the read-only identity surface; editing lives here so the two do not fight
/// over which cubit owns the session.
class AccountScreen extends StatelessWidget {
  const AccountScreen({required this.initialDisplayName, super.key});

  final String initialDisplayName;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProfileEditCubit>(
          create: (BuildContext context) => ProfileEditCubit(
            serviceLocator<AccountGateway>(),
            initialName: initialDisplayName,
          ),
        ),
        BlocProvider<PasswordChangeCubit>(
          create: (BuildContext context) =>
              PasswordChangeCubit(serviceLocator<PasswordGateway>()),
        ),
      ],
      child: const _AccountBody(),
    );
  }
}

class _AccountBody extends StatelessWidget {
  const _AccountBody();

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
        children: <Widget>[
          Text(
            l10n.accountProfileTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          _ProfileEdit(onError: _showError),
          const Divider(height: LegalHubTheme.spaceXl),
          Text(
            l10n.accountPasswordTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          _PasswordChange(onError: _showError),
          const Divider(height: LegalHubTheme.spaceXl),
          Text(
            l10n.accountDangerTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.accountDeleteAction,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _openDeleteSheet(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openDeleteSheet(BuildContext context) async {
    final bool deleted = await showDeleteAccountSheet(context);
    if (!deleted || !context.mounted) {
      return;
    }
    // The RPC succeeded: end the local session and return to sign-in. The
    // message names exactly what was removed rather than claiming everything.
    final AppLocalizations l10n = AppLocalizations.of(context);
    await context.read<AuthCubit>().signOut();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.accountDeleteSuccess)));
    context.go(AppRoutes.signIn);
  }
}

class _ProfileEdit extends StatelessWidget {
  const _ProfileEdit({required this.onError});

  final void Function(BuildContext context, String message) onError;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextEditingController controller = TextEditingController(
      text: context.read<ProfileEditCubit>().state.name,
    );
    return BlocConsumer<ProfileEditCubit, ProfileEditState>(
      listenWhen: (ProfileEditState a, ProfileEditState b) =>
          b.lastError != null && a.lastError != b.lastError,
      listener: (BuildContext context, ProfileEditState state) {
        if (state.lastError != null) {
          onError(context, state.lastError!.userMessage);
          context.read<ProfileEditCubit>().acknowledgeError();
        } else if (state.saved) {
          onError(context, l10n.accountSaved);
        }
      },
      builder: (BuildContext context, ProfileEditState state) {
        return Column(
          children: <Widget>[
            Semantics(
              label: l10n.accountDisplayNameLabel,
              child: LegalHubTextField(
                controller: controller,
                hint: l10n.accountDisplayNameLabel,
                onChanged: (String value) =>
                    context.read<ProfileEditCubit>().nameChanged(value),
              ),
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: state.saving || state.name.trim().length < 2
                    ? null
                    : () => context.read<ProfileEditCubit>().save(),
                child: Text(l10n.accountSave),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PasswordChange extends StatefulWidget {
  const _PasswordChange({required this.onError});

  final void Function(BuildContext context, String message) onError;

  @override
  State<_PasswordChange> createState() => _PasswordChangeState();
}

class _PasswordChangeState extends State<_PasswordChange> {
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String? _validate(AppLocalizations l10n, String? value) =>
      LegalHubValidators.strongPassword(l10n)(value);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocConsumer<PasswordChangeCubit, PasswordChangeState>(
      listenWhen: (PasswordChangeState a, PasswordChangeState b) =>
          (b.lastError != null && a.lastError != b.lastError) ||
          (b.changed && !a.changed),
      listener: (BuildContext context, PasswordChangeState state) {
        if (state.lastError != null) {
          widget.onError(
            context,
            state.needsReauth
                ? l10n.accountPasswordReauth
                : state.lastError!.userMessage,
          );
          context.read<PasswordChangeCubit>().acknowledgeError();
        } else if (state.changed) {
          _newPassword.clear();
          _confirmation.clear();
          widget.onError(context, l10n.accountPasswordChanged);
        }
      },
      builder: (BuildContext context, PasswordChangeState state) {
        return Column(
          children: <Widget>[
            Semantics(
              label: l10n.accountNewPasswordLabel,
              child: LegalHubTextField(
                controller: _newPassword,
                hint: l10n.accountNewPasswordLabel,
                obscureText: true,
                validator: (String? value) => _validate(l10n, value),
                onChanged: (String value) {
                  context.read<PasswordChangeCubit>().newPasswordChanged(value);
                  setState(() {});
                },
              ),
            ),
            if (_newPassword.text.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: LegalHubTheme.spaceXs,
                ),
                child: PasswordStrengthIndicator(value: _newPassword.text),
              ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Semantics(
              label: l10n.accountConfirmPasswordLabel,
              child: LegalHubTextField(
                controller: _confirmation,
                hint: l10n.accountConfirmPasswordLabel,
                obscureText: true,
                onChanged: (String value) => context
                    .read<PasswordChangeCubit>()
                    .confirmationChanged(value),
              ),
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed:
                    state.saving ||
                        _newPassword.text.isEmpty ||
                        _newPassword.text != _confirmation.text ||
                        _validate(l10n, _newPassword.text) != null
                    ? null
                    : () => context.read<PasswordChangeCubit>().submit(),
                child: Text(l10n.accountChangePassword),
              ),
            ),
          ],
        );
      },
    );
  }
}
