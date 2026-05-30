allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.value(rootProject.layout.buildDirectory.dir("../../build").get())

subprojects {
    project.layout.buildDirectory.value(rootProject.layout.buildDirectory.dir(project.name).get())
}

subprojects {
    project.evaluationDependsOn(":app")
}

allprojects {
    plugins.withId("com.android.application") {
        val android = project.extensions.getByName("android")
        if (android is com.android.build.gradle.BaseExtension && android.namespace == null) {
            android.namespace = "com.meshexam." + project.name.replace("-", ".")
        }
    }
    plugins.withId("com.android.library") {
        val android = project.extensions.getByName("android")
        if (android is com.android.build.gradle.BaseExtension && android.namespace == null) {
            android.namespace = "com.meshexam." + project.name.replace("-", ".")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
