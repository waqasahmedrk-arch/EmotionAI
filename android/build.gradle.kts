// NOTE: Do NOT declare any repositories in this file.
// Repositories are managed in settings.gradle.kts via dependencyResolutionManagement.

import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    layout.buildDirectory.set(newSubprojectBuildDir)

    // Keep this if your build relies on evaluating :app first
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
