import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload signing key.
//
// The properties file holds the keystore password in clear text, so it lives
// outside the repository entirely. Its location comes from the
// WEAKSPOT_KEY_PROPERTIES environment variable; android/key.properties is
// kept as a fallback for anyone who prefers the conventional spot. Both are
// git ignored.
//
// Losing the keystore means losing the ability to update this app on Play, and
// anyone who obtains it can publish as you. If neither file is present the
// release build falls back to debug signing, which runs locally but is
// rejected by Play.
val keystoreProperties = Properties()
val keystorePropertiesFile = System.getenv("WEAKSPOT_KEY_PROPERTIES")
    ?.let { file(it) }
    ?.takeIf { it.exists() }
    ?: rootProject.file("key.properties")

val hasSigningConfig = keystorePropertiesFile.exists()
if (hasSigningConfig) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.ebseca.weakspot"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent once published: Play identifies the app by this forever.
        applicationId = "com.ebseca.weakspot"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasSigningConfig) {
            create("upload") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasSigningConfig) {
                signingConfigs.getByName("upload")
            } else {
                // Local convenience only. A debug-signed bundle is rejected by
                // Play, so a real release build requires key.properties.
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
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
