import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/localization/locale_cubit.dart';
import '../../../app/router.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/roles/user_role.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<Locale> _locales = <Locale>[
    Locale('en'),
    Locale('ar'),
    Locale('tr'),
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LocaleState localeState = context.watch<LocaleCubit>().state;
    final AuthState authState = context.watch<AuthCubit>().state;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
        children: <Widget>[
          Text(
            l10n.languageLabel,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          DropdownButtonFormField<Locale>(
            initialValue: localeState.locale,
            decoration: InputDecoration(labelText: l10n.languageLabel),
            items: _locales
                .map(
                  (Locale locale) => DropdownMenuItem<Locale>(
                    value: locale,
                    child: Text(locale.languageCode.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (Locale? value) {
              if (value != null) {
                context.read<LocaleCubit>().setLocale(value);
              }
            },
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
          Text(
            l10n.roleLabel,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(_roleLabel(l10n, authState.session?.primaryRole)),
            subtitle: Text(l10n.demoSessionNotice),
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.profileNavigation),
            onTap: () => context.go(AppRoutes.profile),
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l10n.notificationsTitle),
            onTap: () => context.go(AppRoutes.notifications),
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
          OutlinedButton.icon(
            onPressed: () => context.read<AuthCubit>().signOut(),
            icon: const Icon(Icons.logout),
            label: Text(l10n.signOut),
          ),
        ],
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, UserRole? role) {
    return switch (role) {
      UserRole.attorney => l10n.roleAttorney,
      UserRole.partner => l10n.rolePartner,
      UserRole.complianceOfficer => l10n.roleComplianceOfficer,
      UserRole.researchAnalyst => l10n.roleResearchAnalyst,
      UserRole.admin => l10n.roleAdmin,
      UserRole.client || null => l10n.roleClient,
    };
  }
}
