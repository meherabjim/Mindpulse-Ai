const database = require('../config/database');
const AppError = require('../utils/AppError');

const pool = database.pool || database;

function toNumber(value) {
    if (value === null || value === undefined) {
        return null;
    }

    return Number(value);
}

function parseJson(value, fallback = null) {
    if (!value) {
        return fallback;
    }

    if (typeof value === 'object') {
        return value;
    }

    try {
        return JSON.parse(value);
    } catch {
        return fallback;
    }
}

function roundScore(value) {
    return Number(value.toFixed(2));
}

function getRiskLevel(score) {
    if (score < 25) {
        return 'low';
    }

    if (score < 45) {
        return 'mild';
    }

    if (score < 70) {
        return 'moderate';
    }

    return 'elevated';
}

function getRecommendation(riskLevel) {
    const recommendations = {
        low:
            'Continue your current healthy routine and maintain regular check-ins.',

        mild:
            'Consider a short recovery activity, regular hydration, healthy sleep, and manageable breaks.',

        moderate:
            'Reduce unnecessary pressure, follow a structured recovery plan, and consider speaking with a trusted person or qualified professional.',

        elevated:
            'Prioritize rest and support. Consider contacting a qualified professional. If you feel unsafe or face an emergency, contact local emergency support immediately.'
    };

    return recommendations[riskLevel];
}

function getExplanation(riskLevel) {
    const explanations = {
        low:
            'The submitted wellness indicators currently show a relatively low level of strain.',

        mild:
            'Some submitted indicators suggest mild strain that may benefit from early self-care.',

        moderate:
            'Several submitted indicators suggest meaningful wellness strain and a need for active recovery.',

        elevated:
            'The submitted indicators suggest elevated wellness strain that should not be ignored.'
    };

    return explanations[riskLevel];
}

async function ensureActiveUser(
    executor,
    userId
) {
    const [rows] = await executor.execute(
        `
        SELECT
            id,
            account_status,
            deleted_at
        FROM users
        WHERE id = ?
        LIMIT 1
        `,
        [userId]
    );

    const user = rows[0];

    if (!user || user.deleted_at) {
        throw new AppError(
            404,
            'User account was not found.'
        );
    }

    if (user.account_status !== 'active') {
        throw new AppError(
            403,
            'This account is not currently active.'
        );
    }
}

async function getUserTimezone(userId) {
    const [rows] = await pool.execute(
        `
        SELECT
            COALESCE(
                p.timezone,
                'Asia/Dhaka'
            ) AS timezone
        FROM users AS u
        LEFT JOIN user_profiles AS p
            ON p.user_id = u.id
        WHERE
            u.id = ?
            AND u.deleted_at IS NULL
        LIMIT 1
        `,
        [userId]
    );

    return rows[0]?.timezone || 'Asia/Dhaka';
}

function getDateInTimezone(timezone) {
    try {
        const formatter =
            new Intl.DateTimeFormat(
                'en-US',
                {
                    timeZone: timezone,
                    year: 'numeric',
                    month: '2-digit',
                    day: '2-digit'
                }
            );

        const parts =
            formatter.formatToParts(
                new Date()
            );

        const values = {};

        parts.forEach((part) => {
            values[part.type] = part.value;
        });

        return `${values.year}-${values.month}-${values.day}`;
    } catch {
        return new Date()
            .toISOString()
            .slice(0, 10);
    }
}

function normalizeDirectScore(value) {
    return ((Number(value) - 1) / 4) * 100;
}

function normalizeInverseScore(value) {
    return ((5 - Number(value)) / 4) * 100;
}

function getSleepHoursRisk(hours) {
    if (hours === null || hours === undefined) {
        return null;
    }

    const value = Number(hours);

    if (value < 4) {
        return 100;
    }

    if (value < 5) {
        return 85;
    }

    if (value < 6) {
        return 65;
    }

    if (value < 7) {
        return 35;
    }

    if (value <= 9) {
        return 0;
    }

    if (value <= 10) {
        return 20;
    }

    return 45;
}

