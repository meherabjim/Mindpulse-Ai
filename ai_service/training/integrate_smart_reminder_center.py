import re
from pathlib import Path


ROOT = Path(
    r"E:\project 3\MindPulse-AI"
)

FLUTTER_ROOT = (
    ROOT
    / "mobile_app"
)

main_activity = next(
    (
        FLUTTER_ROOT
        / "android"
        / "app"
        / "src"
        / "main"
        / "kotlin"
    ).rglob(
        "MainActivity.kt"
    )
)

dashboard_path = (
    FLUTTER_ROOT
    / "lib"
    / "features"
    / "dashboard"
    / "screens"
    / "main_dashboard_screen.dart"
)

manifest_path = (
    FLUTTER_ROOT
    / "android"
    / "app"
    / "src"
    / "main"
    / "AndroidManifest.xml"
)

gradle_kts = (
    FLUTTER_ROOT
    / "android"
    / "app"
    / "build.gradle.kts"
)

gradle_groovy = (
    FLUTTER_ROOT
    / "android"
    / "app"
    / "build.gradle"
)


def patch_main_activity() -> None:
    text = main_activity.read_text(
        encoding="utf-8"
    )

    call = (
        "SmartReminderPlugin"
        ".register(this, flutterEngine)"
    )

    if call in text:
        return

    pattern = re.compile(
        r"super\.configureFlutterEngine"
        r"\(\s*flutterEngine\s*\)"
    )

    match = pattern.search(text)

    if match is None:
        raise RuntimeError(
            "configureFlutterEngine super call "
            "was not found."
        )

    replacement = (
        match.group(0)
        + "\n\n        "
        + call
    )

    text = (
        text[:match.start()]
        + replacement
        + text[match.end():]
    )

    main_activity.write_text(
        text,
        encoding="utf-8",
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
        root_end = text.find(">")

        if root_end == -1:
            raise RuntimeError(
                "Manifest root was not found."
            )

        text = (
            text[:root_end + 1]
            + "\n"
            + permission
            + text[root_end + 1:]
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
        "Android Gradle file was not found."
    )


def patch_dashboard() -> None:
    text = dashboard_path.read_text(
        encoding="utf-8"
    )

    import_line = (
        "import '../../reminders/screens/"
        "smart_reminder_center_screen.dart';"
    )

    if import_line not in text:
        class_position = text.find(
            "class MainDashboardScreen"
        )

        if class_position == -1:
            raise RuntimeError(
                "Dashboard class was not found."
            )

        text = (
            text[:class_position].rstrip()
            + "\n"
            + import_line
            + "\n\n"
            + text[class_position:]
        )

    if (
        "title: 'Smart Reminders'"
        not in text
    ):
        tools_start = text.find(
            "const List<_ToolData> tools = ["
        )

        if tools_start == -1:
            raise RuntimeError(
                "Dashboard tools list "
                "was not found."
            )

        tools_end = text.find(
            "    ];",
            tools_start,
        )

        if tools_end == -1:
            raise RuntimeError(
                "Dashboard tools-list ending "
                "was not found."
            )

        tool_item = """      _ToolData(
        icon: Icons.notifications_active_outlined,
        title: 'Smart Reminders',
        subtitle: 'Gentle wellness reminders',
      ),
"""

        text = (
            text[:tools_end]
            + tool_item
            + text[tools_end:]
        )

    if (
        "const SmartReminderCenterScreen()"
        not in text
    ):
        possible_markers = [
            (
                "              if "
                "(tool.title == 'Mindful Screen Time') {"
            ),
            (
                "              if "
                "(tool.title == 'Daily Check-in') {"
            ),
        ]

        marker = next(
            (
                item
                for item in possible_markers
                if item in text
            ),
            None,
        )

        if marker is None:
            raise RuntimeError(
                "Dashboard navigation marker "
                "was not found."
            )

        navigation = """              if (tool.title == 'Smart Reminders') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const SmartReminderCenterScreen(),
                  ),
                );

                return;
              }

"""

        text = text.replace(
            marker,
            navigation + marker,
            1,
        )

    dashboard_path.write_text(
        text,
        encoding="utf-8",
    )


def main() -> None:
    patch_main_activity()
    patch_manifest()
    patch_gradle()
    patch_dashboard()

    print(
        "Smart Reminder Center integrated successfully."
    )


if __name__ == "__main__":
    main()
