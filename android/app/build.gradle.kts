import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase(부부 공유) 설정 파일이 있을 때만 google-services 플러그인을 켠다.
// 파일이 없어도 앱은 로컬 저장소만으로 정상 빌드·동작해야 한다는 원칙 때문에
// 하드 의존으로 두지 않는다. 설정 파일은 .gitignore 에 있어 커밋되지 않는다.
if (project.file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// 릴리즈 서명 키 정보. 저장소에는 없고 빌드하는 기기에만 둔다.
// 이 파일이 없으면 디버그 키로 서명한다 (개발용 PC, CI 등).
// 만드는 방법은 RELEASE.md 참고.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKey) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.jong0227.ninedogs"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 가 최신 날짜/시간 API 를 쓰는데,
        // 구형 안드로이드에도 그 API 를 제공하려면 이게 필요하다.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jong0227.ninedogs"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 같은 코드를 두 경로로 배포한다. GitHub Release 사이드로드용(github)과
    // Play 스토어용(playstore). Play 는 자체 업데이트 메커니즘 외의 방법으로
    // 앱이 스스로를 갱신하는 걸 금지해서, 그 기능(권한·FileProvider)은
    // github flavor 매니페스트(src/github/)에만 둔다. 어느 flavor인지는
    // Dart 쪽에 --dart-define=DISTRIBUTION=... 으로 넘겨서 화면에 반영한다.
    flavorDimensions += "distribution"
    productFlavors {
        create("github") { dimension = "distribution" }
        create("playstore") { dimension = "distribution" }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // key.properties 가 있으면 실제 릴리즈 키로, 없으면 디버그 키로 서명한다.
            // 디버그 키로 서명된 APK 는 개인 테스트용으로는 설치되지만
            // 스토어에는 올릴 수 없다.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
