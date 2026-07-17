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

function normalizeTags(value, errors) {
    if (value === undefined) {
        return undefined;
    }

    if (!Array.isArray(value)) {
        errors.push('Tags must be an array.');
        return [];
    }

    if (value.length > 10) {
        errors.push(
            'A journal may contain a maximum of 10 tags.'
        );
    }

    const tags = [];
    const usedNames = new Set();

    value.forEach((item, index) => {
        if (typeof item !== 'string') {
            errors.push(
                `Tag ${index + 1} must be a string.`
            );
            return;
        }

        const name = item
            .trim()
            .replace(/\s+/g, ' ');

        if (
            name.length < 1 ||
            name.length > 60
        ) {
            errors.push(
                `Tag ${index + 1} must contain between 1 and 60 characters.`
            );
            return;
        }

        const normalizedName =
            name.toLowerCase();

        if (!usedNames.has(normalizedName)) {
            usedNames.add(normalizedName);
            tags.push(name);
        }
    });

    return tags;
}

function validateJournalCreate(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Journal data must be an object.'
            ],
            data
        };
    }

    if (
        body.title === undefined ||
        body.title === null ||
        body.title === ''
    ) {
        data.title = null;
    } else if (
        typeof body.title !== 'string' ||
        body.title.trim().length > 180
    ) {
        errors.push(
            'Journal title must contain no more than 180 characters.'
        );
    } else {
        data.title = body.title.trim();
    }

    if (
        typeof body.content !== 'string' ||
        body.content.trim().length < 1
    ) {
        errors.push(
            'Journal content is required.'
        );
    } else if (
        body.content.trim().length > 50000
    ) {
        errors.push(
            'Journal content must contain no more than 50,000 characters.'
        );
    } else {
        data.content = body.content.trim();
    }

    if (body.entry_date === undefined) {
        data.entry_date = null;
    } else if (!isValidDate(body.entry_date)) {
        errors.push(
            'Entry date must use YYYY-MM-DD format.'
        );
    } else {
        data.entry_date = body.entry_date;
    }

    if (
        body.mood_score === undefined ||
        body.mood_score === null ||
        body.mood_score === ''
    ) {
        data.mood_score = null;
    } else if (
        !Number.isInteger(body.mood_score) ||
        body.mood_score < 1 ||
        body.mood_score > 5
    ) {
        errors.push(
            'Mood score must be an integer from 1 to 5.'
        );
    } else {
        data.mood_score = body.mood_score;
    }

    if (
        body.is_private !== undefined &&
        typeof body.is_private !== 'boolean'
    ) {
        errors.push(
            'is_private must be a boolean.'
        );
    } else {
        data.is_private =
            body.is_private === undefined
                ? true
                : body.is_private;
    }

    if (
        body.is_favorite !== undefined &&
        typeof body.is_favorite !== 'boolean'
    ) {
        errors.push(
            'is_favorite must be a boolean.'
        );
    } else {
        data.is_favorite =
            body.is_favorite === true;
    }

    data.tags =
        normalizeTags(body.tags, errors) || [];

    return {
        errors,
        data
    };
}

function validateJournalUpdate(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Journal data must be an object.'
            ],
            data
        };
    }

    if (hasOwn(body, 'title')) {
        if (
            body.title === null ||
            body.title === ''
        ) {
            data.title = null;
        } else if (
            typeof body.title !== 'string' ||
            body.title.trim().length > 180
        ) {
            errors.push(
                'Journal title must contain no more than 180 characters.'
            );
        } else {
            data.title = body.title.trim();
        }
    }

    if (hasOwn(body, 'content')) {
        if (
            typeof body.content !== 'string' ||
            body.content.trim().length < 1
        ) {
            errors.push(
                'Journal content cannot be empty.'
            );
        } else if (
            body.content.trim().length > 50000
        ) {
            errors.push(
                'Journal content must contain no more than 50,000 characters.'
            );
        } else {
            data.content = body.content.trim();
        }
    }

    if (hasOwn(body, 'entry_date')) {
        if (!isValidDate(body.entry_date)) {
            errors.push(
                'Entry date must use YYYY-MM-DD format.'
            );
        } else {
            data.entry_date = body.entry_date;
        }
    }

    if (hasOwn(body, 'mood_score')) {
        if (
            body.mood_score === null ||
            body.mood_score === ''
        ) {
            data.mood_score = null;
        } else if (
            !Number.isInteger(body.mood_score) ||
            body.mood_score < 1 ||
            body.mood_score > 5
        ) {
            errors.push(
                'Mood score must be an integer from 1 to 5 or null.'
            );
        } else {
            data.mood_score =
                body.mood_score;
        }
    }

    [
        'is_private',
        'is_favorite'
    ].forEach((field) => {
        if (!hasOwn(body, field)) {
            return;
        }

        if (typeof body[field] !== 'boolean') {
            errors.push(
                `${field} must be a boolean.`
            );
        } else {
            data[field] = body[field];
        }
    });

    if (hasOwn(body, 'tags')) {
        data.tags =
            normalizeTags(
                body.tags,
                errors
            );
    }

    if (
        Object.keys(data).length === 0 &&
        errors.length === 0
    ) {
        errors.push(
            'At least one journal field is required.'
        );
    }

    return {
        errors,
        data
    };
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

function validateJournalQuery(query = {}) {
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

    const search =
        typeof query.search === 'string'
            ? query.search.trim()
            : '';

    if (search.length > 100) {
        errors.push(
            'Search text must contain no more than 100 characters.'
        );
    }

    const tag =
        typeof query.tag === 'string'
            ? query.tag.trim()
            : '';

    if (tag.length > 60) {
        errors.push(
            'Tag filter must contain no more than 60 characters.'
        );
    }

    let favorite = null;

    if (query.favorite !== undefined) {
        favorite =
            parseBoolean(query.favorite);

        if (favorite === null) {
            errors.push(
                'Favorite filter must be true or false.'
            );
        }
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
                    : 20,

            search,
            tag,
            favorite,
            fromDate,
            toDate
        }
    };
}

function validateTagCreate(body = {}) {
    const errors = [];
    const name =
        typeof body.name === 'string'
            ? body.name
                .trim()
                .replace(/\s+/g, ' ')
            : '';

    if (
        name.length < 1 ||
        name.length > 60
    ) {
        errors.push(
            'Tag name must contain between 1 and 60 characters.'
        );
    }

    return {
        errors,
        data: {
            name
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
    validateJournalCreate,
    validateJournalUpdate,
    validateJournalQuery,
    validateTagCreate,
    validatePositiveId
};
