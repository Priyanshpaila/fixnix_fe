plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.fixnix_frontend"

    // Use Flutter’s values where appropriate
    compileSdk = flutter.compileSdkVersion

    // ✅ Pin to the highest required NDK
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.fixnix_frontend"

        // ✅ Raise minSdk to satisfy firebase-messaging 25.x (requires ≥ 23)
        // If flutter.minSdkVersion is already ≥ 23, this line is still fine.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ✅ Java 17 + desugaring
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // TODO: replace with your real signing config before publishing
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Core library desugaring for Java 8+ APIs on older Android
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Firebase BoM (keeps all Firebase artifacts at compatible versions)
    implementation(platform("com.google.firebase:firebase-bom:34.3.0"))

    // Add Firebase products you use (examples below)
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")
    // implementation("com.google.firebase:firebase-crashlytics")
    // implementation("com.google.firebase:firebase-config")
}
