const path = require("path");

require("dotenv").config({
    path: path.resolve(
        __dirname,
        "..",
        ".env"
    ),
    override: true,
});

const aiService = require(
    "../src/services/ai.service"
);


async function run() {
    console.log(
        "Testing Node.js to FastAPI connection..."
    );

    const health =
        await aiService.health();

    const journal =
        await aiService.analyzeJournal({
            text: (
                "Today I felt stressed and tired " +
                "because of study pressure, but " +
                "I am hopeful that I can improve."
            ),
            language: "en",
            mood_score: 3,
        });

    const safety =
        await aiService.checkSafety({
            text:
                "I feel stressed, but I am safe.",
        });

    const recommendations =
        await aiService
            .getWellnessRecommendations({
                mood_score: 2,
                stress_level: 5,
                energy_level: 2,
                sleep_hours: 5,
                hydration_cups: 3,
                burnout_score: 70,
            });

    const result = {
        connection: {
            success:
                health.success === true,
            service:
                health.service,
            status:
                health.status,
        },

        journal_analysis: {
            sentiment:
                journal.sentiment,
            sentiment_score:
                journal.sentiment_score,
            confidence:
                journal.confidence,
            detected_language:
                journal.detected_language,
            emotion_count:
                journal.emotions.length,
            safety_flagged:
                journal.safety.flagged,
        },

        safety_check: {
            flagged:
                safety.flagged,
            severity:
                safety.severity,
            emergency_action_recommended:
                safety
                    .emergency_action_recommended,
        },

        wellness_recommendation: {
            risk_score:
                recommendations.risk_score,
            risk_level:
                recommendations.risk_level,
            recommendation_count:
                recommendations
                    .recommendations.length,
        },
    };

    console.log(
        JSON.stringify(
            result,
            null,
            2
        )
    );

    console.log(
        "Node.js to FastAPI integration successful."
    );
}


run().catch((error) => {
    console.error(
        "Node.js to FastAPI integration failed."
    );

    console.error({
        name: error.name,
        code: error.code,
        message: error.message,
        upstream_status:
            error.upstreamStatus,
        details: error.details,
    });

    process.exit(1);
});
