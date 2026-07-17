package com.mindpulseai.mindpulse_ai

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters

class ScreenTimeWorker(
    appContext: Context,
    workerParameters: WorkerParameters
) : Worker(
    appContext,
    workerParameters
) {
    override fun doWork(): Result {
        val preferences =
            applicationContext
                .getSharedPreferences(
                    PREFERENCES_NAME,
                    Context.MODE_PRIVATE
                )

        val currentTime =
            System.currentTimeMillis()

        preferences.edit()
            .putLong(
                KEY_LAST_CHECK_AT,
                currentTime
            )
            .apply()

        if (
            !preferences.getBoolean(
                KEY_REMINDERS_ENABLED,
                false
            )
        ) {
            saveStatus(
                preferences,
                "disabled"
            )

            return Result.success()
        }

        if (
            !ScreenTimeUsageCalculator
                .hasUsageAccess(
                    applicationContext
                )
        ) {
            saveStatus(
                preferences,
                "usage_access_missing"
            )

            return Result.success()
        }

        val summary =
            ScreenTimeUsageCalculator
                .getTodaySummary(
                    applicationContext
                )

        val socialMinutes =
            summary.socialUsageMs /
                60_000L

        val longestMinutes =
            summary.longestSessionMs /
                60_000L

        preferences.edit()
            .putLong(
                KEY_LAST_SOCIAL_MINUTES,
                socialMinutes
            )
            .putLong(
                KEY_LAST_LONGEST_MINUTES,
                longestMinutes
            )
            .putString(
                KEY_LAST_LONGEST_APP,
                summary.longestAppName
            )
            .apply()

        val dailyLimit =
            preferences.getInt(
                KEY_DAILY_SOCIAL_LIMIT,
                90
            )

        val sessionLimit =
            preferences.getInt(
                KEY_SESSION_LIMIT,
                45
            )

        val reminderMessage =
            when {
                socialMinutes >=
                    dailyLimit -> {
                    "You have spent about " +
                        "$socialMinutes minutes " +
                        "on social apps today. " +
                        "Put the phone aside and " +
                        "take a short recovery break."
                }

                longestMinutes >=
                    sessionLimit -> {
                    val appName =
                        summary.longestAppName
                            ?: "an app"

                    "You used $appName continuously " +
                        "for about $longestMinutes minutes. " +
                        "Give your eyes and mind a rest."
                }

                else -> null
            }

        if (reminderMessage == null) {
            saveStatus(
                preferences,
                "within_limits"
            )

            return Result.success()
        }

        if (
            !ScreenTimeNotificationHelper
                .canPostNotifications(
                    applicationContext
                )
        ) {
            saveStatus(
                preferences,
                "notification_permission_missing"
            )

            return Result.success()
        }

        val previousReminder =
            preferences.getLong(
                KEY_LAST_REMINDER_AT,
                0L
            )

        val cooldownMs =
            preferences.getInt(
                KEY_COOLDOWN_MINUTES,
                120
            ) * 60_000L

        if (
            currentTime -
                previousReminder <
            cooldownMs
        ) {
            saveStatus(
                preferences,
                "cooldown"
            )

            return Result.success()
        }

        ScreenTimeNotificationHelper
            .showNotification(
                applicationContext,
                "Time for a mindful break",
                reminderMessage
            )


        val voiceEnabled =
            preferences.getBoolean(
                KEY_VOICE_ENABLED,
                false
            )

        if (voiceEnabled) {
            val banglaMessage =
                when {
                    socialMinutes >=
                        dailyLimit -> {
                        "আপনি আজ সামাজিক যোগাযোগমাধ্যমে " +
                            "প্রায় $socialMinutes মিনিট " +
                            "সময় কাটিয়েছেন। এখন ফোনটি " +
                            "কিছুক্ষণ রেখে দশ মিনিট " +
                            "বিশ্রাম নিন।"
                    }

                    longestMinutes >=
                        sessionLimit -> {
                        "আপনি একটানা প্রায় " +
                            "$longestMinutes মিনিট " +
                            "ফোন ব্যবহার করেছেন। " +
                            "চোখ ও মনকে বিশ্রাম দিতে " +
                            "এখন কিছুক্ষণ ফোনটি রাখুন।"
                    }

                    else -> null
                }

            if (banglaMessage != null) {
                BanglaVoiceReminderHelper
                    .speak(
                        applicationContext,
                        banglaMessage
                    )
            }
        }

        preferences.edit()
            .putLong(
                KEY_LAST_REMINDER_AT,
                currentTime
            )
            .putString(
                KEY_LAST_STATUS,
                "reminder_sent"
            )
            .apply()

        return Result.success()
    }

    private fun saveStatus(
        preferences:
            android.content.SharedPreferences,
        status: String
    ) {
        preferences.edit()
            .putString(
                KEY_LAST_STATUS,
                status
            )
            .apply()
    }

    companion object {
        const val PREFERENCES_NAME =
            "mindpulse_screen_time"

        const val KEY_REMINDERS_ENABLED =
            "background_reminders_enabled"

        const val KEY_DAILY_SOCIAL_LIMIT =
            "daily_social_limit_minutes"

        const val KEY_SESSION_LIMIT =
            "continuous_session_limit_minutes"

        const val KEY_COOLDOWN_MINUTES =
            "reminder_cooldown_minutes"

        const val KEY_VOICE_ENABLED =
            "bangla_voice_enabled"

        const val KEY_LAST_CHECK_AT =
            "last_background_check_at"

        const val KEY_LAST_REMINDER_AT =
            "last_background_reminder_at"

        const val KEY_LAST_STATUS =
            "last_background_status"

        const val KEY_LAST_SOCIAL_MINUTES =
            "last_social_minutes"

        const val KEY_LAST_LONGEST_MINUTES =
            "last_longest_minutes"

        const val KEY_LAST_LONGEST_APP =
            "last_longest_app"
    }
}

