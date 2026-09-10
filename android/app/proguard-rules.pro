# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.internal.** { *; }
-keep class io.flutter.provider.** { *; }
-dontwarn io.flutter.app.**
-dontwarn io.flutter.plugin.**

# Preserve Model Classes
-keepclassmembers class * {
    @annotation.Keep *;
}
