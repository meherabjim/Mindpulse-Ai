from pathlib import Path
import re


ROOT = Path(
    r"E:\project 3\MindPulse-AI\mobile_app"
)

kotlin_root = (
    ROOT
    / "android"
    / "app"
    / "src"
    / "main"
    / "kotlin"
)

main_activity = next(
    kotlin_root.rglob(
        "MainActivity.kt"
    )
)

worker_path = (
    main_activity.parent
    / "SmartReminderWorker.kt"
)

plugin_path = (
    main_activity.parent
    / "SmartReminderPlugin.kt"
)

manifest_path = (
    ROOT
    / "android"
    / "app"
    / "src"
    / "main"
    / "AndroidManifest.xml"
)


def patch_worker() -> None:
    text = worker_path.read_text(
        encoding="utf-8"
    )

    if (
        '"skip_today_$reminderId"'
        not in text
    ):
        pattern = re.compile(
            r"(if\s*\(\s*"
            r"reminderId\.isBlank\(\)"
            r"\s*\)\s*\{\s*"
            r"continue\s*"
            r"\})",
            re.DOTALL,
        )

        skip_block = r'''

            val skippedDate =
                preferences.getString(
                    "skip_today_$reminderId",
                    null
                )

            if (skippedDate == today) {
                continue
            }
'''

        text, count = pattern.subn(
            r"\1" + skip_block,
            text,
            count=1,
        )

        if count != 1:
            raise RuntimeError(
                "Reminder ID validation "
                "block was not found."
            )

    if (
        "vibrationEnabled &&"
        in text
        and
        "vibrationEnabled &&\n"
        in text
    ):
        pattern = re.compile(
            r"SmartReminderNotificationHelper"
            r"\s*\.show\(\s*"
            r"applicationContext\s*,\s*"
            r"reminderId\s*,\s*"
            r"title\s*,\s*"
            r"message\s*,\s*"
            r"vibrationEnabled\s*&&\s*"
            r"!quietHours\s*,?\s*"
            r"\)",
            re.DOTALL,
        )

        replacement = r'''SmartReminderNotificationHelper
                    .show(
                        applicationContext,
                        reminderId,
                        title,
                        message,
                        vibrationEnabled &&
                            !quietHours,
                        voiceEnabled
                    )'''

        text, count = pattern.subn(
            replacement,
            text,
            count=1,
        )

        if count != 1:
            raise RuntimeError(
                "Worker notification call "
                "was not found."
            )

    worker_path.write_text(
        text,
        encoding="utf-8",
    )


def patch_plugin() -> None:
    if not plugin_path.exists():
        return

    text = plugin_path.read_text(
        encoding="utf-8"
    )

    pattern = re.compile(
        r"SmartReminderNotificationHelper"
        r"\s*\.show\(\s*"
        r"activity\s*,\s*"
        r"reminderId\s*,\s*"
        r"title\s*,\s*"
        r"message\s*,\s*"
        r"vibration\s*,?\s*"
        r"\)",
        re.DOTALL,
    )

    replacement = r'''SmartReminderNotificationHelper
                            .show(
                                activity,
                                reminderId,
                                title,
                                message,
                                vibration,
                                voice
                            )'''

    patched, count = pattern.subn(
        replacement,
        text,
        count=1,
    )

    if count == 1:
        plugin_path.write_text(
            patched,
            encoding="utf-8",
        )


def patch_manifest() -> None:
    text = manifest_path.read_text(
        encoding="utf-8"
    )

    receiver_name = (
        ".SmartReminderActionReceiver"
    )

    if receiver_name not in text:
        receiver = r'''
        <receiver
            android:name=".SmartReminderActionReceiver"
            android:enabled="true"
            android:exported="false" />
'''

        marker = "</application>"

        if marker not in text:
            raise RuntimeError(
                "Application closing tag "
                "was not found."
            )

        text = text.replace(
            marker,
            receiver + "\n    " + marker,
            1,
        )

    manifest_path.write_text(
        text,
        encoding="utf-8",
    )


def main() -> None:
    patch_worker()
    patch_plugin()
    patch_manifest()

    print(
        "Reminder actions integrated successfully."
    )


if __name__ == "__main__":
    main()
