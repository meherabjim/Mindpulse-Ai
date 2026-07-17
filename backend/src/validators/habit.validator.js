const FREQUENCY_TYPES = new Set([
    'daily',
    'specific_days',
    'weekly'
]);

const WEEKDAYS = new Set([
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
]);

const LOG_STATUSES = new Set([
    'pending',
    'completed',
    'skipped'
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

function normalizeOptionalString(
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

    const normalized =
        value.trim().replace(/\s+/g, ' ');

    if (normalized.length > maximumLength) {
        errors.push(
            `${label} must contain no more than ${maximumLength} characters.`
        );
        return null;
    }

    return normalized || null;
}

function normalizeScheduleDays(
    value,
    errors
) {
    if (
        value === undefined ||
        value === null
    ) {
        return null;
    }

    if (!Array.isArray(value)) {
        errors.push(
            'schedule_days must be an array.'
        );
        return null;
    }

    const result = [];
    const used = new Set();

    value.forEach((day) => {
        const normalized =
            typeof day === 'string'
                ? day.trim().toLowerCase()
                : '';

        if (!WEEKDAYS.has(normalized)) {
            errors.push(
                `Invalid schedule day: ${day}`
            );
            return;
        }

        if (!used.has(normalized)) {
            used.add(normalized);
            result.push(normalized);
        }
    });

    return result;
}

function validateHabitCreate(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Habit data must be an object.'
            ],
            data
        };
    }

    if (
        body.template_id !== undefined &&
        body.template_id !== null
    ) {
        const templateId =
            Number(body.template_id);

        if (
            !Number.isSafeInteger(templateId) ||
            templateId <= 0
        ) {
            errors.push(
                'template_id must be a positive integer.'
            );
        } else {
            data.template_id = templateId;
        }
    } else {
        data.template_id = null;
    }

    if (body.name !== undefined) {
        const name =
            typeof body.name === 'string'
                ? body.name
                    .trim()
                    .replace(/\s+/g, ' ')
                : '';

        if (
            name.length < 2 ||
            name.length > 120
        ) {
            errors.push(
                'Habit name must contain between 2 and 120 characters.'
            );
        } else {
            data.name = name;
        }
    }

    if (
        !data.template_id &&
        !data.name
    ) {
        errors.push(
            'Habit name is required when no template is selected.'
        );
    }

    if (body.category !== undefined) {
        const category =
            typeof body.category === 'string'
                ? body.category.trim()
                : '';

        if (
            category.length < 1 ||
            category.length > 80
        ) {
            errors.push(
                'Habit category must contain between 1 and 80 characters.'
            );
        } else {
            data.category = category;
        }
    }

    if (
        !data.template_id &&
        !data.category
    ) {
        errors.push(
            'Habit category is required when no template is selected.'
        );
    }

    data.description =
        normalizeOptionalString(
            body.description,
            500,
            'Description',
            errors
        );

    const frequencyType =
        body.frequency_type || 'daily';

    if (!FREQUENCY_TYPES.has(frequencyType)) {
        errors.push(
            'frequency_type must be daily, specific_days, or weekly.'
        );
    } else {
        data.frequency_type =
            frequencyType;
    }

    data.schedule_days =
        normalizeScheduleDays(
            body.schedule_days,
            errors
        );

    if (
        frequencyType === 'specific_days' &&
        (!data.schedule_days ||
            data.schedule_days.length === 0)
    ) {
        errors.push(
            'specific_days habits require at least one schedule day.'
        );
    }

    if (
        frequencyType === 'weekly' &&
        (!data.schedule_days ||
            data.schedule_days.length !== 1)
    ) {
        errors.push(
            'Weekly habits require exactly one schedule day.'
        );
    }

    if (frequencyType === 'daily') {
        data.schedule_days = null;
    }

    if (body.target_value !== undefined) {
        const targetValue =
            Number(body.target_value);

        if (
            !Number.isFinite(targetValue) ||
            targetValue <= 0 ||
            targetValue > 999999
        ) {
            errors.push(
                'target_value must be greater than 0.'
            );
        } else {
            data.target_value =
                Number(targetValue.toFixed(2));
        }
    }

    data.unit =
        normalizeOptionalString(
            body.unit,
            40,
            'Unit',
            errors
        );

    if (
        body.reminder_enabled !== undefined &&
        typeof body.reminder_enabled !== 'boolean'
    ) {
        errors.push(
            'reminder_enabled must be a boolean.'
        );
    } else {
        data.reminder_enabled =
            body.reminder_enabled === true;
    }

    if (
        body.reminder_time === undefined ||
        body.reminder_time === null ||
        body.reminder_time === ''
    ) {
        data.reminder_time = null;
    } else if (
        typeof body.reminder_time !== 'string' ||
        !isValidTime(body.reminder_time)
    ) {
        errors.push(
            'reminder_time must use HH:MM or HH:MM:SS format.'
        );
    } else {
        data.reminder_time =
            body.reminder_time;
    }

    if (body.start_date === undefined) {
        data.start_date = null;
    } else if (!isValidDate(body.start_date)) {
        errors.push(
            'start_date must use YYYY-MM-DD format.'
        );
    } else {
        data.start_date =
            body.start_date;
    }

    if (
        body.end_date === undefined ||
        body.end_date === null ||
        body.end_date === ''
    ) {
        data.end_date = null;
    } else if (!isValidDate(body.end_date)) {
        errors.push(
            'end_date must use YYYY-MM-DD format.'
        );
    } else {
        data.end_date =
            body.end_date;
    }

    if (
        data.start_date &&
        data.end_date &&
        data.end_date < data.start_date
    ) {
        errors.push(
            'end_date cannot be earlier than start_date.'
        );
    }

    return {
        errors,
        data
    };
}