function calculateCheckinScore(checkin) {
    const factors = [];

    function addFactor({
        key,
        label,
        risk,
        weight,
        value
    }) {
        if (
            risk === null ||
            risk === undefined ||
            Number.isNaN(risk)
        ) {
            return;
        }

        factors.push({
            key,
            label,
            value,
            risk_score:
                roundScore(risk),
            weight
        });
    }

    addFactor({
        key: 'mood_score',
        label: 'Low mood',
        risk:
            normalizeInverseScore(
                checkin.mood_score
            ),
        weight: 0.15,
        value: checkin.mood_score
    });

    addFactor({
        key: 'stress_level',
        label: 'Stress',
        risk:
            normalizeDirectScore(
                checkin.stress_level
            ),
        weight: 0.2,
        value: checkin.stress_level
    });

    addFactor({
        key: 'energy_level',
        label: 'Low energy',
        risk:
            normalizeInverseScore(
                checkin.energy_level
            ),
        weight: 0.1,
        value: checkin.energy_level
    });

    addFactor({
        key: 'sleep_hours',
        label: 'Sleep duration',
        risk:
            getSleepHoursRisk(
                checkin.sleep_hours
            ),
        weight: 0.1,
        value: checkin.sleep_hours
    });

    if (checkin.sleep_quality !== null) {
        addFactor({
            key: 'sleep_quality',
            label: 'Poor sleep quality',
            risk:
                normalizeInverseScore(
                    checkin.sleep_quality
                ),
            weight: 0.1,
            value: checkin.sleep_quality
        });
    }

    if (checkin.focus_level !== null) {
        addFactor({
            key: 'focus_level',
            label: 'Low focus',
            risk:
                normalizeInverseScore(
                    checkin.focus_level
                ),
            weight: 0.08,
            value: checkin.focus_level
        });
    }

    if (
        checkin.motivation_level !== null
    ) {
        addFactor({
            key: 'motivation_level',
            label: 'Low motivation',
            risk:
                normalizeInverseScore(
                    checkin.motivation_level
                ),
            weight: 0.08,
            value:
                checkin.motivation_level
        });
    }

    if (
        checkin.restlessness_level !== null
    ) {
        addFactor({
            key: 'restlessness_level',
            label: 'Restlessness',
            risk:
                normalizeDirectScore(
                    checkin.restlessness_level
                ),
            weight: 0.07,
            value:
                checkin.restlessness_level
        });
    }

    if (
        checkin.work_study_pressure !== null
    ) {
        addFactor({
            key: 'work_study_pressure',
            label: 'Work or study pressure',
            risk:
                normalizeDirectScore(
                    checkin.work_study_pressure
                ),
            weight: 0.07,
            value:
                checkin.work_study_pressure
        });
    }

    const activityRisk =
        checkin.physical_activity_minutes >= 20
            ? 0
            : checkin.physical_activity_minutes > 0
                ? 25
                : 55;

    addFactor({
        key: 'physical_activity_minutes',
        label: 'Low physical activity',
        risk: activityRisk,
        weight: 0.025,
        value:
            checkin.physical_activity_minutes
    });

    const hydrationRisk =
        checkin.water_intake_glasses >= 8
            ? 0
            : checkin.water_intake_glasses >= 4
                ? 20
                : checkin.water_intake_glasses > 0
                    ? 40
                    : 60;

    addFactor({
        key: 'water_intake_glasses',
        label: 'Low hydration',
        risk: hydrationRisk,
        weight: 0.025,
        value:
            checkin.water_intake_glasses
    });

    const totalWeight =
        factors.reduce(
            (sum, factor) =>
                sum + factor.weight,
            0
        );

    const weightedScore =
        factors.reduce(
            (sum, factor) =>
                sum +
                factor.risk_score *
                    factor.weight,
            0
        ) / totalWeight;

    const score =
        roundScore(weightedScore);

    const riskLevel =
        getRiskLevel(score);

    const mainFactors =
        [...factors]
            .sort(
                (a, b) =>
                    b.risk_score -
                    a.risk_score
            )
            .slice(0, 5);

    return {
        score,
        riskLevel,
        mainFactors,
        explanation:
            getExplanation(riskLevel),
        recommendation:
            getRecommendation(riskLevel)
    };
}