object ScreenTimeNotificationHelper {
    private const val CHANNEL_ID =
        "mindpulse_screen_time"

    private const val NOTIFICATION_ID =
        2107

    fun canPostNotifications(
        context: Context
    ): Boolean {
        return (
            Build.VERSION.SDK_INT <
                Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission
                    .POST_NOTIFICATIONS
            ) ==
                PackageManager
                    .PERMISSION_GRANTED
        )
    }

    fun showTestNotification(
        context: Context
    ): Boolean {
        if (
            !canPostNotifications(
                context
            )
        ) {
            return false
        }

        showNotification(
            context,
            "MindPulse reminder test",
            "Background reminders are ready. " +
                "MindPulse will gently remind you " +
                "when your selected usage limit is reached."
        )

        return true
    }

    fun showNotification(
        context: Context,
        title: String,
        message: String
    ) {
        createChannel(context)

        val launchIntent =
            context.packageManager
                .getLaunchIntentForPackage(
                    context.packageName
                )
                ?: Intent(
                    context,
                    MainActivity::class.java
                )

        launchIntent.addFlags(
            Intent.FLAG_ACTIVITY_CLEAR_TOP
        )

        val pendingIntent =
            PendingIntent.getActivity(
                context,
                2107,
                launchIntent,
                PendingIntent
                    .FLAG_UPDATE_CURRENT or
                    PendingIntent
                        .FLAG_IMMUTABLE
            )

        val notification =
            NotificationCompat.Builder(
                context,
                CHANNEL_ID
            )
                .setSmallIcon(
                    context.applicationInfo
                        .icon
                )
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(
                    NotificationCompat
                        .BigTextStyle()
                        .bigText(message)
                )
                .setPriority(
                    NotificationCompat
                        .PRIORITY_DEFAULT
                )
                .setAutoCancel(true)
                .setContentIntent(
                    pendingIntent
                )
                .build()

        val manager =
            context.getSystemService(
                Context.NOTIFICATION_SERVICE
            ) as NotificationManager

        manager.notify(
            NOTIFICATION_ID,
            notification
        )
    }

    private fun createChannel(
        context: Context
    ) {
        if (
            Build.VERSION.SDK_INT <
            Build.VERSION_CODES.O
        ) {
            return
        }

        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "Mindful Screen Time",
                NotificationManager
                    .IMPORTANCE_DEFAULT
            ).apply {
                description =
                    "Gentle reminders for " +
                    "extended phone usage."
            }

        val manager =
            context.getSystemService(
                Context.NOTIFICATION_SERVICE
            ) as NotificationManager

        manager.createNotificationChannel(
            channel
        )
    }
}
