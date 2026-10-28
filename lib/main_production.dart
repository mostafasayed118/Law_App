import 'package:legalhub/app/flavor.dart';
import 'package:legalhub/main.dart' as entrypoint;

/// Production flavor entrypoint.
///
/// Run / build with:
/// `flutter run --flavor production -t lib/main_production.dart
/// --dart-define-from-file=.env.production`
Future<void> main() => entrypoint.runGuardedEntrypoint(
  () => entrypoint.bootstrap(AppConfig.productionFromEnvironment()),
);
