import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")

    // The Flutter Gradle Plugin must be applied after
    // the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(
        FileInputStream(keystorePropertiesFile)
    )
}

android {
    namespace = "am.appsosa.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "am.appsosa.app"

        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

/*
 * Flutter/Gradle workaround:
 * copy the APK produced by Gradle to the directory
 * where Flutter expects to find it.
 */
val syncFlutterReleaseApk by tasks.registering(Copy::class) {
    from(
        layout.buildDirectory.dir(
            "outputs/apk/release"
        )
    )

    include("*.apk")

    into(
        rootProject.projectDir.parentFile
            .resolve("build/app/outputs/flutter-apk")
    )

    doFirst {
        println("=== COPYING RELEASE APK TO FLUTTER OUTPUT ===")
    }
}

tasks.matching {
    it.name == "assembleRelease"
}.configureEach {
    finalizedBy(syncFlutterReleaseApk)
}