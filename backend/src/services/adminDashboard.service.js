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

function normalizeContext(context = {}) {
    return {
        ip_address:
            context.ip_address
                ? String(
                    context.ip_address
                ).slice(0, 45)
                : null,

        user_agent:
            context.user_agent
                ? String(
                    context.user_agent
                ).slice(0, 500)
                : null
    };
}

async function insertAudit(
    executor,
    {
        adminId,
        action,
        entityType,
        entityId,
        oldValues,
        newValues,
        metadata,
        context
    }
) {
    const requestContext =
        normalizeContext(context);

    await executor.execute(
        `
        INSERT INTO audit_logs (
            admin_user_id,
            actor_type,
            action,
            entity_type,
            entity_id,
            old_values,
            new_values,
            metadata,
            ip_address,
            user_agent
        )
        VALUES (
            ?,
            'admin',
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?
        )
        `,
        [
            adminId,
            action,
            entityType || null,
            entityId || null,

            oldValues
                ? JSON.stringify(oldValues)
                : null,

            newValues
                ? JSON.stringify(newValues)
                : null,

            metadata
                ? JSON.stringify(metadata)
                : null,

            requestContext.ip_address,
            requestContext.user_agent
        ]
    );
}

async function getDashboardSummary() {
    const [
        userResult,
        wellnessResult,
        safetyResult,
        reportResult,
        engagementResult,
        notificationResult
    ] = await Promise.all([
        pool.execute(
            `
            SELECT
                COUNT(*) AS total_users,

                COALESCE(
                    SUM(
                        account_status =
                            'active'
                    ),
                    0
                ) AS active_users,

                COALESCE(
                    SUM(
                        account_status =
                            'suspended'
                    ),
                    0
                ) AS suspended_users,

                COALESCE(
                    SUM(
                        account_status =
                            'inactive'
                    ),
                    0
                ) AS inactive_users,

                COALESCE(
                    SUM(
                        onboarding_completed =
                            TRUE
                    ),
                    0
                ) AS onboarded_users,

                COALESCE(
                    SUM(
                        created_at >=
                        DATE_SUB(
                            CURRENT_TIMESTAMP,
                            INTERVAL 7 DAY
                        )
                    ),
                    0
                ) AS new_users_7_days,

                COALESCE(
                    SUM(
                        created_at >=
                        DATE_SUB(
                            CURRENT_TIMESTAMP,
                            INTERVAL 30 DAY
                        )
                    ),
                    0
                ) AS new_users_30_days

            FROM users
            WHERE deleted_at IS NULL
            `
        ),

        pool.execute(
            `
            SELECT
                (
                    SELECT COUNT(*)
                    FROM daily_checkins
                    WHERE checkin_date =
                        CURDATE()
                ) AS checkins_today,

                (
                    SELECT COUNT(*)
                    FROM wellness_scans
                    WHERE DATE(completed_at) =
                        CURDATE()
                ) AS wellness_scans_today,

                (
                    SELECT COUNT(*)
                    FROM burnout_assessments
                    WHERE DATE(assessed_at) =
                        CURDATE()
                ) AS burnout_assessments_today,

                (
                    SELECT COUNT(*)
                    FROM burnout_assessments
                    WHERE
                        risk_level IN (
                            'moderate',
                            'elevated'
                        )
                        AND assessed_at >=
                            DATE_SUB(
                                CURRENT_TIMESTAMP,
                                INTERVAL 7 DAY
                            )
                ) AS risk_assessments_7_days
            `
        ),

        pool.execute(
            `
            SELECT
                COUNT(*) AS total_events,

                COALESCE(
                    SUM(
                        review_status =
                            'unreviewed'
                    ),
                    0
                ) AS unreviewed_events,

                COALESCE(
                    SUM(
                        severity_level =
                            'critical'
                    ),
                    0
                ) AS critical_events,

                COALESCE(
                    SUM(
                        severity_level IN (
                            'high',
                            'critical'
                        )
                        AND review_status =
                            'unreviewed'
                    ),
                    0
                ) AS urgent_unreviewed

            FROM ai_safety_events
            `
        ),

        pool.execute(
            `
            SELECT
                COUNT(*) AS total_reports,

                COALESCE(
                    SUM(
                        status =
                            'completed'
                    ),
                    0
                ) AS completed_reports,

                COALESCE(
                    SUM(
                        status IN (
                            'pending',
                            'generating'
                        )
                    ),
                    0
                ) AS pending_reports,

                COALESCE(
                    SUM(
                        status =
                            'failed'
                    ),
                    0
                ) AS failed_reports

            FROM reports
            `
        ),

        pool.execute(
            `
            SELECT
                (
                    SELECT COUNT(*)
                    FROM journals
                    WHERE deleted_at IS NULL
                ) AS journal_entries,

                (
                    SELECT COUNT(*)
                    FROM habits
                    WHERE
                        deleted_at IS NULL
                        AND is_active = TRUE
                        AND is_archived = FALSE
                ) AS active_habits,

                (
                    SELECT COUNT(*)
                    FROM ai_conversations
                    WHERE deleted_at IS NULL
                ) AS ai_conversations,

                (
                    SELECT COUNT(*)
                    FROM ai_messages
                ) AS ai_messages,

                (
                    SELECT COUNT(*)
                    FROM recovery_plans
                    WHERE status = 'active'
                ) AS active_recovery_plans
            `
        ),

        pool.execute(
            `
            SELECT
                COUNT(*) AS total_notifications,

                COALESCE(
                    SUM(
                        read_at IS NULL
                        AND status <>
                            'cancelled'
                    ),
                    0
                ) AS unread_notifications,

                COALESCE(
                    SUM(
                        notification_type =
                            'announcement'
                    ),
                    0
                ) AS announcements

            FROM notifications
            `
        )
    ]);

    const users = userResult[0][0];
    const wellness =
        wellnessResult[0][0];
    const safety = safetyResult[0][0];
    const reports = reportResult[0][0];
    const engagement =
        engagementResult[0][0];
    const notifications =
        notificationResult[0][0];

    return {
        users: {
            total:
                numberValue(
                    users.total_users
                ),
            active:
                numberValue(
                    users.active_users
                ),
            suspended:
                numberValue(
                    users.suspended_users
                ),
            inactive:
                numberValue(
                    users.inactive_users
                ),
            onboarded:
                numberValue(
                    users.onboarded_users
                ),
            new_last_7_days:
                numberValue(
                    users.new_users_7_days
                ),
            new_last_30_days:
                numberValue(
                    users.new_users_30_days
                )
        },

        wellness: {
            checkins_today:
                numberValue(
                    wellness.checkins_today
                ),
            scans_today:
                numberValue(
                    wellness
                        .wellness_scans_today
                ),
            assessments_today:
                numberValue(
                    wellness
                        .burnout_assessments_today
                ),
            meaningful_risk_last_7_days:
                numberValue(
                    wellness
                        .risk_assessments_7_days
                )
        },

        safety: {
            total_events:
                numberValue(
                    safety.total_events
                ),
            unreviewed:
                numberValue(
                    safety.unreviewed_events
                ),
            critical:
                numberValue(
                    safety.critical_events
                ),
            urgent_unreviewed:
                numberValue(
                    safety.urgent_unreviewed
                )
        },

        reports: {
            total:
                numberValue(
                    reports.total_reports
                ),
            completed:
                numberValue(
                    reports.completed_reports
                ),
            pending:
                numberValue(
                    reports.pending_reports
                ),
            failed:
                numberValue(
                    reports.failed_reports
                )
        },

        engagement: {
            journals:
                numberValue(
                    engagement.journal_entries
                ),
            active_habits:
                numberValue(
                    engagement.active_habits
                ),
            ai_conversations:
                numberValue(
                    engagement.ai_conversations
                ),
            ai_messages:
                numberValue(
                    engagement.ai_messages
                ),
            active_recovery_plans:
                numberValue(
                    engagement
                        .active_recovery_plans
                )
        },

        notifications: {
            total:
                numberValue(
                    notifications
                        .total_notifications
                ),
            unread:
                numberValue(
                    notifications
                        .unread_notifications
                ),
            announcements:
                numberValue(
                    notifications
                        .announcements
                )
        },

        generated_at:
            new Date().toISOString()
    };
}

