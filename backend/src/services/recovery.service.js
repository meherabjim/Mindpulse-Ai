const database = require('../config/database');
const AppError = require('../utils/AppError');

const pool = database.pool || database;

function numberOrNull(value) {
    return value === null ||
        value === undefined
        ? null
        : Number(value);
}

function booleanValue(value) {
    return Boolean(Number(value));
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
        WHERE u.id = ?
        LIMIT 1
        `,
        [userId]
    );

    return rows[0]?.timezone ||
        'Asia/Dhaka';
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
            values[part.type] =
                part.value;
        });

        return `${values.year}-${values.month}-${values.day}`;
    } catch {
        return new Date()
            .toISOString()
            .slice(0, 10);
    }
}

function mapActivity(row) {
    return {
        id: Number(row.id),
        title: row.title,
        slug: row.slug,
        category: row.category,
        description: row.description,
        instructions: row.instructions,
        duration_minutes:
            Number(row.duration_minutes),
        difficulty_level:
            row.difficulty_level,
        icon_name: row.icon_name,
        audio_url: row.audio_url
    };
}

function mapTask(row) {
    return {
        id: Number(row.id),
        recovery_activity_id:
            row.recovery_activity_id === null
                ? null
                : Number(
                    row.recovery_activity_id
                ),
        activity_title:
            row.activity_title || null,
        title: row.title,
        description: row.description,
        task_type: row.task_type,
        target_value:
            numberOrNull(row.target_value),
        target_unit: row.target_unit,
        scheduled_date:
            row.scheduled_date,
        scheduled_time:
            row.scheduled_time,
        status: row.status,
        completed_at:
            row.completed_at,
        created_at: row.created_at,
        updated_at: row.updated_at
    };
}

function mapPlan(row) {
    return {
        id: Number(row.id),
        title: row.title,
        description: row.description,
        overall_goal: row.overall_goal,
        generated_by: row.generated_by,
        status: row.status,
        start_date: row.start_date,
        end_date: row.end_date,
        review_date: row.review_date,
        task_total:
            Number(row.task_total || 0),
        completed_tasks:
            Number(
                row.completed_tasks || 0
            ),
        progress_percent:
            Number(row.task_total || 0) === 0
                ? 0
                : Number(
                    (
                        Number(
                            row.completed_tasks || 0
                        ) /
                        Number(row.task_total) *
                        100
                    ).toFixed(2)
                ),
        created_at: row.created_at,
        updated_at: row.updated_at
    };
}

async function listActivities(userId) {
    await ensureActiveUser(pool, userId);

    const [rows] = await pool.execute(
        `
        SELECT
            id,
            title,
            slug,
            category,
            description,
            instructions,
            duration_minutes,
            difficulty_level,
            icon_name,
            audio_url
        FROM recovery_activities
        WHERE is_active = TRUE
        ORDER BY
            display_order ASC,
            id ASC
        `
    );

    return rows.map(mapActivity);
}

async function saveActivityLog(
    userId,
    activityId,
    logData
) {
    await ensureActiveUser(pool, userId);

    const [activityRows] =
        await pool.execute(
            `
            SELECT id
            FROM recovery_activities
            WHERE
                id = ?
                AND is_active = TRUE
            LIMIT 1
            `,
            [activityId]
        );

    if (!activityRows[0]) {
        throw new AppError(
            404,
            'Recovery activity was not found.'
        );
    }

    const [result] = await pool.execute(
        `
        INSERT INTO recovery_activity_logs (
            user_id,
            recovery_activity_id,
            status,
            started_at,
            completed_at,
            duration_seconds,
            rating,
            note
        )
        VALUES (
            ?,
            ?,
            ?,
            CURRENT_TIMESTAMP,
            CASE
                WHEN ? = 'completed'
                THEN CURRENT_TIMESTAMP
                ELSE NULL
            END,
            ?,
            ?,
            ?
        )
        `,
        [
            userId,
            activityId,
            logData.status,
            logData.status,
            logData.duration_seconds,
            logData.rating,
            logData.note
        ]
    );

    const [rows] = await pool.execute(
        `
        SELECT
            ral.id,
            ral.recovery_activity_id,
            ra.title AS activity_title,
            ral.status,
            ral.started_at,
            ral.completed_at,
            ral.duration_seconds,
            ral.rating,
            ral.note,
            ral.created_at
        FROM recovery_activity_logs AS ral
        INNER JOIN recovery_activities AS ra
            ON ra.id =
                ral.recovery_activity_id
        WHERE
            ral.id = ?
            AND ral.user_id = ?
        LIMIT 1
        `,
        [
            result.insertId,
            userId
        ]
    );

    return {
        id: Number(rows[0].id),
        recovery_activity_id:
            Number(
                rows[0]
                    .recovery_activity_id
            ),
        activity_title:
            rows[0].activity_title,
        status: rows[0].status,
        started_at:
            rows[0].started_at,
        completed_at:
            rows[0].completed_at,
        duration_seconds:
            numberOrNull(
                rows[0].duration_seconds
            ),
        rating:
            numberOrNull(rows[0].rating),
        note: rows[0].note,
        created_at:
            rows[0].created_at
    };
}

async function listActivityLogs(
    userId,
    options
) {
    await ensureActiveUser(pool, userId);

    const offset =
        (options.page - 1) *
        options.limit;

    const [countRows] =
        await pool.execute(
            `
            SELECT COUNT(*) AS total
            FROM recovery_activity_logs
            WHERE user_id = ?
            `,
            [userId]
        );

    const [rows] = await pool.execute(
        `
        SELECT
            ral.id,
            ral.recovery_activity_id,
            ra.title AS activity_title,
            ral.status,
            ral.started_at,
            ral.completed_at,
            ral.duration_seconds,
            ral.rating,
            ral.note,
            ral.created_at
        FROM recovery_activity_logs AS ral
        INNER JOIN recovery_activities AS ra
            ON ra.id =
                ral.recovery_activity_id
        WHERE ral.user_id = ?
        ORDER BY
            ral.started_at DESC,
            ral.id DESC
        LIMIT ${options.limit}
        OFFSET ${offset}
        `,
        [userId]
    );

    const total =
        Number(countRows[0].total);

    return {
        logs: rows.map((row) => ({
            id: Number(row.id),
            recovery_activity_id:
                Number(
                    row.recovery_activity_id
                ),
            activity_title:
                row.activity_title,
            status: row.status,
            started_at:
                row.started_at,
            completed_at:
                row.completed_at,
            duration_seconds:
                numberOrNull(
                    row.duration_seconds
                ),
            rating:
                numberOrNull(row.rating),
            note: row.note,
            created_at:
                row.created_at
        })),

        pagination: {
            page: options.page,
            limit: options.limit,
            total,
            total_pages:
                Math.ceil(
                    total / options.limit
                )
        }
    };
}

async function verifyActivityIds(
    executor,
    tasks
) {
    const activityIds = [
        ...new Set(
            tasks
                .map(
                    (task) =>
                        task.recovery_activity_id
                )
                .filter(Boolean)
        )
    ];

    if (activityIds.length === 0) {
        return;
    }

    const placeholders =
        activityIds.map(() => '?').join(',');

    const [rows] = await executor.execute(
        `
        SELECT id
        FROM recovery_activities
        WHERE
            id IN (${placeholders})
            AND is_active = TRUE
        `,
        activityIds
    );

    if (rows.length !== activityIds.length) {
        throw new AppError(
            422,
            'One or more recovery activities are invalid or inactive.'
        );
    }
}

async function createPlan(
    userId,
    planData
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        await verifyActivityIds(
            connection,
            planData.tasks
        );

        const timezone =
            await getUserTimezone(userId);

        const startDate =
            planData.start_date ||
            getDateInTimezone(timezone);

        const [result] =
            await connection.execute(
                `
                INSERT INTO recovery_plans (
                    user_id,
                    title,
                    description,
                    overall_goal,
                    generated_by,
                    status,
                    start_date,
                    end_date,
                    review_date
                )
                VALUES (
                    ?, ?, ?, ?, ?,
                    'active', ?, ?, ?
                )
                `,
                [
                    userId,
                    planData.title,
                    planData.description,
                    planData.overall_goal,
                    planData.generated_by,
                    startDate,
                    planData.end_date,
                    planData.review_date
                ]
            );

        const planId =
            result.insertId;

        for (const task of planData.tasks) {
            await connection.execute(
                `
                INSERT INTO recovery_plan_tasks (
                    recovery_plan_id,
                    recovery_activity_id,
                    title,
                    description,
                    task_type,
                    target_value,
                    target_unit,
                    scheduled_date,
                    scheduled_time,
                    status
                )
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, 'pending'
                )
                `,
                [
                    planId,
                    task.recovery_activity_id,
                    task.title,
                    task.description,
                    task.task_type,
                    task.target_value,
                    task.target_unit,
                    task.scheduled_date ||
                        startDate,
                    task.scheduled_time
                ]
            );
        }

        await connection.commit();

        return getPlanById(
            userId,
            planId
        );
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function getPlanRows(
    userId,
    extraCondition = '',
    parameters = []
) {
    const [rows] = await pool.execute(
        `
        SELECT
            rp.id,
            rp.title,
            rp.description,
            rp.overall_goal,
            rp.generated_by,
            rp.status,
            DATE_FORMAT(
                rp.start_date,
                '%Y-%m-%d'
            ) AS start_date,
            DATE_FORMAT(
                rp.end_date,
                '%Y-%m-%d'
            ) AS end_date,
            DATE_FORMAT(
                rp.review_date,
                '%Y-%m-%d'
            ) AS review_date,
            rp.created_at,
            rp.updated_at,

            COUNT(rpt.id)
                AS task_total,

            SUM(
                CASE
                    WHEN rpt.status =
                        'completed'
                    THEN 1
                    ELSE 0
                END
            ) AS completed_tasks

        FROM recovery_plans AS rp

        LEFT JOIN recovery_plan_tasks AS rpt
            ON rpt.recovery_plan_id =
                rp.id

        WHERE
            rp.user_id = ?
            ${extraCondition}

        GROUP BY
            rp.id,
            rp.title,
            rp.description,
            rp.overall_goal,
            rp.generated_by,
            rp.status,
            rp.start_date,
            rp.end_date,
            rp.review_date,
            rp.created_at,
            rp.updated_at

        ORDER BY
            rp.created_at DESC,
            rp.id DESC
        `,
        [
            userId,
            ...parameters
        ]
    );

    return rows;
}

async function getPlanById(
    userId,
    planId
) {
    await ensureActiveUser(pool, userId);

    const rows = await getPlanRows(
        userId,
        'AND rp.id = ?',
        [planId]
    );

    if (!rows[0]) {
        throw new AppError(
            404,
            'Recovery plan was not found.'
        );
    }

    const plan =
        mapPlan(rows[0]);

    const [taskRows] =
        await pool.execute(
            `
            SELECT
                rpt.*,
                ra.title AS activity_title
            FROM recovery_plan_tasks AS rpt
            LEFT JOIN recovery_activities AS ra
                ON ra.id =
                    rpt.recovery_activity_id
            WHERE rpt.recovery_plan_id = ?
            ORDER BY
                rpt.scheduled_date ASC,
                rpt.scheduled_time ASC,
                rpt.id ASC
            `,
            [planId]
        );

    plan.tasks =
        taskRows.map(mapTask);

    return plan;
}

async function listPlans(userId) {
    await ensureActiveUser(pool, userId);

    const rows =
        await getPlanRows(userId);

    return rows.map(mapPlan);
}

async function getActivePlan(userId) {
    await ensureActiveUser(pool, userId);

    const rows = await getPlanRows(
        userId,
        "AND rp.status = 'active'"
    );

    if (!rows[0]) {
        return null;
    }

    return getPlanById(
        userId,
        rows[0].id
    );
}

async function updatePlanStatus(
    userId,
    planId,
    status
) {
    await ensureActiveUser(pool, userId);

    const [result] =
        await pool.execute(
            `
            UPDATE recovery_plans
            SET status = ?
            WHERE
                id = ?
                AND user_id = ?
            `,
            [
                status,
                planId,
                userId
            ]
        );

    if (result.affectedRows === 0) {
        throw new AppError(
            404,
            'Recovery plan was not found.'
        );
    }

    return getPlanById(
        userId,
        planId
    );
}

async function updateTask(
    userId,
    taskId,
    taskData
) {
    await ensureActiveUser(pool, userId);

    const [ownershipRows] =
        await pool.execute(
            `
            SELECT rpt.id
            FROM recovery_plan_tasks AS rpt
            INNER JOIN recovery_plans AS rp
                ON rp.id =
                    rpt.recovery_plan_id
            WHERE
                rpt.id = ?
                AND rp.user_id = ?
            LIMIT 1
            `,
            [
                taskId,
                userId
            ]
        );

    if (!ownershipRows[0]) {
        throw new AppError(
            404,
            'Recovery task was not found.'
        );
    }

    const columnMap = {
        title: 'title',
        description: 'description',
        scheduled_date:
            'scheduled_date',
        scheduled_time:
            'scheduled_time',
        status: 'status'
    };

    const entries =
        Object.entries(taskData)
            .filter(
                ([key]) =>
                    columnMap[key]
            );

    const assignments = entries
        .map(
            ([key]) =>
                `${columnMap[key]} = ?`
        );

    const values =
        entries.map(([, value]) => value);

    if (
        Object.prototype.hasOwnProperty.call(
            taskData,
            'status'
        )
    ) {
        assignments.push(
            `
            completed_at =
                CASE
                    WHEN ? = 'completed'
                    THEN COALESCE(
                        completed_at,
                        CURRENT_TIMESTAMP
                    )
                    ELSE NULL
                END
            `
        );

        values.push(taskData.status);
    }

    await pool.execute(
        `
        UPDATE recovery_plan_tasks
        SET ${assignments.join(', ')}
        WHERE id = ?
        `,
        [
            ...values,
            taskId
        ]
    );

    const [rows] = await pool.execute(
        `
        SELECT
            rpt.*,
            ra.title AS activity_title
        FROM recovery_plan_tasks AS rpt
        LEFT JOIN recovery_activities AS ra
            ON ra.id =
                rpt.recovery_activity_id
        WHERE rpt.id = ?
        LIMIT 1
        `,
        [taskId]
    );

    return mapTask(rows[0]);
}

function sleepRecoveryScore(hours) {
    if (hours >= 7 && hours <= 9) {
        return 100;
    }

    if (
        (hours >= 6 && hours < 7) ||
        (hours > 9 && hours <= 10)
    ) {
        return 75;
    }

    if (
        (hours >= 5 && hours < 6) ||
        (hours > 10 && hours <= 11)
    ) {
        return 50;
    }

    return 25;
}

function calculateRecoveryScore(data) {
    const components = [];

    function add(value, weight) {
        if (
            value !== null &&
            value !== undefined
        ) {
            components.push({
                value,
                weight
            });
        }
    }

    add(data.mood_score, 0.15);

    add(
        data.stress_score === null
            ? null
            : 100 - data.stress_score,
        0.15
    );

    add(
        data.sleep_hours === null
            ? null
            : sleepRecoveryScore(
                data.sleep_hours
            ),
        0.15
    );

    add(data.energy_level, 0.15);

    add(
        data.habit_completion_percent,
        0.15
    );

    add(
        data.activity_completion_percent,
        0.10
    );

    add(
        data.burnout_score === null
            ? null
            : 100 - data.burnout_score,
        0.15
    );

    const totalWeight =
        components.reduce(
            (sum, item) =>
                sum + item.weight,
            0
        );

    const score =
        components.reduce(
            (sum, item) =>
                sum +
                item.value *
                    item.weight,
            0
        ) / totalWeight;

    return Number(score.toFixed(2));
}

async function saveProgress(
    userId,
    progressData
) {
    await ensureActiveUser(pool, userId);

    if (progressData.recovery_plan_id) {
        const [planRows] =
            await pool.execute(
                `
                SELECT id
                FROM recovery_plans
                WHERE
                    id = ?
                    AND user_id = ?
                LIMIT 1
                `,
                [
                    progressData
                        .recovery_plan_id,
                    userId
                ]
            );

        if (!planRows[0]) {
            throw new AppError(
                404,
                'Recovery plan was not found.'
            );
        }
    }

    const timezone =
        await getUserTimezone(userId);

    const progressDate =
        progressData.progress_date ||
        getDateInTimezone(timezone);

    const recoveryScore =
        calculateRecoveryScore(
            progressData
        );

    await pool.execute(
        `
        INSERT INTO recovery_progress (
            user_id,
            recovery_plan_id,
            progress_date,
            mood_score,
            stress_score,
            sleep_hours,
            energy_level,
            habit_completion_percent,
            activity_completion_percent,
            burnout_score,
            recovery_score,
            note
        )
        VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?,
            ?, ?, ?
        )

        ON DUPLICATE KEY UPDATE
            recovery_plan_id =
                VALUES(recovery_plan_id),
            mood_score =
                VALUES(mood_score),
            stress_score =
                VALUES(stress_score),
            sleep_hours =
                VALUES(sleep_hours),
            energy_level =
                VALUES(energy_level),
            habit_completion_percent =
                VALUES(
                    habit_completion_percent
                ),
            activity_completion_percent =
                VALUES(
                    activity_completion_percent
                ),
            burnout_score =
                VALUES(burnout_score),
            recovery_score =
                VALUES(recovery_score),
            note = VALUES(note)
        `,
        [
            userId,
            progressData.recovery_plan_id,
            progressDate,
            progressData.mood_score,
            progressData.stress_score,
            progressData.sleep_hours,
            progressData.energy_level,
            progressData
                .habit_completion_percent,
            progressData
                .activity_completion_percent,
            progressData.burnout_score,
            recoveryScore,
            progressData.note
        ]
    );

    const [rows] = await pool.execute(
        `
        SELECT *
        FROM recovery_progress
        WHERE
            user_id = ?
            AND progress_date = ?
        LIMIT 1
        `,
        [
            userId,
            progressDate
        ]
    );

    return {
        id: Number(rows[0].id),
        recovery_plan_id:
            rows[0].recovery_plan_id === null
                ? null
                : Number(
                    rows[0]
                        .recovery_plan_id
                ),
        progress_date:
            rows[0].progress_date,
        mood_score:
            numberOrNull(
                rows[0].mood_score
            ),
        stress_score:
            numberOrNull(
                rows[0].stress_score
            ),
        sleep_hours:
            numberOrNull(
                rows[0].sleep_hours
            ),
        energy_level:
            numberOrNull(
                rows[0].energy_level
            ),
        habit_completion_percent:
            numberOrNull(
                rows[0]
                    .habit_completion_percent
            ),
        activity_completion_percent:
            numberOrNull(
                rows[0]
                    .activity_completion_percent
            ),
        burnout_score:
            numberOrNull(
                rows[0].burnout_score
            ),
        recovery_score:
            Number(
                rows[0].recovery_score
            ),
        note: rows[0].note,
        created_at:
            rows[0].created_at,
        updated_at:
            rows[0].updated_at
    };
}

async function listProgress(
    userId,
    options
) {
    await ensureActiveUser(pool, userId);

    const offset =
        (options.page - 1) *
        options.limit;

    const [countRows] =
        await pool.execute(
            `
            SELECT COUNT(*) AS total
            FROM recovery_progress
            WHERE user_id = ?
            `,
            [userId]
        );

    const [rows] = await pool.execute(
        `
        SELECT *
        FROM recovery_progress
        WHERE user_id = ?
        ORDER BY
            progress_date DESC,
            id DESC
        LIMIT ${options.limit}
        OFFSET ${offset}
        `,
        [userId]
    );

    const total =
        Number(countRows[0].total);

    return {
        progress: rows.map((row) => ({
            id: Number(row.id),
            recovery_plan_id:
                row.recovery_plan_id === null
                    ? null
                    : Number(
                        row.recovery_plan_id
                    ),
            progress_date:
                row.progress_date,
            recovery_score:
                Number(
                    row.recovery_score
                ),
            mood_score:
                numberOrNull(
                    row.mood_score
                ),
            stress_score:
                numberOrNull(
                    row.stress_score
                ),
            sleep_hours:
                numberOrNull(
                    row.sleep_hours
                ),
            energy_level:
                numberOrNull(
                    row.energy_level
                ),
            habit_completion_percent:
                numberOrNull(
                    row
                        .habit_completion_percent
                ),
            activity_completion_percent:
                numberOrNull(
                    row
                        .activity_completion_percent
                ),
            burnout_score:
                numberOrNull(
                    row.burnout_score
                ),
            note: row.note
        })),

        pagination: {
            page: options.page,
            limit: options.limit,
            total,
            total_pages:
                Math.ceil(
                    total / options.limit
                )
        }
    };
}

module.exports = {
    listActivities,
    saveActivityLog,
    listActivityLogs,
    createPlan,
    listPlans,
    getActivePlan,
    getPlanById,
    updatePlanStatus,
    updateTask,
    saveProgress,
    listProgress
};
