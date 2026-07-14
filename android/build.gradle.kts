allprojects {
    repositories {
        google()
        mavenCentral()
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

// file_picker/share_plus pull in flutter_plugin_android_lifecycle, which needs
// compileSdk 36. The app module sets its own (app/build.gradle.kts), but plugin
// subprojects inherit Flutter's default (34); force 36 on every Android
// subproject so they all agree (#26).
subprojects {
    // Skip projects Gradle has already evaluated (e.g. :app, which sets its own
    // compileSdk) — registering afterEvaluate on those throws. Plugin modules are
    // still un-evaluated here, so their compileSdk is raised to 36 in time.
    if (!state.executed) {
        afterEvaluate {
            val androidExtension = extensions.findByName("android")
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                androidExtension.compileSdkVersion(36)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