function addDays(dateString, days) {
    const date =
        new Date(
            `${dateString}T00:00:00Z`
        );

    date.setUTCDate(
        date.getUTCDate() + days
    );

    return date
        .toISOString()
        .slice(0, 10);
}

async function getDashboardTrends(days) {
    const [todayRows] =
        await pool.execute(
            `
            SELECT DATE_FORMAT(
                CURDATE(),
                '%Y-%m-%d'
            ) AS today
            `
        );

    const today =
        todayRows[0].today;

    const startDate =
        addDays(today, -(days - 1));

    const [
        usersResult,
        checkinsResult,
        scansResult,
        burnoutResult,
        safetyResult,
        reportsResult
    ] = await Promise.all([
        pool.execute(
            `
            SELECT
                DATE_FORMAT(
                    created_at,
                    '%Y-%m-%d'
                ) AS date_key,
                COUNT(*) AS total
            FROM users
            WHERE
                deleted_at IS NULL
                AND DATE(created_at)
                    BETWEEN ? AND ?
            GROUP BY DATE(created_at)
            `,
            [
                startDate,
                today
            ]
        ),

        pool.execute(
            `
            SELECT
                DATE_FORMAT(
                    checkin_date,
                    '%Y-%m-%d'
                ) AS date_key,
                COUNT(*) AS total
            FROM daily_checkins
            WHERE checkin_date
                BETWEEN ? AND ?
            GROUP BY checkin_date
            `,
            [
                startDate,
                today
            ]
        ),

        pool.execute(
            `
            SELECT
                DATE_FORMAT(
                    completed_at,
                    '%Y-%m-%d'
                ) AS date_key,
                COUNT(*) AS total
            FROM wellness_scans
            WHERE DATE(completed_at)
                BETWEEN ? AND ?
            GROUP BY DATE(completed_at)
            `,
            [
                startDate,
                today
            ]
        ),

        pool.execute(
            `
            SELECT
                DATE_FORMAT(
                    assessed_at,
                    '%Y-%m-%d'
                ) AS date_key,

                COUNT(*) AS total,

                ROUND(
                    AVG(burnout_score),
                    2
                ) AS average_score

            FROM burnout_assessments

            WHERE DATE(assessed_at)
                BETWEEN ? AND ?

            GROUP BY DATE(assessed_at)
            `,
            [
                startDate,
                today
            ]
        ),

        pool.execute(
            `
            SELECT
                DATE_FORMAT(
                    created_at,
                    '%Y-%m-%d'
                ) AS date_key,
                COUNT(*) AS total
            FROM ai_safety_events
            WHERE DATE(created_at)
                BETWEEN ? AND ?
            GROUP BY DATE(created_at)
            `,
            [
                startDate,
                today
            ]
        ),

        pool.execute(
            `
            SELECT
                DATE_FORMAT(
                    created_at,
                    '%Y-%m-%d'
                ) AS date_key,
                COUNT(*) AS total
            FROM reports
            WHERE DATE(created_at)
                BETWEEN ? AND ?
            GROUP BY DATE(created_at)
            `,
            [
                startDate,
                today
            ]
        )
    ]);

    function createMap(rows) {
        return new Map(
            rows.map((row) => [
                row.date_key,
                row
            ])
        );
    }

    const usersMap =
        createMap(usersResult[0]);

    const checkinsMap =
        createMap(checkinsResult[0]);

    const scansMap =
        createMap(scansResult[0]);

    const burnoutMap =
        createMap(burnoutResult[0]);

    const safetyMap =
        createMap(safetyResult[0]);

    const reportsMap =
        createMap(reportsResult[0]);

    const trends = [];

    for (
        let index = 0;
        index < days;
        index += 1
    ) {
        const date =
            addDays(startDate, index);

        trends.push({
            date,

            new_users:
                numberValue(
                    usersMap.get(date)?.total
                ),

            checkins:
                numberValue(
                    checkinsMap.get(date)?.total
                ),

            wellness_scans:
                numberValue(
                    scansMap.get(date)?.total
                ),

            burnout_assessments:
                numberValue(
                    burnoutMap.get(date)?.total
                ),

            average_burnout_score:
                burnoutMap.get(date)
                    ?.average_score ===
                    null ||
                burnoutMap.get(date)
                    ?.average_score ===
                    undefined
                    ? null
                    : Number(
                        burnoutMap.get(date)
                            .average_score
                    ),

            safety_events:
                numberValue(
                    safetyMap.get(date)?.total
                ),

            reports:
                numberValue(
                    reportsMap.get(date)?.total
                )
        });
    }

    return {
        period_start: startDate,
        period_end: today,
        days,
        trends
    };
}

