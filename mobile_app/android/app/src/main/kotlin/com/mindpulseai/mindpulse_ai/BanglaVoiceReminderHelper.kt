package com.mindpulseai.mindpulse_ai

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

object BanglaVoiceReminderHelper {
    fun speak(
        context: Context,
        message: String
    ): Boolean {
        if (message.isBlank()) {
            return false
        }

        val completed =
            CountDownLatch(1)

        val succeeded =
            AtomicBoolean(false)

        lateinit var engine:
            TextToSpeech

        engine =
            TextToSpeech(
                context.applicationContext
            ) {
                status ->

                if (
                    status !=
                    TextToSpeech.SUCCESS
                ) {
                    completed.countDown()
                    return@TextToSpeech
                }

                var languageResult =
                    engine.setLanguage(
                        Locale(
                            "bn",
                            "BD"
                        )
                    )

                if (
                    languageResult ==
                        TextToSpeech
                            .LANG_MISSING_DATA ||
                    languageResult ==
                        TextToSpeech
                            .LANG_NOT_SUPPORTED
                ) {
                    languageResult =
                        engine.setLanguage(
                            Locale("bn")
                        )
                }

                if (
                    languageResult ==
                        TextToSpeech
                            .LANG_MISSING_DATA ||
                    languageResult ==
                        TextToSpeech
                            .LANG_NOT_SUPPORTED
                ) {
                    completed.countDown()
                    return@TextToSpeech
                }

                engine.setSpeechRate(
                    0.90f
                )

                engine.setPitch(
                    1.0f
                )

                val utteranceId =
                    UUID.randomUUID()
                        .toString()

                engine.setOnUtteranceProgressListener(
                    object :
                        UtteranceProgressListener() {
                        override fun onStart(
                            utteranceId: String?
                        ) {
                            // Speech started.
                        }

                        override fun onDone(
                            utteranceId: String?
                        ) {
                            succeeded.set(true)
                            completed.countDown()
                        }

                        @Deprecated(
                            "Deprecated by Android"
                        )
                        override fun onError(
                            utteranceId: String?
                        ) {
                            completed.countDown()
                        }

                        override fun onError(
                            utteranceId: String?,
                            errorCode: Int
                        ) {
                            completed.countDown()
                        }
                    }
                )

                val result =
                    engine.speak(
                        message,
                        TextToSpeech
                            .QUEUE_FLUSH,
                        null,
                        utteranceId
                    )

                if (
                    result ==
                    TextToSpeech.ERROR
                ) {
                    completed.countDown()
                }
            }

        try {
            completed.await(
                20,
                TimeUnit.SECONDS
            )
        } catch (
            error: InterruptedException
        ) {
            Thread.currentThread()
                .interrupt()
        } finally {
            engine.stop()
            engine.shutdown()
        }

        return succeeded.get()
    }
}