function validateHabitUpdate(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Habit data must be an object.'
            ],
            data
        };
    }

    if (hasOwn(body, 'name')) {
        const name =
            typeof body.name === 'string'
                ? body.name
                    .trim()
                    .replace(/\s+/g, ' ')
                : '';

        if (
            name.length < 2 ||
            name.length > 120
        ) {
            errors.push(
                'Habit name must contain between 2 and 120 characters.'
            );
        } else {
            data.name = name;
        }
    }

    if (hasOwn(body, 'description')) {
        data.description =
            normalizeOptionalString(
                body.description,
                500,
                'Description',
                errors
            );
    }

    if (hasOwn(body, 'category')) {
        const category =
            typeof body.category === 'string'
                ? body.category.trim()
                : '';

        if (
            category.length < 1 ||
            category.length > 80
        ) {
            errors.push(
                'Habit category must contain between 1 and 80 characters.'
            );
        } else {
            data.category = category;
        }
    }

    if (hasOwn(body, 'frequency_type')) {
        if (
            !FREQUENCY_TYPES.has(
                body.frequency_type
            )
        ) {
            errors.push(
                'frequency_type must be daily, specific_days, or weekly.'
            );
        } else {
            data.frequency_type =
                body.frequency_type;
        }
    }

    if (hasOwn(body, 'schedule_days')) {
        data.schedule_days =
            normalizeScheduleDays(
                body.schedule_days,
                errors
            );
    }

    if (hasOwn(body, 'target_value')) {
        const targetValue =
            Number(body.target_value);

        if (
            !Number.isFinite(targetValue) ||
            targetValue <= 0 ||
            targetValue > 999999
        ) {
            errors.push(
                'target_value must be greater than 0.'
            );
        } else {
            data.target_value =
                Number(targetValue.toFixed(2));
        }
    }

    if (hasOwn(body, 'unit')) {
        data.unit =
            normalizeOptionalString(
                body.unit,
                40,
                'Unit',
                errors
            );
    }

    if (hasOwn(body, 'reminder_enabled')) {
        if (
            typeof body.reminder_enabled !==
            'boolean'
        ) {
            errors.push(
                'reminder_enabled must be a boolean.'
            );
        } else {
            data.reminder_enabled =
                body.reminder_enabled;
        }
    }

    if (hasOwn(body, 'reminder_time')) {
        if (
            body.reminder_time === null ||
            body.reminder_time === ''
        ) {
            data.reminder_time = null;
        } else if (
            typeof body.reminder_time !==
                'string' ||
            !isValidTime(body.reminder_time)
        ) {
            errors.push(
                'reminder_time must use HH:MM or HH:MM:SS format.'
            );
        } else {
            data.reminder_time =
                body.reminder_time;
        }
    }

    [
        'start_date',
        'end_date'
    ].forEach((field) => {
        if (!hasOwn(body, field)) {
            return;
        }

        if (
            field === 'end_date' &&
            (
                body[field] === null ||
                body[field] === ''
            )
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

    if (hasOwn(body, 'is_active')) {
        if (typeof body.is_active !== 'boolean') {
            errors.push(
                'is_active must be a boolean.'
            );
        } else {
            data.is_active =
                body.is_active;
        }
    }

    if (
        Object.keys(data).length === 0 &&
        errors.length === 0
    ) {
        errors.push(
            'At least one habit field is required.'
        );
    }

    return {
        errors,
        data
    };
}

function validateHabitLog(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Habit log data must be an object.'
            ],
            data
        };
    }

    if (body.log_date === undefined) {
        data.log_date = null;
    } else if (!isValidDate(body.log_date)) {
        errors.push(
            'log_date must use YYYY-MM-DD format.'
        );
    } else {
        data.log_date = body.log_date;
    }

    const status =
        body.status || 'completed';

    if (!LOG_STATUSES.has(status)) {
        errors.push(
            'status must be pending, completed, or skipped.'
        );
    } else {
        data.status = status;
    }

    if (
        body.completed_value === undefined ||
        body.completed_value === null ||
        body.completed_value === ''
    ) {
        data.completed_value = null;
    } else {
        const completedValue =
            Number(body.completed_value);

        if (
            !Number.isFinite(completedValue) ||
            completedValue < 0 ||
            completedValue > 999999
        ) {
            errors.push(
                'completed_value must be 0 or greater.'
            );
        } else {
            data.completed_value =
                Number(
                    completedValue.toFixed(2)
                );
        }
    }

    data.note =
        normalizeOptionalString(
            body.note,
            500,
            'Habit log note',
            errors
        );

    return {
        errors,
        data
    };
}

function validateHabitHistoryQuery(query = {}) {
    const errors = [];

    const page =
        query.page === undefined
            ? 1
            : Number(query.page);

    const limit =
        query.limit === undefined
            ? 31
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
            page:
                Number.isInteger(page) && page > 0
                    ? page
                    : 1,

            limit:
                Number.isInteger(limit) &&
                limit >= 1 &&
                limit <= 100
                    ? limit
                    : 31,

            fromDate,
            toDate
        }
    };
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

module.exports = {
    validateHabitCreate,
    validateHabitUpdate,
    validateHabitLog,
    validateHabitHistoryQuery,
    validatePositiveId
};
