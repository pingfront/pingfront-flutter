group = "dev.pingfront.flutter.superwall"
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

// The native adapter, sh.pingfront:pingfront-superwall, comes from Maven Central.

repositories {
    google()
    mavenCentral()
}

plugins {
    id("com.android.library")
}

extensions.configure<com.android.build.api.dsl.LibraryExtension> {
    namespace = "dev.pingfront.flutter.superwall"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 26
        consumerProguardFiles("consumer-rules.pro")
    }
}

kotlin {
    explicitApi()
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        allWarningsAsErrors.set(true)
    }
}

dependencies {
    // The adapter brings Superwall's SDK and pingfront-core.
    implementation("sh.pingfront:pingfront-superwall:1.0.0")
}
