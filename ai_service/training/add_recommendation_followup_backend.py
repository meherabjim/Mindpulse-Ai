from datetime import datetime
from pathlib import Path
import shutil


ROOT = Path(
    r"E:\project 3\MindPulse-AI"
)

BACKEND = ROOT / "backend"
SRC = BACKEND / "src"

APP_FILE = SRC / "app.js"

SERVICE_FILE = (
    SRC
    / "services"
    / "recommendationSession.service.js"
)

VALIDATOR_FILE = (
    SRC
    / "validators"
    / "recommendationSession.validator.js"
)

CONTROLLER_FILE = (
    SRC
    / "controllers"
    / "recommendationSession.controller.js"
)

ROUTES_FILE = (
    SRC
    / "routes"
    / "recommendationSession.routes.js"
)

SQL_FILE = (
    ROOT
    / "database"
    / "recommendation_sessions.sql"
)

MIGRATION_RUNNER = (
    BACKEND
    / "scripts"
    / "runRecommendationSessionMigration.js"
)


if not APP_FILE.exists():
    raise RuntimeError(
        f"Backend app file was not found: "
        f"{APP_FILE}"
    )


backup_dir = (
    ROOT
    / "backups"
    / (
        "recommendation_followup_backend_"
        + datetime.now().strftime(
            "%Y%m%d_%H%M%S"
        )
    )
)

backup_dir.mkdir(
    parents=True,
    exist_ok=True,
)

shutil.copy2(
    APP_FILE,
    backup_dir / APP_FILE.name,
)


for directory in (
    SERVICE_FILE.parent,
    VALIDATOR_FILE.parent,
    CONTROLLER_FILE.parent,
    ROUTES_FILE.parent,
    SQL_FILE.parent,
    MIGRATION_RUNNER.parent,
):
    directory.mkdir(
        parents=True,
        exist_ok=True,
    )


SQL_FILE.write_text(
r'''CREATE TABLE IF NOT EXISTS recommendation_sessions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    user_id BIGINT UNSIGNED NOT NULL,

    client_session_key VARCHAR(80) NOT NULL,

    recommendation_source VARCHAR(40)
        NOT NULL DEFAULT 'ai_wellness',

    recommendation_category VARCHAR(60)
        NOT NULL,

    recommendation_title VARCHAR(180)
        NOT NULL,

    recommendation_action VARCHAR(1500)
        NOT NULL,

    priority_level ENUM(
        'low',
        'medium',
        'high'
    ) NOT NULL DEFAULT 'medium',

    suggested_duration_seconds
        INT UNSIGNED NOT NULL,

    actual_duration_seconds
        INT UNSIGNED NOT NULL DEFAULT 0,

    status ENUM(
        'started',
        'completed',
        'abandoned',
        'remind_later'
    ) NOT NULL DEFAULT 'started',

    before_mood TINYINT UNSIGNED NULL,
    before_stress TINYINT UNSIGNED NULL,

    after_mood TINYINT UNSIGNED NULL,
    after_stress TINYINT UNSIGNED NULL,

    feedback_type ENUM(
        'helpful',
        'neutral',
        'not_useful'
    ) NULL,

    feedback_note VARCHAR(500) NULL,

    tracking_source ENUM(
        'in_app_timer',
        'self_report'
    ) NOT NULL DEFAULT 'in_app_timer',

    started_at DATETIME
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    ended_at DATETIME NULL,

    created_at DATETIME
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at DATETIME
        NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY
        uq_recommendation_session_client (
            user_id,
            client_session_key
        ),

    KEY
        idx_recommendation_session_user_date (
            user_id,
            started_at
        ),

    KEY
        idx_recommendation_session_user_status (
            user_id,
            status
        ),

    KEY
        idx_recommendation_session_category (
            recommendation_category
        ),

    CONSTRAINT
        fk_recommendation_session_user

        FOREIGN KEY (user_id)
        REFERENCES users (id)
        ON DELETE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_unicode_ci;
''',
    encoding="utf-8",
)


