const REPORT_TYPES = new Set([
    'weekly',
    'monthly',
    'burnout',
    'habit',
    'sleep',
    'recovery',
    'custom'
]);

const DEVICE_PLATFORMS = new Set([
    'android',
    'ios',
    'web'
]);

function isPlainObject(value) {
    return (
        value !== null &&
        typeof value === 'object' &&
        !Array.isArray(value)
    );
}

function isValidDate(value) {
    if (
        typeof value !== 'string' ||
        !/^\d{4}-\d{2}-\d{2}$/.test(value)
    ) {
        return false;
    }

    const date =
        new Date(`${value}T00:00:00Z`);

    return (
        !Number.isNaN(date.getTime()) &&
        date.toISOString().slice(0, 10) ===
            value
    );
}

function validatePositiveId(value, label) {
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

function validatePagination(query = {}) {
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

function validateDeviceToken(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Device token data must be an object.'
            ],
            data
        };
    }

    const token =
        typeof body.token === 'string'
            ? body.token.trim()
            : '';

    if (
        token.length < 10 ||
        token.length > 500
    ) {
        errors.push(
            'Device token must contain between 10 and 500 characters.'
        );
    } else {
        data.token = token;
    }

    const platform =
        body.platform || 'android';

    if (!DEVICE_PLATFORMS.has(platform)) {
        errors.push(
            'Platform must be android, ios, or web.'
        );
    } else {
        data.platform = platform;
    }

    if (
        body.device_name === undefined ||
        body.device_name === null ||
        body.device_name === ''
    ) {
        data.device_name = null;
    } else if (
        typeof body.device_name !== 'string' ||
        body.device_name.trim().length > 150
    ) {
        errors.push(
            'Device name must contain no more than 150 characters.'
        );
    } else {
        data.device_name =
            body.device_name.trim();
    }

    return {
        errors,
        data
    };
}

function validateReportRequest(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Report data must be an object.'
            ],
            data
        };
    }

    const reportType =
        body.report_type || 'weekly';

    if (!REPORT_TYPES.has(reportType)) {
        errors.push(
            'Invalid report_type.'
        );
    } else {
        data.report_type = reportType;
    }

    if (
        body.period_start === undefined ||
        body.period_start === null ||
        body.period_start === ''
    ) {
        data.period_start = null;
    } else if (
        !isValidDate(body.period_start)
    ) {
        errors.push(
            'period_start must use YYYY-MM-DD format.'
        );
    } else {
        data.period_start =
            body.period_start;
    }

    if (
        body.period_end === undefined ||
        body.period_end === null ||
        body.period_end === ''
    ) {
        data.period_end = null;
    } else if (
        !isValidDate(body.period_end)
    ) {
        errors.push(
            'period_end must use YYYY-MM-DD format.'
        );
    } else {
        data.period_end =
            body.period_end;
    }

    if (
        reportType === 'custom' &&
        (
            !data.period_start ||
            !data.period_end
        )
    ) {
        errors.push(
            'Custom reports require period_start and period_end.'
        );
    }

    if (
        data.period_start &&
        data.period_end &&
        data.period_start >
            data.period_end
    ) {
        errors.push(
            'period_start cannot be later than period_end.'
        );
    }

    return {
        errors,
        data
    };
}

module.exports = {
    validatePositiveId,
    validatePagination,
    validateDeviceToken,
    validateReportRequest
};
