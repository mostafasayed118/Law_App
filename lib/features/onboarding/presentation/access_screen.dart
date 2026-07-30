import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../core/auth/auth_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/presentation/auth_cubit.dart';

class AccessScreen extends StatelessWidget {
  const AccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(
              LegalHubTheme.marginMobile,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.appTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                  ),
                  const SizedBox(height: LegalHubTheme.spaceXl),
                  Text(
                    l10n.accessTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: LegalHubTheme.spaceMd),
                  Text(l10n.accessBody, textAlign: TextAlign.center),
                  const SizedBox(height: LegalHubTheme.spaceXl),
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (BuildContext context, AuthState state) {
                      final bool loading = state.status == AuthStatus.loading;
                      return LoadingElevatedButton(
                        onPressed: loading
                            ? null
                            : () =>
                                  context.read<AuthCubit>().startDemoSession(),
                        label: l10n.continueAsDemo,
                        loading: loading,
                        icon: Icons.play_arrow_outlined,
                      );
                    },
                  ),
                  const SizedBox(height: LegalHubTheme.spaceMd),
                  Text(
                    l10n.demoSessionNotice,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
