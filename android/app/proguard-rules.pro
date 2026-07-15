# Flutter standard ProGuard keep rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Services & Sign In keep rules
-dontwarn com.google.android.gms.**

# Support Library keep rules
-dontwarn androidx.**

# Ignore Play Store core / deferred component dependencies warnings
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Tell R8 to ignore missing class warnings and compile successfully
-ignorewarnings
