from pathlib import Path


ROOT = Path(
    r"E:\project 3\MindPulse-AI\mobile_app"
)

manifest_path = (
    ROOT
    / "android"
    / "app"
    / "src"
    / "main"
    / "AndroidManifest.xml"
)

screen_path = (
    ROOT
    / "lib"
    / "features"
    / "digital_wellbeing"
    / "screens"
    / "mindful_screen_time_screen.dart"
)

gradle_kts = (
    ROOT
    / "android"
    / "app"
    / "build.gradle.kts"
)

gradle_groovy = (
    ROOT
    / "android"
    / "app"
    / "build.gradle"
)


def patch_manifest() -> None:
    text = manifest_path.read_text(
        encoding="utf-8"
    )

    permission = (
        '    <uses-permission '
        'android:name="android.permission.'
        'POST_NOTIFICATIONS" />'
    )

    if (
        "android.permission.POST_NOTIFICATIONS"
        not in text
    ):
        manifest_end = text.find(">")

        if manifest_end == -1:
            raise RuntimeError(
                "Manifest root was not found."
            )

        text = (
            text[: manifest_end + 1]
            + "\n"
            + permission
            + text[manifest_end + 1 :]
        )

    manifest_path.write_text(
        text,
        encoding="utf-8",
    )


def patch_gradle() -> None:
    dependency = (
        "androidx.work:"
        "work-runtime-ktx:2.10.5"
    )

    if gradle_kts.exists():
        text = gradle_kts.read_text(
            encoding="utf-8"
        )

        if dependency not in text:
            text += (
                "\n\ndependencies {\n"
                '    implementation("'
                + dependency
                + '")\n'
                "}\n"
            )

        gradle_kts.write_text(
            text,
            encoding="utf-8",
        )

        return

    if gradle_groovy.exists():
        text = gradle_groovy.read_text(
            encoding="utf-8"
        )

        if dependency not in text:
            text += (
                "\n\ndependencies {\n"
                '    implementation "'
                + dependency
                + '"\n'
                "}\n"
            )

        gradle_groovy.write_text(
            text,
            encoding="utf-8",
        )

        return

    raise RuntimeError(
        "Android app Gradle file was not found."
    )


def patch_screen() -> None:
    text = screen_path.read_text(
        encoding="utf-8"
    )

    import_line = (
        "import '../widgets/"
        "background_reminder_card.dart';"
    )

    if import_line not in text:
        service_import = (
            "import '../services/"
            "screen_time_service.dart';"
        )

        if service_import not in text:
            raise RuntimeError(
                "Screen-time service import "
                "was not found."
            )

        text = text.replace(
            service_import,
            service_import
            + "\n"
            + import_line,
            1,
        )

    widget_marker = (
        "BackgroundReminderCard("
    )

    if widget_marker not in text:
        privacy_marker = (
            "                    "
            "_buildPrivacyCard(),"
        )

        widget_block = """                    BackgroundReminderCard(
                      key: ValueKey<String>(
                        '$_dailySocialLimitMinutes-'
                        '$_sessionLimitMinutes',
                      ),
                      dailySocialLimitMinutes:
                          _dailySocialLimitMinutes,
                      sessionLimitMinutes:
                          _sessionLimitMinutes,
                    ),

                    const SizedBox(
                      height: 14,
                    ),

"""

        if privacy_marker not in text:
            raise RuntimeError(
                "Privacy-card insertion point "
                "was not found."
            )

        text = text.replace(
            privacy_marker,
            widget_block
            + privacy_marker,
            1,
        )

    screen_path.write_text(
        text,
        encoding="utf-8",
    )


def main() -> None:
    patch_manifest()
    patch_gradle()
    patch_screen()

    print(
        "Background reminder Phase 2 integrated."
    )


if __name__ == "__main__":
    main()
