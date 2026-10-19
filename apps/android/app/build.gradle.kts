plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val uploadSigning = listOf(
    "LINEPAY_ANDROID_KEYSTORE", "LINEPAY_ANDROID_STORE_PASSWORD",
    "LINEPAY_ANDROID_KEY_ALIAS", "LINEPAY_ANDROID_KEY_PASSWORD",
).associateWith { providers.environmentVariable(it).orNull }
val hasUploadSigning = uploadSigning.values.any { it != null }
if (hasUploadSigning) {
    require(uploadSigning.values.all { !it.isNullOrBlank() }) {
        "All four LINEPAY_ANDROID signing environment variables must be supplied."
    }
}

android {
    namespace = "com.streamentry.linepay.android"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.streamentry.linepay.android"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    if (hasUploadSigning) {
        signingConfigs {
            create("upload") {
                storeFile = file(requireNotNull(uploadSigning["LINEPAY_ANDROID_KEYSTORE"]))
                storePassword = uploadSigning["LINEPAY_ANDROID_STORE_PASSWORD"]
                keyAlias = uploadSigning["LINEPAY_ANDROID_KEY_ALIAS"]
                keyPassword = uploadSigning["LINEPAY_ANDROID_KEY_PASSWORD"]
            }
        }
        buildTypes.getByName("release").signingConfig = signingConfigs.getByName("upload")
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    sourceSets.getByName("androidTest").assets.srcDir(
        rootProject.file("../../shared/contracts/backup"),
    )

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    jvmToolchain(21)
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        allWarningsAsErrors.set(true)
    }
}

dependencyLocking { lockAllConfigurations() }

dependencies {
    implementation(project(":domain"))
    implementation(project(":backup"))
    implementation("com.google.code.gson:gson:2.11.0")
    testImplementation("junit:junit:4.13.2")

    val composeBom = platform("androidx.compose:compose-bom:2026.06.00")
    implementation(composeBom)
    androidTestImplementation(composeBom)
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
