group = "dev.pingfront.flutter"
version = "1.0.0"

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // AGP 9 builds Kotlin itself (built-in Kotlin); the app's build picks the Kotlin version.
        classpath("com.android.tools.build:gradle:9.5.0")
    }
}

// The native SDK, sh.pingfront:pingfront, comes from Maven Central.

repositories {
    google()
    mavenCentral()
}

plugins {
    id("com.android.library")
}

// Configured through the AGP DSL interface, not the `android {}` accessor, which AGP 9 deprecates
// while Flutter needs the old DSL switched on.
extensions.configure<com.android.build.api.dsl.LibraryExtension> {
    namespace = "dev.pingfront.flutter"

    // The native SDK compiles against SDK 36 and starts at Android 8.0 (API 26).
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 26
        consumerProguardFiles("consumer-rules.pro")
    }

    testOptions {
        unitTests.all { it.useJUnitPlatform() }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        allWarningsAsErrors.set(true)
    }
}

dependencies {
    implementation("sh.pingfront:pingfront:1.0.0")
    // The same versions as the native Android SDK uses: messages and the team cross to Dart as the
    // SDK's own JSON, and the embedded chat's activity result registry for `FlutterActivity` (ChatView.kt). The chat
    // itself is the SDK's `PingFrontChatView`, so the plugin needs no Compose compiler.
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    implementation("androidx.activity:activity:1.13.0")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit5")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}
