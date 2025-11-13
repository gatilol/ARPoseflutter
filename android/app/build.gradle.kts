plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flu_ar_simple"
    compileSdk = 36  // ← Changez cette ligne
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    
    kotlinOptions {
        jvmTarget = "17"  // ← Ajoutez cette section
    }

    defaultConfig {
        applicationId = "com.example.flu_ar_simple"
        minSdk = 24  // ← Changez cette ligne (important pour ARCore)
        targetSdk = 36  // ← Changez cette ligne
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    
    buildTypes {
        release {
        signingConfig = signingConfigs.getByName("debug")        }
    }
}

flutter {
    source = "../.."
}
