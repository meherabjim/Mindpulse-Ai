const database =
    require('../config/database');

const AppError =
    require('../utils/AppError');

const pool = database.pool || database;

function numberValue(value) {
    return Number(value || 0);
}

function booleanValue(value) {
    return Boolean(Number(value));
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

function calculateLongestStreak(
    dateValues
) {
    const uniqueDates = [
        ...new Set(dateValues)
    ].sort();

    if (uniqueDates.length === 0) {
        return 0;
    }

    let longest = 1;
    let current = 1;

    for (
        let index = 1;
        index < uniqueDates.length;
        index += 1
    ) {
        const previous =
            new Date(
                `${uniqueDates[index - 1]}T00:00:00Z`
            );

        const currentDate =
            new Date(
                `${uniqueDates[index]}T00:00:00Z`
            );

        const differenceDays =
            Math.round(
                (
                    currentDate.getTime() -
                    previous.getTime()
                ) /
                86400000
            );

        if (differenceDays === 1) {
            current += 1;
            longest =
                Math.max(longest, current);
        } else {
            current = 1;
        }
    }

    return longest;
}

async function calculateMetrics(userId) {
    const [
        checkinRowsResult,
        journalRowsResult,
        countRowsResult,
        recoveryRowsResult
    ] = await Promise.all([
        pool.execute(
            `
            SELECT
                DATE_FORMAT(
                    checkin_date,
                    '%Y-%m-%d'
                ) AS event_date,
                water_intake_glasses,
                sleep_hours
            FROM daily_checkins
            WHERE user_id = ?
            ORDER BY checkin_date ASC
            `,
            [userId]
        ),

        pool.execute(
            `
            SELECT DISTINCT
                DATE_FORMAT(
                    entry_date,
                    '%Y-%m-%d'
                ) AS event_date
            FROM journals
            WHERE
                user_id = ?
                AND deleted_at IS NULL
            ORDER BY entry_date ASC
            `,
            [userId]
        ),

        pool.execute(
            `
            SELECT
                (
                    SELECT COUNT(*)
                    FROM wellness_scans
                    WHERE user_id = ?
                ) AS wellness_scan_count,

                (
                    SELECT COUNT(*)
                    FROM habit_logs AS hl
                    INNER JOIN habits AS h
                        ON h.id = hl.habit_id
                    WHERE
                        h.user_id = ?
                        AND h.deleted_at IS NULL
                        AND hl.status =
                            'completed'
                ) AS habit_completion_count,

                (
                    SELECT COUNT(*)
                    FROM habit_logs AS hl
                    INNER JOIN habits AS h
                        ON h.id = hl.habit_id
                    WHERE
                        h.user_id = ?
                        AND h.deleted_at IS NULL
                        AND hl.status =
                            'completed'
                        AND (
                            LOWER(h.name)
                                LIKE '%walk%'
                            OR LOWER(h.category)
                                LIKE '%walk%'
                            OR LOWER(h.category)
                                LIKE '%activity%'
                        )
                ) AS walking_completion_count,

                (
                    SELECT COUNT(*)
                    FROM recovery_activity_logs
                        AS ral
                    INNER JOIN recovery_activities
                        AS ra
                        ON ra.id =
                            ral.recovery_activity_id
                    WHERE
                        ral.user_id = ?
                        AND ral.status =
                            'completed'
                        AND (
                            LOWER(ra.title)
                                LIKE '%calm%'
                            OR LOWER(ra.title)
                                LIKE '%breath%'
                            OR LOWER(ra.title)
                                LIKE '%meditat%'
                            OR LOWER(ra.title)
                                LIKE '%relax%'
                            OR LOWER(ra.category)
                                LIKE '%calm%'
                            OR LOWER(ra.category)
                                LIKE '%breath%'
                            OR LOWER(ra.category)
                                LIKE '%meditat%'
                            OR LOWER(ra.category)
                                LIKE '%relax%'
                        )
                ) AS calm_activity_count
            `,
            [
                userId,
                userId,
                userId,
                userId
            ]
        ),

        pool.execute(
            `
            SELECT
                COALESCE(
                    MAX(recovery_score),
                    0
                ) AS recovery_score
            FROM recovery_progress
            WHERE user_id = ?
            `,
            [userId]
        )
    ]);

    const checkins =
        checkinRowsResult[0];

    const journals =
        journalRowsResult[0];

    const counts =
        countRowsResult[0][0];

    const recovery =
        recoveryRowsResult[0][0];

    return {
        total_checkins:
            checkins.length,

        checkin_streak:
            calculateLongestStreak(
                checkins.map(
                    (row) => row.event_date
                )
            ),

        hydration_target_days:
            checkins.filter(
                (row) =>
                    Number(
                        row.water_intake_glasses
                    ) >= 8
            ).length,

        sleep_target_days:
            checkins.filter((row) => {
                const hours =
                    Number(row.sleep_hours);

                return (
                    row.sleep_hours !== null &&
                    hours >= 7 &&
                    hours <= 9
                );
            }).length,

        calm_activity_count:
            numberValue(
                counts.calm_activity_count
            ),

        journal_streak:
            calculateLongestStreak(
                journals.map(
                    (row) => row.event_date
                )
            ),

        walking_completion_count:
            numberValue(
                counts.walking_completion_count
            ),

        habit_completion_count:
            numberValue(
                counts.habit_completion_count
            ),

        recovery_score:
            numberValue(
                recovery.recovery_score
            ),

        wellness_scan_count:
            numberValue(
                counts.wellness_scan_count
            )
    };
}

function replaceVariables(
    template,
    variables
) {
    let result = template;

    Object.entries(variables)
        .forEach(([key, value]) => {
            result = result.replaceAll(
                `{{${key}}}`,
                String(value)
            );
        });

    return result;
}

async function getUserName(
    executor,
    userId
) {
    const [rows] =
        await executor.execute(
            `
            SELECT
                COALESCE(
                    p.full_name,
                    u.email
                ) AS user_name
            FROM users AS u
            LEFT JOIN user_profiles AS p
                ON p.user_id = u.id
            WHERE u.id = ?
            LIMIT 1
            `,
            [userId]
        );

    return rows[0]?.user_name ||
        'MindPulse User';
}

async function createAchievementNotification(
    executor,
    userId,
    badge
) {
    const [templateRows] =
        await executor.execute(
            `
            SELECT *
            FROM notification_templates
            WHERE
                template_code =
                    'ACHIEVEMENT_EARNED'
                AND is_active = TRUE
            LIMIT 1
            `
        );

    const template =
        templateRows[0] || null;

    const userName =
        await getUserName(
            executor,
            userId
        );

    const variables = {
        user_name: userName,
        badge_name: badge.name
    };

    const title = template
        ? replaceVariables(
            template.title_template,
            variables
        )
        : 'New achievement unlocked';

    const body = template
        ? replaceVariables(
            template.body_template,
            variables
        )
        : `You earned the ${badge.name} badge.`;

    await executor.execute(
        `
        INSERT INTO notifications (
            user_id,
            template_id,
            notification_type,
            title,
            body,
            priority_level,
            data_payload,
            status,
            sent_at
        )
        VALUES (
            ?,
            ?,
            'achievement',
            ?,
            ?,
            'normal',
            ?,
            'sent',
            CURRENT_TIMESTAMP
        )
        `,
        [
            userId,
            template?.id || null,
            title,
            body,
            JSON.stringify({
                badge_id:
                    Number(badge.id),
                badge_code:
                    badge.badge_code
            })
        ]
    );
}

async function syncAchievements(userId) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        const metrics =
            await calculateMetrics(userId);

        const [badgeRows] =
            await connection.execute(
                `
                SELECT *
                FROM badges
                WHERE is_active = TRUE
                ORDER BY
                    display_order ASC,
                    id ASC
                `
            );

        const newlyEarned = [];

        for (const badge of badgeRows) {
            const currentValue =
                Number(
                    metrics[
                        badge.criteria_type
                    ] || 0
                );

            const targetValue =
                Number(
                    badge.criteria_value
                );

            const isCompleted =
                currentValue >= targetValue;

            await connection.execute(
                `
                INSERT INTO achievement_progress (
                    user_id,
                    badge_id,
                    current_value,
                    target_value,
                    is_completed,
                    completed_at,
                    last_progress_at
                )
                VALUES (
                    ?, ?, ?, ?, ?,
                    CASE
                        WHEN ? = TRUE
                        THEN CURRENT_TIMESTAMP
                        ELSE NULL
                    END,
                    CURRENT_TIMESTAMP
                )

                ON DUPLICATE KEY UPDATE
                    current_value =
                        VALUES(current_value),

                    target_value =
                        VALUES(target_value),

                    completed_at =
                        CASE
                            WHEN
                                is_completed = FALSE
                                AND
                                VALUES(
                                    is_completed
                                ) = TRUE
                            THEN CURRENT_TIMESTAMP
                            ELSE completed_at
                        END,

                    is_completed =
                        GREATEST(
                            is_completed,
                            VALUES(is_completed)
                        ),

                    last_progress_at =
                        CURRENT_TIMESTAMP
                `,
                [
                    userId,
                    badge.id,
                    currentValue,
                    targetValue,
                    Number(isCompleted),
                    Number(isCompleted)
                ]
            );

            if (isCompleted) {
                const [awardResult] =
                    await connection.execute(
                        `
                        INSERT IGNORE INTO user_badges (
                            user_id,
                            badge_id,
                            points_awarded,
                            criteria_snapshot,
                            source_reference_type
                        )
                        VALUES (
                            ?, ?, ?, ?, 'achievement_sync'
                        )
                        `,
                        [
                            userId,
                            badge.id,
                            badge.points_reward,
                            JSON.stringify({
                                criteria_type:
                                    badge.criteria_type,
                                current_value:
                                    currentValue,
                                target_value:
                                    targetValue
                            })
                        ]
                    );

                if (
                    awardResult.affectedRows === 1
                ) {
                    newlyEarned.push({
                        id:
                            Number(badge.id),
                        badge_code:
                            badge.badge_code,
                        name:
                            badge.name,
                        points_reward:
                            Number(
                                badge.points_reward
                            )
                    });

                    await createAchievementNotification(
                        connection,
                        userId,
                        badge
                    );
                }
            }
        }

        const [pointRows] =
            await connection.execute(
                `
                SELECT
                    COALESCE(
                        SUM(points_awarded),
                        0
                    ) AS total_points
                FROM user_badges
                WHERE user_id = ?
                `,
                [userId]
            );

        const totalPoints =
            Number(
                pointRows[0].total_points
            );

        const [levelRows] =
            await connection.execute(
                `
                SELECT *
                FROM levels
                WHERE
                    is_active = TRUE
                    AND minimum_points <= ?
                    AND (
                        maximum_points IS NULL
                        OR maximum_points >= ?
                    )
                ORDER BY
                    minimum_points DESC
                LIMIT 1
                `,
                [
                    totalPoints,
                    totalPoints
                ]
            );

        const level =
            levelRows[0];

        if (!level) {
            throw new AppError(
                500,
                'No matching achievement level was found.'
            );
        }

        await connection.execute(
            `
            INSERT INTO user_levels (
                user_id,
                level_id,
                total_points,
                achieved_at
            )
            VALUES (
                ?, ?, ?, CURRENT_TIMESTAMP
            )

            ON DUPLICATE KEY UPDATE
                achieved_at =
                    CASE
                        WHEN level_id <>
                            VALUES(level_id)
                        THEN CURRENT_TIMESTAMP
                        ELSE achieved_at
                    END,

                level_id =
                    VALUES(level_id),

                total_points =
                    VALUES(total_points)
            `,
            [
                userId,
                level.id,
                totalPoints
            ]
        );

        await connection.commit();

        const summary =
            await getAchievementSummary(
                userId
            );

        return {
            ...summary,
            newly_earned:
                newlyEarned,
            metrics
        };
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function getAchievementSummary(userId) {
    await ensureActiveUser(pool, userId);

    const [levelRows] =
        await pool.execute(
            `
            SELECT
                ul.total_points,
                ul.achieved_at,

                l.id AS level_id,
                l.name AS level_name,
                l.description,
                l.icon_name,
                l.minimum_points,
                l.maximum_points

            FROM user_levels AS ul

            INNER JOIN levels AS l
                ON l.id = ul.level_id

            WHERE ul.user_id = ?
            LIMIT 1
            `,
            [userId]
        );

    let level = null;
    let totalPoints = 0;

    if (levelRows[0]) {
        const row = levelRows[0];

        totalPoints =
            Number(row.total_points);

        level = {
            id: Number(row.level_id),
            name: row.level_name,
            description:
                row.description,
            icon_name:
                row.icon_name,
            minimum_points:
                Number(
                    row.minimum_points
                ),
            maximum_points:
                row.maximum_points === null
                    ? null
                    : Number(
                        row.maximum_points
                    ),
            achieved_at:
                row.achieved_at
        };
    }

    const [nextLevelRows] =
        await pool.execute(
            `
            SELECT
                id,
                name,
                minimum_points
            FROM levels
            WHERE
                is_active = TRUE
                AND minimum_points > ?
            ORDER BY minimum_points ASC
            LIMIT 1
            `,
            [totalPoints]
        );

    const [badgeRows] =
        await pool.execute(
            `
            SELECT
                b.id,
                b.badge_code,
                b.name,
                b.description,
                b.category,
                b.criteria_type,
                b.criteria_value,
                b.points_reward,
                b.icon_name,

                COALESCE(
                    ap.current_value,
                    0
                ) AS current_value,

                COALESCE(
                    ap.target_value,
                    b.criteria_value
                ) AS target_value,

                COALESCE(
                    ap.is_completed,
                    0
                ) AS is_completed,

                ap.completed_at,
                ub.earned_at,
                ub.criteria_snapshot

            FROM badges AS b

            LEFT JOIN achievement_progress AS ap
                ON ap.badge_id = b.id
                AND ap.user_id = ?

            LEFT JOIN user_badges AS ub
                ON ub.badge_id = b.id
                AND ub.user_id = ?

            WHERE b.is_active = TRUE

            ORDER BY
                b.display_order ASC,
                b.id ASC
            `,
            [
                userId,
                userId
            ]
        );

    const badges =
        badgeRows.map((row) => {
            const currentValue =
                Number(row.current_value);

            const targetValue =
                Number(row.target_value);

            return {
                id: Number(row.id),
                badge_code:
                    row.badge_code,
                name: row.name,
                description:
                    row.description,
                category:
                    row.category,
                criteria_type:
                    row.criteria_type,
                current_value:
                    currentValue,
                target_value:
                    targetValue,
                progress_percent:
                    Math.min(
                        100,
                        Number(
                            (
                                currentValue /
                                targetValue *
                                100
                            ).toFixed(2)
                        )
                    ),
                points_reward:
                    Number(
                        row.points_reward
                    ),
                icon_name:
                    row.icon_name,
                is_completed:
                    booleanValue(
                        row.is_completed
                    ),
                completed_at:
                    row.completed_at,
                earned_at:
                    row.earned_at,
                criteria_snapshot:
                    parseJson(
                        row.criteria_snapshot,
                        null
                    )
            };
        });

    const nextLevel =
        nextLevelRows[0]
            ? {
                id:
                    Number(
                        nextLevelRows[0].id
                    ),
                name:
                    nextLevelRows[0].name,
                minimum_points:
                    Number(
                        nextLevelRows[0]
                            .minimum_points
                    ),
                points_needed:
                    Math.max(
                        0,
                        Number(
                            nextLevelRows[0]
                                .minimum_points
                        ) - totalPoints
                    )
            }
            : null;

    return {
        total_points: totalPoints,
        level,
        next_level: nextLevel,
        earned_badges:
            badges.filter(
                (badge) =>
                    badge.is_completed
            ).length,
        total_badges:
            badges.length,
        badges
    };
}

module.exports = {
    syncAchievements,
    getAchievementSummary
};