async function listUsers(options) {
    const conditions = [
        'u.deleted_at IS NULL'
    ];

    const parameters = [];

    if (options.search) {
        conditions.push(
            `
            (
                u.email LIKE ?
                OR p.full_name LIKE ?
            )
            `
        );

        const searchValue =
            `%${options.search}%`;

        parameters.push(
            searchValue,
            searchValue
        );
    }

    if (options.status) {
        conditions.push(
            'u.account_status = ?'
        );

        parameters.push(
            options.status
        );
    }

    if (options.onboarding !== null) {
        conditions.push(
            'u.onboarding_completed = ?'
        );

        parameters.push(
            Number(options.onboarding)
        );
    }

    if (options.fromDate) {
        conditions.push(
            'DATE(u.created_at) >= ?'
        );

        parameters.push(
            options.fromDate
        );
    }

    if (options.toDate) {
        conditions.push(
            'DATE(u.created_at) <= ?'
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
            FROM users AS u
            LEFT JOIN user_profiles AS p
                ON p.user_id = u.id
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
                u.id,
                u.email,
                u.account_status,
                u.onboarding_completed,
                u.email_verified_at,
                u.last_login_at,
                u.created_at,
                u.updated_at,

                p.full_name,
                p.age_range,
                p.gender,
                p.occupation,
                p.user_type,
                p.wellness_goal,
                p.preferred_language,
                p.timezone,

                ul.total_points,
                l.name AS level_name,

                (
                    SELECT ba.risk_level
                    FROM burnout_assessments
                        AS ba
                    WHERE ba.user_id = u.id
                    ORDER BY
                        ba.assessed_at DESC,
                        ba.id DESC
                    LIMIT 1
                ) AS latest_risk_level,

                (
                    SELECT ba.burnout_score
                    FROM burnout_assessments
                        AS ba
                    WHERE ba.user_id = u.id
                    ORDER BY
                        ba.assessed_at DESC,
                        ba.id DESC
                    LIMIT 1
                ) AS latest_burnout_score,

                (
                    SELECT COUNT(*)
                    FROM daily_checkins AS dc
                    WHERE dc.user_id = u.id
                ) AS checkin_count

            FROM users AS u

            LEFT JOIN user_profiles AS p
                ON p.user_id = u.id

            LEFT JOIN user_levels AS ul
                ON ul.user_id = u.id

            LEFT JOIN levels AS l
                ON l.id = ul.level_id

            WHERE ${whereClause}

            ORDER BY
                u.created_at DESC,
                u.id DESC

            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            parameters
        );

    const total =
        numberValue(countRows[0].total);

    return {
        users: rows.map((row) => ({
            id: Number(row.id),
            email: row.email,
            full_name:
                row.full_name,
            account_status:
                row.account_status,
            onboarding_completed:
                booleanValue(
                    row.onboarding_completed
                ),
            email_verified:
                row.email_verified_at !==
                null,
            last_login_at:
                row.last_login_at,
            profile: {
                age_range:
                    row.age_range,
                gender:
                    row.gender,
                occupation:
                    row.occupation,
                user_type:
                    row.user_type,
                wellness_goal:
                    row.wellness_goal,
                preferred_language:
                    row.preferred_language,
                timezone:
                    row.timezone
            },
            achievement: {
                total_points:
                    numberValue(
                        row.total_points
                    ),
                level_name:
                    row.level_name
            },
            wellness: {
                latest_risk_level:
                    row.latest_risk_level,
                latest_burnout_score:
                    row
                        .latest_burnout_score ===
                    null
                        ? null
                        : Number(
                            row
                                .latest_burnout_score
                        ),
                checkin_count:
                    numberValue(
                        row.checkin_count
                    )
            },
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
                    total / options.limit
                )
        }
    };
}

async function getUserById(userId) {
    const [rows] =
        await pool.execute(
            `
            SELECT
                u.id,
                u.email,
                u.account_status,
                u.onboarding_completed,
                u.email_verified_at,
                u.last_login_at,
                u.created_at,
                u.updated_at,

                p.full_name,
                p.profile_photo_url,
                p.age_range,
                p.gender,
                p.occupation,
                p.user_type,
                p.wellness_goal,
                p.preferred_language,
                p.timezone,

                ul.total_points,
                l.id AS level_id,
                l.name AS level_name

            FROM users AS u

            LEFT JOIN user_profiles AS p
                ON p.user_id = u.id

            LEFT JOIN user_levels AS ul
                ON ul.user_id = u.id

            LEFT JOIN levels AS l
                ON l.id = ul.level_id

            WHERE
                u.id = ?
                AND u.deleted_at IS NULL

            LIMIT 1
            `,
            [userId]
        );

    if (!rows[0]) {
        throw new AppError(
            404,
            'User account was not found.'
        );
    }

    const user = rows[0];

    const [
        countResult,
        checkinResult,
        scanResult,
        burnoutResult,
        badgeResult
    ] = await Promise.all([
        pool.execute(
            `
            SELECT
                (
                    SELECT COUNT(*)
                    FROM daily_checkins
                    WHERE user_id = ?
                ) AS checkins,

                (
                    SELECT COUNT(*)
                    FROM wellness_scans
                    WHERE user_id = ?
                ) AS wellness_scans,

                (
                    SELECT COUNT(*)
                    FROM journals
                    WHERE
                        user_id = ?
                        AND deleted_at IS NULL
                ) AS journals,

                (
                    SELECT COUNT(*)
                    FROM habits
                    WHERE
                        user_id = ?
                        AND deleted_at IS NULL
                ) AS habits,

                (
                    SELECT COUNT(*)
                    FROM reports
                    WHERE user_id = ?
                ) AS reports,

                (
                    SELECT COUNT(*)
                    FROM ai_conversations
                    WHERE
                        user_id = ?
                        AND deleted_at IS NULL
                ) AS conversations,

                (
                    SELECT COUNT(*)
                    FROM ai_safety_events
                    WHERE user_id = ?
                ) AS safety_events
            `,
            [
                userId,
                userId,
                userId,
                userId,
                userId,
                userId,
                userId
            ]
        ),

        pool.execute(
            `
            SELECT
                id,
                DATE_FORMAT(
                    checkin_date,
                    '%Y-%m-%d'
                ) AS checkin_date,
                mood_score,
                stress_level,
                energy_level,
                sleep_hours,
                water_intake_glasses,
                physical_activity_minutes
            FROM daily_checkins
            WHERE user_id = ?
            ORDER BY
                checkin_date DESC,
                id DESC
            LIMIT 7
            `,
            [userId]
        ),

        pool.execute(
            `
            SELECT
                id,
                total_score,
                risk_level,
                summary,
                completed_at
            FROM wellness_scans
            WHERE user_id = ?
            ORDER BY
                completed_at DESC,
                id DESC
            LIMIT 1
            `,
            [userId]
        ),

        pool.execute(
            `
            SELECT
                id,
                burnout_score,
                risk_level,
                assessment_source,
                factor_details,
                explanation,
                assessed_at
            FROM burnout_assessments
            WHERE user_id = ?
            ORDER BY
                assessed_at DESC,
                id DESC
            LIMIT 1
            `,
            [userId]
        ),

        pool.execute(
            `
            SELECT
                b.id,
                b.badge_code,
                b.name,
                b.category,
                ub.points_awarded,
                ub.earned_at
            FROM user_badges AS ub
            INNER JOIN badges AS b
                ON b.id = ub.badge_id
            WHERE ub.user_id = ?
            ORDER BY ub.earned_at DESC
            `,
            [userId]
        )
    ]);

    const counts =
        countResult[0][0];

    const latestScan =
        scanResult[0][0] || null;

    const latestBurnout =
        burnoutResult[0][0] || null;

    return {
        id: Number(user.id),
        email: user.email,
        full_name:
            user.full_name,
        account_status:
            user.account_status,
        onboarding_completed:
            booleanValue(
                user.onboarding_completed
            ),
        email_verified_at:
            user.email_verified_at,
        last_login_at:
            user.last_login_at,

        profile: {
            profile_photo_url:
                user.profile_photo_url,
            age_range:
                user.age_range,
            gender:
                user.gender,
            occupation:
                user.occupation,
            user_type:
                user.user_type,
            wellness_goal:
                user.wellness_goal,
            preferred_language:
                user.preferred_language,
            timezone:
                user.timezone
        },

        achievement: {
            level: user.level_id
                ? {
                    id:
                        Number(user.level_id),
                    name:
                        user.level_name
                }
                : null,

            total_points:
                numberValue(
                    user.total_points
                ),

            badges:
                badgeResult[0].map(
                    (badge) => ({
                        id:
                            Number(badge.id),
                        badge_code:
                            badge.badge_code,
                        name:
                            badge.name,
                        category:
                            badge.category,
                        points_awarded:
                            Number(
                                badge
                                    .points_awarded
                            ),
                        earned_at:
                            badge.earned_at
                    })
                )
        },

        statistics: {
            checkins:
                numberValue(
                    counts.checkins
                ),
            wellness_scans:
                numberValue(
                    counts.wellness_scans
                ),
            journals:
                numberValue(
                    counts.journals
                ),
            habits:
                numberValue(
                    counts.habits
                ),
            reports:
                numberValue(
                    counts.reports
                ),
            ai_conversations:
                numberValue(
                    counts.conversations
                ),
            safety_events:
                numberValue(
                    counts.safety_events
                )
        },

        latest_wellness_scan:
            latestScan
                ? {
                    id:
                        Number(
                            latestScan.id
                        ),
                    total_score:
                        Number(
                            latestScan
                                .total_score
                        ),
                    risk_level:
                        latestScan
                            .risk_level,
                    summary:
                        latestScan.summary,
                    completed_at:
                        latestScan
                            .completed_at
                }
                : null,

        latest_burnout_assessment:
            latestBurnout
                ? {
                    id:
                        Number(
                            latestBurnout.id
                        ),
                    burnout_score:
                        Number(
                            latestBurnout
                                .burnout_score
                        ),
                    risk_level:
                        latestBurnout
                            .risk_level,
                    assessment_source:
                        latestBurnout
                            .assessment_source,
                    factor_details:
                        parseJson(
                            latestBurnout
                                .factor_details,
                            null
                        ),
                    explanation:
                        latestBurnout
                            .explanation,
                    assessed_at:
                        latestBurnout
                            .assessed_at
                }
                : null,

        recent_checkins:
            checkinResult[0].map(
                (checkin) => ({
                    id:
                        Number(checkin.id),
                    checkin_date:
                        checkin.checkin_date,
                    mood_score:
                        Number(
                            checkin.mood_score
                        ),
                    stress_level:
                        Number(
                            checkin
                                .stress_level
                        ),
                    energy_level:
                        Number(
                            checkin
                                .energy_level
                        ),
                    sleep_hours:
                        checkin.sleep_hours ===
                        null
                            ? null
                            : Number(
                                checkin
                                    .sleep_hours
                            ),
                    water_intake_glasses:
                        Number(
                            checkin
                                .water_intake_glasses
                        ),
                    physical_activity_minutes:
                        Number(
                            checkin
                                .physical_activity_minutes
                        )
                })
            ),

        created_at:
            user.created_at,
        updated_at:
            user.updated_at
    };
}

async function updateUserStatus(
    adminId,
    userId,
    statusData,
    context
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        const [rows] =
            await connection.execute(
                `
                SELECT
                    id,
                    email,
                    account_status
                FROM users
                WHERE
                    id = ?
                    AND deleted_at IS NULL
                LIMIT 1
                FOR UPDATE
                `,
                [userId]
            );

        const user = rows[0];

        if (!user) {
            throw new AppError(
                404,
                'User account was not found.'
            );
        }

        if (
            user.account_status !==
            statusData.account_status
        ) {
            await connection.execute(
                `
                UPDATE users
                SET account_status = ?
                WHERE id = ?
                `,
                [
                    statusData.account_status,
                    userId
                ]
            );

            await insertAudit(
                connection,
                {
                    adminId,
                    action:
                        'user_status_updated',
                    entityType:
                        'user',
                    entityId:
                        userId,
                    oldValues: {
                        account_status:
                            user.account_status
                    },
                    newValues: {
                        account_status:
                            statusData
                                .account_status
                    },
                    metadata: {
                        email:
                            user.email,
                        reason:
                            statusData.reason
                    },
                    context
                }
            );
        }

        await connection.commit();

        return getUserById(userId);
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function listSafetyEvents(options) {
    const conditions = ['1 = 1'];
    const parameters = [];

    if (options.reviewStatus) {
        conditions.push(
            'ase.review_status = ?'
        );

        parameters.push(
            options.reviewStatus
        );
    }

    if (options.severity) {
        conditions.push(
            'ase.severity_level = ?'
        );

        parameters.push(
            options.severity
        );
    }

    if (options.eventType) {
        conditions.push(
            'ase.event_type = ?'
        );

        parameters.push(
            options.eventType
        );
    }

    if (options.fromDate) {
        conditions.push(
            'DATE(ase.created_at) >= ?'
        );

        parameters.push(
            options.fromDate
        );
    }

    if (options.toDate) {
        conditions.push(
            'DATE(ase.created_at) <= ?'
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
            FROM ai_safety_events AS ase
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
                ase.id,
                ase.user_id,
                ase.conversation_id,
                ase.message_id,
                ase.event_type,
                ase.severity_level,
                ase.matched_terms,
                ase.redacted_excerpt,
                ase.action_taken,
                ase.emergency_contact_shown,
                ase.review_status,
                ase.reviewed_at,
                ase.created_at,

                u.email,
                p.full_name,
                ac.title AS conversation_title

            FROM ai_safety_events AS ase

            INNER JOIN users AS u
                ON u.id = ase.user_id

            LEFT JOIN user_profiles AS p
                ON p.user_id = u.id

            LEFT JOIN ai_conversations AS ac
                ON ac.id =
                    ase.conversation_id

            WHERE ${whereClause}

            ORDER BY
                FIELD(
                    ase.severity_level,
                    'critical',
                    'high',
                    'moderate',
                    'low'
                ),
                ase.created_at DESC,
                ase.id DESC

            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            parameters
        );

    const total =
        numberValue(countRows[0].total);

    return {
        events: rows.map((row) => ({
            id: Number(row.id),
            user: {
                id:
                    Number(row.user_id),
                email:
                    row.email,
                full_name:
                    row.full_name
            },
            conversation: {
                id:
                    row.conversation_id ===
                    null
                        ? null
                        : Number(
                            row
                                .conversation_id
                        ),
                title:
                    row.conversation_title
            },
            message_id:
                row.message_id === null
                    ? null
                    : Number(
                        row.message_id
                    ),
            event_type:
                row.event_type,
            severity_level:
                row.severity_level,
            matched_terms:
                parseJson(
                    row.matched_terms,
                    []
                ),
            redacted_excerpt:
                row.redacted_excerpt,
            action_taken:
                row.action_taken,
            emergency_contact_shown:
                booleanValue(
                    row
                        .emergency_contact_shown
                ),
            review_status:
                row.review_status,
            reviewed_at:
                row.reviewed_at,
            created_at:
                row.created_at
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

async function getSafetyEventById(eventId) {
    const [rows] =
        await pool.execute(
            `
            SELECT
                ase.*,

                u.email,
                u.account_status,
                p.full_name,
                p.timezone,

                ac.title AS conversation_title,
                ac.status AS conversation_status

            FROM ai_safety_events AS ase

            INNER JOIN users AS u
                ON u.id = ase.user_id

            LEFT JOIN user_profiles AS p
                ON p.user_id = u.id

            LEFT JOIN ai_conversations AS ac
                ON ac.id =
                    ase.conversation_id

            WHERE ase.id = ?
            LIMIT 1
            `,
            [eventId]
        );

    if (!rows[0]) {
        throw new AppError(
            404,
            'Safety event was not found.'
        );
    }

    const row = rows[0];

    const [reviewRows] =
        await pool.execute(
            `
            SELECT
                al.id,
                al.admin_user_id,
                al.new_values,
                al.metadata,
                al.created_at,
                au.full_name AS admin_name,
                au.email AS admin_email
            FROM audit_logs AS al
            LEFT JOIN admin_users AS au
                ON au.id =
                    al.admin_user_id
            WHERE
                al.entity_type =
                    'ai_safety_event'
                AND al.entity_id = ?
                AND al.action =
                    'safety_event_reviewed'
            ORDER BY
                al.created_at DESC,
                al.id DESC
            `,
            [eventId]
        );

    return {
        id: Number(row.id),

        user: {
            id: Number(row.user_id),
            email: row.email,
            full_name:
                row.full_name,
            account_status:
                row.account_status,
            timezone:
                row.timezone
        },

        conversation: {
            id:
                row.conversation_id ===
                null
                    ? null
                    : Number(
                        row.conversation_id
                    ),
            title:
                row.conversation_title,
            status:
                row.conversation_status
        },

        message_id:
            row.message_id === null
                ? null
                : Number(row.message_id),

        event_type:
            row.event_type,

        severity_level:
            row.severity_level,

        matched_terms:
            parseJson(
                row.matched_terms,
                []
            ),

        redacted_excerpt:
            row.redacted_excerpt,

        action_taken:
            row.action_taken,

        emergency_contact_shown:
            booleanValue(
                row.emergency_contact_shown
            ),

        review_status:
            row.review_status,

        reviewed_at:
            row.reviewed_at,

        review_history:
            reviewRows.map(
                (review) => ({
                    id:
                        Number(review.id),
                    admin: {
                        id:
                            review
                                .admin_user_id ===
                            null
                                ? null
                                : Number(
                                    review
                                        .admin_user_id
                                ),
                        name:
                            review.admin_name,
                        email:
                            review.admin_email
                    },
                    new_values:
                        parseJson(
                            review.new_values,
                            null
                        ),
                    metadata:
                        parseJson(
                            review.metadata,
                            null
                        ),
                    created_at:
                        review.created_at
                })
            ),

        created_at:
            row.created_at
    };
}

async function reviewSafetyEvent(
    adminId,
    eventId,
    reviewData,
    context
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        const [rows] =
            await connection.execute(
                `
                SELECT
                    id,
                    user_id,
                    event_type,
                    severity_level,
                    review_status,
                    reviewed_at
                FROM ai_safety_events
                WHERE id = ?
                LIMIT 1
                FOR UPDATE
                `,
                [eventId]
            );

        const event = rows[0];

        if (!event) {
            throw new AppError(
                404,
                'Safety event was not found.'
            );
        }

        await connection.execute(
            `
            UPDATE ai_safety_events
            SET
                review_status = ?,

                reviewed_at =
                    CASE
                        WHEN ? =
                            'unreviewed'
                        THEN NULL
                        ELSE CURRENT_TIMESTAMP
                    END

            WHERE id = ?
            `,
            [
                reviewData.review_status,
                reviewData.review_status,
                eventId
            ]
        );

        await insertAudit(
            connection,
            {
                adminId,
                action:
                    'safety_event_reviewed',
                entityType:
                    'ai_safety_event',
                entityId:
                    eventId,
                oldValues: {
                    review_status:
                        event.review_status,
                    reviewed_at:
                        event.reviewed_at
                },
                newValues: {
                    review_status:
                        reviewData
                            .review_status
                },
                metadata: {
                    user_id:
                        Number(
                            event.user_id
                        ),
                    event_type:
                        event.event_type,
                    severity_level:
                        event.severity_level,
                    note:
                        reviewData.note
                },
                context
            }
        );

        await connection.commit();

        return getSafetyEventById(
            eventId
        );
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function listReports(options) {
    const conditions = ['1 = 1'];
    const parameters = [];

    if (options.reportType) {
        conditions.push(
            'r.report_type = ?'
        );

        parameters.push(
            options.reportType
        );
    }

    if (options.status) {
        conditions.push(
            'r.status = ?'
        );

        parameters.push(
            options.status
        );
    }

    if (options.userId) {
        conditions.push(
            'r.user_id = ?'
        );

        parameters.push(
            options.userId
        );
    }

    if (options.fromDate) {
        conditions.push(
            'r.period_start >= ?'
        );

        parameters.push(
            options.fromDate
        );
    }

    if (options.toDate) {
        conditions.push(
            'r.period_end <= ?'
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
            FROM reports AS r
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
                r.id,
                r.user_id,
                r.report_type,

                DATE_FORMAT(
                    r.period_start,
                    '%Y-%m-%d'
                ) AS period_start,

                DATE_FORMAT(
                    r.period_end,
                    '%Y-%m-%d'
                ) AS period_end,

                r.status,
                r.summary,
                r.generated_by,
                r.algorithm_version,
                r.generated_at,
                r.failure_reason,
                r.created_at,

                u.email,
                p.full_name,

                (
                    SELECT COUNT(*)
                    FROM report_files AS rf
                    WHERE rf.report_id = r.id
                ) AS file_count

            FROM reports AS r

            INNER JOIN users AS u
                ON u.id = r.user_id

            LEFT JOIN user_profiles AS p
                ON p.user_id = u.id

            WHERE ${whereClause}

            ORDER BY
                r.created_at DESC,
                r.id DESC

            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            parameters
        );

    const total =
        numberValue(countRows[0].total);

    return {
        reports: rows.map((row) => ({
            id: Number(row.id),
            user: {
                id:
                    Number(row.user_id),
                email:
                    row.email,
                full_name:
                    row.full_name
            },
            report_type:
                row.report_type,
            period_start:
                row.period_start,
            period_end:
                row.period_end,
            status:
                row.status,
            summary:
                row.summary,
            generated_by:
                row.generated_by,
            algorithm_version:
                row.algorithm_version,
            generated_at:
                row.generated_at,
            failure_reason:
                row.failure_reason,
            file_count:
                numberValue(
                    row.file_count
                ),
            created_at:
                row.created_at
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

async function getReportById(reportId) {
    const [rows] =
        await pool.execute(
            `
            SELECT
                r.*,

                DATE_FORMAT(
                    r.period_start,
                    '%Y-%m-%d'
                ) AS formatted_period_start,

                DATE_FORMAT(
                    r.period_end,
                    '%Y-%m-%d'
                ) AS formatted_period_end,

                u.email,
                p.full_name

            FROM reports AS r

            INNER JOIN users AS u
                ON u.id = r.user_id

            LEFT JOIN user_profiles AS p
                ON p.user_id = u.id

            WHERE r.id = ?
            LIMIT 1
            `,
            [reportId]
        );

    if (!rows[0]) {
        throw new AppError(
            404,
            'Report was not found.'
        );
    }

    const row = rows[0];

    const [fileRows] =
        await pool.execute(
            `
            SELECT
                id,
                file_name,
                file_path,
                mime_type,
                file_size_bytes,
                storage_type,
                checksum_sha256,
                expires_at,
                created_at
            FROM report_files
            WHERE report_id = ?
            ORDER BY id DESC
            `,
            [reportId]
        );

    return {
        id: Number(row.id),

        user: {
            id: Number(row.user_id),
            email: row.email,
            full_name:
                row.full_name
        },

        report_type:
            row.report_type,

        period_start:
            row.formatted_period_start,

        period_end:
            row.formatted_period_end,

        status: row.status,
        summary: row.summary,

        metrics:
            parseJson(
                row.metrics,
                {}
            ),

        recommendations:
            row.recommendations,

        generated_by:
            row.generated_by,

        algorithm_version:
            row.algorithm_version,

        generated_at:
            row.generated_at,

        failure_reason:
            row.failure_reason,

        files:
            fileRows.map((file) => ({
                id: Number(file.id),
                file_name:
                    file.file_name,
                file_path:
                    file.file_path,
                mime_type:
                    file.mime_type,
                file_size_bytes:
                    file
                        .file_size_bytes ===
                    null
                        ? null
                        : Number(
                            file
                                .file_size_bytes
                        ),
                storage_type:
                    file.storage_type,
                checksum_sha256:
                    file.checksum_sha256,
                expires_at:
                    file.expires_at,
                created_at:
                    file.created_at
            })),

        created_at:
            row.created_at,

        updated_at:
            row.updated_at
    };
}

async function createAnnouncement(
    adminId,
    announcementData,
    context
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        let userConditions = [
            "account_status = 'active'",
            'deleted_at IS NULL'
        ];

        const userParameters = [];

        if (
            announcementData.user_ids.length >
            0
        ) {
            const placeholders =
                announcementData.user_ids
                    .map(() => '?')
                    .join(',');

            userConditions.push(
                `id IN (${placeholders})`
            );

            userParameters.push(
                ...announcementData.user_ids
            );
        }

        const [users] =
            await connection.execute(
                `
                SELECT id
                FROM users
                WHERE ${userConditions.join(
                    ' AND '
                )}
                `,
                userParameters
            );

        if (users.length === 0) {
            throw new AppError(
                422,
                'No active users matched this announcement.'
            );
        }

        const [templateRows] =
            await connection.execute(
                `
                SELECT id
                FROM notification_templates
                WHERE
                    template_code =
                        'GENERAL_ANNOUNCEMENT'
                    AND is_active = TRUE
                LIMIT 1
                `
            );

        const templateId =
            templateRows[0]?.id ||
            null;

        const isScheduled =
            announcementData.scheduled_at !==
            null;

        for (const user of users) {
            await connection.execute(
                `
                INSERT INTO notifications (
                    user_id,
                    template_id,
                    created_by_admin_id,
                    notification_type,
                    title,
                    body,
                    priority_level,
                    data_payload,
                    status,
                    scheduled_at,
                    sent_at
                )
                VALUES (
                    ?,
                    ?,
                    ?,
                    'announcement',
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?
                )
                `,
                [
                    user.id,
                    templateId,
                    adminId,
                    announcementData.title,
                    announcementData.body,
                    announcementData
                        .priority_level,

                    JSON.stringify({
                        announcement_title:
                            announcementData.title,
                        announcement_body:
                            announcementData.body
                    }),

                    isScheduled
                        ? 'scheduled'
                        : 'sent',

                    announcementData
                        .scheduled_at,

                    isScheduled
                        ? null
                        : new Date()
                ]
            );
        }

        await insertAudit(
            connection,
            {
                adminId,
                action:
                    'announcement_created',
                entityType:
                    'notification_announcement',
                entityId: null,
                oldValues: null,
                newValues: {
                    title:
                        announcementData.title,
                    body:
                        announcementData.body,
                    priority_level:
                        announcementData
                            .priority_level,
                    scheduled_at:
                        announcementData
                            .scheduled_at
                },
                metadata: {
                    recipient_count:
                        users.length,
                    targeted:
                        announcementData
                            .user_ids.length >
                        0
                },
                context
            }
        );

        await connection.commit();

        return {
            title:
                announcementData.title,
            priority_level:
                announcementData
                    .priority_level,
            status:
                isScheduled
                    ? 'scheduled'
                    : 'sent',
            scheduled_at:
                announcementData
                    .scheduled_at,
            recipient_count:
                users.length
        };
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function listAuditLogs(options) {
    const conditions = ['1 = 1'];
    const parameters = [];

    if (options.actorType) {
        conditions.push(
            'al.actor_type = ?'
        );

        parameters.push(
            options.actorType
        );
    }

    if (options.action) {
        conditions.push(
            'al.action LIKE ?'
        );

        parameters.push(
            `%${options.action}%`
        );
    }

    if (options.entityType) {
        conditions.push(
            'al.entity_type = ?'
        );

        parameters.push(
            options.entityType
        );
    }

    if (options.fromDate) {
        conditions.push(
            'DATE(al.created_at) >= ?'
        );

        parameters.push(
            options.fromDate
        );
    }

    if (options.toDate) {
        conditions.push(
            'DATE(al.created_at) <= ?'
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
            FROM audit_logs AS al
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
                al.*,

                u.email AS user_email,

                au.full_name AS admin_name,
                au.email AS admin_email

            FROM audit_logs AS al

            LEFT JOIN users AS u
                ON u.id = al.user_id

            LEFT JOIN admin_users AS au
                ON au.id =
                    al.admin_user_id

            WHERE ${whereClause}

            ORDER BY
                al.created_at DESC,
                al.id DESC

            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            parameters
        );

    const total =
        numberValue(countRows[0].total);

    return {
        logs: rows.map((row) => ({
            id: Number(row.id),
            actor_type:
                row.actor_type,
            actor: {
                user_id:
                    row.user_id === null
                        ? null
                        : Number(
                            row.user_id
                        ),
                user_email:
                    row.user_email,
                admin_user_id:
                    row.admin_user_id ===
                    null
                        ? null
                        : Number(
                            row
                                .admin_user_id
                        ),
                admin_name:
                    row.admin_name,
                admin_email:
                    row.admin_email
            },
            action:
                row.action,
            entity_type:
                row.entity_type,
            entity_id:
                row.entity_id === null
                    ? null
                    : Number(
                        row.entity_id
                    ),
            old_values:
                parseJson(
                    row.old_values,
                    null
                ),
            new_values:
                parseJson(
                    row.new_values,
                    null
                ),
            metadata:
                parseJson(
                    row.metadata,
                    null
                ),
            ip_address:
                row.ip_address,
            user_agent:
                row.user_agent,
            created_at:
                row.created_at
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

async function listSystemLogs(options) {
    const conditions = ['1 = 1'];
    const parameters = [];

    if (options.logLevel) {
        conditions.push(
            'log_level = ?'
        );

        parameters.push(
            options.logLevel
        );
    }

    if (options.serviceName) {
        conditions.push(
            'service_name = ?'
        );

        parameters.push(
            options.serviceName
        );
    }

    if (options.eventCode) {
        conditions.push(
            'event_code = ?'
        );

        parameters.push(
            options.eventCode
        );
    }

    if (options.search) {
        conditions.push(
            `
            (
                message LIKE ?
                OR context_data LIKE ?
                OR request_id LIKE ?
            )
            `
        );

        const searchValue =
            `%${options.search}%`;

        parameters.push(
            searchValue,
            searchValue,
            searchValue
        );
    }

    if (options.fromDate) {
        conditions.push(
            'DATE(occurred_at) >= ?'
        );

        parameters.push(
            options.fromDate
        );
    }

    if (options.toDate) {
        conditions.push(
            'DATE(occurred_at) <= ?'
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
            FROM system_logs
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
                log_level,
                service_name,
                event_code,
                message,
                context_data,
                stack_trace,
                request_id,
                occurred_at,
                created_at
            FROM system_logs
            WHERE ${whereClause}
            ORDER BY
                occurred_at DESC,
                id DESC
            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            parameters
        );

    const total =
        numberValue(countRows[0].total);

    return {
        logs: rows.map((row) => ({
            id: Number(row.id),
            log_level:
                row.log_level,
            service_name:
                row.service_name,
            event_code:
                row.event_code,
            message:
                row.message,
            context_data:
                parseJson(
                    row.context_data,
                    null
                ),
            stack_trace:
                row.stack_trace,
            request_id:
                row.request_id,
            occurred_at:
                row.occurred_at,
            created_at:
                row.created_at
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

module.exports = {
    getDashboardSummary,
    getDashboardTrends,
    listUsers,
    getUserById,
    updateUserStatus,
    listSafetyEvents,
    getSafetyEventById,
    reviewSafetyEvent,
    listReports,
    getReportById,
    createAnnouncement,
    listAuditLogs,
    listSystemLogs
};
