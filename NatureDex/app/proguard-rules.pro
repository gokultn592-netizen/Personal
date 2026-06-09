# Add project specific ProGuard rules here.
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Preserve source file and line numbers for stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# --- OkHttp & Okio ---
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# --- Retrofit ---
-keep class retrofit2.** { *; }
-dontwarn retrofit2.**
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# --- Moshi ---
-keep class com.squareup.moshi.** { *; }
-dontwarn com.squareup.moshi.**
-keep class *JsonAdapter { *; }
-keepclassmembers class * {
    @com.squareup.moshi.Json <fields>;
}

# --- Room ---
-keep class androidx.room.** { *; }
-dontwarn androidx.room.**
-keep class * extends androidx.room.RoomDatabase

# --- Firebase & Play Services ---
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# --- NatureDex App Data Models & VM ---
-keep class com.example.data.** { *; }
-keep class com.example.ui.screens.LeaderboardEntry { *; }

# --- Security: Strip Debug and Verbose Logs in Release Builds ---
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
}
