from datetime import datetime
from pathlib import Path
import shutil


ROOT = Path(
    r"E:\project 3\MindPulse-AI"
)

SERVICE = (
    ROOT
    / "mobile_app"
    / "lib"
    / "features"
    / "recommendations"
    / "services"
    / "recommendation_session_service.dart"
)

FOLLOWUP = (
    ROOT
    / "mobile_app"
    / "lib"
    / "features"
    / "recommendations"
    / "screens"
    / "recommendation_followup_screen.dart"
)

HISTORY = (
    ROOT
    / "mobile_app"
    / "lib"
    / "features"
    / "recommendations"
    / "screens"
    / "recommendation_history_screen.dart"
)


for path in (
    SERVICE,
    FOLLOWUP,
    HISTORY,
):
    if not path.exists():
        raise RuntimeError(
            f"Required file was not found: {path}"
        )


service_text = SERVICE.read_text(
    encoding="utf-8",
)

if (
    "getSummary({" not in service_text
    or "getHistory({" not in service_text
):
    raise RuntimeError(
        "History API methods are missing "
        "from recommendation service."
    )


history_text = HISTORY.read_text(
    encoding="utf-8",
)

if (
    "class RecommendationHistoryScreen"
    not in history_text
):
    raise RuntimeError(
        "Recommendation history screen "
        "is incomplete."
    )


backup_dir = (
    ROOT
    / "backups"
    / (
        "history_navigation_repair_"
        + datetime.now().strftime(
            "%Y%m%d_%H%M%S"
        )
    )
)

backup_path = (
    backup_dir
    / FOLLOWUP.relative_to(ROOT)
)

backup_path.parent.mkdir(
    parents=True,
    exist_ok=True,
)

shutil.copy2(
    FOLLOWUP,
    backup_path,
)


text = FOLLOWUP.read_text(
    encoding="utf-8",
)


history_import = (
    "import "
    "'recommendation_history_screen.dart';"
)

service_import = (
    "import '../services/"
    "recommendation_session_service.dart';"
)

if history_import not in text:
    if service_import not in text:
        raise RuntimeError(
            "Service import marker "
            "was not found."
        )

    text = text.replace(
        service_import,
        service_import
        + "\n"
        + history_import,
        1,
    )


def find_closing_parenthesis(
    source: str,
    opening_index: int,
) -> int:
    depth = 0
    quote = None
    escaped = False

    for index in range(
        opening_index,
        len(source),
    ):
        character = source[index]

        if quote is not None:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = None

            continue

        if character in (
            "'",
            '"',
        ):
            quote = character
            continue

        if character == "(":
            depth += 1

        elif character == ")":
            depth -= 1

            if depth == 0:
                return index

    return -1


if (
    "tooltip: 'Follow-up history'"
    not in text
):
    marker = "appBar: AppBar("

    search_from = 0
    appbar_start = -1
    opening_index = -1
    closing_index = -1

    while True:
        candidate = text.find(
            marker,
            search_from,
        )

        if candidate == -1:
            break

        candidate_open = (
            candidate
            + len(marker)
            - 1
        )

        candidate_close = (
            find_closing_parenthesis(
                text,
                candidate_open,
            )
        )

        if candidate_close == -1:
            raise RuntimeError(
                "AppBar closing parenthesis "
                "was not found."
            )

        body = text[
            candidate_open + 1:
            candidate_close
        ]

        if (
            "'Action Follow-up'"
            in body
        ):
            appbar_start = candidate
            opening_index = candidate_open
            closing_index = candidate_close
            break

        search_from = (
            candidate_close + 1
        )

    if appbar_start == -1:
        raise RuntimeError(
            "Action Follow-up AppBar "
            "was not found."
        )

    body = text[
        opening_index + 1:
        closing_index
    ].rstrip()

    if (
        body
        and not body.endswith(",")
    ):
        body += ","

    actions = r'''
        actions: [
          IconButton(
            tooltip: 'Follow-up history',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const RecommendationHistoryScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.history_rounded,
            ),
          ),
        ],
      '''

    repaired_body = (
        body
        + "\n"
        + actions
    )

    text = (
        text[:opening_index + 1]
        + repaired_body
        + text[closing_index:]
    )


FOLLOWUP.write_text(
    text,
    encoding="utf-8",
)


print(
    "History navigation repair "
    "completed successfully."
)

print(
    "Verified: history API methods"
)

print(
    "Verified: history screen"
)

print(
    f"Updated: {FOLLOWUP}"
)

print(
    f"Backup created: {backup_dir}"
)
