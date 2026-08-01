const aiService = require(
    "../services/ai.service"
);

const aiLogService = require(
    "../services/aiLog.service"
);


function sendSuccess(
    res,
    message,
    data,
    meta = {}
) {
    return res.status(200).json({
        success: true,
        message,
        data,
        meta,
    });
}


function sendAiError(
    res,
    error
) {
    const statusCode =
        Number.isInteger(
            error.statusCode
        )
            ? error.statusCode
            : 500;

    return res
        .status(statusCode)
        .json({
            success: false,

            message:
                error.message ||
                "AI service request failed.",

            error: {
                code:
                    error.code ||
                    "AI_SERVICE_ERROR",

                upstream_status:
                    error.upstreamStatus ||
                    null,

                details:
                    process.env.NODE_ENV ===
                    "development"
                        ? error.details || null
                        : null,
            },
        });
}


function getAuthenticatedUserId(req) {
    return (
        req.user?.id ||
        req.user?.user_id ||
        req.auth?.id ||
        req.auth?.user_id ||
        null
    );
}


async function writeLogSafely(payload) {
    try {
        return await aiLogService
            .createAiAnalysisLog(
                payload
            );
    } catch (error) {
        console.error(
            "AI analysis log failed:",
            error.message
        );

        return null;
    }
}


async function health(req, res) {
    const startedAt = Date.now();

    try {
        const result =
            await aiService.health();

        return sendSuccess(
            res,
            "AI service is healthy.",
            result,
            {
                response_time_ms:
                    Date.now() -
                    startedAt,
            }
        );
    } catch (error) {
        return sendAiError(
            res,
            error
        );
    }
}


async function analyzeJournal(
    req,
    res
) {
    const startedAt = Date.now();

    const userId =
        getAuthenticatedUserId(req);

    const requestSummary = {
        text_length:
            typeof req.body.text ===
            "string"
                ? req.body.text.length
                : 0,

        language:
            req.body.language ||
            "auto",

        mood_score:
            req.body.mood_score ??
            null,
    };

    try {
        const result =
            await aiService
                .analyzeJournal({
                    text:
                        req.body.text,

                    language:
                        req.body.language ||
                        "auto",

                    mood_score:
                        req.body
                            .mood_score ??
                        null,
                });

        const processingTimeMs =
            Date.now() -
            startedAt;

        const log =
            await writeLogSafely({
                userId,

                analysisType:
                    "journal",

                requestSummary,

                responseSummary: {
                    sentiment:
                        result.sentiment,

                    sentiment_score:
                        result
                            .sentiment_score,

                    confidence:
                        result.confidence,

                    detected_language:
                        result
                            .detected_language,

                    emotion_count:
                        Array.isArray(
                            result.emotions
                        )
                            ? result
                                  .emotions
                                  .length
                            : 0,

                    safety_flagged:
                        result.safety
                            ?.flagged ??
                        false,

                    safety_severity:
                        result.safety
                            ?.severity ??
                        "low",
                },

                safetyFlagged:
                    result.safety
                        ?.flagged ??
                    false,

                severity:
                    result.safety
                        ?.severity ??
                    "low",

                success: true,

                processingTimeMs,
            });

        return sendSuccess(
            res,
            "Journal analysis completed.",
            result,
            {
                user_id:
                    userId,

                response_time_ms:
                    processingTimeMs,

                engine:
                    "mindpulse-fastapi",

                log_id:
                    log?.id ??
                    null,
            }
        );
    } catch (error) {
        await writeLogSafely({
            userId,

            analysisType:
                "journal",

            requestSummary,

            success: false,

            errorCode:
                error.code ||
                "AI_SERVICE_ERROR",

            processingTimeMs:
                Date.now() -
                startedAt,
        });

        return sendAiError(
            res,
            error
        );
    }
}


async function checkSafety(
    req,
    res
) {
    const startedAt = Date.now();

    const userId =
        getAuthenticatedUserId(req);

    const requestSummary = {
        text_length:
            typeof req.body.text ===
            "string"
                ? req.body.text.length
                : 0,
    };

    try {
        const result =
            await aiService
                .checkSafety({
                    text:
                        req.body.text,
                });

        const processingTimeMs =
            Date.now() -
            startedAt;

        const log =
            await writeLogSafely({
                userId,

                analysisType:
                    "safety",

                requestSummary,

                responseSummary: {
                    flagged:
                        result.flagged,

                    severity:
                        result.severity,

                    emergency_action_recommended:
                        result
                            .emergency_action_recommended,
                },

                safetyFlagged:
                    result.flagged,

                severity:
                    result.severity,

                success: true,

                processingTimeMs,
            });

        return sendSuccess(
            res,
            "Safety analysis completed.",
            result,
            {
                user_id:
                    userId,

                response_time_ms:
                    processingTimeMs,

                log_id:
                    log?.id ??
                    null,
            }
        );
    } catch (error) {
        await writeLogSafely({
            userId,

            analysisType:
                "safety",

            requestSummary,

            success: false,

            errorCode:
                error.code ||
                "AI_SERVICE_ERROR",

            processingTimeMs:
                Date.now() -
                startedAt,
        });

        return sendAiError(
            res,
            error
        );
    }
}


