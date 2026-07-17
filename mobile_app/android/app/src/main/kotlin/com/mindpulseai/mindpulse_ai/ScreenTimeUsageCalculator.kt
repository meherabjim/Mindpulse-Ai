package com.mindpulseai.mindpulse_ai

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import java.util.Calendar

data class ScreenTimeSummary(
    val totalUsageMs: Long,
    val socialUsageMs: Long,
    val longestSessionMs: Long,
    val longestAppName: String?,
    val longestPackageName: String?
)

object ScreenTimeUsageCalculator {
    val socialPackages = setOf(
        "com.facebook.katana",
        "com.facebook.orca",
        "com.instagram.android",
        "com.zhiliaoapp.musically",
        "com.ss.android.ugc.trill",
        "com.google.android.youtube",
        "com.twitter.android",
        "com.snapchat.android",
        "com.reddit.frontpage",
        "org.telegram.messenger",
        "com.whatsapp"
    )

    private val excludedPackages = setOf(
        "com.android.systemui",
        "com.android.permissioncontroller",
        "com.google.android.permissioncontroller",
        "com.google.android.apps.nexuslauncher"
    )

    fun hasUsageAccess(
        context: Context
    ): Boolean {
        val appOps =
            context.getSystemService(
                Context.APP_OPS_SERVICE
            ) as AppOpsManager

        val mode =
            if (
                Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.Q
            ) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager
                        .OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager
                        .OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            }

