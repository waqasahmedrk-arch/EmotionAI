pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val path = properties.getProperty("flutter.sdk")
        require(path != null) { "flutter.sdk not set in local.properties" }
        path
    }
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    // Repos for Gradle PLUGINS
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Repos for all project DEPENDENCIES
dependencyResolutionManagement {
    // IMPORTANT: allow project-level repos added by plugins (Flutter adds one).
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // Flutter / Android artifacts mirror
        maven(url = uri("https://storage.googleapis.com/download.flutter.io"))
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    id("com.google.gms.google-services") version "4.3.15" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