async function getRecommendations(
    req,
    res
) {
    const startedAt = Date.now();

    const userId =
        getAuthenticatedUserId(req);

    const requestSummary = {
        mood_score:
            req.body.mood_score,

        stress_level:
            req.body.stress_level,

        energy_level:
            req.body.energy_level,

        sleep_hours:
            req.body.sleep_hours,

        hydration_cups:
            req.body
                .hydration_cups ??
            0,

        burnout_score:
            req.body
                .burnout_score ??
            null,
    };

    try {
        const result =
            await aiService
                .getWellnessRecommendations(
                    requestSummary
                );

        const processingTimeMs =
            Date.now() -
            startedAt;

        const log =
            await writeLogSafely({
                userId,

                analysisType:
                    "wellness",

                requestSummary,

                responseSummary: {
                    risk_score:
                        result.risk_score,

                    risk_level:
                        result.risk_level,

                    recommendation_count:
                        Array.isArray(
                            result
                                .recommendations
                        )
                            ? result
                                  .recommendations
                                  .length
                            : 0,
                },

                riskScore:
                    result.risk_score,

                riskLevel:
                    result.risk_level,

                success: true,

                processingTimeMs,
            });

        return sendSuccess(
            res,
            "Wellness recommendations generated.",
            result,
            {
                user_id:
                    userId,

                response_time_ms:
                    processingTimeMs,

                engine:
                    "mindpulse-fastapi",

                log_id:
                    log?.id ??
                    null,
            }
        );
    } catch (error) {
        await writeLogSafely({
            userId,

            analysisType:
                "wellness",

            requestSummary,

            success: false,

            errorCode:
                error.code ||
                "AI_SERVICE_ERROR",

            processingTimeMs:
                Date.now() -
                startedAt,
        });

        return sendAiError(
            res,
            error
        );
    }
}


async function predictWellness(
    req,
    res
) {
    const startedAt = Date.now();

    const userId =
        getAuthenticatedUserId(req);

    const requestSummary = {
        mood_score:
            req.body.mood_score,

        stress_level:
            req.body.stress_level,

        energy_level:
            req.body.energy_level,

        sleep_hours:
            req.body.sleep_hours,

        sleep_quality:
            req.body.sleep_quality,

        focus_level:
            req.body.focus_level,

        motivation_level:
            req.body.motivation_level,

        restlessness_level:
            req.body.restlessness_level,

        work_study_pressure:
            req.body.work_study_pressure,

        physical_activity_minutes:
            req.body
                .physical_activity_minutes ??
            0,

        hydration_cups:
            req.body
                .hydration_cups ??
            0,

        social_withdrawal:
            req.body.social_withdrawal,
    };

    try {
        const result =
            await aiService
                .predictWellness(
                    requestSummary
                );

        const processingTimeMs =
            Date.now() -
            startedAt;

        const predictions =
            result.predictions ||
            {};

        const log =
            await writeLogSafely({
                userId,

                analysisType:
                    "wellness",

                requestSummary,

                responseSummary: {
                    engine:
                        result.engine,

                    production_ready:
                        result
                            .production_ready,

                    training_data_type:
                        result
                            .training_data_type,

                    burnout_label:
                        predictions
                            .burnout
                            ?.label ??
                        null,

                    burnout_confidence:
                        predictions
                            .burnout
                            ?.confidence ??
                        null,

                    stress_label:
                        predictions
                            .stress
                            ?.label ??
                        null,

                    stress_confidence:
                        predictions
                            .stress
                            ?.confidence ??
                        null,

                    mood_label:
                        predictions
                            .mood
                            ?.label ??
                        null,

                    mood_confidence:
                        predictions
                            .mood
                            ?.confidence ??
                        null,
                },

                riskLevel:
                    predictions
                        .burnout
                        ?.label ??
                    null,

                success: true,

                processingTimeMs,
            });

        return sendSuccess(
            res,
            "ML wellness prediction completed.",
            result,
            {
                user_id:
                    userId,

                response_time_ms:
                    processingTimeMs,

                engine:
                    result.engine ||
                    "mindpulse-random-forest",

                log_id:
                    log?.id ??
                    null,
            }
        );
    } catch (error) {
        await writeLogSafely({
            userId,

            analysisType:
                "wellness",

            requestSummary,

            success: false,

            errorCode:
                error.code ||
                "AI_SERVICE_ERROR",

            processingTimeMs:
                Date.now() -
                startedAt,
        });

        return sendAiError(
            res,
            error
        );
    }
}


