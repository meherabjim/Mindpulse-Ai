package com.mindpulseai.mindpulse_ai

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.max
import kotlin.math.roundToLong

object ScreenTimeInsightCalculator {
    private const val MINUTE_MS = 60_000L
    private const val SESSION_GAP_MS = 2L * MINUTE_MS

    private data class UsageInterval(
        val start: Long,
        val end: Long,
        val packageName: String
    )

    private data class DaySummary(
        val date: String,
        val totalMs: Long,
        val sessionCount: Int,
        val longestSessionMs: Long,
        val morningMs: Long,
        val lateNightMs: Long,
        val mindPulseMs: Long
    )

    fun getInsights(context: Context): Map<String, Any?> {
        val hasAccess =
            ScreenTimeUsageCalculator.hasUsageAccess(context)

        if (!hasAccess) {
            return mapOf(
                "has_usage_access" to false,
                "generated_at" to System.currentTimeMillis(),
                "privacy_mode" to "local_aggregate_only"
            )
        }

        val now = System.currentTimeMillis()
        val todayStart = startOfDay(now)
        val today = calculateDay(context, todayStart, now)

        val history = mutableListOf<DaySummary>()

        for (daysAgo in 1..7) {
            val dayStart = startOfDayOffset(now, -daysAgo)
            val dayEnd = startOfDayOffset(now, -(daysAgo - 1))
            history.add(calculateDay(context, dayStart, dayEnd))
        }

        val averageMs =
            if (history.isEmpty()) {
                0L
            } else {
                history.map { it.totalMs.toDouble() }.average().roundToLong()
            }

        return mapOf(
            "has_usage_access" to true,
            "generated_at" to now,
            "privacy_mode" to "local_aggregate_only",
            "today" to dayToMap(today),
            "seven_day_average_minutes" to toMinutes(averageMs),
            "difference_from_average_minutes" to
                signedMinutes(today.totalMs - averageMs),
            "history" to history.reversed().map { dayToMap(it) },
            "interpretation_note" to
                "Phone-use statistics are approximate personal-use patterns. " +
                "They do not prove that phone use caused a mood, stress, sleep, " +
                "or health change.",
            "data_note" to
                "Only aggregate time and session counts are returned to MindPulse. " +
                "Messages, typing, passwords, notification content, and screen " +
                "content are not read."
        )
    }