VALIDATOR_FILE.write_text(
r'''const SOURCES = new Set([
    'ai_wellness',
    'wellness_scan',
    'recovery',
    'manual'
]);

const PRIORITIES = new Set([
    'low',
    'medium',
    'high'
]);

const TRACKING_SOURCES = new Set([
    'in_app_timer',
    'self_report'
]);

const TERMINAL_STATUSES = new Set([
    'completed',
    'abandoned',
    'remind_later'
]);

const FEEDBACK_TYPES = new Set([
    'helpful',
    'neutral',
    'not_useful'
]);


function isPlainObject(value) {
    return (
        value !== null &&
        typeof value === 'object' &&
        !Array.isArray(value)
    );
}


function normalizedString(
    value,
    {
        label,
        minimum,
        maximum,
        required = true
    },
    errors
) {
    if (
        value === undefined ||
        value === null
    ) {
        if (required) {
            errors.push(
                `${label} is required.`
            );
        }

        return null;
    }

    if (typeof value !== 'string') {
        errors.push(
            `${label} must be a string.`
        );

        return null;
    }

    const text = value.trim();

    if (
        !text &&
        !required
    ) {
        return null;
    }

    if (
        text.length < minimum ||
        text.length > maximum
    ) {
        errors.push(
            `${label} must contain between ` +
            `${minimum} and ${maximum} characters.`
        );

        return null;
    }

    return text;
}


function optionalScale(
    value,
    label,
    errors
) {
    if (
        value === undefined ||
        value === null ||
        value === ''
    ) {
        return null;
    }

    const number = Number(value);

    if (
        !Number.isInteger(number) ||
        number < 1 ||
        number > 5
    ) {
        errors.push(
            `${label} must be an integer from 1 to 5.`
        );

        return null;
    }

    return number;
}


function validateStart(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Recommendation session data must be an object.'
            ],
            data
        };
    }

    data.client_session_key =
        normalizedString(
            body.client_session_key,
            {
                label:
                    'Client session key',
                minimum: 10,
                maximum: 80
            },
            errors
        );

    if (
        data.client_session_key &&
        !/^[A-Za-z0-9_.:-]+$/.test(
            data.client_session_key
        )
    ) {
        errors.push(
            'Client session key contains invalid characters.'
        );
    }

    const source =
        body.recommendation_source ||
        'ai_wellness';

    if (!SOURCES.has(source)) {
        errors.push(
            'Recommendation source is invalid.'
        );
    } else {
        data.recommendation_source =
            source;
    }

    data.recommendation_category =
        normalizedString(
            body.recommendation_category,
            {
                label:
                    'Recommendation category',
                minimum: 2,
                maximum: 60
            },
            errors
        );

    data.recommendation_title =
        normalizedString(
            body.recommendation_title,
            {
                label:
                    'Recommendation title',
                minimum: 2,
                maximum: 180
            },
            errors
        );

    data.recommendation_action =
        normalizedString(
            body.recommendation_action,
            {
                label:
                    'Recommendation action',
                minimum: 2,
                maximum: 1500
            },
            errors
        );

    const priority =
        body.priority_level ||
        'medium';

    if (!PRIORITIES.has(priority)) {
        errors.push(
            'Priority level is invalid.'
        );
    } else {
        data.priority_level =
            priority;
    }

    const suggestedDuration =
        Number(
            body.suggested_duration_seconds
        );

    if (
        !Number.isInteger(
            suggestedDuration
        ) ||
        suggestedDuration < 30 ||
        suggestedDuration > 7200
    ) {
        errors.push(
            'Suggested duration must be an integer ' +
            'from 30 to 7200 seconds.'
        );
    } else {
        data.suggested_duration_seconds =
            suggestedDuration;
    }

    data.before_mood =
        optionalScale(
            body.before_mood,
            'Before mood',
            errors
        );

    data.before_stress =
        optionalScale(
            body.before_stress,
            'Before stress',
            errors
        );

    const trackingSource =
        body.tracking_source ||
        'in_app_timer';

    if (
        !TRACKING_SOURCES.has(
            trackingSource
        )
    ) {
        errors.push(
            'Tracking source is invalid.'
        );
    } else {
        data.tracking_source =
            trackingSource;
    }

    return {
        errors,
        data
    };
}


function validateFinish(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Recommendation completion data must be an object.'
            ],
            data
        };
    }

    if (
        !TERMINAL_STATUSES.has(
            body.status
        )
    ) {
        errors.push(
            'Status must be completed, abandoned, or remind_later.'
        );
    } else {
        data.status =
            body.status;
    }

    const actualDuration =
        Number(
            body.actual_duration_seconds
        );

    if (
        !Number.isInteger(
            actualDuration
        ) ||
        actualDuration < 0 ||
        actualDuration > 86400
    ) {
        errors.push(
            'Actual duration must be an integer ' +
            'from 0 to 86400 seconds.'
        );
    } else {
        data.actual_duration_seconds =
            actualDuration;
    }

    data.after_mood =
        optionalScale(
            body.after_mood,
            'After mood',
            errors
        );

    data.after_stress =
        optionalScale(
            body.after_stress,
            'After stress',
            errors
        );

    if (
        body.feedback_type === undefined ||
        body.feedback_type === null ||
        body.feedback_type === ''
    ) {
        data.feedback_type = null;
    } else if (
        !FEEDBACK_TYPES.has(
            body.feedback_type
        )
    ) {
        errors.push(
            'Feedback type is invalid.'
        );
    } else {
        data.feedback_type =
            body.feedback_type;
    }

    data.feedback_note =
        normalizedString(
            body.feedback_note,
            {
                label:
                    'Feedback note',
                minimum: 1,
                maximum: 500,
                required: false
            },
            errors
        );

    return {
        errors,
        data
    };
}


function validatePositiveId(
    value
) {
    const id = Number(value);

    if (
        !Number.isSafeInteger(id) ||
        id <= 0
    ) {
        return {
            errors: [
                'Recommendation session ID must be a positive integer.'
            ],
            id: null
        };
    }

    return {
        errors: [],
        id
    };
}


function validateHistoryQuery(
    query = {}
) {
    const errors = [];

    const page =
        query.page === undefined
            ? 1
            : Number(query.page);

    const limit =
        query.limit === undefined
            ? 20
            : Number(query.limit);

    if (
        !Number.isInteger(page) ||
        page < 1
    ) {
        errors.push(
            'Page must be a positive integer.'
        );
    }

    if (
        !Number.isInteger(limit) ||
        limit < 1 ||
        limit > 100
    ) {
        errors.push(
            'Limit must be an integer from 1 to 100.'
        );
    }

    return {
        errors,
        data: {
            page:
                Number.isInteger(page) &&
                page > 0
                    ? page
                    : 1,

            limit:
                Number.isInteger(limit) &&
                limit >= 1 &&
                limit <= 100
                    ? limit
                    : 20
        }
    };
}


function validateSummaryQuery(
    query = {}
) {
    const days =
        query.days === undefined
            ? 7
            : Number(query.days);

    if (
        !Number.isInteger(days) ||
        days < 1 ||
        days > 90
    ) {
        return {
            errors: [
                'Summary days must be an integer from 1 to 90.'
            ],
            data: {
                days: 7
            }
        };
    }

    return {
        errors: [],
        data: {
            days
        }
    };
}


module.exports = {
    validateStart,
    validateFinish,
    validatePositiveId,
    validateHistoryQuery,
    validateSummaryQuery
};
''',
    encoding="utf-8",
)