function normalizeReadingPlanPayload(body) {
    const profile =
        body &&
        typeof body.profile === "object" &&
        !Array.isArray(body.profile)
            ? body.profile
            : null;

    const availability =
        body &&
        typeof body.availability === "object" &&
        !Array.isArray(body.availability)
            ? body.availability
            : null;

    const items =
        Array.isArray(body?.items)
            ? body.items
            : [];

    if (!profile) {
        const error = new Error(
            "A learning profile is required."
        );
        error.statusCode = 400;
        error.code = "READING_PROFILE_REQUIRED";
        throw error;
    }

    if (!availability) {
        const error = new Error(
            "Reading availability is required."
        );
        error.statusCode = 400;
        error.code = "READING_AVAILABILITY_REQUIRED";
        throw error;
    }

    if (
        items.length < 1 ||
        items.length > 30
    ) {
        const error = new Error(
            "Select between 1 and 30 reading items."
        );
        error.statusCode = 400;
        error.code = "READING_ITEM_COUNT_INVALID";
        throw error;
    }

    const invalidItem = items.find(
        (item) =>
            !item ||
            typeof item !== "object" ||
            Array.isArray(item) ||
            typeof item.id !== "string" ||
            !item.id.trim() ||
            typeof item.title !== "string" ||
            !item.title.trim()
    );

    if (invalidItem) {
        const error = new Error(
            "Every reading item needs an id and title."
        );
        error.statusCode = 400;
        error.code = "READING_ITEM_INVALID";
        throw error;
    }

    return {
        profile,
        items,
        availability,
        goal:
            typeof body.goal === "string" &&
            body.goal.trim()
                ? body.goal.trim()
                : "general_reading",
        target_date:
            typeof body.target_date === "string" &&
            body.target_date.trim()
                ? body.target_date.trim()
                : null,
    };
}


async function generateReadingPlan(
    req,
    res
) {
    const startedAt = Date.now();
    const userId =
        getAuthenticatedUserId(req);

    let payload;

    try {
        payload =
            normalizeReadingPlanPayload(
                req.body || {}
            );
    } catch (error) {
        return sendAiError(
            res,
            error
        );
    }

    const typeCounts = {};

    for (const item of payload.items) {
        const type =
            typeof item.type === "string"
                ? item.type
                : "unknown";

        typeCounts[type] =
            (typeCounts[type] || 0) + 1;
    }

    const requestSummary = {
        education_system:
            payload.profile
                .education_system ||
            null,
        education_level:
            payload.profile
                .education_level ||
            null,
        class_or_year:
            payload.profile
                .class_or_year ||
            null,
        stream:
            payload.profile
                .stream ||
            null,
        subject_count:
            Array.isArray(
                payload.profile.subjects
            )
                ? payload.profile
                      .subjects.length
                : 0,
        item_count:
            payload.items.length,
        item_type_counts:
            typeCounts,
        sessions_per_week:
            payload.availability
                .sessions_per_week ||
            null,
        has_target_date:
            Boolean(
                payload.target_date
            ),
    };

    try {
        const result =
            await aiService
                .generateReadingPlan(
                    payload
                );

        const processingTimeMs =
            Date.now() -
            startedAt;

        const log =
            await writeLogSafely({
                userId,
                analysisType:
                    "reading_plan",
                requestSummary,
                responseSummary: {
                    plan_id:
                        result.plan_id ||
                        null,
                    engine:
                        result.engine ||
                        null,
                    session_count:
                        Array.isArray(
                            result.sessions
                        )
                            ? result
                                  .sessions
                                  .length
                            : 0,
                    overall_confidence:
                        result
                            .overall_confidence ??
                        null,
                },
                success: true,
                processingTimeMs,
            });

        return sendSuccess(
            res,
            "Reading plan generated.",
            result,
            {
                user_id: userId,
                response_time_ms:
                    processingTimeMs,
                engine:
                    result.engine ||
                    "mindpulse-transparent-reading-plan-v1",
                log_id:
                    log?.id ??
                    null,
            }
        );
    } catch (error) {
        await writeLogSafely({
            userId,
            analysisType:
                "reading_plan",
            requestSummary,
            success: false,
            errorCode:
                error.code ||
                "AI_SERVICE_ERROR",
            processingTimeMs:
                Date.now() -
                startedAt,
        });

        return sendAiError(
            res,
            error
        );
    }
}


module.exports = {
    health,
    analyzeJournal,
    checkSafety,
    getRecommendations,
    predictWellness,
    generateReadingPlan,
};
