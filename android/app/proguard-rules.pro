# FFmpegKit is called from native code (JNI); keep its classes and members.
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.arthenica.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**

# Flutter deferred components reference Play Core classes that aren't used here.
-dontwarn com.google.android.play.core.**
