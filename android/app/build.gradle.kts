import java.io.FileInputStream
import java.util.Properties

// Release signing (audit doc §12.19): credentials live in android/key.properties
// (gitignored); the keystore itself lives outside the repo. When the file is
// absent the build falls back to debug signing ONLY behind an explicit
// opt-in (R4, 2026-09-24): `-PallowDebugSigning=true` on the Gradle command
// line or `ALLOW_DEBUG_SIGNING=true` in the environment (the CI
// release-build-proof job sets the env var). A store AAB built on a machine
// missing the keystore without the flag FAILS loudly instead of silently
// shipping debug-signed bytes.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val allowDebugSigning =
    project.hasProperty("allowDebugSigning") ||
        System.getenv("ALLOW_DEBUG_SIGNING") == "true"

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // ApplicationId confirmed by the owner on 2026-09-23 (audit doc §12.19) —
    // it is the app's deep-link scheme host (com.legalhub.app://accept-invite)
    // and must not change after a store upload.
    namespace = "com.legalhub.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Required: product flavors below set per-flavor `resValue`s (app_name).
    // AGP refuses custom flavor resource values while this is disabled.
    buildFeatures {
        resValues = true
    }

    defaultConfig {
        applicationId = "com.legalhub.app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Default deep-link scheme (== applicationId, audit doc §12.19).
        // Each product flavor below overrides it so a dev install owns
        // `com.legalhub.app.dev://` and can never intercept prod links.
        manifestPlaceholders["deepLinkScheme"] = "com.legalhub.app"
    }

    // Build flavors: `development` (daily loop) vs `production` (store).
    // Select with `--flavor development|production` on every flutter
    // run/build invocation. Production keeps the original applicationId
    // byte-for-byte (audit doc §12.19: it must not change after a store
    // upload); development appends `.dev` so both installs coexist on one
    // device. `flutter run`/`flutter build` without `--flavor` builds every
    // flavor — always pass `--flavor` explicitly.
    flavorDimensions += "environment"
    productFlavors {
        create("development") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "LegalHub Dev")
            manifestPlaceholders["deepLinkScheme"] = "com.legalhub.app.dev"
        }
        create("production") {
            dimension = "environment"
            resValue("string", "app_name", "LegalHub")
            manifestPlaceholders["deepLinkScheme"] = "com.legalhub.app"
        }
    }

    buildTypes {
        release {
            // Real upload keystore when android/key.properties exists (the
            // standard Flutter release-signing pattern); debug keys otherwise
            // ONLY with the explicit R4 opt-in above.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.create("release") {
                    storeFile = file(keystoreProperties["storeFile"] as String)
                    storePassword = keystoreProperties["storePassword"] as String
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                }
            } else if (allowDebugSigning) {
                signingConfigs.getByName("debug")
            } else {
                throw GradleException(
                    "android/key.properties is missing and neither " +
                        "-PallowDebugSigning nor ALLOW_DEBUG_SIGNING=true " +
                        "was provided. Refusing to build a release with " +
                        "debug keys: provide the upload keystore (audit " +
                        "doc §12.19) or opt in explicitly for a local/CI " +
                        "compile proof (never a store artifact).",
                )
            }
            // R3 (2026-09-24): R8 minification + resource shrinking so
            // release binaries ship hardened and lean. Rules live in
            // proguard-rules.pro (Flutter engine/plugin keep-rules).
            // Store AABs are additionally built with Dart obfuscation:
            // flutter build appbundle --release --obfuscate
            //   --split-debug-info=build/symbols
            // (symbols kept per release for crash-symbolication; CI's
            // compile proof below stays non-obfuscated on purpose).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
