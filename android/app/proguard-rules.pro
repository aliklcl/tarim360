# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# App classes
-keep class com.ali.tarlatakip.** { *; }

# Google Play Core - R8 auto-generated missing rules
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# SQLite / SQLCipher
-keep class net.sqlcipher.** { *; }
-dontwarn net.sqlcipher.**

# Sqflite
-keep class com.tekartik.sqflite.** { *; }

# Google Sign-In & GMS
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Kotlin Coroutines
-dontwarn kotlinx.coroutines.**

# General debugging info
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
