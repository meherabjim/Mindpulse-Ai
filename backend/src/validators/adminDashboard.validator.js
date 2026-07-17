const USER_STATUSES = new Set([
    'active',
    'suspended',
    'inactive'
]);

const SAFETY_REVIEW_STATUSES = new Set([
    'unreviewed',
    'reviewed',
    'false_positive'
]);

const SAFETY_SEVERITIES = new Set([
    'low',
    'moderate',
    'high',
    'critical'
]);

const SAFETY_EVENT_TYPES = new Set([
    'self_harm',
    'crisis',
    'severe_distress',
    'abuse',
    'medical_emergency',
    'other'
]);

const REPORT_TYPES = new Set([
    'weekly',
    'monthly',
    'burnout',
    'habit',
    'sleep',
    'recovery',
    'custom'
]);

const REPORT_STATUSES = new Set([
    'pending',
    'generating',
    'completed',
    'failed'
]);

const PRIORITY_LEVELS = new Set([
    'low',
    'normal',
    'high'
]);

const ACTOR_TYPES = new Set([
    'user',
    'admin',
    'system'
]);

const LOG_LEVELS = new Set([
    'debug',
    'info',
    'warning',
    'error',
    'critical'
]);

const SERVICE_NAMES = new Set([
    'backend',
    'ai_service',
    'database',
    'notification',
    'admin_dashboard',
    'mobile_app',
    'other'
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

    const parsed =
        new Date(`${value}T00:00:00Z`);

    return (
        !Number.isNaN(parsed.getTime()) &&
        parsed.toISOString().slice(0, 10) ===
            value
    );
}

function normalizeDateTime(value) {
    if (
        value === undefined ||
        value === null ||
        value === ''
    ) {
        return null;
    }

    if (typeof value !== 'string') {
        return null;
    }

    const parsed = new Date(value);

    if (Number.isNaN(parsed.getTime())) {
        return null;
    }

    return parsed
        .toISOString()
        .slice(0, 19)
        .replace('T', ' ');
}

function parseBoolean(value) {
    if (
        value === true ||
        value === 'true' ||
        value === '1'
    ) {
        return true;
    }

    if (
        value === false ||
        value === 'false' ||
        value === '0'
    ) {
        return false;
    }

    return null;
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

function validateDateRange(query = {}) {
    const errors = [];

    const fromDate =
        query.from_date || null;

    const toDate =
        query.to_date || null;

    if (
        fromDate &&
        !isValidDate(fromDate)
    ) {
        errors.push(
            'from_date must use YYYY-MM-DD format.'
        );
    }

    if (
        toDate &&
        !isValidDate(toDate)
    ) {
        errors.push(
            'to_date must use YYYY-MM-DD format.'
        );
    }

    if (
        fromDate &&
        toDate &&
        fromDate > toDate
    ) {
        errors.push(
            'from_date cannot be later than to_date.'
        );
    }

    return {
        errors,
        data: {
            fromDate,
            toDate
        }
    };
}

function validateTrendQuery(query = {}) {
    const errors = [];

    const days =
        query.days === undefined
            ? 14
            : Number(query.days);

    if (
        !Number.isInteger(days) ||
        days < 7 ||
        days > 90
    ) {
        errors.push(
            'Trend days must be an integer from 7 to 90.'
        );
    }

    return {
        errors,
        data: {
            days:
                Number.isInteger(days) &&
                days >= 7 &&
                days <= 90
                    ? days
                    : 14
        }
    };
}

function validateUserListQuery(query = {}) {
    const pagination =
        validatePagination(query);

    const dates =
        validateDateRange(query);

    const errors = [
        ...pagination.errors,
        ...dates.errors
    ];

    const search =
        typeof query.search === 'string'
            ? query.search.trim()
            : '';

    if (search.length > 100) {
        errors.push(
            'Search text must contain no more than 100 characters.'
        );
    }

    let status = null;

    if (query.status !== undefined) {
        status = query.status;

        if (!USER_STATUSES.has(status)) {
            errors.push(
                'User status must be active, suspended, or inactive.'
            );
        }
    }

    let onboarding = null;

    if (query.onboarding_completed !== undefined) {
        onboarding =
            parseBoolean(
                query.onboarding_completed
            );

        if (onboarding === null) {
            errors.push(
                'onboarding_completed must be true or false.'
            );
        }
    }

    return {
        errors,
        data: {
            ...pagination.data,
            ...dates.data,
            search,
            status,
            onboarding
        }
    };
}

function validateUserStatus(body = {}) {
    const errors = [];

    if (!isPlainObject(body)) {
        return {
            errors: [
                'User status data must be an object.'
            ],
            data: {}
        };
    }

    if (!USER_STATUSES.has(body.account_status)) {
        errors.push(
            'account_status must be active, suspended, or inactive.'
        );
    }

    const reason =
        typeof body.reason === 'string'
            ? body.reason.trim()
            : '';

    if (reason.length > 500) {
        errors.push(
            'Status reason must contain no more than 500 characters.'
        );
    }

    return {
        errors,
        data: {
            account_status:
                body.account_status,
            reason: reason || null
        }
    };
}

function validateSafetyListQuery(query = {}) {
    const pagination =
        validatePagination(query);

    const dates =
        validateDateRange(query);

    const errors = [
        ...pagination.errors,
        ...dates.errors
    ];

    const reviewStatus =
        query.review_status || null;

    const severity =
        query.severity_level || null;

    const eventType =
        query.event_type || null;

    if (
        reviewStatus &&
        !SAFETY_REVIEW_STATUSES.has(
            reviewStatus
        )
    ) {
        errors.push(
            'Invalid safety review status.'
        );
    }

    if (
        severity &&
        !SAFETY_SEVERITIES.has(severity)
    ) {
        errors.push(
            'Invalid safety severity level.'
        );
    }

    if (
        eventType &&
        !SAFETY_EVENT_TYPES.has(eventType)
    ) {
        errors.push(
            'Invalid safety event type.'
        );
    }

    return {
        errors,
        data: {
            ...pagination.data,
            ...dates.data,
            reviewStatus,
            severity,
            eventType
        }
    };
}

function validateSafetyReview(body = {}) {
    const errors = [];

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Safety review data must be an object.'
            ],
            data: {}
        };
    }

    if (
        !SAFETY_REVIEW_STATUSES.has(
            body.review_status
        )
    ) {
        errors.push(
            'review_status must be unreviewed, reviewed, or false_positive.'
        );
    }

    const note =
        typeof body.note === 'string'
            ? body.note.trim()
            : '';

    if (note.length > 1000) {
        errors.push(
            'Review note must contain no more than 1000 characters.'
        );
    }

    return {
        errors,
        data: {
            review_status:
                body.review_status,
            note: note || null
        }
    };
}

