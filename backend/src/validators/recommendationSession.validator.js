const SOURCES = new Set([
    'ai_wellness',
    'wellness_scan',
    'recovery',
    'manual'
]);

const PRIORITIES = new Set([
    'low',
    'medium',
    'high'
]);

const TRACKING_SOURCES = new Set([
    'in_app_timer',
    'self_report'
]);

const TERMINAL_STATUSES = new Set([
    'completed',
    'abandoned',
    'remind_later'
]);

const FEEDBACK_TYPES = new Set([
    'helpful',
    'neutral',
    'not_useful'
]);


function isPlainObject(value) {
    return (
        value !== null &&
        typeof value === 'object' &&
        !Array.isArray(value)
    );
}


function normalizedString(
    value,
    {
        label,
        minimum,
        maximum,
        required = true
    },
    errors
) {
    if (
        value === undefined ||
        value === null
    ) {
        if (required) {
            errors.push(
                `${label} is required.`
            );
        }

        return null;
    }

    if (typeof value !== 'string') {
        errors.push(
            `${label} must be a string.`
        );

        return null;
    }

    const text = value.trim();

    if (
        !text &&
        !required
    ) {
        return null;
    }

    if (
        text.length < minimum ||
        text.length > maximum
    ) {
        errors.push(
            `${label} must contain between ` +
            `${minimum} and ${maximum} characters.`
        );

        return null;
    }

    return text;
}


function optionalScale(
    value,
    label,
    errors
) {
    if (
        value === undefined ||
        value === null ||
        value === ''
    ) {
        return null;
    }

    const number = Number(value);

    if (
        !Number.isInteger(number) ||
        number < 1 ||
        number > 5
    ) {
        errors.push(
            `${label} must be an integer from 1 to 5.`
        );

        return null;
    }

    return number;
}


function validateStart(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Recommendation session data must be an object.'
            ],
            data
        };
    }

    data.client_session_key =
        normalizedString(
            body.client_session_key,
            {
                label:
                    'Client session key',
                minimum: 10,
                maximum: 80
            },
            errors
        );

    if (
        data.client_session_key &&
        !/^[A-Za-z0-9_.:-]+$/.test(
            data.client_session_key
        )
    ) {
        errors.push(
            'Client session key contains invalid characters.'
        );
    }

    const source =
        body.recommendation_source ||
        'ai_wellness';

    if (!SOURCES.has(source)) {
        errors.push(
            'Recommendation source is invalid.'
        );
    } else {
        data.recommendation_source =
            source;
    }

    data.recommendation_category =
        normalizedString(
            body.recommendation_category,
            {
                label:
                    'Recommendation category',
                minimum: 2,
                maximum: 60
            },
            errors
        );

    data.recommendation_title =
        normalizedString(
            body.recommendation_title,
            {
                label:
                    'Recommendation title',
                minimum: 2,
                maximum: 180
            },
            errors
        );

    data.recommendation_action =
        normalizedString(
            body.recommendation_action,
            {
                label:
                    'Recommendation action',
                minimum: 2,
                maximum: 1500
            },
            errors
        );

    const priority =
        body.priority_level ||
        'medium';

    if (!PRIORITIES.has(priority)) {
        errors.push(
            'Priority level is invalid.'
        );
    } else {
        data.priority_level =
            priority;
    }

    const suggestedDuration =
        Number(
            body.suggested_duration_seconds
        );

    if (
        !Number.isInteger(
            suggestedDuration
        ) ||
        suggestedDuration < 30 ||
        suggestedDuration > 7200
    ) {
        errors.push(
            'Suggested duration must be an integer ' +
            'from 30 to 7200 seconds.'
        );
    } else {
        data.suggested_duration_seconds =
            suggestedDuration;
    }

    data.before_mood =
        optionalScale(
            body.before_mood,
            'Before mood',
            errors
        );

    data.before_stress =
        optionalScale(
            body.before_stress,
            'Before stress',
            errors
        );

    const trackingSource =
        body.tracking_source ||
        'in_app_timer';

    if (
        !TRACKING_SOURCES.has(
            trackingSource
        )
    ) {
        errors.push(
            'Tracking source is invalid.'
        );
    } else {
        data.tracking_source =
            trackingSource;
    }

    return {
        errors,
        data
    };
}


function validateFinish(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Recommendation completion data must be an object.'
            ],
            data
        };
    }

    if (
        !TERMINAL_STATUSES.has(
            body.status
        )
    ) {
        errors.push(
            'Status must be completed, abandoned, or remind_later.'
        );
    } else {
        data.status =
            body.status;
    }

    const actualDuration =
        Number(
            body.actual_duration_seconds
        );

    if (
        !Number.isInteger(
            actualDuration
        ) ||
        actualDuration < 0 ||
        actualDuration > 86400
    ) {
        errors.push(
            'Actual duration must be an integer ' +
            'from 0 to 86400 seconds.'
        );
    } else {
        data.actual_duration_seconds =
            actualDuration;
    }

    data.after_mood =
        optionalScale(
            body.after_mood,
            'After mood',
            errors
        );

    data.after_stress =
        optionalScale(
            body.after_stress,
            'After stress',
            errors
        );

    if (
        body.feedback_type === undefined ||
        body.feedback_type === null ||
        body.feedback_type === ''
    ) {
        data.feedback_type = null;
    } else if (
        !FEEDBACK_TYPES.has(
            body.feedback_type
        )
    ) {
        errors.push(
            'Feedback type is invalid.'
        );
    } else {
        data.feedback_type =
            body.feedback_type;
    }

    data.feedback_note =
        normalizedString(
            body.feedback_note,
            {
                label:
                    'Feedback note',
                minimum: 1,
                maximum: 500,
                required: false
            },
            errors
        );

    return {
        errors,
        data
    };
}


function validatePositiveId(
    value
) {
    const id = Number(value);

    if (
        !Number.isSafeInteger(id) ||
        id <= 0
    ) {
        return {
            errors: [
                'Recommendation session ID must be a positive integer.'
            ],
            id: null
        };
    }

    return {
        errors: [],
        id
    };
}


function validateHistoryQuery(
    query = {}
) {
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


function validateSummaryQuery(
    query = {}
) {
    const days =
        query.days === undefined
            ? 7
            : Number(query.days);

    if (
        !Number.isInteger(days) ||
        days < 1 ||
        days > 90
    ) {
        return {
            errors: [
                'Summary days must be an integer from 1 to 90.'
            ],
            data: {
                days: 7
            }
        };
    }

    return {
        errors: [],
        data: {
            days
        }
    };
}


module.exports = {
    validateStart,
    validateFinish,
    validatePositiveId,
    validateHistoryQuery,
    validateSummaryQuery
};
