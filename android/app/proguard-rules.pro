# Twilio
-keep class com.twilio.** { *; }
-dontwarn com.twilio.**

# Flutter plugin method channels
-keep class io.flutter.plugin.common.** { *; }
-keepclassmembers class * {
    @io.flutter.plugin.common.MethodChannel$MethodCallHandler <fields>;
}
