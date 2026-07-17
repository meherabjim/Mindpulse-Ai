const SCORE_FIELDS = [
    'mood_score',
    'stress_level',
    'energy_level',
    'sleep_quality',
    'focus_level',
    'motivation_level',
    'restlessness_level',
    'work_study_pressure'
];

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

function validateIntegerRange(
    value,
    minimum,
    maximum
) {
    return (
        Number.isInteger(value) &&
        value >= minimum &&
        value <= maximum
    );
}

function validateCheckin(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Daily check-in data must be an object.'
            ],
            data
        };
    }

    if (hasOwn(body, 'checkin_date')) {
        if (!isValidDate(body.checkin_date)) {
            errors.push(
                'Check-in date must use YYYY-MM-DD format.'
            );
        } else {
            data.checkin_date = body.checkin_date;
        }
    }

    [
        'mood_score',
        'stress_level',
        'energy_level'
    ].forEach((field) => {
        if (
            !validateIntegerRange(
                body[field],
                1,
                5
            )
        ) {
            errors.push(
                `${field} must be an integer from 1 to 5.`
            );
        } else {
            data[field] = body[field];
        }
    });

    SCORE_FIELDS
        .filter(
            (field) =>
                ![
                    'mood_score',
                    'stress_level',
                    'energy_level'
                ].includes(field)
        )
        .forEach((field) => {
            if (!hasOwn(body, field)) {
                data[field] = null;
                return;
            }

            if (
                body[field] === null ||
                body[field] === ''
            ) {
                data[field] = null;
                return;
            }

            if (
                !validateIntegerRange(
                    body[field],
                    1,
                    5
                )
            ) {
                errors.push(
                    `${field} must be an integer from 1 to 5 or null.`
                );
            } else {
                data[field] = body[field];
            }
        });

    if (
        !hasOwn(body, 'sleep_hours') ||
        body.sleep_hours === null ||
        body.sleep_hours === ''
    ) {
        data.sleep_hours = null;
    } else if (
        typeof body.sleep_hours !== 'number' ||
        !Number.isFinite(body.sleep_hours) ||
        body.sleep_hours < 0 ||
        body.sleep_hours > 24
    ) {
        errors.push(
            'sleep_hours must be a number from 0 to 24.'
        );
    } else {
        data.sleep_hours =
            Number(body.sleep_hours.toFixed(2));
    }

    if (
        !hasOwn(
            body,
            'physical_activity_minutes'
        )
    ) {
        data.physical_activity_minutes = 0;
    } else if (
        !validateIntegerRange(
            body.physical_activity_minutes,
            0,
            1440
        )
    ) {
        errors.push(
            'physical_activity_minutes must be an integer from 0 to 1440.'
        );
    } else {
        data.physical_activity_minutes =
            body.physical_activity_minutes;
    }

    if (
        !hasOwn(body, 'water_intake_glasses')
    ) {
        data.water_intake_glasses = 0;
    } else if (
        !validateIntegerRange(
            body.water_intake_glasses,
            0,
            50
        )
    ) {
        errors.push(
            'water_intake_glasses must be an integer from 0 to 50.'
        );
    } else {
        data.water_intake_glasses =
            body.water_intake_glasses;
    }

    if (
        !hasOwn(body, 'note') ||
        body.note === null ||
        body.note === ''
    ) {
        data.note = null;
    } else if (
        typeof body.note !== 'string' ||
        body.note.trim().length > 2000
    ) {
        errors.push(
            'Note must contain no more than 2000 characters.'
        );
    } else {
        data.note = body.note.trim();
    }

    return {
        errors,
        data
    };
}

function validateScanSubmission(body = {}) {
    const errors = [];
    const answers = [];

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Wellness scan data must be an object.'
            ],
            data: {
                answers
            }
        };
    }

    if (
        !Array.isArray(body.answers) ||
        body.answers.length === 0
    ) {
        errors.push(
            'At least one wellness answer is required.'
        );

        return {
            errors,
            data: {
                answers
            }
        };
    }

    const usedQuestionIds = new Set();

    body.answers.forEach((answer, index) => {
        if (!isPlainObject(answer)) {
            errors.push(
                `Answer ${index + 1} must be an object.`
            );
            return;
        }

        const questionId =
            Number(answer.question_id);

        if (
            !Number.isSafeInteger(questionId) ||
            questionId <= 0
        ) {
            errors.push(
                `Answer ${index + 1} has an invalid question_id.`
            );
            return;
        }

        if (usedQuestionIds.has(questionId)) {
            errors.push(
                `Question ${questionId} was answered more than once.`
            );
            return;
        }

        usedQuestionIds.add(questionId);

        const responseValue =
            Number(answer.response_value);

        if (
            !Number.isInteger(responseValue)
        ) {
            errors.push(
                `Question ${questionId} requires an integer response_value.`
            );
            return;
        }

        let responseText = null;

        if (
            answer.response_text !== undefined &&
            answer.response_text !== null &&
            answer.response_text !== ''
        ) {
            if (
                typeof answer.response_text !==
                    'string' ||
                answer.response_text.trim().length >
                    500
            ) {
                errors.push(
                    `Question ${questionId} response_text must contain no more than 500 characters.`
                );
                return;
            }

            responseText =
                answer.response_text.trim();
        }

        answers.push({
            question_id: questionId,
            response_value: responseValue,
            response_text: responseText
        });
    });

    return {
        errors,
        data: {
            answers
        }
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

    const fromDate =
        query.from_date || null;

    const toDate =
        query.to_date || null;

    if (
        fromDate !== null &&
        !isValidDate(fromDate)
    ) {
        errors.push(
            'from_date must use YYYY-MM-DD format.'
        );
    }

    if (
        toDate !== null &&
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
                Number.isInteger(page) &&
                page > 0
                    ? page
                    : 1,

            limit:
                Number.isInteger(limit) &&
                limit >= 1 &&
                limit <= 100
                    ? limit
                    : 20,

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
    validateCheckin,
    validateScanSubmission,
    validateHistoryQuery,
    validatePositiveId
};
