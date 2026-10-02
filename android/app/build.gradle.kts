import java.io.FileInputStream
import java.util.Properties

// Assinatura de release (F5-T05b — doc 06 §4): carrega android/key.properties
// quando existir; sem o arquivo, o build release usa a debug key (fallback).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.com.oliverlucas.lista_compras"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications exige desugaring da biblioteca (F53-T05).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identidade única do app local (F48): pacote e nome do Lite.
        applicationId = "br.com.oliverlucas.listacompras.lite"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "app_name", "Minhas Listas")
    }

    buildFeatures {
        // resValue(...) exige o build feature habilitado (AGP 8+).
        resValues = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // AGP 9 liga o R8/minify por padrão no release. As regras do MLKit
            // OCR (RF-37, F54) ficam em proguard-rules.pro — sem elas o R8
            // aborta por "Missing class" dos reconhecedores opcionais de
            // chinês/devanagari/japonês/coreano (dívida L-10).
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Assinatura real quando key.properties existe; debug key caso contrário,
            // para builds locais/CI seguirem funcionando sem o keystore.
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
