allprojects {
    repositories {
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // این بخش تمام پکیج‌ها را مجبور می‌کند به جای نسخه ۹، از نسخه ۸.۱۱.۱ استفاده کنند
    buildscript {
        repositories {
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/public") }
            google()
            mavenCentral()
        }
        configurations.all {
            resolutionStrategy {
                force("com.android.tools.build:gradle:8.11.1")
                force("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20")
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}