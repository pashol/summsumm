# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.engine.FlutterEngine
-keep class io.flutter.embedding.engine.plugins.** { *; }

# Generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class io.flutter.embedding.engine.plugins.util.GeneratedPluginRegister { *; }

# AndroidX
-keep class androidx.** { *; }
-keep interface androidx.** { *; }

# Network models
-keep class app.summsumm.models.** { *; }

# SSE parsing
-keepclassmembers class app.summsumm.services.AiService { *; }

# FFmpeg Kit
-keep class com.antonkarpenko.ffmpegkit.** { *; }

# Google Play Core (referenced by Flutter embedding but not used)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**