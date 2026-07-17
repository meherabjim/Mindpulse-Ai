package com.mindpulseai.mindpulse_ai

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import org.json.JSONObject
import java.util.concurrent.TimeUnit

object SmartReminderScheduler {
    private const val PERIODIC_WORK_NAME =
        "mindpulse_smart_reminder_periodic"

    private const val IMMEDIATE_WORK_NAME =
        "mindpulse_smart_reminder_immediate"

    fun sync(
        context: Context
    ) {
        val preferences =
            context.getSharedPreferences(
                SmartReminderWorker
                    .PREFERENCES_NAME,
                Context.MODE_PRIVATE
            )

        val configText =
            preferences.getString(
                SmartReminderWorker
                    .KEY_CONFIG_JSON,
                null
            )

        val enabled =
            try {
                if (
                    configText.isNullOrBlank()
                ) {
                    false
                } else {
                    JSONObject(
                        configText
                    ).optBoolean(
                        "master_enabled",
                        false
                    )
                }
            } catch (
                error: Exception
            ) {
                false
            }

        if (enabled) {
            enable(context)
        } else {
            disable(context)
        }
    }

    fun enable(
        context: Context
    ) {
        val request =
            PeriodicWorkRequestBuilder<
                SmartReminderWorker
            >(
                15,
                TimeUnit.MINUTES
            ).build()

        WorkManager.getInstance(
            context
        ).enqueueUniquePeriodicWork(
            PERIODIC_WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            request
        )

        runNow(context)
    }

    fun disable(
        context: Context
    ) {
        WorkManager.getInstance(
            context
        ).cancelUniqueWork(
            PERIODIC_WORK_NAME
        )

        WorkManager.getInstance(
            context
        ).cancelUniqueWork(
            IMMEDIATE_WORK_NAME
        )
    }

    fun runNow(
        context: Context
    ) {
        val request =
            OneTimeWorkRequestBuilder<
                SmartReminderWorker
            >().build()

        WorkManager.getInstance(
            context
        ).enqueueUniqueWork(
            IMMEDIATE_WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            request
        )
    }
}
