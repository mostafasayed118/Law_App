import 'package:legalhub/app/flavor.dart';
import 'package:legalhub/main.dart' as entrypoint;

/// Development flavor entrypoint.
///
/// Run / build with:
/// `flutter run --flavor development -t lib/main_development.dart
/// --dart-define-from-file=.env.development`
Future<void> main() async {
  await entrypoint.bootstrap(AppConfig.developmentFromEnvironment());
}
