const ACTIVITY_STATUSES = new Set([
    'started',
    'completed',
    'cancelled'
]);

const PLAN_STATUSES = new Set([
    'active',
    'completed',
    'paused',
    'cancelled'
]);

const GENERATED_BY = new Set([
    'rule_based',
    'ai',
    'manual'
]);

const TASK_TYPES = new Set([
    'sleep',
    'hydration',
    'habit',
    'recovery_activity',
    'journal',
    'physical_activity',
    'custom'
]);

const TASK_STATUSES = new Set([
    'pending',
    'completed',
    'skipped',
    'rescheduled'
]);

function hasOwn(object, key) {
    return Object.prototype.hasOwnProperty.call(
        object || {},
        key
    );
}

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

    const date = new Date(`${value}T00:00:00Z`);

    return (
        !Number.isNaN(date.getTime()) &&
        date.toISOString().slice(0, 10) === value
    );
}

function isValidTime(value) {
    return /^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(
        value
    );
}

function optionalString(
    value,
    maximumLength,
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

    if (typeof value !== 'string') {
        errors.push(
            `${label} must be a string or null.`
        );

        return null;
    }

    const normalized = value.trim();

    if (normalized.length > maximumLength) {
        errors.push(
            `${label} must contain no more than ${maximumLength} characters.`
        );

        return null;
    }

    return normalized || null;
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

function validateActivityLog(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Recovery activity log must be an object.'
            ],
            data
        };
    }

    const status = body.status || 'completed';

    if (!ACTIVITY_STATUSES.has(status)) {
        errors.push(
            'Status must be started, completed, or cancelled.'
        );
    } else {
        data.status = status;
    }

    if (
        body.duration_seconds === undefined ||
        body.duration_seconds === null ||
        body.duration_seconds === ''
    ) {
        data.duration_seconds = null;
    } else if (
        !Number.isInteger(body.duration_seconds) ||
        body.duration_seconds < 0 ||
        body.duration_seconds > 86400
    ) {
        errors.push(
            'duration_seconds must be an integer from 0 to 86400.'
        );
    } else {
        data.duration_seconds =
            body.duration_seconds;
    }

    if (
        body.rating === undefined ||
        body.rating === null ||
        body.rating === ''
    ) {
        data.rating = null;
    } else if (
        !Number.isInteger(body.rating) ||
        body.rating < 1 ||
        body.rating > 5
    ) {
        errors.push(
            'Rating must be an integer from 1 to 5.'
        );
    } else {
        data.rating = body.rating;
    }

    data.note = optionalString(
        body.note,
        500,
        'Activity note',
        errors
    );

    return {
        errors,
        data
    };
}

function validatePlanTask(task = {}, index = 0) {
    const errors = [];
    const data = {};

    if (!isPlainObject(task)) {
        return {
            errors: [
                `Task ${index + 1} must be an object.`
            ],
            data
        };
    }

    if (
        task.recovery_activity_id !== undefined &&
        task.recovery_activity_id !== null
    ) {
        const activityId =
            Number(task.recovery_activity_id);

        if (
            !Number.isSafeInteger(activityId) ||
            activityId <= 0
        ) {
            errors.push(
                `Task ${index + 1} has an invalid recovery_activity_id.`
            );
        } else {
            data.recovery_activity_id =
                activityId;
        }
    } else {
        data.recovery_activity_id = null;
    }

    const title =
        typeof task.title === 'string'
            ? task.title.trim()
            : '';

    if (
        title.length < 2 ||
        title.length > 180
    ) {
        errors.push(
            `Task ${index + 1} title must contain between 2 and 180 characters.`
        );
    } else {
        data.title = title;
    }

    data.description = optionalString(
        task.description,
        1000,
        `Task ${index + 1} description`,
        errors
    );

    if (!TASK_TYPES.has(task.task_type)) {
        errors.push(
            `Task ${index + 1} has an invalid task_type.`
        );
    } else {
        data.task_type = task.task_type;
    }

    if (
        task.target_value === undefined ||
        task.target_value === null ||
        task.target_value === ''
    ) {
        data.target_value = null;
    } else {
        const targetValue =
            Number(task.target_value);

        if (
            !Number.isFinite(targetValue) ||
            targetValue <= 0 ||
            targetValue > 999999
        ) {
            errors.push(
                `Task ${index + 1} target_value must be greater than 0.`
            );
        } else {
            data.target_value =
                Number(targetValue.toFixed(2));
        }
    }

    data.target_unit = optionalString(
        task.target_unit,
        50,
        `Task ${index + 1} target unit`,
        errors
    );

    if (
        task.scheduled_date === undefined ||
        task.scheduled_date === null ||
        task.scheduled_date === ''
    ) {
        data.scheduled_date = null;
    } else if (!isValidDate(task.scheduled_date)) {
        errors.push(
            `Task ${index + 1} scheduled_date must use YYYY-MM-DD format.`
        );
    } else {
        data.scheduled_date =
            task.scheduled_date;
    }

    if (
        task.scheduled_time === undefined ||
        task.scheduled_time === null ||
        task.scheduled_time === ''
    ) {
        data.scheduled_time = null;
    } else if (!isValidTime(task.scheduled_time)) {
        errors.push(
            `Task ${index + 1} scheduled_time must use HH:MM format.`
        );
    } else {
        data.scheduled_time =
            task.scheduled_time;
    }

    return {
        errors,
        data
    };
}

