from __future__ import annotations

import hashlib
from datetime import datetime, timezone

from app.models.schemas import (
    ReadingDifficultyAssessment,
    ReadingPlanRequest,
    ReadingPlanResponse,
    ReadingPlanSession,
    ReadingPlanSource,
)


DAY_ORDER = [
    "mon",
    "tue",
    "wed",
    "thu",
    "fri",
    "sat",
    "sun",
]

DAY_LABELS = {
    "en": {
        "mon": "Monday",
        "tue": "Tuesday",
        "wed": "Wednesday",
        "thu": "Thursday",
        "fri": "Friday",
        "sat": "Saturday",
        "sun": "Sunday",
    },
    "bn": {
        "mon": "সোমবার",
        "tue": "মঙ্গলবার",
        "wed": "বুধবার",
        "thu": "বৃহস্পতিবার",
        "fri": "শুক্রবার",
        "sat": "শনিবার",
        "sun": "রবিবার",
    },
}


CONTENT_FOCUS = {
    "textbook": (
        "Read one syllabus section, mark key concepts, and solve one check question.",
        "একটি সিলেবাস অংশ পড়ুন, মূল ধারণা চিহ্নিত করুন এবং একটি যাচাই প্রশ্ন সমাধান করুন।",
    ),
    "supplementary": (
        "Use this item to clarify one difficult topic from your main subject.",
        "মূল বিষয়ের একটি কঠিন অংশ পরিষ্কার করতে এই সহায়ক বই ব্যবহার করুন।",
    ),
    "book": (
        "Read a focused section and write three takeaways.",
        "একটি নির্দিষ্ট অংশ পড়ুন এবং তিনটি মূল বিষয় লিখুন।",
    ),
    "novel": (
        "Read one manageable section and note character or theme changes.",
        "একটি সুবিধাজনক অংশ পড়ুন এবং চরিত্র বা ভাবের পরিবর্তন লিখুন।",
    ),
    "magazine": (
        "Read one feature or article and note the main claim and evidence.",
        "একটি ফিচার বা প্রবন্ধ পড়ুন এবং মূল বক্তব্য ও প্রমাণ লিখুন।",
    ),
    "article": (
        "Read the introduction and conclusion first, then capture the central argument.",
        "আগে ভূমিকা ও উপসংহার পড়ুন, তারপর কেন্দ্রীয় যুক্তিটি লিখুন।",
    ),
    "research_paper": (
        "Review the abstract, method, findings, and one limitation.",
        "সারসংক্ষেপ, পদ্ধতি, ফলাফল এবং একটি সীমাবদ্ধতা পর্যালোচনা করুন।",
    ),
    "own_material": (
        "Study one topic from your material and create a short recall check.",
        "নিজের পাঠ্য থেকে একটি বিষয় পড়ুন এবং ছোট একটি স্মরণ-পরীক্ষা তৈরি করুন।",
    ),
}


def _language(request: ReadingPlanRequest) -> str:
    return "bn" if request.profile.preferred_language in {"bn", "both"} else "en"


def _text(language: str, english: str, bangla: str) -> str:
    return bangla if language == "bn" else english


def _difficulty_assessment(
    request: ReadingPlanRequest,
    item_index: int,
) -> ReadingDifficultyAssessment:
    item = request.items[item_index]
    language = _language(request)

    if item.user_difficulty != "unknown":
        return ReadingDifficultyAssessment(
            item_id=item.id,
            label=item.user_difficulty,
            confidence=0.95,
            basis=["user_feedback"],
            note=_text(
                language,
                "This difficulty comes from your own feedback, not from Google or a publisher rating.",
                "এই কঠিনতা আপনার নিজের মতামত থেকে এসেছে; Google বা প্রকাশকের rating থেকে নয়।",
            ),
        )

    metadata_basis: list[str] = []

    if item.source == "google_books":
        metadata_basis.append("google_books_catalogue_metadata")
    elif item.source == "crossref":
        metadata_basis.append("crossref_scholarly_metadata")
    elif item.source == "nctb":
        metadata_basis.append("nctb_official_textbook_identity")
    elif item.source == "open_library":
        metadata_basis.append("open_library_catalogue_metadata")
    else:
        metadata_basis.append("manual_metadata")

    if item.subject and item.subject in request.profile.subjects:
        metadata_basis.append("profile_subject_match")

    confidence = 0.45
    if item.identifier:
        confidence += 0.08
    if item.author:
        confidence += 0.05
    if item.subject:
        confidence += 0.05
    confidence = min(confidence, 0.65)

    return ReadingDifficultyAssessment(
        item_id=item.id,
        label="unknown",
        confidence=round(confidence, 2),
        basis=metadata_basis,
        note=_text(
            language,
            "The catalogue identifies the item but does not provide an authoritative personal difficulty rating. The first session is diagnostic.",
            "ক্যাটালগ বই বা পাঠ্যটি শনাক্ত করে, কিন্তু আপনার জন্য নির্ভরযোগ্য কঠিনতার rating দেয় না। প্রথম সেশনটি পর্যবেক্ষণমূলক হবে।",
        ),
    )


