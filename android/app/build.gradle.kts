import java.io.FileInputStream
import java.util.Properties

// Release signing (audit doc §12.19): credentials live in android/key.properties
// (gitignored); the keystore itself lives outside the repo. When the file is
// absent (e.g. CI without secrets) the build falls back to debug signing so
// `flutter build/run --release` still works.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

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

    defaultConfig {
        applicationId = "com.legalhub.app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Real upload keystore when android/key.properties exists (the
            // standard Flutter release-signing pattern); debug keys otherwise.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.create("release") {
                    storeFile = file(keystoreProperties["storeFile"] as String)
                    storePassword = keystoreProperties["storePassword"] as String
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                }
            } else {
                signingConfigs.getByName("debug")
            }
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
