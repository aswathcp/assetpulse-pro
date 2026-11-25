# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase & Google Services
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Mobile Scanner & Google ML Kit
-keep class com.google.mlkit.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn androidx.camera.**

# Biometric & Local Auth
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }

# Kotlin Coroutines & Datastore
-dontwarn kotlinx.coroutines.**
-dontwarn com.google.common.**
