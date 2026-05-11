plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // FlutterFire (ok to keep even if unused yet)
    id("com.google.gms.google-services")
    // Must be last among Android/Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.lost_found"

    // Your plugins (firebase_auth, etc.) want 35
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.lost_found"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    // Toolchains
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    buildTypes {
        release {
            // debug signing so `flutter run --release` works locally
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Flutter plugin wires sources automatically
flutter {
    source = "../.."
}

/**
 * Keep dependencies minimal here.
 * Do NOT add repositories{} in this file (settings.gradle.kts manages repos).
 * Also avoid forcing TensorFlow deps here—let the Dart plugin (tflite_flutter)
 * pull the right native AARs to prevent duplicate-class errors.
 */
dependencies {
    // (Intentionally empty)
}
