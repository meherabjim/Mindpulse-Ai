const mysql = require("mysql2/promise");


const pool = mysql.createPool({
    host:
        process.env.DB_HOST ||
        "127.0.0.1",

    port:
        Number(
            process.env.DB_PORT ||
            3306
        ),

    user:
        process.env.DB_USER ||
        "root",

    password:
        process.env.DB_PASSWORD ||
        "",

    database:
        process.env.DB_NAME ||
        "mindpulse_ai",

    waitForConnections:
        true,

    connectionLimit:
        5,

    queueLimit:
        0,

    charset:
        "utf8mb4",
});


function serialize(value) {
    if (
        value === undefined ||
        value === null
    ) {
        return null;
    }

    try {
        return JSON.stringify(value);
    } catch {
        return JSON.stringify({
            serialization_error: true,
        });
    }
}


async function createAiAnalysisLog({
    userId = null,
    analysisType,
    requestSummary = null,
    responseSummary = null,
    safetyFlagged = null,
    severity = null,
    riskScore = null,
    riskLevel = null,
    success = true,
    errorCode = null,
    processingTimeMs = null,
}) {
    const sql = `
        INSERT INTO ai_analysis_logs (
            user_id,
            analysis_type,
            request_summary,
            response_summary,
            safety_flagged,
            severity,
            risk_score,
            risk_level,
            success,
            error_code,
            processing_time_ms
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;

    const values = [
        userId,
        analysisType,
        serialize(requestSummary),
        serialize(responseSummary),

        safetyFlagged === null
            ? null
            : Boolean(safetyFlagged),

        severity,
        riskScore,
        riskLevel,
        Boolean(success),
        errorCode,
        processingTimeMs,
    ];

    const [result] =
        await pool.execute(
            sql,
            values
        );

    return {
        id: result.insertId,
    };
}


module.exports = {
    createAiAnalysisLog,
};
