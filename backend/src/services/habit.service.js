const database = require('../config/database');
const AppError = require('../utils/AppError');

const pool = database.pool || database;

const WEEKDAY_NAMES = [
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday'
];

function booleanValue(value) {
    return Boolean(Number(value));
}

function numberOrNull(value) {
    return value === null ||
        value === undefined
        ? null
        : Number(value);
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

function parseDate(value) {
    return new Date(
        `${value}T00:00:00Z`
    );
}

function formatDate(date) {
    return date
        .toISOString()
        .slice(0, 10);
}

function addDays(date, days) {
    const result =
        new Date(date.getTime());

    result.setUTCDate(
        result.getUTCDate() + days
    );

    return result;
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

function mapHabit(row) {
    return {
        id: Number(row.id),
        template_id:
            row.template_id === null
                ? null
                : Number(row.template_id),
        name: row.name,
        description:
            row.description,
        category:
            row.category,
        frequency_type:
            row.frequency_type,
        schedule_days:
            parseJson(
                row.schedule_days,
                null
            ),
        target_value:
            Number(row.target_value),
        unit: row.unit,
        reminder_enabled:
            booleanValue(
                row.reminder_enabled
            ),
        reminder_time:
            row.reminder_time,
        start_date:
            row.start_date,
        end_date:
            row.end_date,
        current_streak:
            Number(row.current_streak),
        longest_streak:
            Number(row.longest_streak),
        is_active:
            booleanValue(row.is_active),
        is_archived:
            booleanValue(row.is_archived),
        today_log:
            row.today_log || null,
        created_at:
            row.created_at,
        updated_at:
            row.updated_at
    };
}

function isScheduledOn(
    habit,
    dateString
) {
    if (
        dateString < habit.start_date ||
        (
            habit.end_date &&
            dateString > habit.end_date
        )
    ) {
        return false;
    }

    if (
        habit.frequency_type === 'daily'
    ) {
        return true;
    }

    const scheduleDays =
        parseJson(
            habit.schedule_days,
            []
        );

    const weekday =
        WEEKDAY_NAMES[
            parseDate(
                dateString
            ).getUTCDay()
        ];

    return scheduleDays.includes(
        weekday
    );
}

function validateResolvedHabit(habit) {
    if (!habit.name || !habit.category) {
        throw new AppError(
            422,
            'Habit name and category are required.'
        );
    }

    const scheduleDays =
        parseJson(
            habit.schedule_days,
            null
        );

    if (
        habit.frequency_type ===
            'specific_days' &&
        (
            !Array.isArray(scheduleDays) ||
            scheduleDays.length === 0
        )
    ) {
        throw new AppError(
            422,
            'Specific-day habits require at least one schedule day.'
        );
    }

    if (
        habit.frequency_type === 'weekly' &&
        (
            !Array.isArray(scheduleDays) ||
            scheduleDays.length !== 1
        )
    ) {
        throw new AppError(
            422,
            'Weekly habits require exactly one schedule day.'
        );
    }

    if (
        habit.end_date &&
        habit.end_date < habit.start_date
    ) {
        throw new AppError(
            422,
            'Habit end date cannot be earlier than its start date.'
        );
    }
}

async function listTemplates(userId) {
    await ensureActiveUser(pool, userId);

    const [rows] = await pool.execute(
        `
        SELECT
            id,
            name,
            category,
            description,
            icon_name,
            default_target_value,
            default_unit,
            display_order
        FROM habit_templates
        WHERE is_active = TRUE
        ORDER BY
            display_order ASC,
            id ASC
        `
    );

    return rows.map((row) => ({
        id: Number(row.id),
        name: row.name,
        category:
            row.category,
        description:
            row.description,
        icon_name:
            row.icon_name,
        default_target_value:
            numberOrNull(
                row.default_target_value
            ),
        default_unit:
            row.default_unit,
        display_order:
            Number(row.display_order)
    }));
}

async function getHabitRow(
    executor,
    userId,
    habitId,
    lock = false
) {
    const [rows] = await executor.execute(
        `
        SELECT
            h.id,
            h.template_id,
            h.name,
            h.description,
            h.category,
            h.frequency_type,
            h.schedule_days,
            h.target_value,
            h.unit,
            h.reminder_enabled,
            h.reminder_time,
            DATE_FORMAT(
                h.start_date,
                '%Y-%m-%d'
            ) AS start_date,
            DATE_FORMAT(
                h.end_date,
                '%Y-%m-%d'
            ) AS end_date,
            h.current_streak,
            h.longest_streak,
            h.is_active,
            h.is_archived,
            h.created_at,
            h.updated_at
        FROM habits AS h
        WHERE
            h.id = ?
            AND h.user_id = ?
            AND h.deleted_at IS NULL
        LIMIT 1
        ${lock ? 'FOR UPDATE' : ''}
        `,
        [
            habitId,
            userId
        ]
    );

    return rows[0] || null;
}

async function getHabitById(
    userId,
    habitId
) {
    await ensureActiveUser(pool, userId);

    const row =
        await getHabitRow(
            pool,
            userId,
            habitId
        );

    if (!row) {
        throw new AppError(
            404,
            'Habit was not found.'
        );
    }

    const timezone =
        await getUserTimezone(userId);

    const today =
        getDateInTimezone(timezone);

    const [logRows] =
        await pool.execute(
            `
            SELECT
                id,
                DATE_FORMAT(
                    log_date,
                    '%Y-%m-%d'
                ) AS log_date,
                status,
                completed_value,
                note,
                completed_at
            FROM habit_logs
            WHERE
                habit_id = ?
                AND log_date = ?
            LIMIT 1
            `,
            [
                habitId,
                today
            ]
        );

    if (logRows[0]) {
        row.today_log = {
            id: Number(logRows[0].id),
            log_date:
                logRows[0].log_date,
            status:
                logRows[0].status,
            completed_value:
                numberOrNull(
                    logRows[0]
                        .completed_value
                ),
            note:
                logRows[0].note,
            completed_at:
                logRows[0].completed_at
        };
    }

    return mapHabit(row);
}

async function createHabit(
    userId,
    habitData
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        let template = null;

        if (habitData.template_id) {
            const [templateRows] =
                await connection.execute(
                    `
                    SELECT *
                    FROM habit_templates
                    WHERE
                        id = ?
                        AND is_active = TRUE
                    LIMIT 1
                    `,
                    [habitData.template_id]
                );

            template =
                templateRows[0];

            if (!template) {
                throw new AppError(
                    404,
                    'Habit template was not found.'
                );
            }
        }

        const timezone =
            await getUserTimezone(userId);

        const today =
            getDateInTimezone(timezone);

        const resolvedHabit = {
            template_id:
                habitData.template_id ||
                null,

            name:
                habitData.name ||
                template?.name,

            description:
                habitData.description ??
                template?.description ??
                null,

            category:
                habitData.category ||
                template?.category,

            frequency_type:
                habitData.frequency_type ||
                'daily',

            schedule_days:
                habitData.schedule_days
                    ? JSON.stringify(
                        habitData.schedule_days
                    )
                    : null,

            target_value:
                habitData.target_value ??
                template
                    ?.default_target_value ??
                1,

            unit:
                habitData.unit ??
                template?.default_unit ??
                null,

            reminder_enabled:
                habitData.reminder_enabled,

            reminder_time:
                habitData.reminder_time,

            start_date:
                habitData.start_date ||
                today,

            end_date:
                habitData.end_date
        };

        validateResolvedHabit(
            resolvedHabit
        );

        const [result] =
            await connection.execute(
                `
                INSERT INTO habits (
                    user_id,
                    template_id,
                    name,
                    description,
                    category,
                    frequency_type,
                    schedule_days,
                    target_value,
                    unit,
                    reminder_enabled,
                    reminder_time,
                    start_date,
                    end_date
                )
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, ?
                )
                `,
                [
                    userId,
                    resolvedHabit.template_id,
                    resolvedHabit.name,
                    resolvedHabit.description,
                    resolvedHabit.category,
                    resolvedHabit.frequency_type,
                    resolvedHabit.schedule_days,
                    resolvedHabit.target_value,
                    resolvedHabit.unit,
                    Number(
                        resolvedHabit
                            .reminder_enabled
                    ),
                    resolvedHabit.reminder_time,
                    resolvedHabit.start_date,
                    resolvedHabit.end_date
                ]
            );

        await connection.commit();

        return getHabitById(
            userId,
            result.insertId
        );
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function listHabits(userId) {
    await ensureActiveUser(pool, userId);

    const timezone =
        await getUserTimezone(userId);

    const today =
        getDateInTimezone(timezone);

    const [rows] = await pool.execute(
        `
        SELECT
            h.id,
            h.template_id,
            h.name,
            h.description,
            h.category,
            h.frequency_type,
            h.schedule_days,
            h.target_value,
            h.unit,
            h.reminder_enabled,
            h.reminder_time,
            DATE_FORMAT(
                h.start_date,
                '%Y-%m-%d'
            ) AS start_date,
            DATE_FORMAT(
                h.end_date,
                '%Y-%m-%d'
            ) AS end_date,
            h.current_streak,
            h.longest_streak,
            h.is_active,
            h.is_archived,
            h.created_at,
            h.updated_at,

            hl.id AS today_log_id,
            hl.status AS today_status,
            hl.completed_value
                AS today_completed_value,
            hl.note AS today_note,
            hl.completed_at
                AS today_completed_at

        FROM habits AS h

        LEFT JOIN habit_logs AS hl
            ON hl.habit_id = h.id
            AND hl.log_date = ?

        WHERE
            h.user_id = ?
            AND h.deleted_at IS NULL
            AND h.is_archived = FALSE

        ORDER BY
            h.is_active DESC,
            h.created_at DESC
        `,
        [
            today,
            userId
        ]
    );

    rows.forEach((row) => {
        if (row.today_log_id) {
            row.today_log = {
                id:
                    Number(
                        row.today_log_id
                    ),
                log_date: today,
                status:
                    row.today_status,
                completed_value:
                    numberOrNull(
                        row
                            .today_completed_value
                    ),
                note:
                    row.today_note,
                completed_at:
                    row.today_completed_at
            };
        }
    });

    return rows.map(mapHabit);
}

async function listTodayHabits(userId) {
    const habits =
        await listHabits(userId);

    const timezone =
        await getUserTimezone(userId);

    const today =
        getDateInTimezone(timezone);

    return {
        date: today,
        habits:
            habits.filter(
                (habit) =>
                    habit.is_active &&
                    isScheduledOn(
                        habit,
                        today
                    )
            )
    };
}

async function updateHabit(
    userId,
    habitId,
    habitData
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        const existing =
            await getHabitRow(
                connection,
                userId,
                habitId,
                true
            );

        if (!existing) {
            throw new AppError(
                404,
                'Habit was not found.'
            );
        }

        const resolved = {
            ...existing,
            ...habitData,

            schedule_days:
                Object.prototype
                    .hasOwnProperty.call(
                        habitData,
                        'schedule_days'
                    )
                    ? (
                        habitData.schedule_days
                            ? JSON.stringify(
                                habitData
                                    .schedule_days
                            )
                            : null
                    )
                    : existing.schedule_days
        };

        if (
            resolved.frequency_type ===
            'daily'
        ) {
            resolved.schedule_days = null;
        }

        validateResolvedHabit(resolved);

        const columnMap = {
            name: 'name',
            description: 'description',
            category: 'category',
            frequency_type:
                'frequency_type',
            schedule_days:
                'schedule_days',
            target_value:
                'target_value',
            unit: 'unit',
            reminder_enabled:
                'reminder_enabled',
            reminder_time:
                'reminder_time',
            start_date:
                'start_date',
            end_date:
                'end_date',
            is_active:
                'is_active'
        };

        const entries =
            Object.entries(habitData)
                .filter(
                    ([key]) =>
                        columnMap[key]
                )
                .map(([key, value]) => {
                    if (
                        key ===
                        'schedule_days'
                    ) {
                        return [
                            key,
                            resolved
                                .schedule_days
                        ];
                    }

                    return [key, value];
                });

        const assignments =
            entries
                .map(
                    ([key]) =>
                        `${columnMap[key]} = ?`
                )
                .join(', ');

        const values =
            entries.map(
                ([, value]) =>
                    typeof value === 'boolean'
                        ? Number(value)
                        : value
            );

        await connection.execute(
            `
            UPDATE habits
            SET ${assignments}
            WHERE
                id = ?
                AND user_id = ?
            `,
            [
                ...values,
                habitId,
                userId
            ]
        );

        await recalculateStreaks(
            connection,
            userId,
            habitId
        );

        await connection.commit();

        return getHabitById(
            userId,
            habitId
        );
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function recalculateStreaks(
    executor,
    userId,
    habitId
) {
    const habit =
        await getHabitRow(
            executor,
            userId,
            habitId,
            true
        );

    if (!habit) {
        return;
    }

    const timezone =
        await getUserTimezone(userId);

    const today =
        getDateInTimezone(timezone);

    const finalDate =
        habit.end_date &&
        habit.end_date < today
            ? habit.end_date
            : today;

    const [logRows] =
        await executor.execute(
            `
            SELECT
                DATE_FORMAT(
                    log_date,
                    '%Y-%m-%d'
                ) AS log_date,
                status
            FROM habit_logs
            WHERE
                habit_id = ?
                AND log_date BETWEEN ? AND ?
            ORDER BY log_date ASC
            `,
            [
                habitId,
                habit.start_date,
                finalDate
            ]
        );

    const statusByDate =
        new Map(
            logRows.map((log) => [
                log.log_date,
                log.status
            ])
        );

    const scheduledDates = [];

    let cursor =
        parseDate(habit.start_date);

    const endingDate =
        parseDate(finalDate);

    let safetyCounter = 0;

    while (
        cursor <= endingDate &&
        safetyCounter < 5000
    ) {
        const dateString =
            formatDate(cursor);

        if (
            isScheduledOn(
                habit,
                dateString
            )
        ) {
            scheduledDates.push(
                dateString
            );
        }

        cursor =
            addDays(cursor, 1);

        safetyCounter += 1;
    }

    let longestStreak = 0;
    let runningStreak = 0;

    scheduledDates.forEach((date) => {
        if (
            statusByDate.get(date) ===
            'completed'
        ) {
            runningStreak += 1;

            longestStreak =
                Math.max(
                    longestStreak,
                    runningStreak
                );
        } else {
            runningStreak = 0;
        }
    });

    let currentStreak = 0;

    for (
        let index =
            scheduledDates.length - 1;
        index >= 0;
        index -= 1
    ) {
        const date =
            scheduledDates[index];

        const status =
            statusByDate.get(date);

        if (
            date === today &&
            status !== 'completed'
        ) {
            continue;
        }

        if (status === 'completed') {
            currentStreak += 1;
        } else {
            break;
        }
    }

    await executor.execute(
        `
        UPDATE habits
        SET
            current_streak = ?,
            longest_streak = ?
        WHERE id = ?
        `,
        [
            currentStreak,
            longestStreak,
            habitId
        ]
    );
}

async function saveHabitLog(
    userId,
    habitId,
    logData
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        const habit =
            await getHabitRow(
                connection,
                userId,
                habitId,
                true
            );

        if (!habit) {
            throw new AppError(
                404,
                'Habit was not found.'
            );
        }

        if (
            !booleanValue(habit.is_active) ||
            booleanValue(habit.is_archived)
        ) {
            throw new AppError(
                409,
                'This habit is not active.'
            );
        }

        const timezone =
            await getUserTimezone(userId);

        const logDate =
            logData.log_date ||
            getDateInTimezone(timezone);

        if (
            !isScheduledOn(
                habit,
                logDate
            )
        ) {
            throw new AppError(
                422,
                'This habit is not scheduled for the selected date.'
            );
        }

        const completedValue =
            logData.status === 'completed'
                ? (
                    logData.completed_value ??
                    Number(
                        habit.target_value
                    )
                )
                : logData.completed_value;

        await connection.execute(
            `
            INSERT INTO habit_logs (
                habit_id,
                log_date,
                status,
                completed_value,
                note,
                completed_at
            )
            VALUES (
                ?, ?, ?, ?, ?,
                CASE
                    WHEN ? = 'completed'
                    THEN CURRENT_TIMESTAMP
                    ELSE NULL
                END
            )

            ON DUPLICATE KEY UPDATE
                status =
                    VALUES(status),

                completed_value =
                    VALUES(completed_value),

                note =
                    VALUES(note),

                completed_at =
                    CASE
                        WHEN VALUES(status) =
                            'completed'
                        THEN COALESCE(
                            completed_at,
                            CURRENT_TIMESTAMP
                        )
                        ELSE NULL
                    END
            `,
            [
                habitId,
                logDate,
                logData.status,
                completedValue,
                logData.note,
                logData.status
            ]
        );

        await recalculateStreaks(
            connection,
            userId,
            habitId
        );

        await connection.commit();

        const [rows] =
            await pool.execute(
                `
                SELECT
                    id,
                    DATE_FORMAT(
                        log_date,
                        '%Y-%m-%d'
                    ) AS log_date,
                    status,
                    completed_value,
                    note,
                    completed_at,
                    created_at,
                    updated_at
                FROM habit_logs
                WHERE
                    habit_id = ?
                    AND log_date = ?
                LIMIT 1
                `,
                [
                    habitId,
                    logDate
                ]
            );

        return {
            id: Number(rows[0].id),
            habit_id: habitId,
            log_date:
                rows[0].log_date,
            status:
                rows[0].status,
            completed_value:
                numberOrNull(
                    rows[0]
                        .completed_value
                ),
            note:
                rows[0].note,
            completed_at:
                rows[0].completed_at,
            created_at:
                rows[0].created_at,
            updated_at:
                rows[0].updated_at
        };
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function getHabitLogs(
    userId,
    habitId,
    options
) {
    await ensureActiveUser(pool, userId);

    const habit =
        await getHabitRow(
            pool,
            userId,
            habitId
        );

    if (!habit) {
        throw new AppError(
            404,
            'Habit was not found.'
        );
    }

    const conditions = [
        'habit_id = ?'
    ];

    const parameters = [habitId];

    if (options.fromDate) {
        conditions.push(
            'log_date >= ?'
        );

        parameters.push(
            options.fromDate
        );
    }

    if (options.toDate) {
        conditions.push(
            'log_date <= ?'
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
            FROM habit_logs
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
                id,
                DATE_FORMAT(
                    log_date,
                    '%Y-%m-%d'
                ) AS log_date,
                status,
                completed_value,
                note,
                completed_at,
                created_at,
                updated_at
            FROM habit_logs
            WHERE ${whereClause}
            ORDER BY log_date DESC
            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            parameters
        );

    const total =
        Number(countRows[0].total);

    return {
        habit: mapHabit(habit),

        logs: rows.map((row) => ({
            id: Number(row.id),
            habit_id: habitId,
            log_date:
                row.log_date,
            status:
                row.status,
            completed_value:
                numberOrNull(
                    row.completed_value
                ),
            note: row.note,
            completed_at:
                row.completed_at,
            created_at:
                row.created_at,
            updated_at:
                row.updated_at
        })),

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

async function archiveHabit(
    userId,
    habitId
) {
    await ensureActiveUser(pool, userId);

    const [result] =
        await pool.execute(
            `
            UPDATE habits
            SET
                is_active = FALSE,
                is_archived = TRUE,
                deleted_at =
                    CURRENT_TIMESTAMP
            WHERE
                id = ?
                AND user_id = ?
                AND deleted_at IS NULL
            `,
            [
                habitId,
                userId
            ]
        );

    if (result.affectedRows === 0) {
        throw new AppError(
            404,
            'Habit was not found.'
        );
    }
}

module.exports = {
    listTemplates,
    createHabit,
    listHabits,
    listTodayHabits,
    getHabitById,
    updateHabit,
    saveHabitLog,
    getHabitLogs,
    archiveHabit
};