SERVICE_FILE.write_text(
r'''const database =
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
''',
    encoding="utf-8",
)


CONTROLLER_FILE.write_text(
r'''const AppError =
    require('../utils/AppError');

const recommendationSessionService =
    require(
        '../services/' +
        'recommendationSession.service'
    );

const {
    validateStart,
    validateFinish,
    validatePositiveId,
    validateHistoryQuery,
    validateSummaryQuery
} = require(
    '../validators/' +
    'recommendationSession.validator'
);


function throwValidation(
    message,
    errors
) {
    if (
        errors.length > 0
    ) {
        throw new AppError(
            422,
            message,
            errors
        );
    }
}


async function startSession(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateStart(
            req.body
        );

        throwValidation(
            'Recommendation session validation failed.',
            errors
        );

        const session =
            await recommendationSessionService
                .startSession(
                    req.user.id,
                    data
                );

        return res.status(201).json({
            success: true,

            message:
                'Recommendation follow-up started.',

            data: {
                session
            }
        });
    } catch (error) {
        return next(error);
    }
}


async function finishSession(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id
            );

        throwValidation(
            'Recommendation session ID is invalid.',
            idResult.errors
        );

        const {
            errors,
            data
        } = validateFinish(
            req.body
        );

        throwValidation(
            'Recommendation follow-up validation failed.',
            errors
        );

        const session =
            await recommendationSessionService
                .finishSession(
                    req.user.id,
                    idResult.id,
                    data
                );

        return res.status(200).json({
            success: true,

            message:
                'Recommendation follow-up saved.',

            data: {
                session
            }
        });
    } catch (error) {
        return next(error);
    }
}


async function listHistory(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateHistoryQuery(
            req.query
        );

        throwValidation(
            'Recommendation history query is invalid.',
            errors
        );

        const result =
            await recommendationSessionService
                .listHistory(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,

            message:
                'Recommendation follow-up history retrieved.',

            data: result
        });
    } catch (error) {
        return next(error);
    }
}


async function getSummary(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateSummaryQuery(
            req.query
        );

        throwValidation(
            'Recommendation summary query is invalid.',
            errors
        );

        const summary =
            await recommendationSessionService
                .getSummary(
                    req.user.id,
                    data.days
                );

        return res.status(200).json({
            success: true,

            message:
                'Recommendation follow-up summary retrieved.',

            data: {
                summary
            }
        });
    } catch (error) {
        return next(error);
    }
}


module.exports = {
    startSession,
    finishSession,
    listHistory,
    getSummary
};
''',
    encoding="utf-8",
)


