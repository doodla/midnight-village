import java.net.URI
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The release key: PUBLIC by the owner's decision, for sideloaded installs only
// (release-key/README.md). Replace it with a private key before any store release.
val releaseKey = Properties().apply {
    rootProject.file("release-key/key.properties").inputStream().use { load(it) }
}

// The --dart-define values of this build (the Flutter tool hands them to Gradle,
// base64 and comma separated).
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String? ?: "")
        .split(",")
        .filter { it.isNotEmpty() }
        .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
        .associate { it.substringBefore("=") to it.substringAfter("=", "") }

// Where the web app is served from: the join links' address. Table links open this app
// (App Links) only for this host, and the app draws its QR codes with this origin.
val publicOrigin: String = dartDefines["PUBLIC_ORIGIN"].orEmpty().trim()
val publicHost: String? =
    try {
        URI(publicOrigin).takeIf { it.scheme == "https" }?.host
    } catch (e: Exception) {
        null
    }

// A release build without a public https origin would draw no QR code and share no link:
// it stops here, saying what to pass. Debug builds and tests are not affected.
gradle.taskGraph.whenReady {
    val releasing = allTasks.any { it.project == project && it.name.contains("Release") }
    if (releasing && publicHost == null) {
        throw GradleException(
            "PUBLIC_ORIGIN is missing or is not an https origin " +
                "(got '$publicOrigin'). A release build needs the web app's address, " +
                "so its QR code and Share link point at the web app: add " +
                "--dart-define=PUBLIC_ORIGIN=https://<web app host> " +
                "(docs/dev/deploy-vercel.md, \"The app (web and Android)\"), " +
                "or build with tool/build_android.sh.",
        )
    }
}

android {
    namespace = "com.midnightvillage.midnight_village"
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
        // Kept: APKs with this id are already on phones; a new id would install a second app.
        applicationId = "com.midnightvillage.midnight_village"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // The host table links open this app for (AndroidManifest.xml). A debug build with
        // no origin gets a host no link has.
        manifestPlaceholders["publicHost"] = publicHost ?: "localhost"
    }

    signingConfigs {
        create("release") {
            storeFile = rootProject.file("release-key/" + releaseKey.getProperty("storeFile"))
            storePassword = releaseKey.getProperty("storePassword")
            keyAlias = releaseKey.getProperty("keyAlias")
            keyPassword = releaseKey.getProperty("keyPassword")
            storeType = "pkcs12"
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
