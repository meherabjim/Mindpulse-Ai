package com.mindpulseai.mindpulse_ai.prayer

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.mindpulseai.mindpulse_ai.MainActivity
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

object PrayerAlarmScheduler {
    private const val preferencesName = "mindpulse_prayer_alarm"
    private const val scheduleKey = "scheduled_prayer_alarms"
    private const val scheduleVersionKey = "scheduled_prayer_alarms_version"
    private const val currentScheduleVersion = 2
    private const val actionAlarm = "com.mindpulseai.mindpulse_ai.PRAYER_ALARM"

    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 31) {
            return true
        }
        return context.getSystemService(AlarmManager::class.java)
            .canScheduleExactAlarms()
    }

    fun scheduleAll(context: Context, scheduleJson: String): Int {
        cancelScheduledIntents(context, clearStoredSchedule = false)
        val array = JSONArray(scheduleJson)
        val normalizedArray = JSONArray()
        var count = 0

        for (index in 0 until array.length()) {
            val item = array.getJSONObject(index)
            normalizePrayerReminder(item)
            normalizedArray.put(item)

            if (
                item.getLong("triggerAtMillis") <=
                System.currentTimeMillis() + 20_000L
            ) {
                continue
            }

            scheduleItem(context, item)
            count += 1
        }

        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putString(scheduleKey, normalizedArray.toString())
            .putInt(scheduleVersionKey, currentScheduleVersion)
            .apply()

        return count
    }

    fun scheduleStored(context: Context): Int {
        val preferences = context.getSharedPreferences(
            preferencesName,
            Context.MODE_PRIVATE
        )

        if (
            preferences.getInt(scheduleVersionKey, 0) !=
            currentScheduleVersion
        ) {
            cancelScheduledIntents(
                context,
                clearStoredSchedule = true
            )
            return 0
        }

        val json = preferences.getString(scheduleKey, null)
            ?: return 0

        return scheduleAll(context, json)
    }

    private fun normalizePrayerReminder(item: JSONObject) {
        if (item.optString("eventType") != "prayer_reminder") {
            return
        }

        item.put(
            "message",
            "নামাজের সময় হয়ে যাচ্ছে। আপনারা নামাজের প্রস্তুতি নিন।"
        )
        item.put(
            "voiceBn",
            "নামাজের সময় হয়ে যাচ্ছে। আপনারা নামাজের প্রস্তুতি নিন।"
        )
        item.put(
            "voiceEn",
            "Prayer time is approaching. Please prepare for prayer."
        )
        item.put("durationSeconds", 15)
        item.put("voiceRepeat", 1)
    }

    fun cancelAll(context: Context) {
        cancelScheduledIntents(context, clearStoredSchedule = true)
    }

    private fun scheduleItem(context: Context, item: JSONObject) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val triggerAt = item.getLong("triggerAtMillis")
        val pendingIntent = alarmPendingIntent(context, item)

        if (Build.VERSION.SDK_INT < 31 || alarmManager.canScheduleExactAlarms()) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent
            )
        } else {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent
            )
        }
    }

    private fun cancelScheduledIntents(
        context: Context,
        clearStoredSchedule: Boolean
    ) {
        val preferences = context.getSharedPreferences(
            preferencesName,
            Context.MODE_PRIVATE
        )
        val json = preferences.getString(scheduleKey, null)

        if (!json.isNullOrBlank()) {
            val array = JSONArray(json)
            for (index in 0 until array.length()) {
                cancelItem(context, array.getJSONObject(index).getInt("id"))
            }
        }

        cancelItem(context, 999001)
        cancelItem(context, 999002)

        if (clearStoredSchedule) {
            preferences.edit()
                .remove(scheduleKey)
                .remove(scheduleVersionKey)
                .apply()
        }
    }

    private fun cancelItem(context: Context, id: Int) {
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = actionAlarm
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )

        if (pendingIntent != null) {
            context.getSystemService(AlarmManager::class.java).cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    private fun alarmPendingIntent(
        context: Context,
        item: JSONObject
    ): PendingIntent {
        val id = item.getInt("id")
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = actionAlarm
            putExtra("alarmId", id)
            putExtra("title", item.optString("title", "MindPulse alarm"))
            putExtra(
                "message",
                item.optString("message", "Your reminder is due now.")
            )
            putExtra("voiceBn", item.optString("voiceBn", ""))
            putExtra("voiceEn", item.optString("voiceEn", ""))
            putExtra("prayerBn", item.optString("prayerBn", ""))
            putExtra("prayerEn", item.optString("prayerEn", ""))
            putExtra("durationSeconds", item.optInt("durationSeconds", 15))
            putExtra("voiceRepeat", item.optInt("voiceRepeat", 1))
            putExtra(
                "eventType",
                item.optString("eventType", "prayer_reminder")
            )
        }

        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}