def _priority_score(request: ReadingPlanRequest, index: int) -> tuple[int, int, int]:
    item = request.items[index]
    difficulty_rank = {
        "hard": 3,
        "medium": 2,
        "easy": 1,
        "unknown": 2,
    }[item.user_difficulty]
    subject_match = int(bool(item.subject and item.subject in request.profile.subjects))
    return (item.priority, difficulty_rank, subject_match)


def _ordered_item_indices(request: ReadingPlanRequest) -> list[int]:
    return sorted(
        range(len(request.items)),
        key=lambda index: _priority_score(request, index),
        reverse=True,
    )


def _session_reason(
    request: ReadingPlanRequest,
    item_index: int,
    assessment: ReadingDifficultyAssessment,
) -> str:
    item = request.items[item_index]
    language = _language(request)

    reasons: list[str] = []

    if item.priority >= 4:
        reasons.append(
            _text(language, "you marked it as a high priority", "আপনি এটিকে উচ্চ অগ্রাধিকার দিয়েছেন")
        )

    if item.subject and item.subject in request.profile.subjects:
        reasons.append(
            _text(language, "it matches a selected subject", "এটি আপনার নির্বাচিত বিষয়ের সঙ্গে মেলে")
        )

    if assessment.label == "hard":
        reasons.append(
            _text(language, "your feedback says it is difficult", "আপনার মতামতে এটি কঠিন")
        )
    elif assessment.label == "unknown":
        reasons.append(
            _text(language, "difficulty is not yet confirmed", "কঠিনতা এখনো নিশ্চিত নয়")
        )

    if not reasons:
        reasons.append(
            _text(language, "it is next in your chosen reading order", "এটি আপনার নির্বাচিত পাঠক্রমের পরবর্তী item")
        )

    joined = "; ".join(reasons)
    return _text(
        language,
        f"Scheduled because {joined}.",
        f"সেশনটি রাখা হয়েছে কারণ {joined}।",
    )


def _focus_for_item(request: ReadingPlanRequest, item_index: int) -> str:
    item = request.items[item_index]
    language = _language(request)
    english, bangla = CONTENT_FOCUS.get(item.type, CONTENT_FOCUS["book"])

    if item.user_difficulty == "unknown":
        diagnostic = _text(
            language,
            " Start with a short diagnostic read and rate the difficulty afterward.",
            " শুরুতে ছোট একটি পর্যবেক্ষণমূলক পাঠ নিন এবং শেষে কঠিনতা নির্ধারণ করুন।",
        )
    else:
        diagnostic = ""

    return _text(language, english, bangla) + diagnostic


def _duration_for_item(request: ReadingPlanRequest, item_index: int) -> int:
    item = request.items[item_index]
    base = request.availability.session_minutes

    if item.user_difficulty == "unknown":
        return min(base, 30)
    if item.user_difficulty == "hard":
        return min(120, base + 10)
    if item.user_difficulty == "easy":
        return max(10, base - 5)
    return base


def _plan_id(request: ReadingPlanRequest) -> str:
    identity = "|".join(
        [
            request.profile.education_level,
            request.profile.class_or_year,
            request.goal,
            ",".join(item.id for item in request.items),
            str(request.availability.sessions_per_week),
            datetime.now(timezone.utc).isoformat(),
        ]
    )
    digest = hashlib.sha256(identity.encode("utf-8")).hexdigest()[:14]
    return f"reading_{digest}"


