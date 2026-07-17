const database =
    require('../config/database');

const AppError =
    require('../utils/AppError');


const pool =
    database.pool || database;


function numberValue(value) {
    return Number(value || 0);
}


async function ensureActiveUser(
    executor,
    userId
) {
    const [rows] =
        await executor.execute(
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

    if (
        !user ||
        user.deleted_at
    ) {
        throw new AppError(
            404,
            'User account was not found.'
        );
    }

    if (
        user.account_status !==
        'active'
    ) {
        throw new AppError(
            403,
            'User account is not active.'
        );
    }
}


function mapSession(row) {
    return {
        id:
            Number(row.id),

        client_session_key:
            row.client_session_key,

        recommendation_source:
            row.recommendation_source,

        recommendation_category:
            row.recommendation_category,

        recommendation_title:
            row.recommendation_title,

        recommendation_action:
            row.recommendation_action,

        priority_level:
            row.priority_level,

        suggested_duration_seconds:
            Number(
                row
                    .suggested_duration_seconds
            ),

        actual_duration_seconds:
            Number(
                row
                    .actual_duration_seconds ||
                0
            ),

        status:
            row.status,

        before_mood:
            row.before_mood === null
                ? null
                : Number(
                    row.before_mood
                ),

        before_stress:
            row.before_stress === null
                ? null
                : Number(
                    row.before_stress
                ),

        after_mood:
            row.after_mood === null
                ? null
                : Number(
                    row.after_mood
                ),

        after_stress:
            row.after_stress === null
                ? null
                : Number(
                    row.after_stress
                ),

        feedback_type:
            row.feedback_type,

        feedback_note:
            row.feedback_note,

        tracking_source:
            row.tracking_source,

        started_at:
            row.started_at,

        ended_at:
            row.ended_at,

        created_at:
            row.created_at,

        updated_at:
            row.updated_at
    };
}


async function getSessionById(
    userId,
    sessionId
) {
    const [rows] =
        await pool.execute(
            `
            SELECT *
            FROM recommendation_sessions
            WHERE
                id = ?
                AND user_id = ?
            LIMIT 1
            `,
            [
                sessionId,
                userId
            ]
        );

    if (!rows[0]) {
        throw new AppError(
            404,
            'Recommendation session was not found.'
        );
    }

    return mapSession(
        rows[0]
    );
}


async function startSession(
    userId,
    data
) {
    await ensureActiveUser(
        pool,
        userId
    );

    const [result] =
        await pool.execute(
            `
            INSERT INTO
                recommendation_sessions (
                    user_id,
                    client_session_key,
                    recommendation_source,
                    recommendation_category,
                    recommendation_title,
                    recommendation_action,
                    priority_level,
                    suggested_duration_seconds,
                    before_mood,
                    before_stress,
                    tracking_source,
                    status,
                    started_at
                )

            VALUES (
                ?, ?, ?, ?, ?, ?, ?,
                ?, ?, ?, ?,
                'started',
                CURRENT_TIMESTAMP
            )

            ON DUPLICATE KEY UPDATE
                id = LAST_INSERT_ID(id),
                updated_at =
                    CURRENT_TIMESTAMP
            `,
            [
                userId,
                data.client_session_key,
                data.recommendation_source,
                data.recommendation_category,
                data.recommendation_title,
                data.recommendation_action,
                data.priority_level,
                data
                    .suggested_duration_seconds,
                data.before_mood,
                data.before_stress,
                data.tracking_source
            ]
        );

    return getSessionById(
        userId,
        result.insertId
    );
}


async function finishSession(
    userId,
    sessionId,
    data
) {
    await ensureActiveUser(
        pool,
        userId
    );

    const [rows] =
        await pool.execute(
            `
            SELECT
                id,
                status
            FROM recommendation_sessions
            WHERE
                id = ?
                AND user_id = ?
            LIMIT 1
            `,
            [
                sessionId,
                userId
            ]
        );

    if (!rows[0]) {
        throw new AppError(
            404,
            'Recommendation session was not found.'
        );
    }

    if (
        rows[0].status !==
        'started'
    ) {
        return getSessionById(
            userId,
            sessionId
        );
    }

    await pool.execute(
        `
        UPDATE recommendation_sessions
        SET
            status = ?,
            actual_duration_seconds = ?,
            after_mood = ?,
            after_stress = ?,
            feedback_type = ?,
            feedback_note = ?,
            ended_at =
                CURRENT_TIMESTAMP

        WHERE
            id = ?
            AND user_id = ?
        `,
        [
            data.status,
            data.actual_duration_seconds,
            data.after_mood,
            data.after_stress,
            data.feedback_type,
            data.feedback_note,
            sessionId,
            userId
        ]
    );

    return getSessionById(
        userId,
        sessionId
    );
}


async function listHistory(
    userId,
    options
) {
    await ensureActiveUser(
        pool,
        userId
    );

    const offset =
        (
            options.page - 1
        ) *
        options.limit;

    const [countRows] =
        await pool.execute(
            `
            SELECT COUNT(*) AS total
            FROM recommendation_sessions
            WHERE user_id = ?
            `,
            [userId]
        );

    const [rows] =
        await pool.execute(
            `
            SELECT *
            FROM recommendation_sessions
            WHERE user_id = ?
            ORDER BY
                started_at DESC,
                id DESC
            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            [userId]
        );

    const total =
        numberValue(
            countRows[0].total
        );

    return {
        sessions:
            rows.map(mapSession),

        pagination: {
            page:
                options.page,

            limit:
                options.limit,

            total,

            total_pages:
                Math.ceil(
                    total /
                    options.limit
                )
        }
    };
}


async function getSummary(
    userId,
    days
) {
    await ensureActiveUser(
        pool,
        userId
    );

    const [summaryRows] =
        await pool.execute(
            `
            SELECT
                COUNT(*) AS total_sessions,

                COALESCE(
                    SUM(
                        status =
                            'completed'
                    ),
                    0
                ) AS completed_sessions,

                COALESCE(
                    SUM(
                        status =
                            'abandoned'
                    ),
                    0
                ) AS abandoned_sessions,

                COALESCE(
                    SUM(
                        status =
                            'remind_later'
                    ),
                    0
                ) AS remind_later_sessions,

                COALESCE(
                    SUM(
                        feedback_type =
                            'helpful'
                    ),
                    0
                ) AS helpful_sessions,

                COALESCE(
                    SUM(
                        feedback_type =
                            'not_useful'
                    ),
                    0
                ) AS not_useful_sessions,

                COALESCE(
                    SUM(
                        actual_duration_seconds
                    ),
                    0
                ) AS total_duration_seconds,

                ROUND(
                    AVG(
                        CASE
                            WHEN status =
                                'completed'
                            THEN
                                actual_duration_seconds
                            ELSE NULL
                        END
                    ),
                    2
                ) AS average_completed_seconds

            FROM recommendation_sessions

            WHERE
                user_id = ?

                AND started_at >=
                    DATE_SUB(
                        CURRENT_TIMESTAMP,
                        INTERVAL ${days} DAY
                    )
            `,
            [userId]
        );

    const [categoryRows] =
        await pool.execute(
            `
            SELECT
                recommendation_category
                    AS category,

                COUNT(*) AS total,

                COALESCE(
                    SUM(
                        status =
                            'completed'
                    ),
                    0
                ) AS completed,

                COALESCE(
                    SUM(
                        feedback_type =
                            'helpful'
                    ),
                    0
                ) AS helpful,

                ROUND(
                    AVG(
                        CASE
                            WHEN status =
                                'completed'
                            THEN
                                actual_duration_seconds
                            ELSE NULL
                        END
                    ),
                    2
                ) AS
                    average_completed_seconds

            FROM recommendation_sessions

            WHERE
                user_id = ?

                AND started_at >=
                    DATE_SUB(
                        CURRENT_TIMESTAMP,
                        INTERVAL ${days} DAY
                    )

            GROUP BY
                recommendation_category

            ORDER BY
                completed DESC,
                helpful DESC,
                total DESC
            `,
            [userId]
        );

    const row =
        summaryRows[0];

    return {
        period_days:
            days,

        total_sessions:
            numberValue(
                row.total_sessions
            ),

        completed_sessions:
            numberValue(
                row.completed_sessions
            ),

        abandoned_sessions:
            numberValue(
                row.abandoned_sessions
            ),

        remind_later_sessions:
            numberValue(
                row.remind_later_sessions
            ),

        helpful_sessions:
            numberValue(
                row.helpful_sessions
            ),

        not_useful_sessions:
            numberValue(
                row.not_useful_sessions
            ),

        total_duration_seconds:
            numberValue(
                row.total_duration_seconds
            ),

        average_completed_seconds:
            row.average_completed_seconds ===
            null
                ? null
                : Number(
                    row
                        .average_completed_seconds
                ),

        categories:
            categoryRows.map(
                (category) => ({
                    category:
                        category.category,

                    total:
                        numberValue(
                            category.total
                        ),

                    completed:
                        numberValue(
                            category.completed
                        ),

                    helpful:
                        numberValue(
                            category.helpful
                        ),

                    average_completed_seconds:
                        category
                            .average_completed_seconds ===
                        null
                            ? null
                            : Number(
                                category
                                    .average_completed_seconds
                            )
                })
            )
    };
}


module.exports = {
    startSession,
    finishSession,
    listHistory,
    getSummary,
    getSessionById
};
