from datetime import datetime
from pathlib import Path
import shutil


ROOT = Path(
    r"E:\project 3\MindPulse-AI"
)

files_and_replacements = {
    ROOT
    / "mobile_app"
    / "lib"
    / "features"
    / "wellness"
    / "screens"
    / "wellness_scan_screen.dart": [
        (
            "Wellness Risk Score",
            "Wellness Strain Indicator",
        ),
        (
            "${riskLevel.toUpperCase()} RISK",
            "${riskLevel.toUpperCase()} LEVEL",
        ),
    ],

    ROOT
    / "mobile_app"
    / "lib"
    / "features"
    / "ai"
    / "screens"
    / "ai_wellness_screen.dart": [
        (
            "Generate AI Wellness Plan",
            "Create Wellness Support Plan",
        ),
        (
            "AI wellness result",
            "Wellness support summary",
        ),
    ],

    ROOT
    / "mobile_app"
    / "lib"
    / "features"
    / "checkin"
    / "screens"
    / "daily_checkin_screen.dart": [
        (
            "Wellness risk",
            "Wellness strain",
        ),
    ],

    ROOT
    / "backend"
    / "src"
    / "services"
    / "reportPdf.service.js": [
        (
            "Average wellness-risk score",
            "Average wellness strain indicator",
        ),
        (
            "Latest risk level",
            "Latest wellness support level",
        ),
    ],

    ROOT
    / "backend"
    / "src"
    / "services"
    / "report.service.js": [
        (
            "The latest recorded wellness-risk "
            "level was",
            "The latest recorded wellness support "
            "level was",
        ),
    ],
}


for file_path in files_and_replacements:
    if not file_path.exists():
        raise RuntimeError(
            f"Required file was not found: "
            f"{file_path}"
        )


backup_dir = (
    ROOT
    / "backups"
    / (
        "wellness_wording_"
        + datetime.now().strftime(
            "%Y%m%d_%H%M%S"
        )
    )
)

backup_dir.mkdir(
    parents=True,
    exist_ok=True,
)

total_replacements = 0


for file_path, replacements in (
    files_and_replacements.items()
):
    relative_path = file_path.relative_to(
        ROOT
    )

    backup_path = (
        backup_dir
        / relative_path
    )

    backup_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    shutil.copy2(
        file_path,
        backup_path,
    )

    text = file_path.read_text(
        encoding="utf-8",
    )

    file_count = 0

    for old_text, new_text in replacements:
        count = text.count(old_text)

        if count > 0:
            text = text.replace(
                old_text,
                new_text,
            )

            file_count += count

    file_path.write_text(
        text,
        encoding="utf-8",
    )

    total_replacements += file_count

    print(
        f"Updated: {relative_path}"
    )

    print(
        f"Replacements: {file_count}"
    )


if total_replacements == 0:
    raise RuntimeError(
        "No matching wording was found. "
        "No effective change was made."
    )


print("")
print(
    "Research-based wellness wording "
    "update completed successfully."
)

print(
    f"Total replacements: "
    f"{total_replacements}"
)

print(
    f"Backup created: {backup_dir}"
)

print("")
print(
    "API response fields and database "
    "columns were not changed."
)
