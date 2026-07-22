
# BEGIN MINDPULSE ROOM R8 CONSTRUCTOR FIX
# Required for Room implementations created by reflection in R8 full mode.
-keep class * extends androidx.room.RoomDatabase { void <init>(); }
# END MINDPULSE ROOM R8 CONSTRUCTOR FIX
