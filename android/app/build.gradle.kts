plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace        = "com.ext.boomverse"
    compileSdk       = flutter.compileSdkVersion
    ndkVersion       = "27.0.12077973"

    defaultConfig {
        applicationId  = "com.ext.boomverse"
        minSdk         = 23
        targetSdk      = flutter.targetSdkVersion
        versionCode    = flutter.versionCode
        versionName    = flutter.versionName
    }

    signingConfigs {
        // your custom release keystore
        create("release") {
            storeFile     = file("C:/Users/info/upload-keystore.jks")
            storePassword = "boomverse@123"
            keyAlias      = "upload"
            keyPassword   = "boomverse@123"
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig    = signingConfigs.getByName("release")
            isMinifyEnabled  = true  // set false if you don’t want R8/ProGuard
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            // still uses the default debug keystore so `flutter run --debug` works
            signingConfig    = signingConfigs.getByName("debug")
            isMinifyEnabled  = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

flutter {
    source = "../.."
}
