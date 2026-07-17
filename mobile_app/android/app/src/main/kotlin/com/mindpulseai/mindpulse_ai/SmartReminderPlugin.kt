package com.mindpulseai.mindpulse_ai

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object SmartReminderPlugin {
    private const val CHANNEL =
        "mindpulse/smart_reminders"

    fun register(
        activity: FlutterActivity,
        flutterEngine: FlutterEngine
    ) {
        MethodChannel(
            flutterEngine
                .dartExecutor
                .binaryMessenger,
            CHANNEL
        ).setMethodCallHandler {
            call,
            result ->

            when (call.method) {
                "getConfiguration" -> {
                    val preferences =
                        preferences(activity)

                    result.success(
                        preferences.getString(
                            SmartReminderWorker
                                .KEY_CONFIG_JSON,
                            null
                        )
                    )
                }

                "saveConfiguration" -> {
                    val configJson =
                        call.argument<String>(
                            "configJson"
                        )

                    if (
                        configJson.isNullOrBlank()
                    ) {
                        result.error(
                            "INVALID_CONFIGURATION",
                            "Reminder configuration is empty.",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    preferences(activity)
                        .edit()
                        .putString(
                            SmartReminderWorker
                                .KEY_CONFIG_JSON,
                            configJson
                        )
                        .apply()

                    SmartReminderScheduler
                        .sync(activity)

                    result.success(true)
                }

                "runCheckNow" -> {
                    SmartReminderScheduler
                        .runNow(activity)

                    result.success(true)
                }

                "getStatus" -> {
                    result.success(
                        getStatus(activity)
                    )
                }

                "hasNotificationPermission" -> {
                    result.success(
                        SmartReminderNotificationHelper
                            .canPostNotifications(
                                activity
                            )
                    )
                }

                "openNotificationSettings" -> {
                    openNotificationSettings(
                        activity
                    )

                    result.success(true)
                }

                "sendTestReminder" -> {
                    val reminderId =
                        call.argument<String>(
                            "id"
                        ) ?: "test"

                    val title =
                        call.argument<String>(
                            "title"
                        ) ?: "মাইন্ডপালস"

                    val message =
                        call.argument<String>(
                            "message"
                        ) ?: (
                            "এটি একটি মাইন্ডপালস " +
                            "রিমাইন্ডার পরীক্ষা।"
                        )

                    val voice =
                        call.argument<Boolean>(
                            "voice"
                        ) ?: false

                    val vibration =
                        call.argument<Boolean>(
                            "vibration"
                        ) ?: false

                    val notificationSent =
                        SmartReminderNotificationHelper
                            .show(
                                activity,
                                reminderId,
                                title,
                                message,
                                vibration,
                                voice
                            )

                    if (
                        notificationSent &&
                        voice
                    ) {
                        val audioManager =
                            activity
                                .getSystemService(
                                    Context
                                        .AUDIO_SERVICE
                                ) as AudioManager

                        if (
                            audioManager
                                .ringerMode ==
                            AudioManager
                                .RINGER_MODE_NORMAL
                        ) {
                            Thread {
                                BanglaVoiceReminderHelper
                                    .speak(
                                        activity
                                            .applicationContext,
                                        message
                                    )
                            }.start()
                        }
                    }

                    result.success(
                        notificationSent
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun preferences(
        context: Context
    ): android.content.SharedPreferences {
        return context
            .getSharedPreferences(
                SmartReminderWorker
                    .PREFERENCES_NAME,
                Context.MODE_PRIVATE
            )
    }

    private fun getStatus(
        context: Context
    ): Map<String, Any?> {
        val preferences =
            preferences(context)

        return mapOf(
            "last_check_at" to
                preferences.getLong(
                    SmartReminderWorker
                        .KEY_LAST_CHECK_AT,
                    0L
                ),

            "last_reminder_at" to
                preferences.getLong(
                    SmartReminderWorker
                        .KEY_LAST_REMINDER_AT,
                    0L
                ),

            "last_reminder_id" to
                preferences.getString(
                    SmartReminderWorker
                        .KEY_LAST_REMINDER_ID,
                    null
                ),

            "last_reminder_title" to
                preferences.getString(
                    SmartReminderWorker
                        .KEY_LAST_REMINDER_TITLE,
                    null
                ),

            "last_status" to
                preferences.getString(
                    SmartReminderWorker
                        .KEY_LAST_STATUS,
                    "not_started"
                ),

            "daily_count" to
                preferences.getInt(
                    SmartReminderWorker
                        .KEY_DAILY_COUNT,
                    0
                ),

            "notification_permission" to
                SmartReminderNotificationHelper
                    .canPostNotifications(
                        context
                    )
        )
    }

    private fun openNotificationSettings(
        context: Context
    ) {
        val intent =
            Intent(
                Settings
                    .ACTION_APP_NOTIFICATION_SETTINGS
            ).apply {
                putExtra(
                    Settings
                        .EXTRA_APP_PACKAGE,
                    context.packageName
                )

                addFlags(
                    Intent
                        .FLAG_ACTIVITY_NEW_TASK
                )
            }

        context.startActivity(
            intent
        )
    }
}