ROUTES_FILE.write_text(
r'''const express =
    require('express');

const recommendationSessionController =
    require(
        '../controllers/' +
        'recommendationSession.controller'
    );

const {
    authenticate
} = require(
    '../middleware/auth.middleware'
);


const router =
    express.Router();


router.use(
    authenticate
);


router.post(
    '/recommendation-sessions',
    recommendationSessionController
        .startSession
);


router.patch(
    '/recommendation-sessions/:id',
    recommendationSessionController
        .finishSession
);


router.get(
    '/recommendation-sessions/history',
    recommendationSessionController
        .listHistory
);


router.get(
    '/recommendation-sessions/summary',
    recommendationSessionController
        .getSummary
);


module.exports =
    router;
''',
    encoding="utf-8",
)


MIGRATION_RUNNER.write_text(
r'''const fs =
    require('fs');

const path =
    require('path');

const mysql =
    require('mysql2/promise');


require('dotenv').config({
    path: path.resolve(
        __dirname,
        '..',
        '.env'
    ),
    override: true
});


async function run() {
    const sqlPath =
        path.resolve(
            __dirname,
            '..',
            '..',
            'database',
            'recommendation_sessions.sql'
        );

    const sql =
        fs.readFileSync(
            sqlPath,
            'utf8'
        );

    const connection =
        await mysql.createConnection({
            host:
                process.env.DB_HOST ||
                '127.0.0.1',

            port:
                Number(
                    process.env.DB_PORT ||
                    3306
                ),

            user:
                process.env.DB_USER ||
                'root',

            password:
                process.env.DB_PASSWORD ||
                '',

            database:
                process.env.DB_NAME ||
                'mindpulse_ai',

            charset:
                'utf8mb4',

            multipleStatements:
                true
        });

    try {
        await connection.query(
            sql
        );

        const [rows] =
            await connection.execute(
                `
                SELECT
                    COUNT(*) AS column_count

                FROM information_schema.columns

                WHERE
                    table_schema =
                        DATABASE()

                    AND table_name =
                        'recommendation_sessions'
                `
            );

        console.log(
            'Recommendation session migration completed.'
        );

        console.log(
            'Table: recommendation_sessions'
        );

        console.log(
            'Column count:',
            Number(
                rows[0].column_count
            )
        );
    } finally {
        await connection.end();
    }
}


run().catch((error) => {
    console.error(
        'Recommendation session migration failed.'
    );

    console.error(
        error.message
    );

    process.exit(1);
});
''',
    encoding="utf-8",
)


app_text = APP_FILE.read_text(
    encoding="utf-8",
)


require_line = (
    "const recommendationSessionRoutes = "
    "require('./routes/"
    "recommendationSession.routes');"
)

if require_line not in app_text:
    marker = (
        "const aiRoutes = "
        "require('./routes/ai.routes');"
    )

    if marker not in app_text:
        raise RuntimeError(
            "AI route import marker was not found "
            "in backend app.js."
        )

    app_text = app_text.replace(
        marker,
        marker + "\n" + require_line,
        1,
    )


mount_line = (
    "app.use('/api/v1', "
    "recommendationSessionRoutes);"
)

if mount_line not in app_text:
    marker = (
        "app.use('/api/v1', "
        "engagementRoutes);"
    )

    if marker not in app_text:
        raise RuntimeError(
            "Engagement route mount marker "
            "was not found in backend app.js."
        )

    app_text = app_text.replace(
        marker,
        marker + "\n" + mount_line,
        1,
    )


APP_FILE.write_text(
    app_text,
    encoding="utf-8",
)


print(
    "Recommendation follow-up backend "
    "foundation created successfully."
)

print(
    f"Backup created: {backup_dir}"
)

print(
    f"Created: {SQL_FILE}"
)

print(
    f"Created: {SERVICE_FILE}"
)

print(
    f"Created: {VALIDATOR_FILE}"
)

print(
    f"Created: {CONTROLLER_FILE}"
)

print(
    f"Created: {ROUTES_FILE}"
)

print(
    f"Created: {MIGRATION_RUNNER}"
)

print(
    f"Updated: {APP_FILE}"
)

print(
    "No phone permission was added."
)