function validatePlanCreate(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Recovery plan data must be an object.'
            ],
            data
        };
    }

    const title =
        typeof body.title === 'string'
            ? body.title.trim()
            : '';

    if (
        title.length < 2 ||
        title.length > 180
    ) {
        errors.push(
            'Plan title must contain between 2 and 180 characters.'
        );
    } else {
        data.title = title;
    }

    data.description = optionalString(
        body.description,
        5000,
        'Plan description',
        errors
    );

    data.overall_goal = optionalString(
        body.overall_goal,
        500,
        'Overall goal',
        errors
    );

    const generatedBy =
        body.generated_by || 'manual';

    if (!GENERATED_BY.has(generatedBy)) {
        errors.push(
            'generated_by must be rule_based, ai, or manual.'
        );
    } else {
        data.generated_by = generatedBy;
    }

    if (
        body.start_date === undefined ||
        body.start_date === null ||
        body.start_date === ''
    ) {
        data.start_date = null;
    } else if (!isValidDate(body.start_date)) {
        errors.push(
            'start_date must use YYYY-MM-DD format.'
        );
    } else {
        data.start_date =
            body.start_date;
    }

    [
        'end_date',
        'review_date'
    ].forEach((field) => {
        if (
            body[field] === undefined ||
            body[field] === null ||
            body[field] === ''
        ) {
            data[field] = null;
            return;
        }

        if (!isValidDate(body[field])) {
            errors.push(
                `${field} must use YYYY-MM-DD format.`
            );
        } else {
            data[field] = body[field];
        }
    });

    if (
        data.start_date &&
        data.end_date &&
        data.end_date < data.start_date
    ) {
        errors.push(
            'end_date cannot be earlier than start_date.'
        );
    }

    if (
        body.tasks !== undefined &&
        !Array.isArray(body.tasks)
    ) {
        errors.push(
            'Tasks must be an array.'
        );

        data.tasks = [];
    } else {
        const tasks = body.tasks || [];

        if (tasks.length > 30) {
            errors.push(
                'A recovery plan may contain a maximum of 30 tasks.'
            );
        }

        data.tasks = tasks.map(
            (task, index) => {
                const result =
                    validatePlanTask(
                        task,
                        index
                    );

                errors.push(
                    ...result.errors
                );

                return result.data;
            }
        );
    }

    return {
        errors,
        data
    };
}

function validatePlanStatus(body = {}) {
    const status = body.status;
    const errors = [];

    if (!PLAN_STATUSES.has(status)) {
        errors.push(
            'Plan status must be active, completed, paused, or cancelled.'
        );
    }

    return {
        errors,
        data: {
            status
        }
    };
}

