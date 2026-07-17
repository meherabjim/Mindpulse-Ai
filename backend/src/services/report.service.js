const database =
    require('../config/database');

const AppError =
    require('../utils/AppError');

const pool = database.pool || database;

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

async function ensureActiveUser(userId) {
    const [rows] = await pool.execute(
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

function addDays(dateString, amount) {
    const date =
        new Date(
            `${dateString}T00:00:00Z`
        );

    date.setUTCDate(
        date.getUTCDate() + amount
    );

    return date
        .toISOString()
        .slice(0, 10);
}

function firstDayOfMonth(dateString) {
    return `${dateString.slice(0, 7)}-01`;
}

function resolvePeriod(
    reportType,
    start,
    end,
    today
) {
    if (start && end) {
        return {
            periodStart: start,
            periodEnd: end
        };
    }

    if (reportType === 'monthly') {
        return {
            periodStart:
                firstDayOfMonth(today),
            periodEnd: today
        };
    }

    return {
        periodStart:
            addDays(today, -6),
        periodEnd: today
    };
}

async function calculateMetrics(
    userId,
    periodStart,
    periodEnd
) {
    const [
        checkinResult,
        wellnessResult,
        habitResult,
        recoveryResult,
        journalResult,
        burnoutResult
    ] = await Promise.all([
        pool.execute(
            `
            SELECT
                COUNT(*) AS checkin_count,
                ROUND(
                    AVG(mood_score),
                    2
                ) AS average_mood,
                ROUND(
                    AVG(stress_level),
                    2
                ) AS average_stress,
                ROUND(
                    AVG(energy_level),
                    2
                ) AS average_energy,
                ROUND(
                    AVG(sleep_hours),
                    2
                ) AS average_sleep_hours,
                SUM(
                    CASE
                        WHEN
                            water_intake_glasses >= 8
                        THEN 1
                        ELSE 0
                    END
                ) AS hydration_target_days,
                SUM(
                    CASE
                        WHEN
                            sleep_hours BETWEEN 7 AND 9
                        THEN 1
                        ELSE 0
                    END
                ) AS sleep_target_days
            FROM daily_checkins
            WHERE
                user_id = ?
                AND checkin_date
                    BETWEEN ? AND ?
            `,
            [
                userId,
                periodStart,
                periodEnd
            ]
        ),

        pool.execute(
            `
            SELECT
                COUNT(*) AS scan_count,
                ROUND(
                    AVG(total_score),
                    2
                ) AS average_wellness_risk
            FROM wellness_scans
            WHERE
                user_id = ?
                AND DATE(completed_at)
                    BETWEEN ? AND ?
            `,
            [
                userId,
                periodStart,
                periodEnd
            ]
        ),

        pool.execute(
            `
            SELECT
                COUNT(*) AS total_logs,

                SUM(
                    CASE
                        WHEN hl.status =
                            'completed'
                        THEN 1
                        ELSE 0
                    END
                ) AS completed_logs

            FROM habit_logs AS hl

            INNER JOIN habits AS h
                ON h.id = hl.habit_id

            WHERE
                h.user_id = ?
                AND h.deleted_at IS NULL
                AND hl.log_date
                    BETWEEN ? AND ?
            `,
            [
                userId,
                periodStart,
                periodEnd
            ]
        ),

        pool.execute(
            `
            SELECT
                (
                    SELECT COUNT(*)
                    FROM recovery_activity_logs
                    WHERE
                        user_id = ?
                        AND status =
                            'completed'
                        AND DATE(completed_at)
                            BETWEEN ? AND ?
                ) AS completed_activities,

                (
                    SELECT ROUND(
                        AVG(recovery_score),
                        2
                    )
                    FROM recovery_progress
                    WHERE
                        user_id = ?
                        AND progress_date
                            BETWEEN ? AND ?
                ) AS average_recovery_score
            `,
            [
                userId,
                periodStart,
                periodEnd,
                userId,
                periodStart,
                periodEnd
            ]
        ),

        pool.execute(
            `
            SELECT COUNT(*) AS journal_count
            FROM journals
            WHERE
                user_id = ?
                AND deleted_at IS NULL
                AND entry_date
                    BETWEEN ? AND ?
            `,
            [
                userId,
                periodStart,
                periodEnd
            ]
        ),

        pool.execute(
            `
            SELECT
                ROUND(
                    AVG(burnout_score),
                    2
                ) AS average_burnout_score,

                (
                    SELECT risk_level
                    FROM burnout_assessments
                    WHERE
                        user_id = ?
                        AND DATE(assessed_at)
                            BETWEEN ? AND ?
                    ORDER BY
                        assessed_at DESC,
                        id DESC
                    LIMIT 1
                ) AS latest_risk_level

            FROM burnout_assessments

            WHERE
                user_id = ?
                AND DATE(assessed_at)
                    BETWEEN ? AND ?
            `,
            [
                userId,
                periodStart,
                periodEnd,
                userId,
                periodStart,
                periodEnd
            ]
        )
    ]);

    const checkin =
        checkinResult[0][0];

    const wellness =
        wellnessResult[0][0];

    const habit =
        habitResult[0][0];

    const recovery =
        recoveryResult[0][0];

    const journal =
        journalResult[0][0];

    const burnout =
        burnoutResult[0][0];

    const totalHabitLogs =
        Number(habit.total_logs || 0);

    const completedHabitLogs =
        Number(
            habit.completed_logs || 0
        );

    return {
        period_start: periodStart,
        period_end: periodEnd,

        checkins: {
            count:
                Number(
                    checkin.checkin_count || 0
                ),
            average_mood:
                numberOrNull(
                    checkin.average_mood
                ),
            average_stress:
                numberOrNull(
                    checkin.average_stress
                ),
            average_energy:
                numberOrNull(
                    checkin.average_energy
                ),
            average_sleep_hours:
                numberOrNull(
                    checkin.average_sleep_hours
                ),
            hydration_target_days:
                Number(
                    checkin
                        .hydration_target_days || 0
                ),
            sleep_target_days:
                Number(
                    checkin
                        .sleep_target_days || 0
                )
        },

        wellness: {
            scan_count:
                Number(
                    wellness.scan_count || 0
                ),
            average_risk_score:
                numberOrNull(
                    wellness
                        .average_wellness_risk
                )
        },

        habits: {
            total_logs:
                totalHabitLogs,
            completed_logs:
                completedHabitLogs,
            completion_percent:
                totalHabitLogs === 0
                    ? 0
                    : Number(
                        (
                            completedHabitLogs /
                            totalHabitLogs *
                            100
                        ).toFixed(2)
                    )
        },

        recovery: {
            completed_activities:
                Number(
                    recovery
                        .completed_activities || 0
                ),
            average_recovery_score:
                numberOrNull(
                    recovery
                        .average_recovery_score
                )
        },

        journals: {
            count:
                Number(
                    journal.journal_count || 0
                )
        },

        burnout: {
            average_score:
                numberOrNull(
                    burnout
                        .average_burnout_score
                ),
            latest_risk_level:
                burnout.latest_risk_level
        }
    };
}

function buildSummary(metrics) {
    const parts = [];

    parts.push(
        `You completed ${metrics.checkins.count} daily check-in(s) during this period.`
    );

    parts.push(
        `Habit completion was ${metrics.habits.completion_percent}%.`
    );

    if (
        metrics.checkins.average_sleep_hours !==
        null
    ) {
        parts.push(
            `Average sleep was ${metrics.checkins.average_sleep_hours} hours.`
        );
    }

    if (
        metrics.recovery
            .average_recovery_score !== null
    ) {
        parts.push(
            `Average recovery score was ${metrics.recovery.average_recovery_score}.`
        );
    }

    if (
        metrics.burnout
            .latest_risk_level
    ) {
        parts.push(
            `The latest recorded wellness support level was ${metrics.burnout.latest_risk_level}.`
        );
    }

    return parts.join(' ');
}

function buildRecommendations(metrics) {
    const recommendations = [];

    if (
        metrics.checkins.count < 3
    ) {
        recommendations.push(
            'Complete regular check-ins to improve trend accuracy.'
        );
    }

    if (
        metrics.checkins.average_sleep_hours !==
            null &&
        metrics.checkins.average_sleep_hours < 7
    ) {
        recommendations.push(
            'Work toward a more consistent sleep schedule.'
        );
    }

    if (
        metrics.habits.completion_percent <
        60
    ) {
        recommendations.push(
            'Reduce habit targets and focus on small repeatable actions.'
        );
    }

    if (
        metrics.burnout.latest_risk_level ===
            'moderate' ||
        metrics.burnout.latest_risk_level ===
            'elevated'
    ) {
        recommendations.push(
            'Prioritize recovery and consider support from a trusted person or qualified professional.'
        );
    }

    if (recommendations.length === 0) {
        recommendations.push(
            'Continue your current wellness routine and review your progress regularly.'
        );
    }

    return recommendations.join(' ');
}

async function createReportNotification(
    executor,
    userId,
    reportId,
    periodStart,
    periodEnd
) {
    const [templateRows] =
        await executor.execute(
            `
            SELECT *
            FROM notification_templates
            WHERE
                template_code =
                    'WEEKLY_REPORT_READY'
                AND is_active = TRUE
            LIMIT 1
            `
        );

    const template =
        templateRows[0];

    const title =
        template?.title_template ||
        'Your wellness report is ready';

    const body =
        template?.body_template ||
        'Your latest wellness report is ready to view.';

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
            ?, ?,
            'report_ready',
            ?, ?,
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
                report_id:
                    Number(reportId),
                report_period:
                    `${periodStart} to ${periodEnd}`
            })
        ]
    );
}

