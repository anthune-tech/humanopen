# llama_flutter_android plugin - keep all classes used by JNI
-keep class com.write4me.llama_flutter_android.** { *; }

# Keep Kotlin function bridge methods used by JNI callbacks
-keep,allowobfuscation,allowoptimization class kotlin.jvm.functions.** { *; }
-keepclassmembers class * implements kotlin.jvm.functions.Function1 {
    public java.lang.Object invoke(java.lang.Object);
}