function validateTaskUpdate(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Recovery task data must be an object.'
            ],
            data
        };
    }

    if (hasOwn(body, 'status')) {
        if (!TASK_STATUSES.has(body.status)) {
            errors.push(
                'Task status must be pending, completed, skipped, or rescheduled.'
            );
        } else {
            data.status = body.status;
        }
    }

    if (hasOwn(body, 'title')) {
        const title =
            typeof body.title === 'string'
                ? body.title.trim()
                : '';

        if (
            title.length < 2 ||
            title.length > 180
        ) {
            errors.push(
                'Task title must contain between 2 and 180 characters.'
            );
        } else {
            data.title = title;
        }
    }

    if (hasOwn(body, 'description')) {
        data.description = optionalString(
            body.description,
            1000,
            'Task description',
            errors
        );
    }

    if (hasOwn(body, 'scheduled_date')) {
        if (!isValidDate(body.scheduled_date)) {
            errors.push(
                'scheduled_date must use YYYY-MM-DD format.'
            );
        } else {
            data.scheduled_date =
                body.scheduled_date;
        }
    }

    if (hasOwn(body, 'scheduled_time')) {
        if (
            body.scheduled_time === null ||
            body.scheduled_time === ''
        ) {
            data.scheduled_time = null;
        } else if (
            !isValidTime(body.scheduled_time)
        ) {
            errors.push(
                'scheduled_time must use HH:MM format.'
            );
        } else {
            data.scheduled_time =
                body.scheduled_time;
        }
    }

    if (
        Object.keys(data).length === 0 &&
        errors.length === 0
    ) {
        errors.push(
            'At least one recovery task field is required.'
        );
    }

    return {
        errors,
        data
    };
}

function validateProgress(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Recovery progress data must be an object.'
            ],
            data
        };
    }

    if (
        body.recovery_plan_id !== undefined &&
        body.recovery_plan_id !== null
    ) {
        const planId =
            Number(body.recovery_plan_id);

        if (
            !Number.isSafeInteger(planId) ||
            planId <= 0
        ) {
            errors.push(
                'recovery_plan_id must be a positive integer.'
            );
        } else {
            data.recovery_plan_id =
                planId;
        }
    } else {
        data.recovery_plan_id = null;
    }

    if (
        body.progress_date === undefined ||
        body.progress_date === null ||
        body.progress_date === ''
    ) {
        data.progress_date = null;
    } else if (!isValidDate(body.progress_date)) {
        errors.push(
            'progress_date must use YYYY-MM-DD format.'
        );
    } else {
        data.progress_date =
            body.progress_date;
    }

    const percentageFields = [
        'mood_score',
        'stress_score',
        'energy_level',
        'habit_completion_percent',
        'activity_completion_percent',
        'burnout_score'
    ];

    percentageFields.forEach((field) => {
        if (
            body[field] === undefined ||
            body[field] === null ||
            body[field] === ''
        ) {
            data[field] = null;
            return;
        }

        const value = Number(body[field]);

        if (
            !Number.isFinite(value) ||
            value < 0 ||
            value > 100
        ) {
            errors.push(
                `${field} must be a number from 0 to 100.`
            );
        } else {
            data[field] =
                Number(value.toFixed(2));
        }
    });

    if (
        body.sleep_hours === undefined ||
        body.sleep_hours === null ||
        body.sleep_hours === ''
    ) {
        data.sleep_hours = null;
    } else {
        const sleepHours =
            Number(body.sleep_hours);

        if (
            !Number.isFinite(sleepHours) ||
            sleepHours < 0 ||
            sleepHours > 24
        ) {
            errors.push(
                'sleep_hours must be a number from 0 to 24.'
            );
        } else {
            data.sleep_hours =
                Number(sleepHours.toFixed(2));
        }
    }

    data.note = optionalString(
        body.note,
        1000,
        'Progress note',
        errors
    );

    const metricFields = [
        'mood_score',
        'stress_score',
        'sleep_hours',
        'energy_level',
        'habit_completion_percent',
        'activity_completion_percent',
        'burnout_score'
    ];

    if (
        !metricFields.some(
            (field) =>
                data[field] !== null &&
                data[field] !== undefined
        )
    ) {
        errors.push(
            'At least one recovery progress metric is required.'
        );
    }

    return {
        errors,
        data
    };
}

function validateHistoryQuery(query = {}) {
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
                Number.isInteger(page) && page > 0
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

module.exports = {
    validateActivityLog,
    validatePlanCreate,
    validatePlanStatus,
    validateTaskUpdate,
    validateProgress,
    validateHistoryQuery,
    validatePositiveId
};
