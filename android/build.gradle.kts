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
    // Workaround for old Flutter plugins that do not define android.namespace (AGP 8+ requirement)
    if (name == "telephony") {
        afterEvaluate {
            val androidExt = extensions.findByName("android")
            if (androidExt != null) {
                val getNamespace = androidExt.javaClass.methods.firstOrNull {
                    it.name == "getNamespace" && it.parameterCount == 0
                }
                val setNamespace = androidExt.javaClass.methods.firstOrNull {
                    it.name == "setNamespace" && it.parameterCount == 1
                }
                val currentNamespace = getNamespace?.invoke(androidExt) as? String
                if (currentNamespace.isNullOrBlank()) {
                    setNamespace?.invoke(androidExt, "com.shounakmulay.telephony")
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
