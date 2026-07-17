const database =
    require('../config/database');

const AppError =
    require('../utils/AppError');

const pool = database.pool || database;

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

function mapNotification(row) {
    return {
        id: Number(row.id),
        notification_type:
            row.notification_type,
        title: row.title,
        body: row.body,
        priority_level:
            row.priority_level,
        data_payload:
            parseJson(
                row.data_payload,
                null
            ),
        status: row.status,
        is_read:
            row.read_at !== null,
        scheduled_at:
            row.scheduled_at,
        sent_at:
            row.sent_at,
        delivered_at:
            row.delivered_at,
        read_at:
            row.read_at,
        created_at:
            row.created_at
    };
}

async function listNotifications(
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
            FROM notifications
            WHERE
                user_id = ?
                AND status <> 'cancelled'
            `,
            [userId]
        );

    const [rows] = await pool.execute(
        `
        SELECT *
        FROM notifications
        WHERE
            user_id = ?
            AND status <> 'cancelled'
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
        notifications:
            rows.map(mapNotification),

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

async function getUnreadCount(userId) {
    await ensureActiveUser(userId);

    const [rows] = await pool.execute(
        `
        SELECT COUNT(*) AS unread_count
        FROM notifications
        WHERE
            user_id = ?
            AND read_at IS NULL
            AND status <> 'cancelled'
        `,
        [userId]
    );

    return Number(
        rows[0].unread_count
    );
}

async function markRead(
    userId,
    notificationId
) {
    await ensureActiveUser(userId);

    const [result] =
        await pool.execute(
            `
            UPDATE notifications
            SET
                status = 'read',
                read_at = COALESCE(
                    read_at,
                    CURRENT_TIMESTAMP
                )
            WHERE
                id = ?
                AND user_id = ?
                AND status <> 'cancelled'
            `,
            [
                notificationId,
                userId
            ]
        );

    if (result.affectedRows === 0) {
        throw new AppError(
            404,
            'Notification was not found.'
        );
    }
}

async function markAllRead(userId) {
    await ensureActiveUser(userId);

    const [result] =
        await pool.execute(
            `
            UPDATE notifications
            SET
                status = 'read',
                read_at = COALESCE(
                    read_at,
                    CURRENT_TIMESTAMP
                )
            WHERE
                user_id = ?
                AND read_at IS NULL
                AND status <> 'cancelled'
            `,
            [userId]
        );

    return Number(result.affectedRows);
}

async function cancelNotification(
    userId,
    notificationId
) {
    await ensureActiveUser(userId);

    const [result] =
        await pool.execute(
            `
            UPDATE notifications
            SET status = 'cancelled'
            WHERE
                id = ?
                AND user_id = ?
                AND status <> 'cancelled'
            `,
            [
                notificationId,
                userId
            ]
        );

    if (result.affectedRows === 0) {
        throw new AppError(
            404,
            'Notification was not found.'
        );
    }
}

async function registerDevice(
    userId,
    deviceData
) {
    await ensureActiveUser(userId);

    const [result] =
        await pool.execute(
            `
            INSERT INTO device_tokens (
                user_id,
                token,
                platform,
                device_name,
                is_active,
                last_used_at
            )
            VALUES (
                ?, ?, ?, ?, TRUE,
                CURRENT_TIMESTAMP
            )

            ON DUPLICATE KEY UPDATE
                id = LAST_INSERT_ID(id),
                user_id =
                    VALUES(user_id),
                platform =
                    VALUES(platform),
                device_name =
                    VALUES(device_name),
                is_active = TRUE,
                last_used_at =
                    CURRENT_TIMESTAMP
            `,
            [
                userId,
                deviceData.token,
                deviceData.platform,
                deviceData.device_name
            ]
        );

    const [rows] = await pool.execute(
        `
        SELECT *
        FROM device_tokens
        WHERE
            id = ?
            AND user_id = ?
        LIMIT 1
        `,
        [
            result.insertId,
            userId
        ]
    );

    return {
        id: Number(rows[0].id),
        token: rows[0].token,
        platform:
            rows[0].platform,
        device_name:
            rows[0].device_name,
        is_active:
            booleanValue(
                rows[0].is_active
            ),
        last_used_at:
            rows[0].last_used_at,
        created_at:
            rows[0].created_at
    };
}

async function unregisterDevice(
    userId,
    deviceId
) {
    await ensureActiveUser(userId);

    const [result] =
        await pool.execute(
            `
            UPDATE device_tokens
            SET is_active = FALSE
            WHERE
                id = ?
                AND user_id = ?
                AND is_active = TRUE
            `,
            [
                deviceId,
                userId
            ]
        );

    if (result.affectedRows === 0) {
        throw new AppError(
            404,
            'Active device token was not found.'
        );
    }
}

module.exports = {
    listNotifications,
    getUnreadCount,
    markRead,
    markAllRead,
    cancelNotification,
    registerDevice,
    unregisterDevice
};
