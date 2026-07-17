const CONVERSATION_STATUSES =
    new Set([
        'active',
        'archived',
        'closed'
    ]);

function isPlainObject(value) {
    return (
        value !== null &&
        typeof value === 'object' &&
        !Array.isArray(value)
    );
}

function validateConversationCreate(
    body = {}
) {
    const errors = [];

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Conversation data must be an object.'
            ],
            data: {}
        };
    }

    let title = null;

    if (
        body.title !== undefined &&
        body.title !== null &&
        body.title !== ''
    ) {
        if (
            typeof body.title !== 'string' ||
            body.title.trim().length > 180
        ) {
            errors.push(
                'Conversation title must contain no more than 180 characters.'
            );
        } else {
            title = body.title.trim();
        }
    }

    return {
        errors,
        data: {
            title
        }
    };
}

function validateMessage(body = {}) {
    const errors = [];

    const content =
        typeof body.content === 'string'
            ? body.content.trim()
            : '';

    if (
        content.length < 1 ||
        content.length > 4000
    ) {
        errors.push(
            'Message content must contain between 1 and 4000 characters.'
        );
    }

    return {
        errors,
        data: {
            content
        }
    };
}

function validateConversationStatus(
    body = {}
) {
    const errors = [];

    if (
        !CONVERSATION_STATUSES.has(
            body.status
        )
    ) {
        errors.push(
            'Conversation status must be active, archived, or closed.'
        );
    }

    return {
        errors,
        data: {
            status: body.status
        }
    };
}

function validateQuery(query = {}) {
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
    validateConversationCreate,
    validateMessage,
    validateConversationStatus,
    validateQuery,
    validatePositiveId
};
