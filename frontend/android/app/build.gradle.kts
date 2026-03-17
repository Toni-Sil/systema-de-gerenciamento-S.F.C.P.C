plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sfcpc.frontend"
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
        applicationId = "com.sfcpc.frontend"
        // Android-only: minSdk 23 (Android 6.0) — mínimo para flutter_secure_storage
        // e flutter_local_notifications com alarmes exatos
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: substituir pela signing config de produção antes de publicar na Play Store
            signingConfig = signingConfigs.getByName("debug")
            // Otimizações para release Android
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            applicationIdSuffix = ".debug"
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}
