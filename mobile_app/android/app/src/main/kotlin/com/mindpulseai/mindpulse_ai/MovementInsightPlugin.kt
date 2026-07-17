package com.mindpulseai.mindpulse_ai

// HUMAN_COMPANION_MOVEMENT_V1

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.roundToLong

object MovementInsightPlugin {
    private const val CHANNEL =
        "mindpulse/movement"

    private const val REQUEST_CODE =
        4208

    private const val PREFS =
        "mindpulse_movement"

    private const val BASELINE_DATE =
        "baseline_date"

    private const val BASELINE_STEPS =
        "baseline_steps"

    fun register(
        activity: Activity,
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
                "hasActivityRecognitionPermission" -> {
                    result.success(
                        hasPermission(
                            activity
                        )
                    )
                }

                "requestActivityRecognitionPermission" -> {
                    requestPermission(
                        activity
                    )

                    result.success(
                        true
                    )
                }

                "isStepCounterAvailable" -> {
                    result.success(
                        stepCounter(
                            activity
                        ) != null
                    )
                }

                "getMovementInsights" -> {
                    readMovementInsights(
                        activity,
                        result
                    )
                }

                "openAppSettings" -> {
                    openAppSettings(
                        activity
                    )

                    result.success(
                        true
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasPermission(
        activity: Activity
    ): Boolean {
        if (
            Build.VERSION.SDK_INT
            < Build.VERSION_CODES.Q
        ) {
            return true
        }

        return ContextCompat
            .checkSelfPermission(
                activity,
                Manifest.permission
                    .ACTIVITY_RECOGNITION
            ) ==
            PackageManager
                .PERMISSION_GRANTED
    }

    private fun requestPermission(
        activity: Activity
    ) {
        if (
            hasPermission(
                activity
            )
        ) {
            return
        }

        if (
            Build.VERSION.SDK_INT
            >= Build.VERSION_CODES.Q
        ) {
            ActivityCompat
                .requestPermissions(
                    activity,
                    arrayOf(
                        Manifest.permission
                            .ACTIVITY_RECOGNITION
                    ),
                    REQUEST_CODE
                )
        }
    }

    private fun stepCounter(
        context: Context
    ): Sensor? {
        val manager =
            context.getSystemService(
                Context.SENSOR_SERVICE
            ) as SensorManager

        return manager
            .getDefaultSensor(
                Sensor.TYPE_STEP_COUNTER
            )
    }

    private fun readMovementInsights(
        activity: Activity,
        result: MethodChannel.Result
    ) {
        if (
            !hasPermission(
                activity
            )
        ) {
            result.success(
                unavailable(
                    permissionGranted =
                        false,

                    sensorAvailable =
                        stepCounter(
                            activity
                        ) != null,

                    note = (
                        "Physical activity "
                        + "permission has not "
                        + "been granted."
                    )
                )
            )

            return
        }

        val sensorManager =
            activity.getSystemService(
                Context.SENSOR_SERVICE
            ) as SensorManager

        val sensor =
            sensorManager
                .getDefaultSensor(
                    Sensor.TYPE_STEP_COUNTER
                )

        if (sensor == null) {
            result.success(
                unavailable(
                    permissionGranted =
                        true,

                    sensorAvailable =
                        false,

                    note = (
                        "This device does not "
                        + "expose a step counter "
                        + "sensor."
                    )
                )
            )

            return
        }

        val completed =
            AtomicBoolean(
                false
            )

        val handler =
            Handler(
                Looper.getMainLooper()
            )

        var listenerReference:
            SensorEventListener? =
            null

        val timeout =
            Runnable {
                if (
                    completed
                        .compareAndSet(
                            false,
                            true
                        )
                ) {
                    listenerReference
                        ?.let {
                            sensorManager
                                .unregisterListener(
                                    it
                                )
                        }

                    result.error(
                        "STEP_SENSOR_TIMEOUT",
                        (
                            "The step counter "
                            + "did not return a "
                            + "reading in time."
                        ),
                        null
                    )
                }
            }

        val listener =
            object :
                SensorEventListener {

                override fun onSensorChanged(
                    event: SensorEvent
                ) {
                    if (
                        !completed
                            .compareAndSet(
                                false,
                                true
                            )
                    ) {
                        return
                    }

                    handler
                        .removeCallbacks(
                            timeout
                        )

                    sensorManager
                        .unregisterListener(
                            this
                        )

                    val cumulative =
                        event.values
                            .firstOrNull()
                            ?.toDouble()
                            ?.roundToLong()
                            ?: 0L

                    result.success(
                        buildDailyInsight(
                            activity,
                            cumulative
                        )
                    )
                }

                override fun onAccuracyChanged(
                    sensor: Sensor?,
                    accuracy: Int
                ) {
                    // No action is required.
                }
            }

        listenerReference =
            listener

        val registered =
            sensorManager
                .registerListener(
                    listener,
                    sensor,
                    SensorManager
                        .SENSOR_DELAY_NORMAL
                )

        if (!registered) {
            if (
                completed
                    .compareAndSet(
                        false,
                        true
                    )
            ) {
                result.error(
                    "STEP_SENSOR_UNAVAILABLE",
                    (
                        "The step counter "
                        + "listener could not "
                        + "be registered."
                    ),
                    null
                )
            }

            return
        }

        handler.postDelayed(
            timeout,
            3500L
        )
    }

    private fun buildDailyInsight(
        context: Context,
        cumulativeSteps: Long
    ): Map<String, Any?> {
        val today =
            SimpleDateFormat(
                "yyyy-MM-dd",
                Locale.US
            ).format(
                Date()
            )

        val preferences =
            context
                .getSharedPreferences(
                    PREFS,
                    Context.MODE_PRIVATE
                )

        val storedDate =
            preferences
                .getString(
                    BASELINE_DATE,
                    null
                )

        val storedBaseline =
            preferences
                .getLong(
                    BASELINE_STEPS,
                    cumulativeSteps
                )

        val resetBaseline =
            storedDate != today ||
            cumulativeSteps <
                storedBaseline

        val baseline =
            if (resetBaseline) {
                cumulativeSteps
            } else {
                storedBaseline
            }

        if (resetBaseline) {
            preferences
                .edit()
                .putString(
                    BASELINE_DATE,
                    today
                )
                .putLong(
                    BASELINE_STEPS,
                    cumulativeSteps
                )
                .apply()
        }

        val localSteps =
            max(
                0L,
                cumulativeSteps -
                    baseline
            )

        return mapOf(
            "available" to true,

            "permission_granted" to
                true,

            "sensor_available" to
                true,

            "generated_at" to
                System
                    .currentTimeMillis(),

            "local_date" to
                today,

            "step_count" to
                localSteps,

            "walking_minutes" to
                null,

            "active_minutes" to
                null,

            "source" to
                "android_step_counter",

            "privacy_mode" to
                "local_aggregate_only",

            "coverage" to
                "since_first_read_today",

            "baseline_initialized" to
                resetBaseline,

            "note" to (
                "Steps are counted locally "
                + "from the first stored "
                + "sensor reading for this "
                + "date. Walking minutes "
                + "are not inferred from "
                + "steps."
            )
        )
    }

    private fun unavailable(
        permissionGranted: Boolean,
        sensorAvailable: Boolean,
        note: String
    ): Map<String, Any?> {
        return mapOf(
            "available" to
                false,

            "permission_granted" to
                permissionGranted,

            "sensor_available" to
                sensorAvailable,

            "generated_at" to
                System
                    .currentTimeMillis(),

            "step_count" to
                null,

            "walking_minutes" to
                null,

            "active_minutes" to
                null,

            "source" to
                "none",

            "privacy_mode" to
                "local_aggregate_only",

            "coverage" to
                "unavailable",

            "baseline_initialized" to
                false,

            "note" to
                note
        )
    }

    private fun openAppSettings(
        activity: Activity
    ) {
        val intent =
            Intent(
                Settings
                    .ACTION_APPLICATION_DETAILS_SETTINGS
            ).apply {
                data =
                    Uri.parse(
                        "package:"
                        + activity.packageName
                    )
            }

        activity.startActivity(
            intent
        )
    }
}
