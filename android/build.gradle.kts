buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // This tells Gradle where to find the google-services plugin
        classpath("com.google.gms:google-services:4.4.1") 
        classpath("com.google.firebase:firebase-crashlytics-gradle:2.9.9")
        // You might also have a 'kotlin-gradle-plugin' line here, which is fine
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}


val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