        return mode ==
            AppOpsManager.MODE_ALLOWED
    }

    fun getTodayUsage(
        context: Context
    ): List<Map<String, Any>> {
        if (!hasUsageAccess(context)) {
            return emptyList()
        }

        val usageStatsManager =
            context.getSystemService(
                Context.USAGE_STATS_SERVICE
            ) as UsageStatsManager

        val startCalendar =
            Calendar.getInstance().apply {
                set(
                    Calendar.HOUR_OF_DAY,
                    0
                )

                set(
                    Calendar.MINUTE,
                    0
                )

                set(
                    Calendar.SECOND,
                    0
                )

                set(
                    Calendar.MILLISECOND,
                    0
                )
            }

        val startTime =
            startCalendar.timeInMillis

        val endTime =
            System.currentTimeMillis()

        val usageEvents =
            usageStatsManager.queryEvents(
                startTime,
                endTime
            )

        val activeStarts =
            mutableMapOf<String, Long>()

        val totalDurations =
            mutableMapOf<String, Long>()

        val longestSessions =
            mutableMapOf<String, Long>()

        val sessionCounts =
            mutableMapOf<String, Int>()

        val lastUsedTimes =
            mutableMapOf<String, Long>()

        fun finishSession(
            packageName: String,
            finishedAt: Long
        ) {
            val startedAt =
                activeStarts.remove(
                    packageName
                ) ?: return

            val duration =
                (
                    finishedAt -
                    startedAt
                ).coerceAtLeast(0L)

            if (duration <= 0L) {
                return
            }

            totalDurations[packageName] =
                (
                    totalDurations[
                        packageName
                    ] ?: 0L
                ) + duration

            longestSessions[packageName] =
                maxOf(
                    longestSessions[
                        packageName
                    ] ?: 0L,
                    duration
                )

            sessionCounts[packageName] =
                (
                    sessionCounts[
                        packageName
                    ] ?: 0
                ) + 1

            lastUsedTimes[packageName] =
                maxOf(
                    lastUsedTimes[
                        packageName
                    ] ?: 0L,
                    finishedAt
                )
        }

        val event =
            UsageEvents.Event()

        while (
            usageEvents.hasNextEvent()
        ) {
            usageEvents.getNextEvent(
                event
            )

            val eventPackage =
                event.packageName
                    ?: continue

            val eventTime =
                event.timeStamp

            val isForeground =
                event.eventType ==
                    UsageEvents.Event
                        .MOVE_TO_FOREGROUND ||
                (
                    Build.VERSION.SDK_INT >=
                        Build.VERSION_CODES.Q &&
                    event.eventType ==
                        UsageEvents.Event
                            .ACTIVITY_RESUMED
                )

            val isBackground =
                event.eventType ==
                    UsageEvents.Event
                        .MOVE_TO_BACKGROUND ||
                (
                    Build.VERSION.SDK_INT >=
                        Build.VERSION_CODES.Q &&
                    event.eventType ==
                        UsageEvents.Event
                            .ACTIVITY_PAUSED
                )

            if (isForeground) {
                if (
                    !activeStarts.containsKey(
                        eventPackage
                    )
                ) {
                    activeStarts[
                        eventPackage
                    ] = eventTime
                }

                lastUsedTimes[
                    eventPackage
                ] = maxOf(
                    lastUsedTimes[
                        eventPackage
                    ] ?: 0L,
                    eventTime
                )
            } else if (isBackground) {
                finishSession(
                    eventPackage,
                    eventTime
                )
            }
        }

        activeStarts
            .keys
            .toList()
            .forEach {
                packageName ->

                finishSession(
                    packageName,
                    endTime
                )
            }

        return totalDurations
            .entries
            .filter {
                it.value > 0L
            }
            .map {
                entry ->

                val appPackage =
                    entry.key

                mapOf(
                    "package_name" to
                        appPackage,

                    "app_name" to
                        getApplicationLabel(
                            context,
                            appPackage
                        ),

                    "total_time_ms" to
                        entry.value,

                    "longest_session_ms" to
                        (
                            longestSessions[
                                appPackage
                            ] ?: 0L
                        ),

                    "session_count" to
                        (
                            sessionCounts[
                                appPackage
                            ] ?: 0
                        ),

                    "last_time_used" to
                        (
                            lastUsedTimes[
                                appPackage
                            ] ?: 0L
                        )
                )
            }
            .sortedByDescending {
                (
                    it["total_time_ms"]
                        as? Long
                ) ?: 0L
            }
    }

    fun getTodaySummary(
        context: Context
    ): ScreenTimeSummary {
        val entries =
            getTodayUsage(context)

        val totalUsage =
            entries.sumOf {
                (
                    it["total_time_ms"]
                        as? Long
                ) ?: 0L
            }

        val socialUsage =
            entries
                .filter {
                    socialPackages.contains(
                        it[
                            "package_name"
                        ]?.toString()
                    )
                }
                .sumOf {
                    (
                        it["total_time_ms"]
                            as? Long
                    ) ?: 0L
                }

        val longestEntry =
            entries
                .filter {
                    val packageValue =
                        it[
                            "package_name"
                        ]?.toString()
                            ?: ""

                    packageValue !=
                        context.packageName &&
                    !excludedPackages.contains(
                        packageValue
                    )
                }
                .maxByOrNull {
                    (
                        it[
                            "longest_session_ms"
                        ] as? Long
                    ) ?: 0L
                }

        return ScreenTimeSummary(
            totalUsageMs =
                totalUsage,

            socialUsageMs =
                socialUsage,

            longestSessionMs =
                (
                    longestEntry
                        ?.get(
                            "longest_session_ms"
                        ) as? Long
                ) ?: 0L,

            longestAppName =
                longestEntry
                    ?.get("app_name")
                    ?.toString(),

            longestPackageName =
                longestEntry
                    ?.get("package_name")
                    ?.toString()
        )
    }

    private fun getApplicationLabel(
        context: Context,
        applicationPackage: String
    ): String {
        return try {
            val applicationInfo =
                if (
                    Build.VERSION.SDK_INT >=
                    Build.VERSION_CODES.TIRAMISU
                ) {
                    context.packageManager
                        .getApplicationInfo(
                            applicationPackage,
                            PackageManager
                                .ApplicationInfoFlags
                                .of(0)
                        )
                } else {
                    @Suppress("DEPRECATION")
                    context.packageManager
                        .getApplicationInfo(
                            applicationPackage,
                            0
                        )
                }

            context.packageManager
                .getApplicationLabel(
                    applicationInfo
                )
                .toString()
        } catch (
            error: Exception
        ) {
            applicationPackage
        }
    }
}