def generate_reading_plan(request: ReadingPlanRequest) -> ReadingPlanResponse:
    language = _language(request)
    plan_id = _plan_id(request)
    generated_at = datetime.now(timezone.utc)

    assessments = [
        _difficulty_assessment(request, index)
        for index in range(len(request.items))
    ]

    assessment_by_id = {
        assessment.item_id: assessment
        for assessment in assessments
    }

    ordered_indices = _ordered_item_indices(request)
    preferred_days = [
        day
        for day in DAY_ORDER
        if day in request.availability.preferred_days
    ]
    if not preferred_days:
        preferred_days = ["mon", "wed", "sat"]

    sessions: list[ReadingPlanSession] = []
    occurrences_by_day: dict[str, int] = {}

    for session_index in range(request.availability.sessions_per_week):
        item_index = ordered_indices[session_index % len(ordered_indices)]
        item = request.items[item_index]
        day = preferred_days[session_index % len(preferred_days)]
        day_occurrence = occurrences_by_day.get(day, 0)
        occurrences_by_day[day] = day_occurrence + 1

        start_minutes = (
            request.availability.preferred_start_minutes
            + (day_occurrence * 90)
        ) % (24 * 60)

        assessment = assessment_by_id[item.id]

        sessions.append(
            ReadingPlanSession(
                session_id=f"{plan_id}_{session_index + 1}",
                day=day,
                day_label=DAY_LABELS[language][day],
                start_minutes=start_minutes,
                duration_minutes=_duration_for_item(request, item_index),
                item_id=item.id,
                title=item.title,
                subject=item.subject or "",
                focus=_focus_for_item(request, item_index),
                reason=_session_reason(request, item_index, assessment),
                difficulty=assessment.label,
                confidence=assessment.confidence,
            )
        )

    sources: list[ReadingPlanSource] = []
    seen_sources: set[str] = set()

    source_labels = {
        "google_books": (
            "Google Books",
            "Catalogue identity, author, publisher, date, ISBN and book/magazine type",
        ),
        "crossref": (
            "Crossref",
            "Scholarly-work identity, DOI, publisher and publication metadata",
        ),
        "open_library": (
            "Open Library",
            "Book and edition catalogue metadata",
        ),
        "nctb": (
            "NCTB",
            "Official Bangladesh textbook identity supplied by the user or application catalogue",
        ),
        "manual": (
            "User-provided information",
            "Metadata entered by the user",
        ),
    }

    for item in request.items:
        if item.source in seen_sources:
            continue
        seen_sources.add(item.source)
        name, usage = source_labels.get(item.source, source_labels["manual"])
        sources.append(
            ReadingPlanSource(
                name=name,
                usage=usage,
            )
        )

    unknown_count = sum(
        assessment.label == "unknown"
        for assessment in assessments
    )

    assumptions = [
        _text(
            language,
            "The weekly plan uses the days, start time, session length and item priorities you selected.",
            "সাপ্তাহিক পরিকল্পনায় আপনার নির্বাচিত দিন, শুরুর সময়, সেশনের দৈর্ঘ্য এবং item priority ব্যবহার করা হয়েছে।",
        ),
        _text(
            language,
            "Catalogue metadata verifies identity; it is not treated as a personal difficulty score.",
            "ক্যাটালগ metadata পরিচয় যাচাই করে; এটিকে ব্যক্তিগত কঠিনতার score হিসেবে ধরা হয়নি।",
        ),
    ]

    if unknown_count:
        assumptions.append(
            _text(
                language,
                f"{unknown_count} item(s) need a first-session difficulty check.",
                f"{unknown_count}টি item-এর কঠিনতা প্রথম সেশনের পর যাচাই করতে হবে।",
            )
        )

    if request.target_date is None:
        assumptions.append(
            _text(
                language,
                "No target date was supplied, so deadline pressure was not used.",
                "কোনো target date দেওয়া হয়নি, তাই deadline pressure ব্যবহার করা হয়নি।",
            )
        )

    confidence_values = [assessment.confidence for assessment in assessments]
    overall_confidence = round(sum(confidence_values) / len(confidence_values), 2)

    level_label = request.profile.class_or_year or request.profile.education_level
    summary = _text(
        language,
        (
            f"A transparent {request.availability.sessions_per_week}-session weekly plan was created for "
            f"{len(request.items)} selected item(s) and the {level_label} learning profile."
        ),
        (
            f"{len(request.items)}টি নির্বাচিত item এবং {level_label} শিক্ষা প্রোফাইলের জন্য "
            f"স্বচ্ছ {request.availability.sessions_per_week}-সেশনের সাপ্তাহিক পরিকল্পনা তৈরি হয়েছে।"
        ),
    )

    return ReadingPlanResponse(
        plan_id=plan_id,
        engine="mindpulse-transparent-reading-plan-v1",
        generated_at=generated_at,
        language=language,
        summary=summary,
        overall_confidence=overall_confidence,
        difficulty_assessments=assessments,
        sessions=sessions,
        assumptions=assumptions,
        sources=sources,
        disclaimer=_text(
            language,
            "This plan is an explainable study aid. It does not claim that Google, Crossref, a publisher or an education board rated a book as easy or hard for you.",
            "এটি একটি ব্যাখ্যাযোগ্য পাঠ-সহায়িকা। Google, Crossref, প্রকাশক বা শিক্ষা বোর্ড কোনো বইকে আপনার জন্য সহজ বা কঠিন বলেছে—এমন দাবি এটি করে না।",
        ),
    )
