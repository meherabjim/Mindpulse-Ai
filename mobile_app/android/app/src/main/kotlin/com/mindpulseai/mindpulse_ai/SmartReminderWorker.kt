package com.mindpulseai.mindpulse_ai

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

class SmartReminderWorker(
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

        val now =
            System.currentTimeMillis()

        preferences.edit()
            .putLong(
                KEY_LAST_CHECK_AT,
                now
            )
            .apply()

        val configText =
            preferences.getString(
                KEY_CONFIG_JSON,
                null
            )

        if (configText.isNullOrBlank()) {
            saveStatus(
                preferences,
                "not_configured"
            )

            return Result.success()
        }

        val config =
            try {
                JSONObject(configText)
            } catch (
                error: Exception
            ) {
                saveStatus(
                    preferences,
                    "invalid_configuration"
                )

                return Result.success()
            }

        if (
            !config.optBoolean(
                "master_enabled",
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
            !SmartReminderNotificationHelper
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

        val calendar =
            Calendar.getInstance()

        val currentMinute =
            calendar.get(
                Calendar.HOUR_OF_DAY
            ) * 60 +
                calendar.get(
                    Calendar.MINUTE
                )

        val today =
            SimpleDateFormat(
                "yyyy-MM-dd",
                Locale.US
            ).format(
                Date(now)
            )

        val dailyCountDate =
            preferences.getString(
                KEY_DAILY_COUNT_DATE,
                null
            )

        var dailyCount =
            if (dailyCountDate == today) {
                preferences.getInt(
                    KEY_DAILY_COUNT,
                    0
                )
            } else {
                0
            }

        if (dailyCountDate != today) {
            preferences.edit()
                .putString(
                    KEY_DAILY_COUNT_DATE,
                    today
                )
                .putInt(
                    KEY_DAILY_COUNT,
                    0
                )
                .apply()
        }

        val maximumDailyReminders =
            config.optInt(
                "max_daily_reminders",
                4
            ).coerceIn(
                1,
                8
            )

        if (
            dailyCount >=
            maximumDailyReminders
        ) {
            saveStatus(
                preferences,
                "daily_limit_reached"
            )

            return Result.success()
        }

        val quietStart =
            config.optInt(
                "quiet_start_minutes",
                1320
            )

        val quietEnd =
            config.optInt(
                "quiet_end_minutes",
                420
            )

        val quietHours =
            isInsideRange(
                currentMinute,
                quietStart,
                quietEnd
            )

        val reminders =
            config.optJSONArray(
                "reminders"
            ) ?: JSONArray()

        for (
            index in
            0 until reminders.length()
        ) {
            val reminder =
                reminders.optJSONObject(
                    index
                ) ?: continue

            if (
                !reminder.optBoolean(
                    "enabled",
                    false
                )
            ) {
                continue
            }

            val reminderId =
                reminder.optString(
                    "id",
                    ""
                )

            if (reminderId.isBlank()) {
                continue
            }

            val pauseUntil =
                reminder.optLong(
                    "pause_until",
                    0L
                )

            if (pauseUntil > now) {
                continue
            }

            val frequencyLevel =
                reminder.optInt(
                    "frequency_level",
                    0
                ).coerceIn(
                    0,
                    2
                )

            val skippedDate =
                preferences.getString(
                    "skip_today_$reminderId",
                    null
                )

            if (skippedDate == today) {
                continue
            }


            val reminderType =
                reminder.optString(
                    "type",
                    "daily"
                )

            val due =
                if (
                    reminderType ==
                    "interval"
                ) {
                    isIntervalReminderDue(
                        preferences,
                        reminder,
                        currentMinute,
                        now
                    )
                } else {
                    isDailyReminderDue(
                        preferences,
                        reminder,
                        currentMinute,
                        today
                    )
                }

            if (
                reminderType !=
                    "interval" &&
                frequencyLevel > 0
            ) {
                val lastAdaptiveDelivery =
                    preferences.getLong(
                        "adaptive_last_delivery_" +
                            reminderId,
                        0L
                    )

                val minimumGap =
                    TimeUnit.DAYS.toMillis(
                        (
                            frequencyLevel +
                                1
                        ).toLong()
                    )

                if (
                    lastAdaptiveDelivery >
                        0L &&
                    now -
                        lastAdaptiveDelivery <
                        minimumGap
                ) {
                    continue
                }
            }

            if (!due) {
                continue
            }

            val title =
                reminder.optString(
                    "title_bn",
                    "মাইন্ডপালস রিমাইন্ডার"
                )

            val message =
                reminder.optString(
                    "message_bn",
                    "নিজের যত্ন নিতে একটি ছোট বিরতি নিন।"
                )

            val voiceEnabled =
                reminder.optBoolean(
                    "voice",
                    false
                )

            val vibrationEnabled =
                reminder.optBoolean(
                    "vibration",
                    false
                )

            val notificationSent =
                SmartReminderNotificationHelper
                    .show(
                        applicationContext,
                        reminderId,
                        title,
                        message,
                        vibrationEnabled &&
                            !quietHours,
                        voiceEnabled
                    )

            if (!notificationSent) {
                saveStatus(
                    preferences,
                    "notification_failed"
                )

                return Result.success()
            }

            val audioManager =
                applicationContext
                    .getSystemService(
                        Context.AUDIO_SERVICE
                    ) as AudioManager

            val canSpeak =
                voiceEnabled &&
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

            saveReminderDelivery(
                preferences,
                reminderId,
                reminderType,
                today,
                now
            )

            preferences.edit()
                .putLong(
                    "adaptive_last_delivery_" +
                        reminderId,
                    now
                )
                .apply()

            dailyCount += 1

            preferences.edit()
                .putString(
                    KEY_DAILY_COUNT_DATE,
                    today
                )
                .putInt(
                    KEY_DAILY_COUNT,
                    dailyCount
                )
                .putString(
                    KEY_LAST_STATUS,
                    "reminder_sent"
                )
                .putString(
                    KEY_LAST_REMINDER_ID,
                    reminderId
                )
                .putString(
                    KEY_LAST_REMINDER_TITLE,
                    title
                )
                .putLong(
                    KEY_LAST_REMINDER_AT,
                    now
                )
                .apply()

            /*
             * Human-centred rule:
             * send only one reminder per worker run.
             */
            return Result.success()
        }

        saveStatus(
            preferences,
            "no_reminder_due"
        )

        return Result.success()
    }

    private fun isDailyReminderDue(
        preferences:
            android.content.SharedPreferences,
        reminder: JSONObject,
        currentMinute: Int,
        today: String
    ): Boolean {
        val reminderId =
            reminder.optString(
                "id"
            )

        val hour =
            reminder.optInt(
                "hour",
                7
            )

        val minute =
            reminder.optInt(
                "minute",
                0
            )

        val scheduledMinute =
            hour * 60 + minute

        val alreadySentDate =
            preferences.getString(
                "last_daily_$reminderId",
                null
            )

        if (alreadySentDate == today) {
            return false
        }

        return isInsideDueWindow(
            currentMinute,
            scheduledMinute,
            20
        )
    }

    private fun isIntervalReminderDue(
        preferences:
            android.content.SharedPreferences,
        reminder: JSONObject,
        currentMinute: Int,
        currentTime: Long
    ): Boolean {
        val reminderId =
            reminder.optString(
                "id"
            )

        val activeStart =
            reminder.optInt(
                "active_start_minutes",
                480
            )

        val activeEnd =
            reminder.optInt(
                "active_end_minutes",
                1200
            )

        if (
            !isInsideRange(
                currentMinute,
                activeStart,
                activeEnd
            )
        ) {
            return false
        }

        val intervalMinutes =
            reminder.optInt(
                "interval_minutes",
                180
            ).coerceIn(
                60,
                480
            )

        val frequencyLevel =
            reminder.optInt(
                "frequency_level",
                0
            ).coerceIn(
                0,
                2
            )

        val effectiveIntervalMinutes =
            (
                intervalMinutes *
                    (
                        frequencyLevel +
                            1
                    )
            ).coerceIn(
                60,
                480
            )

        val lastSentAt =
            preferences.getLong(
                "last_interval_$reminderId",
                0L
            )

        if (lastSentAt <= 0L) {
            return true
        }

        return (
            currentTime -
            lastSentAt
        ) >=
            effectiveIntervalMinutes * 60_000L
    }

    private fun saveReminderDelivery(
        preferences:
            android.content.SharedPreferences,
        reminderId: String,
        reminderType: String,
        today: String,
        currentTime: Long
    ) {
        val editor =
            preferences.edit()

        if (
            reminderType ==
            "interval"
        ) {
            editor.putLong(
                "last_interval_$reminderId",
                currentTime
            )
        } else {
            editor.putString(
                "last_daily_$reminderId",
                today
            )
        }

        editor.apply()
    }

    private fun isInsideDueWindow(
        currentMinute: Int,
        scheduledMinute: Int,
        windowMinutes: Int
    ): Boolean {
        val difference =
            (
                currentMinute -
                scheduledMinute +
                1440
            ) % 1440

        return difference in
            0..windowMinutes
    }

    private fun isInsideRange(
        currentMinute: Int,
        startMinute: Int,
        endMinute: Int
    ): Boolean {
        return if (
            startMinute <= endMinute
        ) {
            currentMinute in
                startMinute..endMinute
        } else {
            currentMinute >=
                startMinute ||
                currentMinute <=
                endMinute
        }
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
            "mindpulse_smart_reminders"

        const val KEY_CONFIG_JSON =
            "reminder_config_json"

        const val KEY_LAST_CHECK_AT =
            "last_check_at"

        const val KEY_LAST_REMINDER_AT =
            "last_reminder_at"

        const val KEY_LAST_REMINDER_ID =
            "last_reminder_id"

        const val KEY_LAST_REMINDER_TITLE =
            "last_reminder_title"

        const val KEY_LAST_STATUS =
            "last_status"

        const val KEY_DAILY_COUNT =
            "daily_reminder_count"

        const val KEY_DAILY_COUNT_DATE =
            "daily_reminder_count_date"
    }
}
