import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/app/theme/theme_cubit.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/local/locale_store.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static final List<Locale> _locales = <Locale>[
    for (final String code in supportedLocaleCodes) Locale(code),
  ];

  static const List<ThemeMode> _themeModes = <ThemeMode>[
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Island rebuilds: each row selects only the slice it renders — a locale
    // change doesn't rebuild the theme or role rows and vice versa.
    final Locale locale = context.select<LocaleCubit, Locale>(
      (LocaleCubit cubit) => cubit.state.locale,
    );
    // The role card reads just the projected role, not the whole auth state:
    // a status/error change that leaves the role alone must not rebuild it.
    final UserRole? role = context.select<AuthCubit, UserRole?>(
      (AuthCubit cubit) => cubit.state.session?.primaryRole,
    );
    final ThemeMode themeMode = context.select<ThemeCubit, ThemeMode>(
      (ThemeCubit cubit) => cubit.state,
    );
    // The role card and the sign-out label describe the SESSION: a demo
    // session is not a real account, so the copy follows the backend posture
    // instead of calling a configured account a demo.
    final bool localOnly = backendIsLocalOnly;
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
            initialValue: locale,
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
            title: RoleLabel(role: role),
            subtitle: Text(
              localOnly ? l10n.demoSessionNotice : l10n.sessionNoticeConfigured,
            ),
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.profileNavigation),
            onTap: () => context.push(AppRoutes.profile),
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l10n.notificationsTitle),
            onTap: () => context.push(AppRoutes.notifications),
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.domain_outlined),
            title: Text(l10n.orgTitle),
            onTap: () => context.push(AppRoutes.organizations),
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.how_to_reg_outlined),
            title: Text(l10n.acceptInvitationTitle),
            onTap: () => context.push(AppRoutes.acceptInvitation),
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          // Platform-admin entry (P3.5): a navigation hint for any
          // authenticated user — the owner-only RPCs gate server-side, and a
          // non-owner sees the distinct denied state, never empty success.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(l10n.platformAdminTitle),
            onTap: () => context.push(AppRoutes.platformAdmin),
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
          OutlinedButton.icon(
            onPressed: () => context.read<AuthCubit>().signOut(),
            icon: const Icon(Icons.logout),
            label: Text(localOnly ? l10n.signOut : l10n.signOutConfigured),
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
