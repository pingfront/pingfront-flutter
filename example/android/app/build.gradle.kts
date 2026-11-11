plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin (which builds Kotlin itself).
    id("dev.flutter.flutter-gradle-plugin")
}

// Configured through the AGP DSL interface, not the `android {}` accessor: with the old DSL switched on
// for Flutter (gradle.properties), the accessor is deprecated.
extensions.configure<com.android.build.api.dsl.ApplicationExtension> {
    namespace = "dev.pingfront.pingfront_flutter_example"
    // The native SDK compiles against SDK 36 and starts at Android 8.0 (API 26).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.pingfront.pingfront_flutter_example"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // The example is never released: debug keys, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
