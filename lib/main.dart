import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/legalhub_theme.dart';
import 'app/localization/locale_cubit.dart';
import 'app/router.dart';
import 'app/service_locator.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  configureDependencies(preferences: preferences);
  final LocaleCubit localeCubit = serviceLocator<LocaleCubit>();
  await localeCubit.load();
  final AuthCubit authCubit = serviceLocator<AuthCubit>();
  runApp(
    LegalHubApp(
      router: createAppRouter(authCubit),
      authCubit: authCubit,
      localeCubit: localeCubit,
    ),
  );
}

class LegalHubApp extends StatelessWidget {
  const LegalHubApp({
    required this.router,
    required this.authCubit,
    required this.localeCubit,
    super.key,
  });

  final RouterConfig<Object> router;
  final AuthCubit authCubit;
  final LocaleCubit localeCubit;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<LocaleCubit>.value(value: localeCubit),
      ],
      child: BlocBuilder<LocaleCubit, LocaleState>(
        builder: (BuildContext context, LocaleState state) {
          return MaterialApp.router(
            onGenerateTitle: (BuildContext context) =>
                AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: LegalHubTheme.forBrightness(
              Brightness.light,
              locale: state.locale,
            ),
            darkTheme: LegalHubTheme.forBrightness(
              Brightness.dark,
              locale: state.locale,
            ),
            themeMode: ThemeMode.system,
            locale: state.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
