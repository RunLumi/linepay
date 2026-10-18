plugins { kotlin("jvm") }
kotlin {
    jvmToolchain(21)
    compilerOptions { allWarningsAsErrors.set(true); jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
}
java { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
dependencyLocking { lockAllConfigurations() }
dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("com.google.code.gson:gson:2.11.0")
}
tasks.test { useJUnit(); systemProperty("linepay.sharedContracts", rootProject.file("../../shared/contracts").absolutePath) }
