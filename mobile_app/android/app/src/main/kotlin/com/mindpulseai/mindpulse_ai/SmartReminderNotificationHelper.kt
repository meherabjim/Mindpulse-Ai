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

object SmartReminderNotificationHelper {
    const val EXTRA_ACTION_TYPE =
        "smart_reminder_action_type"

    const val EXTRA_REMINDER_ID =
        "smart_reminder_id"

    const val EXTRA_TITLE =
        "smart_reminder_title"

    const val EXTRA_MESSAGE =
        "smart_reminder_message"

    const val EXTRA_VOICE =
        "smart_reminder_voice"

    const val EXTRA_VIBRATION =
        "smart_reminder_vibration"

    const val ACTION_DONE =
        "done"

    const val ACTION_SNOOZE =
        "snooze"

    const val ACTION_SKIP_TODAY =
        "skip_today"

    const val ACTION_DISABLE =
        "disable"

    private const val GENTLE_CHANNEL =
        "mindpulse_smart_gentle"

    private const val VIBRATION_CHANNEL =
        "mindpulse_smart_vibration"

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

    fun show(
        context: Context,
        reminderId: String,
        title: String,
        message: String,
        vibrate: Boolean,
        voice: Boolean = false
    ): Boolean {
        if (
            !canPostNotifications(
                context
            )
        ) {
            return false
        }

        val channelId =
            if (vibrate) {
                VIBRATION_CHANNEL
            } else {
                GENTLE_CHANNEL
            }

        createChannel(
            context,
            channelId,
            vibrate
        )

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

        val contentIntent =
            PendingIntent.getActivity(
                context,
                reminderId.hashCode(),
                launchIntent,
                PendingIntent
                    .FLAG_UPDATE_CURRENT or
                    PendingIntent
                        .FLAG_IMMUTABLE
            )

        val notification =
            NotificationCompat.Builder(
                context,
                channelId
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
                .setOnlyAlertOnce(true)
                .setContentIntent(
                    contentIntent
                )
                .addAction(
                    android.R.drawable
                        .checkbox_on_background,
                    "Done",
                    createActionIntent(
                        context,
                        ACTION_DONE,
                        reminderId,
                        title,
                        message,
                        voice,
                        vibrate
                    )
                )
                .addAction(
                    android.R.drawable
                        .ic_popup_sync,
                    "Snooze 15m",
                    createActionIntent(
                        context,
                        ACTION_SNOOZE,
                        reminderId,
                        title,
                        message,
                        voice,
                        vibrate
                    )
                )
                .addAction(
                    android.R.drawable
                        .ic_menu_close_clear_cancel,
                    "Skip today",
                    createActionIntent(
                        context,
                        ACTION_SKIP_TODAY,
                        reminderId,
                        title,
                        message,
                        voice,
                        vibrate
                    )
                )
                .addAction(
                    android.R.drawable
                        .ic_delete,
                    "Turn off",
                    createActionIntent(
                        context,
                        ACTION_DISABLE,
                        reminderId,
                        title,
                        message,
                        voice,
                        vibrate
                    )
                )
                .build()

        val manager =
            context.getSystemService(
                Context.NOTIFICATION_SERVICE
            ) as NotificationManager

        manager.notify(
            notificationId(
                reminderId
            ),
            notification
        )

        return true
    }

    fun cancel(
        context: Context,
        reminderId: String
    ) {
        val manager =
            context.getSystemService(
                Context.NOTIFICATION_SERVICE
            ) as NotificationManager

        manager.cancel(
            notificationId(
                reminderId
            )
        )
    }

    private fun createActionIntent(
        context: Context,
        actionType: String,
        reminderId: String,
        title: String,
        message: String,
        voice: Boolean,
        vibrate: Boolean
    ): PendingIntent {
        val intent =
            Intent(
                context,
                SmartReminderActionReceiver::
                    class.java
            ).apply {
                action =
                    "${context.packageName}." +
                        "smart_reminder." +
                        actionType

                putExtra(
                    EXTRA_ACTION_TYPE,
                    actionType
                )

                putExtra(
                    EXTRA_REMINDER_ID,
                    reminderId
                )

                putExtra(
                    EXTRA_TITLE,
                    title
                )

                putExtra(
                    EXTRA_MESSAGE,
                    message
                )

                putExtra(
                    EXTRA_VOICE,
                    voice
                )

                putExtra(
                    EXTRA_VIBRATION,
                    vibrate
                )
            }

        val requestCode =
            (
                reminderId +
                "_" +
                actionType
            ).hashCode()

        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent
                .FLAG_UPDATE_CURRENT or
                PendingIntent
                    .FLAG_IMMUTABLE
        )
    }

    private fun notificationId(
        reminderId: String
    ): Int {
        return reminderId
            .hashCode()
    }

    private fun createChannel(
        context: Context,
        channelId: String,
        vibrate: Boolean
    ) {
        if (
            Build.VERSION.SDK_INT <
            Build.VERSION_CODES.O
        ) {
            return
        }

        val channelName =
            if (vibrate) {
                "MindPulse Important Reminders"
            } else {
                "MindPulse Gentle Reminders"
            }

        val channel =
            NotificationChannel(
                channelId,
                channelName,
                NotificationManager
                    .IMPORTANCE_DEFAULT
            ).apply {
                description =
                    "User-selected MindPulse wellness reminders."

                enableVibration(
                    vibrate
                )

                setSound(
                    null,
                    null
                )
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
