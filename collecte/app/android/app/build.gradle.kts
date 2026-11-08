import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Même clé que Fikajiana (release-keys/, hors Git) : un `key.properties` ici,
// ou celui de l'app, ou les variables ANDROID_KEYSTORE_*.
val keystoreProperties = Properties()
val keystorePropertiesFile = listOf(
    rootProject.file("key.properties"),
    rootProject.file("../../../app/android/key.properties"),
).firstOrNull { it.exists() }
keystorePropertiesFile?.let { keystoreProperties.load(FileInputStream(it)) }

android {
    namespace = "mg.fikajiana.collecte"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "mg.fikajiana.collecte"
        // L'icône est adaptative seulement (Android 8 et plus).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (System.getenv("ANDROID_KEYSTORE_PATH") != null) {
                storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH"))
                keyAlias = System.getenv("ANDROID_KEYSTORE_ALIAS")
                keyPassword = System.getenv("ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD")
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            } else {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Sans clé (CI), l'APK est signé avec la clé de débogage : non diffusable.
            val cleDisponible = System.getenv("ANDROID_KEYSTORE_PATH") != null || keystorePropertiesFile != null
            signingConfig = signingConfigs.getByName(if (cleDisponible) "release" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
