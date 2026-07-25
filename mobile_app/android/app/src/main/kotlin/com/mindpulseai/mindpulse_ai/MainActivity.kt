package com.mindpulseai.mindpulse_ai

import android.Manifest
import android.app.AlarmManager
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.mindpulseai.mindpulse_ai.prayer.PrayerAlarmScheduler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL =
            "mindpulse/screen_time"

        private const val
        NOTIFICATION_PERMISSION_REQUEST =
            4107
    }

    private var pendingNotificationResult:
        MethodChannel.Result? = null

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(
            flutterEngine
        )

        SmartReminderPlugin.register(this, flutterEngine)

        MovementInsightPlugin.register(this, flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "mindpulse/prayer_alarm"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> {
                    result.success(
                        mapOf(
                            "notificationPermission" to
                                hasNotificationPermission(),
                            "exactAlarmPermission" to
                                PrayerAlarmScheduler
                                    .canScheduleExact(this)
                        )
                    )
                }

                "requestNotificationPermission" -> {
                    requestPrayerNotificationPermission()
                    result.success(null)
                }

                "requestExactAlarmPermission" -> {
                    requestExactAlarmPermission()
                    result.success(null)
                }

                "scheduleAlarms" -> {
                    val json =
                        call.argument<String>("json")

                    if (json.isNullOrBlank()) {
                        result.error(
                            "invalid_schedule",
                            "Prayer schedule JSON is missing.",
                            null
                        )
                    } else {
                        result.success(
                            PrayerAlarmScheduler.scheduleAll(
                                this,
                                json
                            )
                        )
                    }
                }

                "cancelAll" -> {
                    PrayerAlarmScheduler.cancelAll(this)
                    result.success(null)
                }

                "testAlarm" -> {
                    val fajr =
                        call.argument<Boolean>("fajr")
                            ?: false

                    PrayerAlarmScheduler.scheduleTest(
                        this,
                        fajr
                    )

                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine
                .dartExecutor
                .binaryMessenger,
            CHANNEL
        ).setMethodCallHandler {
            call,
            result ->

            when (call.method) {
                "hasUsageAccess" -> {
                    result.success(
                        ScreenTimeUsageCalculator
                            .hasUsageAccess(
                                this
                            )
                    )
                }

                "openUsageAccessSettings" -> {
                    openUsageAccessSettings()
                    result.success(true)
                }

                "getTodayUsage" -> {
                    try {
                        result.success(
                            ScreenTimeUsageCalculator
                                .getTodayUsage(
                                    this
                                )
                        )
                    } catch (
                        error: Exception
                    ) {
                        result.error(
                            "USAGE_QUERY_FAILED",
                            error.message,
                            null
                        )
                    }
                }


                "getScreenTimeInsights" -> {
                    try {
                        result.success(
                            ScreenTimeInsightCalculator
                                .getInsights(this)
                        )
                    } catch (error: Exception) {
                        result.error(
                            "SCREEN_TIME_INSIGHT_FAILED",
                            error.message,
                            null
                        )
                    }
                }

                "hasNotificationPermission" -> {
                    result.success(
                        hasNotificationPermission()
                    )
                }

                "requestNotificationPermission" -> {
                    requestNotificationPermission(
                        result
                    )
                }

                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(true)
                }

                "enableBackgroundReminders" -> {
                    val dailyLimit =
                        call.argument<Int>(
                            "dailyLimitMinutes"
                        ) ?: 90

                    val sessionLimit =
                        call.argument<Int>(
                            "sessionLimitMinutes"
                        ) ?: 45

                    val preferences =
                        getSharedPreferences(
                            ScreenTimeWorker
                                .PREFERENCES_NAME,
                            Context.MODE_PRIVATE
                        )

                    preferences.edit()
                        .putBoolean(
                            ScreenTimeWorker
                                .KEY_REMINDERS_ENABLED,
                            true
                        )
                        .putInt(
                            ScreenTimeWorker
                                .KEY_DAILY_SOCIAL_LIMIT,
                            dailyLimit
                        )
                        .putInt(
                            ScreenTimeWorker
                                .KEY_SESSION_LIMIT,
                            sessionLimit
                        )
                        .putInt(
                            ScreenTimeWorker
                                .KEY_COOLDOWN_MINUTES,
                            120
                        )
                        .apply()

                    ScreenTimeReminderScheduler
                        .enable(this)

                    result.success(true)
                }

                "disableBackgroundReminders" -> {
                    val preferences =
                        getSharedPreferences(
                            ScreenTimeWorker
                                .PREFERENCES_NAME,
                            Context.MODE_PRIVATE
                        )

                    preferences.edit()
                        .putBoolean(
                            ScreenTimeWorker
                                .KEY_REMINDERS_ENABLED,
                            false
                        )
                        .putString(
                            ScreenTimeWorker
                                .KEY_LAST_STATUS,
                            "disabled"
                        )
                        .apply()

                    ScreenTimeReminderScheduler
                        .disable(this)

                    result.success(true)
                }

                "runBackgroundCheckNow" -> {
                    ScreenTimeReminderScheduler
                        .runNow(this)

                    result.success(true)
                }

                "sendTestScreenTimeReminder" -> {
                    result.success(
                        ScreenTimeNotificationHelper
                            .showTestNotification(
                                this
                            )
                    )
                }


                "isBanglaVoiceReminderEnabled" -> {
                    val preferences =
                        getSharedPreferences(
                            ScreenTimeWorker
                                .PREFERENCES_NAME,
                            Context.MODE_PRIVATE
                        )

                    result.success(
                        preferences.getBoolean(
                            ScreenTimeWorker
                                .KEY_VOICE_ENABLED,
                            false
                        )
                    )
                }

                "setBanglaVoiceReminderEnabled" -> {
                    val enabled =
                        call.argument<Boolean>(
                            "enabled"
                        ) ?: false

                    val preferences =
                        getSharedPreferences(
                            ScreenTimeWorker
                                .PREFERENCES_NAME,
                            Context.MODE_PRIVATE
                        )

                    preferences.edit()
                        .putBoolean(
                            ScreenTimeWorker
                                .KEY_VOICE_ENABLED,
                            enabled
                        )
                        .apply()

                    result.success(true)
                }

                "testBanglaVoiceReminder" -> {
                    Thread {
                        val spoken =
                            BanglaVoiceReminderHelper
                                .speak(
                                    applicationContext,
                                    "মাইন্ডপালস বাংলা ভয়েস " +
                                        "রিমাইন্ডার চালু হয়েছে। " +
                                        "আপনি অনেকক্ষণ ফোন " +
                                        "ব্যবহার করলে মাইন্ডপালস " +
                                        "আপনাকে বিরতি নিতে " +
                                        "মনে করিয়ে দেবে।"
                                )

                        runOnUiThread {
                            result.success(
                                spoken
                            )
                        }
                    }.start()
                }

                "getBackgroundReminderStatus" -> {
                    result.success(
                        getBackgroundStatus()
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun requestPrayerNotificationPermission() {
        if (
            Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.TIRAMISU &&
            !hasNotificationPermission()
        ) {
            requestPermissions(
                arrayOf(
                    Manifest.permission.POST_NOTIFICATIONS
                ),
                9401
            )
        }
    }

    private fun requestExactAlarmPermission() {
        if (
            Build.VERSION.SDK_INT <
                Build.VERSION_CODES.S
        ) {
            return
        }

        val alarmManager =
            getSystemService(
                AlarmManager::class.java
            )

        if (
            alarmManager
                .canScheduleExactAlarms()
        ) {
            return
        }

        startActivity(
            Intent(
                Settings
                    .ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                Uri.parse(
                    "package:$packageName"
                )
            )
        )
    }

    private fun hasNotificationPermission():
        Boolean {
        return (
            Build.VERSION.SDK_INT <
                Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission
                    .POST_NOTIFICATIONS
            ) ==
                PackageManager
                    .PERMISSION_GRANTED
        )
    }

    private fun requestNotificationPermission(
        result: MethodChannel.Result
    ) {
        if (hasNotificationPermission()) {
            result.success(true)
            return
        }

        if (
            Build.VERSION.SDK_INT <
            Build.VERSION_CODES.TIRAMISU
        ) {
            result.success(true)
            return
        }

        pendingNotificationResult
            ?.success(false)

        pendingNotificationResult =
            result

        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission
                    .POST_NOTIFICATIONS
            ),
            NOTIFICATION_PERMISSION_REQUEST
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults
        )

        if (
            requestCode ==
            NOTIFICATION_PERMISSION_REQUEST
        ) {
            val granted =
                grantResults.isNotEmpty() &&
                grantResults[0] ==
                    PackageManager
                        .PERMISSION_GRANTED

            pendingNotificationResult
                ?.success(granted)

            pendingNotificationResult =
                null
        }
    }

    private fun openUsageAccessSettings() {
        val intent =
            Intent(
                Settings
                    .ACTION_USAGE_ACCESS_SETTINGS
            )

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.Q
        ) {
            intent.data =
                Uri.parse(
                    "package:$packageName"
                )
        }

        startActivity(intent)
    }

    private fun openNotificationSettings() {
        val intent =
            Intent(
                Settings
                    .ACTION_APP_NOTIFICATION_SETTINGS
            ).apply {
                putExtra(
                    Settings
                        .EXTRA_APP_PACKAGE,
                    packageName
                )
            }

        startActivity(intent)
    }

    private fun getBackgroundStatus():
        Map<String, Any?> {
        val preferences =
            getSharedPreferences(
                ScreenTimeWorker
                    .PREFERENCES_NAME,
                Context.MODE_PRIVATE
            )

        return mapOf(
            "enabled" to
                preferences.getBoolean(
                    ScreenTimeWorker
                        .KEY_REMINDERS_ENABLED,
                    false
                ),

            "notification_permission" to
                hasNotificationPermission(),

            "last_check_at" to
                preferences.getLong(
                    ScreenTimeWorker
                        .KEY_LAST_CHECK_AT,
                    0L
                ),

            "last_reminder_at" to
                preferences.getLong(
                    ScreenTimeWorker
                        .KEY_LAST_REMINDER_AT,
                    0L
                ),

            "last_status" to
                preferences.getString(
                    ScreenTimeWorker
                        .KEY_LAST_STATUS,
                    "not_started"
                ),

            "last_social_minutes" to
                preferences.getLong(
                    ScreenTimeWorker
                        .KEY_LAST_SOCIAL_MINUTES,
                    0L
                ),

            "last_longest_minutes" to
                preferences.getLong(
                    ScreenTimeWorker
                        .KEY_LAST_LONGEST_MINUTES,
                    0L
                ),

            "last_longest_app" to
                preferences.getString(
                    ScreenTimeWorker
                        .KEY_LAST_LONGEST_APP,
                    null
                )
        )
    }
}