class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val serviceIntent = Intent(context, PrayerAlarmService::class.java).apply {
            action = PrayerAlarmService.actionStart
            putExtras(intent)
        }
        ContextCompat.startForegroundService(context, serviceIntent)
    }
}

class PrayerBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (
            intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            PrayerAlarmScheduler.scheduleStored(context)
        }
    }
}

class PrayerAlarmService : Service(), TextToSpeech.OnInitListener {
    companion object {
        const val actionStart = "com.mindpulseai.mindpulse_ai.PRAYER_START"
        const val actionStop = "com.mindpulseai.mindpulse_ai.PRAYER_STOP"
        private const val channelId = "mindpulse_prayer_alarm"
        private const val notificationId = 88001
        private const val completedNotificationId = 88004
    }

    private val handler = Handler(Looper.getMainLooper())
    private var mediaPlayer: MediaPlayer? = null
    private var textToSpeech: TextToSpeech? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var voiceBn = ""
    private var voiceEn = ""
    private var prayerBn = ""
    private var prayerEn = ""
    private var currentEventType = "prayer_reminder"
    private var voiceRepeat = 1
    private var useEnglishVoice = false
    private var soundCompleted = false
    private var ttsReady = false
    private var stopped = false
    private var alarmStarted = false
    private var currentTitle = "MindPulse reminder"
    private var currentMessage = "Your reminder is due now."

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == actionStop) {
            stopAlarm()
            return START_NOT_STICKY
        }

        if (intent?.action != actionStart) {
            stopSelf()
            return START_NOT_STICKY
        }

        stopPlaybackOnly()
        stopped = false
        soundCompleted = false
        ttsReady = false

        currentTitle =
            intent.getStringExtra("title") ?: "MindPulse alarm"
        currentMessage =
            intent.getStringExtra("message") ?: "Your reminder is due now."
        voiceBn = intent.getStringExtra("voiceBn") ?: ""
        voiceEn = intent.getStringExtra("voiceEn") ?: ""
        prayerBn = intent.getStringExtra("prayerBn") ?: ""
        prayerEn = intent.getStringExtra("prayerEn") ?: ""
        currentEventType =
            intent.getStringExtra("eventType") ?: "prayer_reminder"
        useEnglishVoice = false
        val durationSeconds = intent
            .getIntExtra("durationSeconds", 15)
            .coerceIn(1, 60)
        voiceRepeat = intent
            .getIntExtra("voiceRepeat", 1)
            .coerceIn(1, 3)

        getSystemService(NotificationManager::class.java)
            .cancel(completedNotificationId)

        alarmStarted = true

        startForeground(
            notificationId,
            buildNotification(currentTitle, currentMessage)
        )
        acquireWakeLock()
        startVibration(durationSeconds)
        startAlarmSound()
        textToSpeech = TextToSpeech(applicationContext, this)

        handler.postDelayed(
            {
                soundCompleted = true
                stopSoundAndVibration()
                speakWhenReady()
            },
            durationSeconds * 1000L
        )

        handler.postDelayed(
            {
                if (!stopped) {
                    stopAlarm()
                }
            },
            90_000L
        )

        return START_NOT_STICKY
    }

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS || stopped) {
            ttsReady = false
            if (soundCompleted) {
                stopAlarm()
            }
            return
        }

        val tts = textToSpeech ?: return
        val bengaliResult = tts.setLanguage(Locale("bn", "BD"))
        if (
            bengaliResult == TextToSpeech.LANG_MISSING_DATA ||
            bengaliResult == TextToSpeech.LANG_NOT_SUPPORTED
        ) {
            tts.setLanguage(Locale.ENGLISH)
            useEnglishVoice = true
        }

        tts.setSpeechRate(0.9f)
        tts.setPitch(1.0f)
        tts.setOnUtteranceProgressListener(
            object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) = Unit

                override fun onError(utteranceId: String?) {
                    handler.post { stopAlarm() }
                }

                override fun onDone(utteranceId: String?) {
                    if (utteranceId == "prayer_voice_final") {
                        handler.postDelayed({ stopAlarm() }, 400L)
                    }
                }
            }
        )
        ttsReady = true
        speakWhenReady()
    }

    private fun isManualReminder(): Boolean {
        return currentEventType.startsWith("manual_")
    }

    private fun buildBanglaVoice(): String {
        if (isManualReminder()) {
            return voiceBn.ifBlank {
                "আপনার রিমাইন্ডারের সময় হয়েছে।"
            }
        }

        return voiceBn.ifBlank {
            "নামাজের সময় হয়ে যাচ্ছে। আপনারা নামাজের প্রস্তুতি নিন।"
        }
    }

    private fun buildEnglishVoice(): String {
        if (isManualReminder()) {
            return voiceEn.ifBlank {
                "Your reminder is due."
            }
        }

        return voiceEn.ifBlank {
            "Prayer time is approaching. Please prepare for prayer."
        }
    }

    private fun speakWhenReady() {
        if (stopped || !soundCompleted || !ttsReady) {
            return
        }

        val tts = textToSpeech ?: return
        val text = if (useEnglishVoice) {
            buildEnglishVoice()
        } else {
            buildBanglaVoice()
        }

        for (index in 1..voiceRepeat) {
            val isLast = index == voiceRepeat

            tts.speak(
                text,
                if (index == 1) {
                    TextToSpeech.QUEUE_FLUSH
                } else {
                    TextToSpeech.QUEUE_ADD
                },
                null,
                if (isLast) {
                    "prayer_voice_final"
                } else {
                    "prayer_voice_$index"
                }
            )

            if (!isLast) {
                tts.playSilentUtterance(
                    650L,
                    TextToSpeech.QUEUE_ADD,
                    "prayer_pause_$index"
                )
            }
        }
    }

    private fun startAlarmSound() {
        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        try {
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(applicationContext, alarmUri)
                isLooping = true
                prepare()
                start()
            }
        } catch (_: Exception) {
            mediaPlayer = null
        }
    }

    private fun startVibration(durationSeconds: Int) {
        vibrator = if (Build.VERSION.SDK_INT >= 31) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        val pattern = longArrayOf(0L, 700L, 450L)
        if (Build.VERSION.SDK_INT >= 26) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }

        handler.postDelayed({ vibrator?.cancel() }, durationSeconds * 1000L)
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(PowerManager::class.java)
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "MindPulse:PrayerAlarm"
        ).apply {
            acquire(95_000L)
        }
    }

    private fun buildNotification(title: String, message: String): Notification {
        val stopIntent = Intent(this, PrayerAlarmService::class.java).apply {
            action = actionStop
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            88002,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val openPendingIntent = PendingIntent.getActivity(
            this,
            88003,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(openPendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Stop",
                stopPendingIntent
            )
            .build()
    }

    private fun buildCompletedNotification(
        title: String,
        message: String
    ): Notification {
        val openPendingIntent = PendingIntent.getActivity(
            this,
            88005,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE
        )

        val completedMessage =
            if (currentEventType == "prayer_reminder") {
                message
            } else {
                "$message Reminder was triggered."
            }

        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(completedMessage)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(completedMessage)
            )
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(false)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setContentIntent(openPendingIntent)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < 26) {
            return
        }

        val channel = NotificationChannel(
            channelId,
            "Prayer and personal reminders",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "MindPulse prayer and personal reminder sound and voice"
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun stopSoundAndVibration() {
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {
            // Already stopped.
        }
        mediaPlayer?.release()
        mediaPlayer = null
        vibrator?.cancel()
    }

    private fun stopPlaybackOnly() {
        handler.removeCallbacksAndMessages(null)
        stopSoundAndVibration()
    }

    private fun stopAlarm() {
        if (stopped) {
            return
        }

        val keepReminderNotification = alarmStarted
        alarmStarted = false
        stopped = true

        stopPlaybackOnly()
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null

        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }

        wakeLock = null

        stopForeground(STOP_FOREGROUND_REMOVE)

        if (keepReminderNotification) {
            getSystemService(NotificationManager::class.java)
                .notify(
                    completedNotificationId,
                    buildCompletedNotification(
                        currentTitle,
                        currentMessage
                    )
                )
        }

        stopSelf()
    }

    override fun onDestroy() {
        stopAlarm()
        super.onDestroy()
    }
}
