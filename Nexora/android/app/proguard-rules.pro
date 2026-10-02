# Firebase Cloud Firestore
# Keep all Firebase-related rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.auth.** { *; }

# WebView
-keep public class android.webkit.** { *; }
-keep public class * extends android.webkit.WebChromeClient { *; }

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Provider / ChangeNotifier
-keep class **.models.** { *; }
-keep class **.services.** { *; }
-keep class **.theme.** { *; }