function validateReportListQuery(query = {}) {
    const pagination =
        validatePagination(query);

    const dates =
        validateDateRange(query);

    const errors = [
        ...pagination.errors,
        ...dates.errors
    ];

    const reportType =
        query.report_type || null;

    const status =
        query.status || null;

    if (
        reportType &&
        !REPORT_TYPES.has(reportType)
    ) {
        errors.push(
            'Invalid report type.'
        );
    }

    if (
        status &&
        !REPORT_STATUSES.has(status)
    ) {
        errors.push(
            'Invalid report status.'
        );
    }

    let userId = null;

    if (query.user_id !== undefined) {
        const result =
            validatePositiveId(
                query.user_id,
                'User ID'
            );

        errors.push(...result.errors);
        userId = result.id;
    }

    return {
        errors,
        data: {
            ...pagination.data,
            ...dates.data,
            reportType,
            status,
            userId
        }
    };
}

function validateAnnouncement(body = {}) {
    const errors = [];

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Announcement data must be an object.'
            ],
            data: {}
        };
    }

    const title =
        typeof body.title === 'string'
            ? body.title.trim()
            : '';

    const content =
        typeof body.body === 'string'
            ? body.body.trim()
            : '';

    if (
        title.length < 2 ||
        title.length > 200
    ) {
        errors.push(
            'Announcement title must contain between 2 and 200 characters.'
        );
    }

    if (
        content.length < 2 ||
        content.length > 1000
    ) {
        errors.push(
            'Announcement body must contain between 2 and 1000 characters.'
        );
    }

    const priority =
        body.priority_level || 'normal';

    if (!PRIORITY_LEVELS.has(priority)) {
        errors.push(
            'priority_level must be low, normal, or high.'
        );
    }

    let userIds = [];

    if (body.user_ids !== undefined) {
        if (!Array.isArray(body.user_ids)) {
            errors.push(
                'user_ids must be an array.'
            );
        } else {
            userIds = [
                ...new Set(
                    body.user_ids.map(Number)
                )
            ];

            if (userIds.length > 500) {
                errors.push(
                    'A targeted announcement may contain a maximum of 500 users.'
                );
            }

            userIds.forEach((id) => {
                if (
                    !Number.isSafeInteger(id) ||
                    id <= 0
                ) {
                    errors.push(
                        'Every user ID must be a positive integer.'
                    );
                }
            });
        }
    }

    let scheduledAt = null;

    if (
        body.scheduled_at !== undefined &&
        body.scheduled_at !== null &&
        body.scheduled_at !== ''
    ) {
        scheduledAt =
            normalizeDateTime(
                body.scheduled_at
            );

        if (!scheduledAt) {
            errors.push(
                'scheduled_at must be a valid ISO date-time.'
            );
        }
    }

    return {
        errors,
        data: {
            title,
            body: content,
            priority_level: priority,
            user_ids: userIds,
            scheduled_at: scheduledAt
        }
    };
}

