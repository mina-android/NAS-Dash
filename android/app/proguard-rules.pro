# R8 Proguard Rules for NAS Dash
-dontwarn org.slf4j.impl.StaticLoggerBinder
-dontwarn org.slf4j.**
-dontwarn jcifs.**
-keep class jcifs.** { *; }
-keep class eu.agno3.jcifs.** { *; }
-keep class androidx.work.** { *; }
