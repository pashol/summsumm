import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val pubCacheDir = System.getenv("PUB_CACHE") ?: "${System.getProperty("user.home")}/.pub-cache"
val sherpaOnnxRuntimeJniLibsDir = layout.buildDirectory.dir("generated/sherpaOnnxRuntimeJniLibs")

val stageSherpaOnnxRuntimeJniLibs by tasks.registering(Copy::class) {
    from("$pubCacheDir/hosted/pub.dev/sherpa_onnx_android_arm64-1.12.39/android/src/main/jniLibs/arm64-v8a/libonnxruntime.so") {
        into("arm64-v8a")
    }
    from("$pubCacheDir/hosted/pub.dev/sherpa_onnx_android_armeabi-1.12.39/android/src/main/jniLibs/armeabi-v7a/libonnxruntime.so") {
        into("armeabi-v7a")
    }
    from("$pubCacheDir/hosted/pub.dev/sherpa_onnx_android_x86_64-1.12.39/android/src/main/jniLibs/x86_64/libonnxruntime.so") {
        into("x86_64")
    }
    into(sherpaOnnxRuntimeJniLibsDir)
}

android {
    namespace = "app.summsumm"
    compileSdk = 36
    ndkVersion = "28.2.13676358"
    defaultConfig {
        applicationId = "app.summsumm"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    packaging {
        jniLibs {
            pickFirsts += "lib/arm64-v8a/libonnxruntime.so"
            pickFirsts += "lib/armeabi-v7a/libonnxruntime.so"
            pickFirsts += "lib/x86_64/libonnxruntime.so"
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDir(sherpaOnnxRuntimeJniLibsDir)
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.core:core:1.15.0")
}

tasks.named("preBuild") {
    dependsOn(stageSherpaOnnxRuntimeJniLibs)
}
