plugins {
    kotlin("jvm") version "2.3.21"
    application
}

group = "org.andreastme.langpermonth"
version = "1.0"

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
}

kotlin {
    jvmToolchain(25)
}

application {
    mainClass.set("org.andreastme.langpermonth.MainKt")
}