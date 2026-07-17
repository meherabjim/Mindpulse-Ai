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

dashboard_path = (
    ROOT
    / "lib"
    / "features"
    / "dashboard"
    / "screens"
    / "main_dashboard_screen.dart"
)


def patch_manifest() -> None:
    text = manifest_path.read_text(
        encoding="utf-8"
    )

    if "xmlns:tools=" not in text:
        text = text.replace(
            "<manifest ",
            (
                '<manifest '
                'xmlns:tools="http://schemas.android.com/tools" '
            ),
            1,
        )

    permission = (
        '    <uses-permission '
        'android:name="android.permission.PACKAGE_USAGE_STATS" '
        'tools:ignore="ProtectedPermissions" />'
    )

    if (
        "android.permission.PACKAGE_USAGE_STATS"
        not in text
    ):
        root_end = text.find(">")

        if root_end == -1:
            raise RuntimeError(
                "Manifest root element was not found."
            )

        text = (
            text[: root_end + 1]
            + "\n"
            + permission
            + text[root_end + 1 :]
        )

    manifest_path.write_text(
        text,
        encoding="utf-8",
    )


def patch_dashboard() -> None:
    text = dashboard_path.read_text(
        encoding="utf-8"
    )

    import_line = (
        "import '../../digital_wellbeing/screens/"
        "mindful_screen_time_screen.dart';"
    )

    if import_line not in text:
        class_position = text.find(
            "class MainDashboardScreen"
        )

        if class_position == -1:
            raise RuntimeError(
                "MainDashboardScreen class was not found."
            )

        text = (
            text[:class_position].rstrip()
            + "\n"
            + import_line
            + "\n\n"
            + text[class_position:]
        )

    if (
        "title: 'Mindful Screen Time'"
        not in text
    ):
        tools_start = text.find(
            "const List<_ToolData> tools = ["
        )

        if tools_start == -1:
            raise RuntimeError(
                "Dashboard tools list was not found."
            )

        tools_end = text.find(
            "    ];",
            tools_start,
        )

        if tools_end == -1:
            raise RuntimeError(
                "Dashboard tools-list ending was not found."
            )

        tool_item = """      _ToolData(
        icon: Icons.phone_android_rounded,
        title: 'Mindful Screen Time',
        subtitle: 'Use phone mindfully',
      ),
"""

        text = (
            text[:tools_end]
            + tool_item
            + text[tools_end:]
        )

    navigation_marker = (
        "              if "
        "(tool.title == 'Daily Check-in') {"
    )

    navigation_block = """              if (tool.title == 'Mindful Screen Time') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const MindfulScreenTimeScreen(),
                  ),
                );

                return;
              }

"""

    if (
        "const MindfulScreenTimeScreen()"
        not in text
    ):
        if navigation_marker not in text:
            raise RuntimeError(
                "Dashboard navigation marker was not found."
            )

        text = text.replace(
            navigation_marker,
            navigation_block
            + navigation_marker,
            1,
        )

    dashboard_path.write_text(
        text,
        encoding="utf-8",
    )


def main() -> None:
    patch_manifest()
    patch_dashboard()

    print(
        "Mindful Screen Time Phase 1 integrated."
    )

    print(
        "Android package:",
        "com.mindpulseai.mindpulse_ai",
    )


if __name__ == "__main__":
    main()
