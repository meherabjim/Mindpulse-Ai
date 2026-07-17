from pathlib import Path


PROJECT = Path(
    r"E:\project 3\MindPulse-AI"
)

flutter_root = (
    PROJECT
    / "mobile_app"
)

main_activity = next(
    (
        flutter_root
        / "android"
        / "app"
        / "src"
        / "main"
        / "kotlin"
    ).rglob("MainActivity.kt")
)

worker_path = (
    main_activity.parent
    / "ScreenTimeWorker.kt"
)

service_path = (
    flutter_root
    / "lib"
    / "features"
    / "digital_wellbeing"
    / "services"
    / "screen_time_service.dart"
)

screen_path = (
    flutter_root
    / "lib"
    / "features"
    / "digital_wellbeing"
    / "screens"
    / "mindful_screen_time_screen.dart"
)


def patch_worker() -> None:
    text = worker_path.read_text(
        encoding="utf-8"
    )

    voice_block = r'''
        val voiceEnabled =
            preferences.getBoolean(
                KEY_VOICE_ENABLED,
                false
            )

        if (voiceEnabled) {
            val banglaMessage =
                when {
                    socialMinutes >=
                        dailyLimit -> {
                        "আপনি আজ সামাজিক যোগাযোগমাধ্যমে " +
                            "প্রায় $socialMinutes মিনিট " +
                            "সময় কাটিয়েছেন। এখন ফোনটি " +
                            "কিছুক্ষণ রেখে দশ মিনিট " +
                            "বিশ্রাম নিন।"
                    }

                    longestMinutes >=
                        sessionLimit -> {
                        "আপনি একটানা প্রায় " +
                            "$longestMinutes মিনিট " +
                            "ফোন ব্যবহার করেছেন। " +
                            "চোখ ও মনকে বিশ্রাম দিতে " +
                            "এখন কিছুক্ষণ ফোনটি রাখুন।"
                    }

                    else -> null
                }

            if (banglaMessage != null) {
                BanglaVoiceReminderHelper
                    .speak(
                        applicationContext,
                        banglaMessage
                    )
            }
        }

'''

    voice_marker = (
        "val voiceEnabled ="
    )

    notification_marker = r'''        ScreenTimeNotificationHelper
            .showNotification(
                applicationContext,
                "Time for a mindful break",
                reminderMessage
            )

        preferences.edit()
'''

    if voice_marker not in text:
        if notification_marker not in text:
            raise RuntimeError(
                "Worker notification marker "
                "was not found."
            )

        text = text.replace(
            notification_marker,
            notification_marker.replace(
                "\n        preferences.edit()\n",
                "\n"
                + voice_block
                + "        preferences.edit()\n",
            ),
            1,
        )

    key_marker = r'''        const val KEY_COOLDOWN_MINUTES =
            "reminder_cooldown_minutes"
'''

    key_block = r'''
        const val KEY_VOICE_ENABLED =
            "bangla_voice_enabled"
'''

    if (
        "KEY_VOICE_ENABLED" not in
        text.split(
            "companion object",
            1,
        )[-1]
    ):
        if key_marker not in text:
            raise RuntimeError(
                "Worker preference marker "
                "was not found."
            )

        text = text.replace(
            key_marker,
            key_marker + key_block,
            1,
        )

    worker_path.write_text(
        text,
        encoding="utf-8",
    )


def patch_main_activity() -> None:
    text = main_activity.read_text(
        encoding="utf-8"
    )

    cases = r'''
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

'''

    if (
        '"isBanglaVoiceReminderEnabled"'
        not in text
    ):
        marker = r'''                "getBackgroundReminderStatus" -> {
'''

        if marker not in text:
            raise RuntimeError(
                "MainActivity insertion "
                "marker was not found."
            )

        text = text.replace(
            marker,
            cases + marker,
            1,
        )

    main_activity.write_text(
        text,
        encoding="utf-8",
    )


def patch_service() -> None:
    text = service_path.read_text(
        encoding="utf-8"
    )

    methods = r'''
  Future<bool>
  isBanglaVoiceReminderEnabled() async {
    _requireAndroid();

    return await _channel.invokeMethod<bool>(
          'isBanglaVoiceReminderEnabled',
        ) ??
        false;
  }

  Future<void>
  setBanglaVoiceReminderEnabled(
    bool enabled,
  ) async {
    _requireAndroid();

    await _channel.invokeMethod<void>(
      'setBanglaVoiceReminderEnabled',
      <String, dynamic>{
        'enabled': enabled,
      },
    );
  }

  Future<bool>
  testBanglaVoiceReminder() async {
    _requireAndroid();

    return await _channel.invokeMethod<bool>(
          'testBanglaVoiceReminder',
        ) ??
        false;
  }

'''

    if (
        "isBanglaVoiceReminderEnabled"
        not in text
    ):
        marker = (
            "  void _requireAndroid() {"
        )

        if marker not in text:
            raise RuntimeError(
                "Flutter service insertion "
                "marker was not found."
            )

        text = text.replace(
            marker,
            methods + marker,
            1,
        )

    service_path.write_text(
        text,
        encoding="utf-8",
    )


def patch_screen() -> None:
    text = screen_path.read_text(
        encoding="utf-8"
    )

    import_line = (
        "import '../widgets/"
        "bangla_voice_reminder_card.dart';"
    )

    if import_line not in text:
        service_import = (
            "import '../services/"
            "screen_time_service.dart';"
        )

        if service_import not in text:
            raise RuntimeError(
                "Screen service import "
                "was not found."
            )

        text = text.replace(
            service_import,
            service_import
            + "\n"
            + import_line,
            1,
        )

    if (
        "const BanglaVoiceReminderCard()"
        not in text
    ):
        marker = (
            "                    "
            "_buildPrivacyCard(),"
        )

        block = """                    const BanglaVoiceReminderCard(),

                    const SizedBox(
                      height: 14,
                    ),

"""

        if marker not in text:
            raise RuntimeError(
                "Screen insertion marker "
                "was not found."
            )

        text = text.replace(
            marker,
            block + marker,
            1,
        )

    screen_path.write_text(
        text,
        encoding="utf-8",
    )


def main() -> None:
    patch_worker()
    patch_main_activity()
    patch_service()
    patch_screen()

    print(
        "Bangla Voice Reminder integrated successfully."
    )


if __name__ == "__main__":
    main()