function validateAuditLogQuery(query = {}) {
    const pagination =
        validatePagination(query);

    const dates =
        validateDateRange(query);

    const errors = [
        ...pagination.errors,
        ...dates.errors
    ];

    const actorType =
        query.actor_type || null;

    if (
        actorType &&
        !ACTOR_TYPES.has(actorType)
    ) {
        errors.push(
            'Invalid audit actor_type.'
        );
    }

    const action =
        typeof query.action === 'string'
            ? query.action.trim()
            : '';

    const entityType =
        typeof query.entity_type === 'string'
            ? query.entity_type.trim()
            : '';

    if (action.length > 150) {
        errors.push(
            'Audit action filter is too long.'
        );
    }

    if (entityType.length > 100) {
        errors.push(
            'Entity type filter is too long.'
        );
    }

    return {
        errors,
        data: {
            ...pagination.data,
            ...dates.data,
            actorType,
            action,
            entityType
        }
    };
}

function validateSystemLogQuery(query = {}) {
    const pagination =
        validatePagination(query);

    const dates =
        validateDateRange(query);

    const errors = [
        ...pagination.errors,
        ...dates.errors
    ];

    const logLevel =
        query.log_level || null;

    const serviceName =
        query.service_name || null;

    if (
        logLevel &&
        !LOG_LEVELS.has(logLevel)
    ) {
        errors.push(
            'Invalid system log level.'
        );
    }

    if (
        serviceName &&
        !SERVICE_NAMES.has(serviceName)
    ) {
        errors.push(
            'Invalid service name.'
        );
    }

    const eventCode =
        typeof query.event_code === 'string'
            ? query.event_code.trim()
            : '';

    const search =
        typeof query.search === 'string'
            ? query.search.trim()
            : '';

    if (eventCode.length > 100) {
        errors.push(
            'Event code filter is too long.'
        );
    }

    if (search.length > 150) {
        errors.push(
            'System log search text is too long.'
        );
    }

    return {
        errors,
        data: {
            ...pagination.data,
            ...dates.data,
            logLevel,
            serviceName,
            eventCode,
            search
        }
    };
}

module.exports = {
    validatePositiveId,
    validateTrendQuery,
    validateUserListQuery,
    validateUserStatus,
    validateSafetyListQuery,
    validateSafetyReview,
    validateReportListQuery,
    validateAnnouncement,
    validateAuditLogQuery,
    validateSystemLogQuery
};
