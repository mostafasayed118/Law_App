import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/localization/locale_cubit.dart';
import '../../../app/router.dart';
import '../../../app/theme/theme_cubit.dart';
import '../../../core/auth/auth_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/presentation/auth_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<Locale> _locales = <Locale>[
    Locale('en'),
    Locale('ar'),
    Locale('tr'),
  ];

  static const List<ThemeMode> _themeModes = <ThemeMode>[
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LocaleState localeState = context.watch<LocaleCubit>().state;
    final AuthState authState = context.watch<AuthCubit>().state;
    final ThemeMode themeMode = context.watch<ThemeCubit>().state;
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
            l10n.themeLabel,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          DropdownButtonFormField<ThemeMode>(
            initialValue: themeMode,
            // isExpanded lets the selected label ellipsize inside the field
            // instead of overflowing — needed on narrow screens (the route
            // transition lays the incoming page out at ~176px) and at text
            // scale 2.0 (the language dropdown's value is short, EN; the
            // theme value, "System default", is not).
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.themeLabel),
            items: _themeModes
                .map(
                  (ThemeMode mode) => DropdownMenuItem<ThemeMode>(
                    value: mode,
                    child: Text(
                      _themeModeLabel(context, mode),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (ThemeMode? value) {
              if (value != null) {
                context.read<ThemeCubit>().setThemeMode(value);
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
            title: RoleLabel(role: authState.session?.primaryRole),
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
          const SizedBox(height: LegalHubTheme.spaceSm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.domain_outlined),
            title: Text(l10n.orgTitle),
            onTap: () => context.go(AppRoutes.organizations),
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.how_to_reg_outlined),
            title: Text(l10n.acceptInvitationTitle),
            onTap: () => context.go(AppRoutes.acceptInvitation),
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          // Platform-admin entry (P3.5): a navigation hint for any
          // authenticated user — the owner-only RPCs gate server-side, and a
          // non-owner sees the distinct denied state, never empty success.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(l10n.platformAdminTitle),
            onTap: () => context.go(AppRoutes.platformAdmin),
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

  static String _themeModeLabel(BuildContext context, ThemeMode mode) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return switch (mode) {
      ThemeMode.system => l10n.themeModeSystem,
      ThemeMode.light => l10n.themeModeLight,
      ThemeMode.dark => l10n.themeModeDark,
    };
  }
}
