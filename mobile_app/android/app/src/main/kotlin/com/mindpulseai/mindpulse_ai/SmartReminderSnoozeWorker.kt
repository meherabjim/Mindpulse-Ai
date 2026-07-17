package com.mindpulseai.mindpulse_ai

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.util.Calendar

class SmartReminderSnoozeWorker(
    appContext: Context,
    workerParameters: WorkerParameters
) : Worker(
    appContext,
    workerParameters
) {
    override fun doWork(): Result {
        val reminderId =
            inputData.getString(
                KEY_REMINDER_ID
            ) ?: return Result.success()

        val title =
            inputData.getString(
                KEY_TITLE
            ) ?: "মাইন্ডপালস রিমাইন্ডার"

        val message =
            inputData.getString(
                KEY_MESSAGE
            ) ?: (
                "নিজের যত্ন নিতে " +
                    "একটি ছোট বিরতি নিন।"
            )

        val voice =
            inputData.getBoolean(
                KEY_VOICE,
                false
            )

        val vibration =
            inputData.getBoolean(
                KEY_VIBRATION,
                false
            )

        val quietHours =
            isQuietHours()

        val notificationSent =
            SmartReminderNotificationHelper
                .show(
                    applicationContext,
                    reminderId,
                    title,
                    message,
                    vibration &&
                        !quietHours,
                    voice
                )

        if (!notificationSent) {
            return Result.success()
        }

        val audioManager =
            applicationContext
                .getSystemService(
                    Context.AUDIO_SERVICE
                ) as AudioManager

        val canSpeak =
            voice &&
            !quietHours &&
            audioManager.ringerMode ==
                AudioManager
                    .RINGER_MODE_NORMAL

        if (canSpeak) {
            BanglaVoiceReminderHelper
                .speak(
                    applicationContext,
                    message
                )
        }

        val preferences =
            applicationContext
                .getSharedPreferences(
                    SmartReminderWorker
                        .PREFERENCES_NAME,
                    Context.MODE_PRIVATE
                )

        preferences.edit()
            .putString(
                SmartReminderWorker
                    .KEY_LAST_STATUS,
                "snoozed_reminder_sent"
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
                SmartReminderWorker
                    .KEY_LAST_REMINDER_AT,
                System.currentTimeMillis()
            )
            .apply()

        return Result.success()
    }

    private fun isQuietHours():
        Boolean {
        val preferences =
            applicationContext
                .getSharedPreferences(
                    SmartReminderWorker
                        .PREFERENCES_NAME,
                    Context.MODE_PRIVATE
                )

        val configText =
            preferences.getString(
                SmartReminderWorker
                    .KEY_CONFIG_JSON,
                null
            ) ?: return false

        val config =
            try {
                JSONObject(
                    configText
                )
            } catch (
                error: Exception
            ) {
                return false
            }

        val start =
            config.optInt(
                "quiet_start_minutes",
                1320
            )

        val end =
            config.optInt(
                "quiet_end_minutes",
                420
            )

        val calendar =
            Calendar.getInstance()

        val current =
            calendar.get(
                Calendar.HOUR_OF_DAY
            ) * 60 +
                calendar.get(
                    Calendar.MINUTE
                )

        return if (start <= end) {
            current in start..end
        } else {
            current >= start ||
                current <= end
        }
    }

    companion object {
        const val KEY_REMINDER_ID =
            "reminder_id"

        const val KEY_TITLE =
            "title"

        const val KEY_MESSAGE =
            "message"

        const val KEY_VOICE =
            "voice"

        const val KEY_VIBRATION =
            "vibration"
    }
}
