const NOTIFICATION_TYPES =
    new Set([
        'checkin_reminder',
        'habit_reminder',
        'sleep_reminder',
        'recovery_reminder',
        'wellness_scan_reminder',
        'report_ready',
        'achievement',
        'inactivity',
        'announcement',
        'system'
    ]);

const PRIORITIES =
    new Set([
        'low',
        'normal',
        'high'
    ]);

function isPlainObject(value) {
    return (
        value !== null &&
        typeof value === 'object' &&
        !Array.isArray(value)
    );
}

function parseBoolean(
    value,
    fallback
) {
    if (value === undefined) {
        return fallback;
    }

    if (
        value === true ||
        value === 1 ||
        value === '1' ||
        value === 'true'
    ) {
        return true;
    }

    if (
        value === false ||
        value === 0 ||
        value === '0' ||
        value === 'false'
    ) {
        return false;
    }

    return null;
}

function validatePositiveId(
    value,
    label
) {
    const id = Number(value);

    if (
        !Number.isSafeInteger(id) ||
        id <= 0
    ) {
        return {
            errors: [
                `${label} must be a positive integer.`
            ],
            id: null
        };
    }

    return {
        errors: [],
        id
    };
}

function validateTestPayload(
    body = {}
) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'FCM test data must be an object.'
            ],
            data
        };
    }

    const userId =
        Number(body.user_id);

    if (
        !Number.isSafeInteger(userId) ||
        userId <= 0
    ) {
        errors.push(
            'user_id must be a positive integer.'
        );
    } else {
        data.user_id = userId;
    }

    const title =
        typeof body.title === 'string'
            ? body.title.trim()
            : '';

    if (
        title.length < 2 ||
        title.length > 200
    ) {
        errors.push(
            'Title must contain between 2 and 200 characters.'
        );
    } else {
        data.title = title;
    }

    const notificationBody =
        typeof body.body === 'string'
            ? body.body.trim()
            : '';

    if (
        notificationBody.length < 2 ||
        notificationBody.length > 1000
    ) {
        errors.push(
            'Body must contain between 2 and 1000 characters.'
        );
    } else {
        data.body =
            notificationBody;
    }

    const notificationType =
        body.notification_type ||
        'system';

    if (
        !NOTIFICATION_TYPES.has(
            notificationType
        )
    ) {
        errors.push(
            'Invalid notification_type.'
        );
    } else {
        data.notification_type =
            notificationType;
    }

    const priorityLevel =
        body.priority_level ||
        'normal';

    if (
        !PRIORITIES.has(
            priorityLevel
        )
    ) {
        errors.push(
            'Invalid priority_level.'
        );
    } else {
        data.priority_level =
            priorityLevel;
    }

    if (
        body.data_payload ===
            undefined ||
        body.data_payload === null
    ) {
        data.data_payload = {};
    } else if (
        !isPlainObject(
            body.data_payload
        )
    ) {
        errors.push(
            'data_payload must be an object.'
        );
    } else {
        const serialized =
            JSON.stringify(
                body.data_payload
            );

        if (serialized.length > 4000) {
            errors.push(
                'data_payload is too large.'
            );
        } else {
            data.data_payload =
                body.data_payload;
        }
    }

    const respectQuietHours =
        parseBoolean(
            body.respect_quiet_hours,
            true
        );

    if (respectQuietHours === null) {
        errors.push(
            'respect_quiet_hours must be true or false.'
        );
    } else {
        data.respect_quiet_hours =
            respectQuietHours;
    }

    return {
        errors,
        data
    };
}

module.exports = {
    validatePositiveId,
    validateTestPayload
};