function mapBurnout(row) {
    if (!row || !row.id) {
        return null;
    }

    return {
        id: Number(row.id),
        burnout_score:
            toNumber(row.burnout_score),
        risk_level: row.risk_level,
        assessment_source:
            row.assessment_source,
        factor_details:
            parseJson(
                row.factor_details,
                []
            ),
        explanation:
            row.explanation,
        algorithm_version:
            row.algorithm_version,
        assessed_at:
            row.assessed_at
    };
}

function mapCheckin(row) {
    return {
        id: Number(row.id),
        checkin_date:
            row.checkin_date,

        mood_score:
            Number(row.mood_score),

        stress_level:
            Number(row.stress_level),

        energy_level:
            Number(row.energy_level),

        sleep_hours:
            toNumber(row.sleep_hours),

        sleep_quality:
            toNumber(row.sleep_quality),

        focus_level:
            toNumber(row.focus_level),

        motivation_level:
            toNumber(
                row.motivation_level
            ),

        restlessness_level:
            toNumber(
                row.restlessness_level
            ),

        physical_activity_minutes:
            Number(
                row.physical_activity_minutes
            ),

        water_intake_glasses:
            Number(
                row.water_intake_glasses
            ),

        work_study_pressure:
            toNumber(
                row.work_study_pressure
            ),

        note: row.note,
        created_at: row.created_at,
        updated_at: row.updated_at,

        burnout_assessment:
            row.burnout_id
                ? mapBurnout({
                    id: row.burnout_id,
                    burnout_score:
                        row.burnout_score,
                    risk_level:
                        row.burnout_risk_level,
                    assessment_source:
                        row.assessment_source,
                    factor_details:
                        row.factor_details,
                    explanation:
                        row.burnout_explanation,
                    algorithm_version:
                        row.algorithm_version,
                    assessed_at:
                        row.assessed_at
                })
                : null
    };
}

async function getCheckinById(
    executor,
    userId,
    checkinId
) {
    const [rows] =
        await executor.execute(
            `
            SELECT
                dc.*,

                ba.id AS burnout_id,
                ba.burnout_score,
                ba.risk_level
                    AS burnout_risk_level,
                ba.assessment_source,
                ba.factor_details,
                ba.explanation
                    AS burnout_explanation,
                ba.algorithm_version,
                ba.assessed_at

            FROM daily_checkins AS dc

            LEFT JOIN burnout_assessments AS ba
                ON ba.id = (
                    SELECT ba2.id
                    FROM burnout_assessments AS ba2
                    WHERE
                        ba2.daily_checkin_id =
                            dc.id
                    ORDER BY ba2.id DESC
                    LIMIT 1
                )

            WHERE
                dc.id = ?
                AND dc.user_id = ?

            LIMIT 1
            `,
            [
                checkinId,
                userId
            ]
        );

    return rows[0]
        ? mapCheckin(rows[0])
        : null;
}

async function saveCheckinBurnout(
    executor,
    userId,
    checkinId,
    result
) {
    const [rows] =
        await executor.execute(
            `
            SELECT id
            FROM burnout_assessments
            WHERE
                user_id = ?
                AND daily_checkin_id = ?
                AND assessment_source =
                    'checkin'
            ORDER BY id DESC
            LIMIT 1
            FOR UPDATE
            `,
            [
                userId,
                checkinId
            ]
        );

    const factorDetails =
        JSON.stringify(
            result.mainFactors
        );

    if (rows[0]) {
        await executor.execute(
            `
            UPDATE burnout_assessments
            SET
                burnout_score = ?,
                risk_level = ?,
                factor_details = ?,
                explanation = ?,
                algorithm_version = '1.0',
                assessed_at =
                    CURRENT_TIMESTAMP
            WHERE id = ?
            `,
            [
                result.score,
                result.riskLevel,
                factorDetails,
                result.explanation,
                rows[0].id
            ]
        );

        return;
    }

    await executor.execute(
        `
        INSERT INTO burnout_assessments (
            user_id,
            daily_checkin_id,
            wellness_scan_id,
            burnout_score,
            risk_level,
            assessment_source,
            factor_details,
            explanation,
            algorithm_version
        )
        VALUES (
            ?,
            ?,
            NULL,
            ?,
            ?,
            'checkin',
            ?,
            ?,
            '1.0'
        )
        `,
        [
            userId,
            checkinId,
            result.score,
            result.riskLevel,
            factorDetails,
            result.explanation
        ]
    );
}