    private fun calculateDay(
        context: Context,
        start: Long,
        end: Long
    ): DaySummary {
        val intervals = queryForegroundIntervals(context, start, end)
        val unionIntervals = mergeIntervals(intervals, 0L)
        val sessions = mergeIntervals(intervals, SESSION_GAP_MS)

        val totalMs = unionIntervals.sumOf {
            max(0L, it.end - it.start)
        }

        val longestMs = sessions.maxOfOrNull {
            max(0L, it.end - it.start)
        } ?: 0L

        val morningStart = minuteOfDay(start, 6 * 60)
        val morningEnd = minuteOfDay(start, 10 * 60)
        val lateNightStart = minuteOfDay(start, 22 * 60)
        val earlyMorningEnd = minuteOfDay(start, 6 * 60)

        val morningMs = overlapTotal(
            unionIntervals,
            morningStart,
            minOf(morningEnd, end)
        )

        val lateNightMs =
            overlapTotal(
                unionIntervals,
                start,
                minOf(earlyMorningEnd, end)
            ) +
            overlapTotal(
                unionIntervals,
                lateNightStart,
                end
            )

        val mindPulseMs = intervals
            .filter { it.packageName == context.packageName }
            .sumOf { max(0L, it.end - it.start) }

        return DaySummary(
            date = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(start)),
            totalMs = totalMs,
            sessionCount = sessions.size,
            longestSessionMs = longestMs,
            morningMs = morningMs,
            lateNightMs = lateNightMs,
            mindPulseMs = mindPulseMs
        )
    }

    private fun queryForegroundIntervals(
        context: Context,
        start: Long,
        end: Long
    ): List<UsageInterval> {
        val manager = context.getSystemService(
            Context.USAGE_STATS_SERVICE
        ) as UsageStatsManager

        val events = manager.queryEvents(start, end)
        val activeStarts = mutableMapOf<String, Long>()
        val intervals = mutableListOf<UsageInterval>()
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)

            val packageName = event.packageName ?: continue

            if (shouldIgnorePackage(packageName)) {
                continue
            }

            val timestamp = event.timeStamp.coerceIn(start, end)

            val isForeground =
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND

            val isBackground =
                event.eventType == UsageEvents.Event.ACTIVITY_PAUSED ||
                event.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND

            if (isForeground) {
                val previousStart = activeStarts[packageName]

                if (previousStart != null && timestamp > previousStart) {
                    intervals.add(
                        UsageInterval(previousStart, timestamp, packageName)
                    )
                }

                activeStarts[packageName] = timestamp
            } else if (isBackground) {
                val activeStart = activeStarts.remove(packageName) ?: continue

                if (timestamp > activeStart) {
                    intervals.add(
                        UsageInterval(activeStart, timestamp, packageName)
                    )
                }
            }
        }

        for ((packageName, activeStart) in activeStarts) {
            if (end > activeStart) {
                intervals.add(UsageInterval(activeStart, end, packageName))
            }
        }

        return intervals
            .filter { it.end > it.start }
            .sortedBy { it.start }
    }

    private fun shouldIgnorePackage(packageName: String): Boolean {
        val normalized = packageName.lowercase(Locale.US)

        return normalized.isBlank() ||
            normalized == "android" ||
            normalized == "com.android.systemui" ||
            normalized.contains("launcher") ||
            normalized.contains("permissioncontroller")
    }

    private fun mergeIntervals(
        source: List<UsageInterval>,
        gapMs: Long
    ): List<UsageInterval> {
        if (source.isEmpty()) {
            return emptyList()
        }

        val sorted = source.sortedBy { it.start }
        val merged = mutableListOf<UsageInterval>()

        var currentStart = sorted.first().start
        var currentEnd = sorted.first().end

        for (index in 1 until sorted.size) {
            val next = sorted[index]

            if (next.start <= currentEnd + gapMs) {
                currentEnd = max(currentEnd, next.end)
            } else {
                merged.add(UsageInterval(currentStart, currentEnd, ""))
                currentStart = next.start
                currentEnd = next.end
            }
        }

        merged.add(UsageInterval(currentStart, currentEnd, ""))
        return merged
    }

    private fun overlapTotal(
        intervals: List<UsageInterval>,
        windowStart: Long,
        windowEnd: Long
    ): Long {
        if (windowEnd <= windowStart) {
            return 0L
        }

        return intervals.sumOf {
            val overlapStart = max(it.start, windowStart)
            val overlapEnd = minOf(it.end, windowEnd)
            max(0L, overlapEnd - overlapStart)
        }
    }

    private fun dayToMap(day: DaySummary): Map<String, Any> {
        return mapOf(
            "date" to day.date,
            "total_minutes" to toMinutes(day.totalMs),
            "session_count" to day.sessionCount,
            "longest_session_minutes" to toMinutes(day.longestSessionMs),
            "morning_minutes" to toMinutes(day.morningMs),
            "late_night_minutes" to toMinutes(day.lateNightMs),
            "mindpulse_minutes" to toMinutes(day.mindPulseMs)
        )
    }

    private fun toMinutes(milliseconds: Long): Long {
        if (milliseconds <= 0L) {
            return 0L
        }

        return milliseconds / MINUTE_MS
    }

    private fun signedMinutes(milliseconds: Long): Long {
        return milliseconds / MINUTE_MS
    }

    private fun startOfDay(timestamp: Long): Long {
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = timestamp
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }

    private fun startOfDayOffset(timestamp: Long, dayOffset: Int): Long {
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = startOfDay(timestamp)
        calendar.add(Calendar.DAY_OF_YEAR, dayOffset)
        return calendar.timeInMillis
    }

    private fun minuteOfDay(dayStart: Long, minute: Int): Long {
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = dayStart
        calendar.add(Calendar.MINUTE, minute)
        return calendar.timeInMillis
    }
}
