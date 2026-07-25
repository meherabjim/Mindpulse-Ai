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
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

object PrayerAlarmScheduler {
    private const val preferencesName = "mindpulse_prayer_alarm"
    private const val scheduleKey = "scheduled_prayer_alarms"
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
        var count = 0

        for (index in 0 until array.length()) {
            val item = array.getJSONObject(index)
            if (item.getLong("triggerAtMillis") <= System.currentTimeMillis() + 20_000L) {
                continue
            }
            scheduleItem(context, item)
            count += 1
        }

        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putString(scheduleKey, scheduleJson)
            .apply()

        return count
    }

    fun scheduleStored(context: Context): Int {
        val json = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .getString(scheduleKey, null)
            ?: return 0
        return scheduleAll(context, json)
    }

    fun cancelAll(context: Context) {
        cancelScheduledIntents(context, clearStoredSchedule = true)
    }

    fun scheduleTest(context: Context, fajr: Boolean) {
        val item = JSONObject().apply {
            put("id", if (fajr) 999002 else 999001)
            put("triggerAtMillis", System.currentTimeMillis() + 15_000L)
            put("title", if (fajr) "Fajr prayer reminder" else "Dhuhr prayer reminder")
            put(
                "message",
                if (fajr) {
                    "30-second alarm, then the current-time voice twice."
                } else {
                    "15-second alarm, then the current-time Dhuhr voice."
                }
            )
            put(
                "voiceBn",
                if (fajr) {
                    "ফজরের নামাজের জন্য প্রস্তুতি নিন।"
                } else {
                    "যোহরের নামাজের জন্য প্রস্তুতি নিন।"
                }
            )
            put(
                "voiceEn",
                if (fajr) {
                    "Please prepare for Fajr prayer."
                } else {
                    "Please prepare for Dhuhr prayer."
                }
            )
            put("prayerBn", if (fajr) "ফজরের" else "যোহরের")
            put("prayerEn", if (fajr) "Fajr" else "Dhuhr")
            put("durationSeconds", if (fajr) 30 else 15)
            put("voiceRepeat", if (fajr) 2 else 1)
        }

        scheduleItem(context, item)
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
            preferences.edit().remove(scheduleKey).apply()
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
            putExtra("title", item.optString("title", "Prayer alarm"))
            putExtra("message", item.optString("message", "Prayer reminder"))
            putExtra("voiceBn", item.optString("voiceBn", ""))
            putExtra("voiceEn", item.optString("voiceEn", ""))
            putExtra("prayerBn", item.optString("prayerBn", ""))
            putExtra("prayerEn", item.optString("prayerEn", ""))
            putExtra("durationSeconds", item.optInt("durationSeconds", 15))
            putExtra("voiceRepeat", item.optInt("voiceRepeat", 1))
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
    private var voiceRepeat = 1
    private var useEnglishVoice = false
    private var soundCompleted = false
    private var ttsReady = false
    private var stopped = false
    private var alarmStarted = false
    private var currentTitle = "Prayer reminder"
    private var currentMessage = "Prayer reminder was triggered."

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
            intent.getStringExtra("title") ?: "Prayer alarm"
        currentMessage =
            intent.getStringExtra("message") ?: "Prayer reminder"
        voiceBn = intent.getStringExtra("voiceBn") ?: ""
        voiceEn = intent.getStringExtra("voiceEn") ?: ""
        prayerBn = intent.getStringExtra("prayerBn") ?: ""
        prayerEn = intent.getStringExtra("prayerEn") ?: ""
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

    private fun toBanglaDigits(value: Int): String {
        val digits = charArrayOf(
            '০', '১', '২', '৩', '৪',
            '৫', '৬', '৭', '৮', '৯'
        )

        return value.toString().map { digit ->
            if (digit.isDigit()) {
                digits[digit.digitToInt()]
            } else {
                digit
            }
        }.joinToString("")
    }

    private fun currentBanglaTimeText(): String {
        val calendar = Calendar.getInstance()
        val hour24 = calendar.get(Calendar.HOUR_OF_DAY)
        val hour12 = when (val value = hour24 % 12) {
            0 -> 12
            else -> value
        }
        val minute = calendar.get(Calendar.MINUTE)

        return if (minute == 0) {
            "${toBanglaDigits(hour12)}টা"
        } else {
            "${toBanglaDigits(hour12)}টা " +
                "${toBanglaDigits(minute)} মিনিট"
        }
    }

    private fun currentEnglishTimeText(): String {
        return SimpleDateFormat(
            "h:mm a",
            Locale.ENGLISH
        ).format(Date())
    }

    private fun buildBanglaVoice(): String {
        if (prayerBn.isBlank()) {
            return voiceBn.ifBlank {
                voiceEn.ifBlank {
                    "নামাজের জন্য প্রস্তুতি নিন।"
                }
            }
        }

        return "এখন ${currentBanglaTimeText()} বাজে। " +
            "আপনি $prayerBn নামাজের জন্য প্রস্তুতি নিন। " +
            "তারপর নামাজ পড়তে যান। নামাজেই আসল সুখ।"
    }

    private fun buildEnglishVoice(): String {
        if (prayerEn.isBlank()) {
            return voiceEn.ifBlank {
                "Please prepare for prayer."
            }
        }

        return "It is now ${currentEnglishTimeText()}. " +
            "Please prepare for $prayerEn prayer, " +
            "then go and pray."
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
            "$message Prayer reminder was triggered."

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
            "Prayer alarms",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "MindPulse prayer alarm sound and voice"
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
