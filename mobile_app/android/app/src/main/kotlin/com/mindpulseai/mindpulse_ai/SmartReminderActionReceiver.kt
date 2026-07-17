package com.mindpulseai.mindpulse_ai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

class SmartReminderActionReceiver :
    BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent
    ) {
        val actionType =
            intent.getStringExtra(
                SmartReminderNotificationHelper
                    .EXTRA_ACTION_TYPE
            ) ?: return

        val reminderId =
            intent.getStringExtra(
                SmartReminderNotificationHelper
                    .EXTRA_REMINDER_ID
            ) ?: return

        val title =
            intent.getStringExtra(
                SmartReminderNotificationHelper
                    .EXTRA_TITLE
            ) ?: "মাইন্ডপালস রিমাইন্ডার"

        val message =
            intent.getStringExtra(
                SmartReminderNotificationHelper
                    .EXTRA_MESSAGE
            ) ?: ""

        val voice =
            intent.getBooleanExtra(
                SmartReminderNotificationHelper
                    .EXTRA_VOICE,
                false
            )

        val vibration =
            intent.getBooleanExtra(
                SmartReminderNotificationHelper
                    .EXTRA_VIBRATION,
                false
            )

        SmartReminderNotificationHelper
            .cancel(
                context,
                reminderId
            )

        val preferences =
            context.getSharedPreferences(
                SmartReminderWorker
                    .PREFERENCES_NAME,
                Context.MODE_PRIVATE
            )

        when (actionType) {
            SmartReminderNotificationHelper
                .ACTION_DONE -> {
                saveAction(
                    preferences,
                    reminderId,
                    title,
                    "done"
                )
            }

            SmartReminderNotificationHelper
                .ACTION_SNOOZE -> {
                scheduleSnooze(
                    context,
                    reminderId,
                    title,
                    message,
                    voice,
                    vibration
                )

                saveAction(
                    preferences,
                    reminderId,
                    title,
                    "snoozed"
                )
            }

            SmartReminderNotificationHelper
                .ACTION_SKIP_TODAY -> {
                val today =
                    SimpleDateFormat(
                        "yyyy-MM-dd",
                        Locale.US
                    ).format(
                        Date()
                    )

                preferences.edit()
                    .putString(
                        "skip_today_$reminderId",
                        today
                    )
                    .apply()

                saveAction(
                    preferences,
                    reminderId,
                    title,
                    "skipped_today"
                )
            }

            SmartReminderNotificationHelper
                .ACTION_DISABLE -> {
                disableReminder(
                    context,
                    preferences,
                    reminderId
                )

                saveAction(
                    preferences,
                    reminderId,
                    title,
                    "disabled_by_user"
                )
            }
        }
    }

    private fun scheduleSnooze(
        context: Context,
        reminderId: String,
        title: String,
        message: String,
        voice: Boolean,
        vibration: Boolean
    ) {
        val data =
            Data.Builder()
                .putString(
                    SmartReminderSnoozeWorker
                        .KEY_REMINDER_ID,
                    reminderId
                )
                .putString(
                    SmartReminderSnoozeWorker
                        .KEY_TITLE,
                    title
                )
                .putString(
                    SmartReminderSnoozeWorker
                        .KEY_MESSAGE,
                    message
                )
                .putBoolean(
                    SmartReminderSnoozeWorker
                        .KEY_VOICE,
                    voice
                )
                .putBoolean(
                    SmartReminderSnoozeWorker
                        .KEY_VIBRATION,
                    vibration
                )
                .build()

        val request =
            OneTimeWorkRequestBuilder<
                SmartReminderSnoozeWorker
            >()
                .setInputData(data)
                .setInitialDelay(
                    15,
                    TimeUnit.MINUTES
                )
                .build()

        WorkManager.getInstance(
            context
        ).enqueueUniqueWork(
            "mindpulse_snooze_$reminderId",
            ExistingWorkPolicy.REPLACE,
            request
        )
    }

    private fun disableReminder(
        context: Context,
        preferences:
            android.content.SharedPreferences,
        reminderId: String
    ) {
        val configText =
            preferences.getString(
                SmartReminderWorker
                    .KEY_CONFIG_JSON,
                null
            ) ?: return

        val config =
            try {
                JSONObject(
                    configText
                )
            } catch (
                error: Exception
            ) {
                return
            }

        val reminders =
            config.optJSONArray(
                "reminders"
            ) ?: return

        for (
            index in
            0 until reminders.length()
        ) {
            val reminder =
                reminders.optJSONObject(
                    index
                ) ?: continue

            if (
                reminder.optString(
                    "id"
                ) ==
                reminderId
            ) {
                reminder.put(
                    "enabled",
                    false
                )

                break
            }
        }

        preferences.edit()
            .putString(
                SmartReminderWorker
                    .KEY_CONFIG_JSON,
                config.toString()
            )
            .apply()

        SmartReminderScheduler
            .sync(context)
    }

    private fun saveAction(
        preferences:
            android.content.SharedPreferences,
        reminderId: String,
        title: String,
        action: String
    ) {
        preferences.edit()
            .putString(
                "last_user_action",
                action
            )
            .putString(
                SmartReminderWorker
                    .KEY_LAST_STATUS,
                action
            )
            .putString(
                SmartReminderWorker
                    .KEY_LAST_REMINDER_ID,
                reminderId
            )
            .putString(
                SmartReminderWorker
                    .KEY_LAST_REMINDER_TITLE,
                title
            )
            .putLong(
                "last_user_action_at",
                System.currentTimeMillis()
            )
            .apply()
    }
}