async function submitCheckin(
    userId,
    checkinData
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        let checkinDate =
            checkinData.checkin_date;

        if (!checkinDate) {
            const timezone =
                await getUserTimezone(userId);

            checkinDate =
                getDateInTimezone(timezone);
        }

        const [result] =
            await connection.execute(
                `
                INSERT INTO daily_checkins (
                    user_id,
                    checkin_date,
                    mood_score,
                    stress_level,
                    energy_level,
                    sleep_hours,
                    sleep_quality,
                    focus_level,
                    motivation_level,
                    restlessness_level,
                    physical_activity_minutes,
                    water_intake_glasses,
                    work_study_pressure,
                    note
                )
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, ?
                )

                ON DUPLICATE KEY UPDATE
                    id = LAST_INSERT_ID(id),
                    mood_score =
                        VALUES(mood_score),
                    stress_level =
                        VALUES(stress_level),
                    energy_level =
                        VALUES(energy_level),
                    sleep_hours =
                        VALUES(sleep_hours),
                    sleep_quality =
                        VALUES(sleep_quality),
                    focus_level =
                        VALUES(focus_level),
                    motivation_level =
                        VALUES(motivation_level),
                    restlessness_level =
                        VALUES(restlessness_level),
                    physical_activity_minutes =
                        VALUES(
                            physical_activity_minutes
                        ),
                    water_intake_glasses =
                        VALUES(
                            water_intake_glasses
                        ),
                    work_study_pressure =
                        VALUES(
                            work_study_pressure
                        ),
                    note = VALUES(note)
                `,
                [
                    userId,
                    checkinDate,
                    checkinData.mood_score,
                    checkinData.stress_level,
                    checkinData.energy_level,
                    checkinData.sleep_hours,
                    checkinData.sleep_quality,
                    checkinData.focus_level,
                    checkinData.motivation_level,
                    checkinData.restlessness_level,
                    checkinData
                        .physical_activity_minutes,
                    checkinData
                        .water_intake_glasses,
                    checkinData
                        .work_study_pressure,
                    checkinData.note
                ]
            );

        const checkinId =
            result.insertId;

        const [checkinRows] =
            await connection.execute(
                `
                SELECT *
                FROM daily_checkins
                WHERE
                    id = ?
                    AND user_id = ?
                LIMIT 1
                `,
                [
                    checkinId,
                    userId
                ]
            );

        const scoreResult =
            calculateCheckinScore(
                checkinRows[0]
            );

        await saveCheckinBurnout(
            connection,
            userId,
            checkinId,
            scoreResult
        );

        await connection.commit();

        return getCheckinById(
            pool,
            userId,
            checkinId
        );
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function getTodayCheckin(userId) {
    await ensureActiveUser(
        pool,
        userId
    );

    const timezone =
        await getUserTimezone(userId);

    const today =
        getDateInTimezone(timezone);

    const [rows] =
        await pool.execute(
            `
            SELECT id
            FROM daily_checkins
            WHERE
                user_id = ?
                AND checkin_date = ?
            LIMIT 1
            `,
            [
                userId,
                today
            ]
        );

    if (!rows[0]) {
        return {
            date: today,
            has_checkin: false,
            checkin: null
        };
    }

    return {
        date: today,
        has_checkin: true,
        checkin:
            await getCheckinById(
                pool,
                userId,
                rows[0].id
            )
    };
}

async function getCheckinHistory(
    userId,
    options
) {
    await ensureActiveUser(
        pool,
        userId
    );

    const conditions = [
        'dc.user_id = ?'
    ];

    const parameters = [
        userId
    ];

    if (options.fromDate) {
        conditions.push(
            'dc.checkin_date >= ?'
        );

        parameters.push(
            options.fromDate
        );
    }

    if (options.toDate) {
        conditions.push(
            'dc.checkin_date <= ?'
        );

        parameters.push(
            options.toDate
        );
    }

    const whereClause =
        conditions.join(' AND ');

    const [countRows] =
        await pool.execute(
            `
            SELECT COUNT(*) AS total
            FROM daily_checkins AS dc
            WHERE ${whereClause}
            `,
            parameters
        );

    const offset =
        (options.page - 1) *
        options.limit;

    const [rows] =
        await pool.execute(
            `
            SELECT
                dc.*,

                ba.id AS burnout_id,
                ba.burnout_score,
                ba.risk_level
                    AS burnout_risk_level,
                ba.assessment_source,
                ba.factor_details,
                ba.explanation
                    AS burnout_explanation,
                ba.algorithm_version,
                ba.assessed_at

            FROM daily_checkins AS dc

            LEFT JOIN burnout_assessments AS ba
                ON ba.id = (
                    SELECT ba2.id
                    FROM burnout_assessments AS ba2
                    WHERE
                        ba2.daily_checkin_id =
                            dc.id
                    ORDER BY ba2.id DESC
                    LIMIT 1
                )

            WHERE ${whereClause}

            ORDER BY
                dc.checkin_date DESC,
                dc.id DESC

            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            parameters
        );

    const total =
        Number(countRows[0].total);

    return {
        checkins:
            rows.map(mapCheckin),

        pagination: {
            page: options.page,
            limit: options.limit,
            total,
            total_pages:
                Math.ceil(
                    total /
                    options.limit
                )
        }
    };
}

async function listQuestions(userId) {
    await ensureActiveUser(
        pool,
        userId
    );

    const [rows] =
        await pool.execute(
            `
            SELECT
                id,
                question_code,
                question_text,
                category,
                response_scale,
                display_order
            FROM wellness_questions
            WHERE is_active = TRUE
            ORDER BY
                display_order ASC,
                id ASC
            `
        );

    return rows.map((row) => ({
        id: Number(row.id),
        question_code:
            row.question_code,
        question_text:
            row.question_text,
        category: row.category,
        response_scale:
            row.response_scale,
        display_order:
            Number(row.display_order)
    }));
}

function normalizeQuestionResponse(
    question,
    responseValue
) {
    if (
        question.response_scale ===
        '1_to_5'
    ) {
        if (
            responseValue < 1 ||
            responseValue > 5
        ) {
            throw new AppError(
                422,
                `${question.question_code} requires a response from 1 to 5.`
            );
        }

        return (
            (responseValue - 1) /
            4
        ) * 100;
    }

    if (
        question.response_scale ===
        '1_to_10'
    ) {
        if (
            responseValue < 1 ||
            responseValue > 10
        ) {
            throw new AppError(
                422,
                `${question.question_code} requires a response from 1 to 10.`
            );
        }

        return (
            (responseValue - 1) /
            9
        ) * 100;
    }

    if (
        responseValue !== 0 &&
        responseValue !== 1
    ) {
        throw new AppError(
            422,
            `${question.question_code} requires 0 for no or 1 for yes.`
        );
    }

    return responseValue * 100;
}

function mapScan(row) {
    return {
        id: Number(row.id),
        total_score:
            toNumber(row.total_score),
        risk_level:
            row.risk_level,
        main_factors:
            parseJson(
                row.main_factors,
                []
            ),
        summary: row.summary,
        recommendation:
            row.recommendation,
        completed_at:
            row.completed_at,
        created_at:
            row.created_at
    };
}

async function getScanById(
    userId,
    scanId
) {
    await ensureActiveUser(
        pool,
        userId
    );

    const [scanRows] =
        await pool.execute(
            `
            SELECT *
            FROM wellness_scans
            WHERE
                id = ?
                AND user_id = ?
            LIMIT 1
            `,
            [
                scanId,
                userId
            ]
        );

    if (!scanRows[0]) {
        throw new AppError(
            404,
            'Wellness scan was not found.'
        );
    }

    const [answerRows] =
        await pool.execute(
            `
            SELECT
                wsa.question_id,
                wq.question_code,
                wq.question_text,
                wq.category,
                wq.response_scale,
                wsa.response_value,
                wsa.response_text
            FROM wellness_scan_answers
                AS wsa
            INNER JOIN wellness_questions
                AS wq
                ON wq.id =
                    wsa.question_id
            WHERE
                wsa.wellness_scan_id = ?
            ORDER BY
                wq.display_order ASC,
                wq.id ASC
            `,
            [scanId]
        );

    const scan =
        mapScan(scanRows[0]);

    scan.answers =
        answerRows.map((row) => ({
            question_id:
                Number(row.question_id),
            question_code:
                row.question_code,
            question_text:
                row.question_text,
            category:
                row.category,
            response_scale:
                row.response_scale,
            response_value:
                Number(row.response_value),
            response_text:
                row.response_text
        }));

    return scan;
}

async function submitScan(
    userId,
    answers
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        const [questionRows] =
            await connection.execute(
                `
                SELECT
                    id,
                    question_code,
                    question_text,
                    category,
                    response_scale,
                    display_order
                FROM wellness_questions
                WHERE is_active = TRUE
                ORDER BY
                    display_order ASC,
                    id ASC
                FOR UPDATE
                `
            );

        if (questionRows.length === 0) {
            throw new AppError(
                409,
                'No active wellness questions are available.'
            );
        }

        const answerMap =
            new Map(
                answers.map(
                    (answer) => [
                        answer.question_id,
                        answer
                    ]
                )
            );

        const activeQuestionIds =
            new Set(
                questionRows.map(
                    (question) =>
                        Number(question.id)
                )
            );

        const missingQuestions =
            questionRows
                .filter(
                    (question) =>
                        !answerMap.has(
                            Number(
                                question.id
                            )
                        )
                )
                .map(
                    (question) =>
                        question.question_code
                );

        const invalidQuestionIds =
            answers
                .filter(
                    (answer) =>
                        !activeQuestionIds.has(
                            answer.question_id
                        )
                )
                .map(
                    (answer) =>
                        answer.question_id
                );

        if (
            missingQuestions.length > 0 ||
            invalidQuestionIds.length > 0
        ) {
            const details = [];

            if (
                missingQuestions.length > 0
            ) {
                details.push(
                    `Missing questions: ${missingQuestions.join(', ')}`
                );
            }

            if (
                invalidQuestionIds.length > 0
            ) {
                details.push(
                    `Invalid or inactive question IDs: ${invalidQuestionIds.join(', ')}`
                );
            }

            throw new AppError(
                422,
                'All active wellness questions must be answered.',
                details
            );
        }

        const scoredAnswers =
            questionRows.map(
                (question) => {
                    const answer =
                        answerMap.get(
                            Number(
                                question.id
                            )
                        );

                    const riskScore =
                        normalizeQuestionResponse(
                            question,
                            answer
                                .response_value
                        );

                    return {
                        question,
                        answer,
                        risk_score:
                            roundScore(
                                riskScore
                            )
                    };
                }
            );

        const totalScore =
            roundScore(
                scoredAnswers.reduce(
                    (sum, item) =>
                        sum +
                        item.risk_score,
                    0
                ) /
                scoredAnswers.length
            );

        const riskLevel =
            getRiskLevel(totalScore);

        const mainFactors =
            [...scoredAnswers]
                .sort(
                    (a, b) =>
                        b.risk_score -
                        a.risk_score
                )
                .slice(0, 3)
                .map((item) => ({
                    question_id:
                        Number(
                            item.question.id
                        ),

                    question_code:
                        item.question
                            .question_code,

                    category:
                        item.question.category,

                    response_value:
                        item.answer
                            .response_value,

                    risk_score:
                        item.risk_score
                }));

        const summary =
            getExplanation(riskLevel);

        const recommendation =
            getRecommendation(riskLevel);

        const [scanResult] =
            await connection.execute(
                `
                INSERT INTO wellness_scans (
                    user_id,
                    total_score,
                    risk_level,
                    main_factors,
                    summary,
                    recommendation
                )
                VALUES (?, ?, ?, ?, ?, ?)
                `,
                [
                    userId,
                    totalScore,
                    riskLevel,
                    JSON.stringify(
                        mainFactors
                    ),
                    summary,
                    recommendation
                ]
            );

        const scanId =
            scanResult.insertId;

        for (
            const item of scoredAnswers
        ) {
            await connection.execute(
                `
                INSERT INTO wellness_scan_answers (
                    wellness_scan_id,
                    question_id,
                    response_value,
                    response_text
                )
                VALUES (?, ?, ?, ?)
                `,
                [
                    scanId,
                    item.question.id,
                    item.answer
                        .response_value,
                    item.answer
                        .response_text
                ]
            );
        }

        await connection.execute(
            `
            INSERT INTO burnout_assessments (
                user_id,
                daily_checkin_id,
                wellness_scan_id,
                burnout_score,
                risk_level,
                assessment_source,
                factor_details,
                explanation,
                algorithm_version
            )
            VALUES (
                ?,
                NULL,
                ?,
                ?,
                ?,
                'wellness_scan',
                ?,
                ?,
                '1.0'
            )
            `,
            [
                userId,
                scanId,
                totalScore,
                riskLevel,
                JSON.stringify(
                    mainFactors
                ),
                summary
            ]
        );

        await connection.commit();

        return getScanById(
            userId,
            scanId
        );
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function getLatestScan(userId) {
    await ensureActiveUser(
        pool,
        userId
    );

    const [rows] =
        await pool.execute(
            `
            SELECT id
            FROM wellness_scans
            WHERE user_id = ?
            ORDER BY
                completed_at DESC,
                id DESC
            LIMIT 1
            `,
            [userId]
        );

    if (!rows[0]) {
        return null;
    }

    return getScanById(
        userId,
        rows[0].id
    );
}

async function getScanHistory(
    userId,
    options
) {
    await ensureActiveUser(
        pool,
        userId
    );

    const offset =
        (options.page - 1) *
        options.limit;

    const [countRows] =
        await pool.execute(
            `
            SELECT COUNT(*) AS total
            FROM wellness_scans
            WHERE user_id = ?
            `,
            [userId]
        );

    const [rows] =
        await pool.execute(
            `
            SELECT *
            FROM wellness_scans
            WHERE user_id = ?
            ORDER BY
                completed_at DESC,
                id DESC
            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            [userId]
        );

    const total =
        Number(countRows[0].total);

    return {
        scans:
            rows.map(mapScan),

        pagination: {
            page: options.page,
            limit: options.limit,
            total,
            total_pages:
                Math.ceil(
                    total /
                    options.limit
                )
        }
    };
}

async function getLatestBurnout(userId) {
    await ensureActiveUser(
        pool,
        userId
    );

    const [rows] =
        await pool.execute(
            `
            SELECT
                id,
                burnout_score,
                risk_level,
                assessment_source,
                factor_details,
                explanation,
                algorithm_version,
                assessed_at
            FROM burnout_assessments
            WHERE user_id = ?
            ORDER BY
                assessed_at DESC,
                id DESC
            LIMIT 1
            `,
            [userId]
        );

    return rows[0]
        ? mapBurnout(rows[0])
        : null;
}

module.exports = {
    submitCheckin,
    getTodayCheckin,
    getCheckinHistory,
    listQuestions,
    submitScan,
    getScanById,
    getLatestScan,
    getScanHistory,
    getLatestBurnout
};
