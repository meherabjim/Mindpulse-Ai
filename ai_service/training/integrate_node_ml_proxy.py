from pathlib import Path


ROOT = Path(
    r"E:\project 3\MindPulse-AI"
)

SERVICE_PATH = (
    ROOT
    / "backend"
    / "src"
    / "services"
    / "ai.service.js"
)

CONTROLLER_PATH = (
    ROOT
    / "backend"
    / "src"
    / "controllers"
    / "ai.controller.js"
)

ROUTES_PATH = (
    ROOT
    / "backend"
    / "src"
    / "routes"
    / "ai.routes.js"
)


def patch_service() -> None:
    text = SERVICE_PATH.read_text(
        encoding="utf-8"
    )

    function_marker = (
        "async function predictWellness("
    )

    function_block = r'''

async function predictWellness(
    payload
) {
    return request(
        "/api/v1/predictions/wellness",
        {
            method: "POST",
            body: payload,
        }
    );
}
'''

    if function_marker not in text:
        text = text.replace(
            "\n\nmodule.exports = {",
            function_block
            + "\n\nmodule.exports = {",
        )

    if (
        "    predictWellness,"
        not in text
    ):
        text = text.replace(
            "    getWellnessRecommendations,\n};",
            (
                "    getWellnessRecommendations,\n"
                "    predictWellness,\n"
                "};"
            ),
        )

    SERVICE_PATH.write_text(
        text,
        encoding="utf-8",
    )


def patch_controller() -> None:
    text = CONTROLLER_PATH.read_text(
        encoding="utf-8"
    )

    function_marker = (
        "async function predictWellness("
    )

    function_block = r'''

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
'''

    if function_marker not in text:
        text = text.replace(
            "\n\nmodule.exports = {",
            function_block
            + "\n\nmodule.exports = {",
        )

    if (
        "    predictWellness,"
        not in text
    ):
        text = text.replace(
            "    getRecommendations,\n};",
            (
                "    getRecommendations,\n"
                "    predictWellness,\n"
                "};"
            ),
        )

    CONTROLLER_PATH.write_text(
        text,
        encoding="utf-8",
    )


def patch_routes() -> None:
    text = ROUTES_PATH.read_text(
        encoding="utf-8"
    )

    route_marker = (
        '    "/wellness/predict",'
    )

    route_block = r'''

router.post(
    "/wellness/predict",
    authenticateUser,
    aiController.predictWellness
);
'''

    if route_marker not in text:
        text = text.replace(
            "\n\nmodule.exports = router;",
            route_block
            + "\n\nmodule.exports = router;",
        )

    ROUTES_PATH.write_text(
        text,
        encoding="utf-8",
    )


def main() -> None:
    patch_service()
    patch_controller()
    patch_routes()

    print(
        "Node.js ML proxy integration completed."
    )

    print(
        "Route: POST "
        "/api/v1/ai/wellness/predict"
    )


if __name__ == "__main__":
    main()