async function generateReport(
    userId,
    requestData
) {
    await ensureActiveUser(userId);

    const timezone =
        await getUserTimezone(userId);

    const today =
        getDateInTimezone(timezone);

    const {
        periodStart,
        periodEnd
    } = resolvePeriod(
        requestData.report_type,
        requestData.period_start,
        requestData.period_end,
        today
    );

    const metrics =
        await calculateMetrics(
            userId,
            periodStart,
            periodEnd
        );

    const summary =
        buildSummary(metrics);

    const recommendations =
        buildRecommendations(metrics);

    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        const [result] =
            await connection.execute(
                `
                INSERT INTO reports (
                    user_id,
                    report_type,
                    period_start,
                    period_end,
                    status,
                    summary,
                    metrics,
                    recommendations,
                    generated_by,
                    algorithm_version,
                    generated_at
                )
                VALUES (
                    ?, ?, ?, ?,
                    'completed',
                    ?, ?, ?,
                    'system',
                    '1.0',
                    CURRENT_TIMESTAMP
                )
                `,
                [
                    userId,
                    requestData.report_type,
                    periodStart,
                    periodEnd,
                    summary,
                    JSON.stringify(metrics),
                    recommendations
                ]
            );

        await createReportNotification(
            connection,
            userId,
            result.insertId,
            periodStart,
            periodEnd
        );

        await connection.commit();

        return getReportById(
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

function mapReport(row) {
    return {
        id: Number(row.id),
        report_type:
            row.report_type,
        period_start:
            row.period_start,
        period_end:
            row.period_end,
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
        created_at:
            row.created_at,
        updated_at:
            row.updated_at
    };
}

async function getReportById(
    userId,
    reportId
) {
    await ensureActiveUser(userId);

    const [rows] = await pool.execute(
        `
        SELECT
            id,
            report_type,
            DATE_FORMAT(
                period_start,
                '%Y-%m-%d'
            ) AS period_start,
            DATE_FORMAT(
                period_end,
                '%Y-%m-%d'
            ) AS period_end,
            status,
            summary,
            metrics,
            recommendations,
            generated_by,
            algorithm_version,
            generated_at,
            failure_reason,
            created_at,
            updated_at
        FROM reports
        WHERE
            id = ?
            AND user_id = ?
        LIMIT 1
        `,
        [
            reportId,
            userId
        ]
    );

    if (!rows[0]) {
        throw new AppError(
            404,
            'Report was not found.'
        );
    }

    const report =
        mapReport(rows[0]);

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
                expires_at,
                created_at
            FROM report_files
            WHERE report_id = ?
            ORDER BY id DESC
            `,
            [reportId]
        );

    report.files =
        fileRows.map((file) => ({
            id: Number(file.id),
            file_name:
                file.file_name,
            file_path:
                file.file_path,
            mime_type:
                file.mime_type,
            file_size_bytes:
                file.file_size_bytes === null
                    ? null
                    : Number(
                        file.file_size_bytes
                    ),
            storage_type:
                file.storage_type,
            expires_at:
                file.expires_at,
            created_at:
                file.created_at
        }));

    return report;
}

async function listReports(
    userId,
    options
) {
    await ensureActiveUser(userId);

    const offset =
        (options.page - 1) *
        options.limit;

    const [countRows] =
        await pool.execute(
            `
            SELECT COUNT(*) AS total
            FROM reports
            WHERE user_id = ?
            `,
            [userId]
        );

    const [rows] = await pool.execute(
        `
        SELECT
            id,
            report_type,
            DATE_FORMAT(
                period_start,
                '%Y-%m-%d'
            ) AS period_start,
            DATE_FORMAT(
                period_end,
                '%Y-%m-%d'
            ) AS period_end,
            status,
            summary,
            metrics,
            recommendations,
            generated_by,
            algorithm_version,
            generated_at,
            failure_reason,
            created_at,
            updated_at
        FROM reports
        WHERE user_id = ?
        ORDER BY
            created_at DESC,
            id DESC
        LIMIT ${options.limit}
        OFFSET ${offset}
        `,
        [userId]
    );

    const total =
        Number(countRows[0].total);

    return {
        reports:
            rows.map(mapReport),

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
    generateReport,
    getReportById,
    listReports
};
