package com.mindpulseai.mindpulse_ai

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object ScreenTimeReminderScheduler {
    private const val PERIODIC_WORK_NAME =
        "mindpulse_screen_time_periodic"

    private const val IMMEDIATE_WORK_NAME =
        "mindpulse_screen_time_immediate"

    fun enable(
        context: Context
    ) {
        val periodicRequest =
            PeriodicWorkRequestBuilder<
                ScreenTimeWorker
            >(
                15,
                TimeUnit.MINUTES
            ).build()

        WorkManager.getInstance(
            context
        ).enqueueUniquePeriodicWork(
            PERIODIC_WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            periodicRequest
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
        val immediateRequest =
            OneTimeWorkRequestBuilder<
                ScreenTimeWorker
            >().build()

        WorkManager.getInstance(
            context
        ).enqueueUniqueWork(
            IMMEDIATE_WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            immediateRequest
        )
    }
}
