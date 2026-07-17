const database =
    require('../config/database');

const AppError =
    require('../utils/AppError');

const {
    getFcmMode,
    isDryRun,
    getFirebaseStatus,
    getFirebaseMessaging
} = require('../config/firebase');

const pool =
    database.pool || database;

const PREFERENCE_COLUMNS = {
    checkin_reminder:
        'checkin_reminders',

    habit_reminder:
        'habit_reminders',

    sleep_reminder:
        'sleep_reminders',

    recovery_reminder:
        'recovery_reminders',

    wellness_scan_reminder:
        'wellness_scan_reminders',

    report_ready:
        'report_notifications',

    achievement:
        'achievement_notifications',

    inactivity:
        'inactivity_reminders',

    announcement:
        'announcement_notifications',

    system: null
};

const INVALID_TOKEN_CODES =
    new Set([
        'messaging/registration-token-not-registered',
        'messaging/invalid-registration-token'
    ]);

function booleanValue(value) {
    return Boolean(Number(value));
}

function parseJson(
    value,
    fallback = {}
) {
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

function truncate(
    value,
    maximumLength
) {
    if (!value) {
        return null;
    }

    return String(value).slice(
        0,
        maximumLength
    );
}

function chunkArray(
    values,
    size
) {
    const chunks = [];

    for (
        let index = 0;
        index < values.length;
        index += size
    ) {
        chunks.push(
            values.slice(
                index,
                index + size
            )
        );
    }

    return chunks;
}

function normalizeFcmData(
    payload,
    notification
) {
    const result = {
        notification_id:
            String(notification.id),

        notification_type:
            String(
                notification
                    .notification_type
            ),

        priority_level:
            String(
                notification
                    .priority_level
            )
    };

    for (
        const [key, value]
        of Object.entries(
            payload || {}
        )
    ) {
        if (
            value === undefined ||
            value === null
        ) {
            continue;
        }

        result[String(key)] =
            typeof value === 'object'
                ? JSON.stringify(value)
                : String(value);
    }

    return result;
}

function parseClockMinutes(value) {
    if (!value) {
        return null;
    }

    const match =
        String(value).match(
            /^(\d{1,2}):(\d{2})/
        );

    if (!match) {
        return null;
    }

    const hour =
        Number(match[1]);

    const minute =
        Number(match[2]);

    if (
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59
    ) {
        return null;
    }

    return hour * 60 + minute;
}

function getLocalMinutes(
    timezone
) {
    try {
        const parts =
            new Intl.DateTimeFormat(
                'en-GB',
                {
                    timeZone:
                        timezone ||
                        'Asia/Dhaka',

                    hour: '2-digit',
                    minute: '2-digit',
                    hourCycle: 'h23'
                }
            ).formatToParts(
                new Date()
            );

        const hour =
            Number(
                parts.find(
                    (part) =>
                        part.type ===
                        'hour'
                )?.value
            );

        const minute =
            Number(
                parts.find(
                    (part) =>
                        part.type ===
                        'minute'
                )?.value
            );

        if (
            !Number.isInteger(hour) ||
            !Number.isInteger(minute)
        ) {
            return null;
        }

        return hour * 60 + minute;
    } catch {
        return null;
    }
}

function isInsideQuietHours(
    notification
) {
    if (
        !booleanValue(
            notification
                .quiet_hours_enabled
        )
    ) {
        return false;
    }

    const start =
        parseClockMinutes(
            notification
                .quiet_hours_start
        );

    const end =
        parseClockMinutes(
            notification
                .quiet_hours_end
        );

    const current =
        getLocalMinutes(
            notification.timezone
        );

    if (
        start === null ||
        end === null ||
        current === null ||
        start === end
    ) {
        return false;
    }

    if (start < end) {
        return (
            current >= start &&
            current < end
        );
    }

    return (
        current >= start ||
        current < end
    );
}

async function getNotification(
    notificationId
) {
    const [rows] =
        await pool.execute(
            `
            SELECT
                n.*,
                u.account_status,
                u.deleted_at,

                COALESCE(
                    np.notifications_enabled,
                    1
                ) AS notifications_enabled,

                COALESCE(
                    np.checkin_reminders,
                    1
                ) AS checkin_reminders,

                COALESCE(
                    np.habit_reminders,
                    1
                ) AS habit_reminders,

                COALESCE(
                    np.sleep_reminders,
                    1
                ) AS sleep_reminders,

                COALESCE(
                    np.recovery_reminders,
                    1
                ) AS recovery_reminders,

                COALESCE(
                    np.wellness_scan_reminders,
                    1
                ) AS wellness_scan_reminders,

                COALESCE(
                    np.report_notifications,
                    1
                ) AS report_notifications,

                COALESCE(
                    np.achievement_notifications,
                    1
                ) AS achievement_notifications,

                COALESCE(
                    np.inactivity_reminders,
                    1
                ) AS inactivity_reminders,

                COALESCE(
                    np.announcement_notifications,
                    1
                ) AS announcement_notifications,

                COALESCE(
                    np.quiet_hours_enabled,
                    0
                ) AS quiet_hours_enabled,

                np.quiet_hours_start,
                np.quiet_hours_end,

                COALESCE(
                    np.timezone,
                    'Asia/Dhaka'
                ) AS timezone

            FROM notifications AS n

            INNER JOIN users AS u
                ON u.id = n.user_id

            LEFT JOIN
                notification_preferences
                    AS np
                ON np.user_id =
                    n.user_id

            WHERE n.id = ?
            LIMIT 1
            `,
            [notificationId]
        );

    if (!rows[0]) {
        throw new AppError(
            404,
            'Notification was not found.'
        );
    }

    return {
        ...rows[0],

        id: Number(rows[0].id),

        user_id:
            Number(rows[0].user_id),

        data_payload:
            parseJson(
                rows[0].data_payload,
                {}
            )
    };
}

function evaluatePolicy(
    notification,
    respectQuietHours
) {
    if (
        notification.deleted_at ||
        notification.account_status !==
            'active'
    ) {
        return {
            allowed: false,
            final_status:
                'cancelled',
            reason:
                'user_account_unavailable'
        };
    }

    if (
        !booleanValue(
            notification
                .notifications_enabled
        )
    ) {
        return {
            allowed: false,
            final_status:
                'cancelled',
            reason:
                'notifications_disabled'
        };
    }

    const preferenceColumn =
        PREFERENCE_COLUMNS[
            notification
                .notification_type
        ];

    if (
        preferenceColumn &&
        !booleanValue(
            notification[
                preferenceColumn
            ]
        )
    ) {
        return {
            allowed: false,
            final_status:
                'cancelled',
            reason:
                'notification_type_disabled'
        };
    }

    if (
        respectQuietHours &&
        isInsideQuietHours(
            notification
        )
    ) {
        return {
            allowed: false,
            final_status:
                null,
            reason:
                'quiet_hours_active'
        };
    }

    return {
        allowed: true,
        final_status: null,
        reason: null
    };
}

async function getActiveDevices(
    userId
) {
    const [rows] =
        await pool.execute(
            `
            SELECT
                id,
                user_id,
                token,
                platform,
                device_name,
                is_active,
                last_used_at
            FROM device_tokens
            WHERE
                user_id = ?
                AND is_active = TRUE
            ORDER BY id ASC
            `,
            [userId]
        );

    return rows.map(
        (row) => ({
            ...row,
            id: Number(row.id),
            user_id:
                Number(row.user_id)
        })
    );
}

function buildMessage(
    notification,
    devices
) {
    const highPriority =
        notification
            .priority_level ===
        'high';

    return {
        tokens:
            devices.map(
                (device) =>
                    device.token
            ),

        notification: {
            title:
                notification.title,
            body:
                notification.body
        },

        data:
            normalizeFcmData(
                notification
                    .data_payload,
                notification
            ),

        android: {
            priority:
                highPriority
                    ? 'high'
                    : 'normal',

            notification: {
                channelId:
                    process.env
                        .FCM_ANDROID_CHANNEL_ID ||
                    'mindpulse_default',

                sound: 'default'
            }
        },

        apns: {
            headers: {
                'apns-priority':
                    highPriority
                        ? '10'
                        : '5'
            },

            payload: {
                aps: {
                    sound: 'default'
                }
            }
        }
    };
}

function createMockResponse(
    devices,
    notificationId
) {
    return {
        successCount:
            devices.length,

        failureCount: 0,

        responses:
            devices.map(
                (device) => ({
                    success: true,

                    messageId:
                        `mock/${notificationId}/${device.id}/${Date.now()}`
                })
            )
    };
}

async function createNotification(
    adminId,
    data
) {
    const [userRows] =
        await pool.execute(
            `
            SELECT
                id,
                account_status,
                deleted_at
            FROM users
            WHERE id = ?
            LIMIT 1
            `,
            [data.user_id]
        );

    const user = userRows[0];

    if (!user || user.deleted_at) {
        throw new AppError(
            404,
            'Target user was not found.'
        );
    }

    const [result] =
        await pool.execute(
            `
            INSERT INTO notifications (
                user_id,
                created_by_admin_id,
                notification_type,
                title,
                body,
                priority_level,
                data_payload,
                status
            )
            VALUES (
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                'pending'
            )
            `,
            [
                data.user_id,
                adminId,
                data.notification_type,
                data.title,
                data.body,
                data.priority_level,

                JSON.stringify(
                    data.data_payload || {}
                )
            ]
        );

    return Number(
        result.insertId
    );
}

async function getAttemptMap(
    notificationId
) {
    const [rows] =
        await pool.execute(
            `
            SELECT
                device_token_id,
                MAX(
                    attempt_number
                ) AS maximum_attempt
            FROM notification_logs
            WHERE notification_id = ?
            GROUP BY device_token_id
            `,
            [notificationId]
        );

    return new Map(
        rows.map(
            (row) => [
                row.device_token_id ===
                    null
                    ? 'null'
                    : Number(
                        row
                            .device_token_id
                    ),

                Number(
                    row.maximum_attempt ||
                    0
                )
            ]
        )
    );
}

async function saveDeliveryResults(
    notification,
    results,
    simulated
) {
    const attemptMap =
        await getAttemptMap(
            notification.id
        );

    const connection =
        await pool.getConnection();

    let successCount = 0;
    let failureCount = 0;
    let deactivatedCount = 0;

    try {
        await connection.beginTransaction();

        for (const result of results) {
            const response =
                result.response;

            const device =
                result.device;

            const attemptNumber =
                (
                    attemptMap.get(
                        device.id
                    ) || 0
                ) + 1;

            if (response.success) {
                successCount += 1;

                await connection.execute(
                    `
                    INSERT INTO
                        notification_logs (
                            notification_id,
                            device_token_id,
                            delivery_status,
                            provider_message_id,
                            attempt_number,
                            error_message,
                            attempted_at
                        )
                    VALUES (
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        NULL,
                        CURRENT_TIMESTAMP
                    )
                    `,
                    [
                        notification.id,
                        device.id,

                        simulated
                            ? 'queued'
                            : 'sent',

                        truncate(
                            response.messageId,
                            255
                        ),

                        attemptNumber
                    ]
                );

                if (!simulated) {
                    await connection.execute(
                        `
                        UPDATE device_tokens
                        SET last_used_at =
                            CURRENT_TIMESTAMP
                        WHERE id = ?
                        `,
                        [device.id]
                    );
                }

                continue;
            }

            failureCount += 1;

            const errorCode =
                response.error?.code ||
                'messaging/unknown-error';

            const errorMessage =
                response.error?.message ||
                errorCode;

            await connection.execute(
                `
                INSERT INTO
                    notification_logs (
                        notification_id,
                        device_token_id,
                        delivery_status,
                        provider_message_id,
                        attempt_number,
                        error_message,
                        attempted_at
                    )
                VALUES (
                    ?,
                    ?,
                    'failed',
                    NULL,
                    ?,
                    ?,
                    CURRENT_TIMESTAMP
                )
                `,
                [
                    notification.id,
                    device.id,
                    attemptNumber,

                    truncate(
                        `${errorCode}: ${errorMessage}`,
                        1000
                    )
                ]
            );

            if (
                INVALID_TOKEN_CODES.has(
                    errorCode
                )
            ) {
                await connection.execute(
                    `
                    UPDATE device_tokens
                    SET is_active = FALSE
                    WHERE id = ?
                    `,
                    [device.id]
                );

                deactivatedCount += 1;
            }
        }

        if (!simulated) {
            if (successCount > 0) {
                await connection.execute(
                    `
                    UPDATE notifications
                    SET
                        status = 'sent',
                        sent_at =
                            CURRENT_TIMESTAMP
                    WHERE id = ?
                    `,
                    [notification.id]
                );
            } else {
                await connection.execute(
                    `
                    UPDATE notifications
                    SET status = 'failed'
                    WHERE id = ?
                    `,
                    [notification.id]
                );
            }
        }

        await connection.commit();

        return {
            success_count:
                successCount,

            failure_count:
                failureCount,

            deactivated_token_count:
                deactivatedCount
        };
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function recordNoDeviceFailure(
    notification
) {
    const attemptMap =
        await getAttemptMap(
            notification.id
        );

    const attemptNumber =
        (
            attemptMap.get('null') ||
            0
        ) + 1;

    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await connection.execute(
            `
            INSERT INTO
                notification_logs (
                    notification_id,
                    device_token_id,
                    delivery_status,
                    provider_message_id,
                    attempt_number,
                    error_message,
                    attempted_at
                )
            VALUES (
                ?,
                NULL,
                'failed',
                NULL,
                ?,
                'No active device token was found.',
                CURRENT_TIMESTAMP
            )
            `,
            [
                notification.id,
                attemptNumber
            ]
        );

        await connection.execute(
            `
            UPDATE notifications
            SET status = 'failed'
            WHERE id = ?
            `,
            [notification.id]
        );

        await connection.commit();
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function sendNotification(
    notificationId,
    options = {}
) {
    const notification =
        await getNotification(
            notificationId
        );

    const respectQuietHours =
        options.respectQuietHours !==
        false;

    const policy =
        evaluatePolicy(
            notification,
            respectQuietHours
        );

    if (!policy.allowed) {
        if (policy.final_status) {
            await pool.execute(
                `
                UPDATE notifications
                SET status = ?
                WHERE id = ?
                `,
                [
                    policy.final_status,
                    notification.id
                ]
            );
        }

        return {
            notification_id:
                notification.id,

            mode: getFcmMode(),
            sent: false,
            skipped: true,
            reason: policy.reason
        };
    }

    const devices =
        await getActiveDevices(
            notification.user_id
        );

    if (devices.length === 0) {
        await recordNoDeviceFailure(
            notification
        );

        return {
            notification_id:
                notification.id,

            mode: getFcmMode(),
            sent: false,
            skipped: false,
            reason:
                'no_active_device_token',

            success_count: 0,
            failure_count: 1,
            deactivated_token_count: 0
        };
    }

    const mode =
        getFcmMode();

    const dryRun =
        isDryRun();

    const simulated =
        mode === 'mock' ||
        dryRun;

    const deviceChunks =
        chunkArray(
            devices,
            500
        );

    const collectedResults = [];

    for (
        const deviceChunk
        of deviceChunks
    ) {
        let batchResponse;

        if (mode === 'mock') {
            batchResponse =
                createMockResponse(
                    deviceChunk,
                    notification.id
                );
        } else {
            const messaging =
                getFirebaseMessaging();

            const message =
                buildMessage(
                    notification,
                    deviceChunk
                );

            batchResponse =
                await messaging
                    .sendEachForMulticast(
                        message,
                        dryRun
                    );
        }

        batchResponse.responses
            .forEach(
                (
                    response,
                    index
                ) => {
                    collectedResults.push({
                        device:
                            deviceChunk[
                                index
                            ],

                        response
                    });
                }
            );
    }

    const delivery =
        await saveDeliveryResults(
            notification,
            collectedResults,
            simulated
        );

    return {
        notification_id:
            notification.id,

        mode,
        dry_run: dryRun,
        simulated,

        sent:
            !simulated &&
            delivery.success_count > 0,

        skipped: false,

        device_count:
            devices.length,

        batch_count:
            deviceChunks.length,

        ...delivery
    };
}

async function createAndSendTest(
    adminId,
    data
) {
    const notificationId =
        await createNotification(
            adminId,
            data
        );

    const delivery =
        await sendNotification(
            notificationId,
            {
                respectQuietHours:
                    data
                        .respect_quiet_hours
            }
        );

    return {
        notification_id:
            notificationId,

        delivery
    };
}

module.exports = {
    getFirebaseStatus,
    sendNotification,
    createAndSendTest
};
