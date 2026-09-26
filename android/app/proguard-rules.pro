# LegalHub release ProGuard / R8 rules (R3, 2026-09-24).
#
# The release build enables minification + resource shrinking
# (build.gradle.kts). These keep-rules are the standard Flutter set: the
# engine, plugins, and platform channels are reached via reflection/JNI, so
# R8 must not strip or rename them. App Dart code ships obfuscated via
# `--obfuscate --split-debug-info` at the `flutter build` layer (store
# builds only — see the release block in build.gradle.kts); these rules
# cover the Android bytecode half.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**
