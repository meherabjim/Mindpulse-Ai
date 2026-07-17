const CONTENT_TYPES = new Set([
    'terms',
    'privacy_policy',
    'wellness_disclaimer',
    'onboarding',
    'help',
    'about',
    'announcement',
    'emergency_guidance',
    'other'
]);

const RESOURCE_TYPES = new Set([
    'emergency_service',
    'crisis_hotline',
    'professional_support',
    'mental_health_service',
    'trusted_contact_guidance',
    'other'
]);

function isPlainObject(value) {
    return (
        value !== null &&
        typeof value === 'object' &&
        !Array.isArray(value)
    );
}

function hasOwn(object, key) {
    return Object.prototype.hasOwnProperty.call(
        object,
        key
    );
}

function parseBoolean(value) {
    if (
        value === true ||
        value === 'true' ||
        value === 1 ||
        value === '1'
    ) {
        return true;
    }

    if (
        value === false ||
        value === 'false' ||
        value === 0 ||
        value === '0'
    ) {
        return false;
    }

    return null;
}

function isValidUrl(value) {
    if (!value) {
        return true;
    }

    try {
        const url = new URL(value);

        return (
            url.protocol === 'http:' ||
            url.protocol === 'https:'
        );
    } catch {
        return false;
    }
}

function normalizeDateTime(value) {
    if (
        value === null ||
        value === ''
    ) {
        return null;
    }

    if (typeof value !== 'string') {
        return undefined;
    }

    const date = new Date(value);

    if (Number.isNaN(date.getTime())) {
        return undefined;
    }

    return date
        .toISOString()
        .slice(0, 19)
        .replace('T', ' ');
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
            'Limit must be between 1 and 100.'
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

function validateContentListQuery(query = {}) {
    const pagination =
        validatePagination(query);

    const errors = [
        ...pagination.errors
    ];

    const contentType =
        query.content_type || null;

    if (
        contentType &&
        !CONTENT_TYPES.has(contentType)
    ) {
        errors.push(
            'Invalid content_type.'
        );
    }

    const languageCode =
        typeof query.language_code ===
            'string'
            ? query.language_code.trim()
            : '';

    if (languageCode.length > 10) {
        errors.push(
            'language_code is too long.'
        );
    }

    let isActive = null;

    if (query.is_active !== undefined) {
        isActive =
            parseBoolean(query.is_active);

        if (isActive === null) {
            errors.push(
                'is_active must be true or false.'
            );
        }
    }

    const search =
        typeof query.search === 'string'
            ? query.search.trim()
            : '';

    if (search.length > 100) {
        errors.push(
            'Search text is too long.'
        );
    }

    return {
        errors,
        data: {
            ...pagination.data,
            contentType,
            languageCode:
                languageCode || null,
            isActive,
            search
        }
    };
}

function validateContentPayload(
    body = {},
    partial = false
) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Content data must be an object.'
            ],
            data
        };
    }

    if (
        !partial ||
        hasOwn(body, 'content_key')
    ) {
        const contentKey =
            typeof body.content_key ===
                'string'
                ? body.content_key.trim()
                : '';

        if (
            contentKey.length < 2 ||
            contentKey.length > 150 ||
            !/^[a-z0-9_-]+$/i.test(
                contentKey
            )
        ) {
            errors.push(
                'content_key must contain 2–150 letters, numbers, underscores, or hyphens.'
            );
        } else {
            data.content_key =
                contentKey;
        }
    }

    if (
        !partial ||
        hasOwn(body, 'content_type')
    ) {
        if (
            !CONTENT_TYPES.has(
                body.content_type
            )
        ) {
            errors.push(
                'Invalid content_type.'
            );
        } else {
            data.content_type =
                body.content_type;
        }
    }

    if (
        !partial ||
        hasOwn(body, 'title')
    ) {
        const title =
            typeof body.title === 'string'
                ? body.title.trim()
                : '';

        if (
            title.length < 2 ||
            title.length > 255
        ) {
            errors.push(
                'Title must contain between 2 and 255 characters.'
            );
        } else {
            data.title = title;
        }
    }

    if (
        !partial ||
        hasOwn(body, 'content')
    ) {
        const content =
            typeof body.content ===
                'string'
                ? body.content.trim()
                : '';

        if (content.length < 10) {
            errors.push(
                'Content must contain at least 10 characters.'
            );
        } else {
            data.content = content;
        }
    }

    if (
        !partial ||
        hasOwn(body, 'version')
    ) {
        const version =
            body.version === undefined
                ? '1.0'
                : String(
                    body.version
                ).trim();

        if (
            version.length < 1 ||
            version.length > 30
        ) {
            errors.push(
                'Version must contain between 1 and 30 characters.'
            );
        } else {
            data.version = version;
        }
    }

    if (
        !partial ||
        hasOwn(body, 'language_code')
    ) {
        const languageCode =
            body.language_code === undefined
                ? 'en'
                : String(
                    body.language_code
                ).trim()
                .toLowerCase();

        if (
            languageCode.length < 2 ||
            languageCode.length > 10
        ) {
            errors.push(
                'language_code must contain between 2 and 10 characters.'
            );
        } else {
            data.language_code =
                languageCode;
        }
    }

    if (
        !partial ||
        hasOwn(body, 'is_active')
    ) {
        const isActive =
            body.is_active === undefined
                ? true
                : parseBoolean(
                    body.is_active
                );

        if (isActive === null) {
            errors.push(
                'is_active must be true or false.'
            );
        } else {
            data.is_active =
                isActive;
        }
    }

    if (
        hasOwn(body, 'published_at')
    ) {
        const publishedAt =
            normalizeDateTime(
                body.published_at
            );

        if (publishedAt === undefined) {
            errors.push(
                'published_at must be a valid ISO date-time or null.'
            );
        } else {
            data.published_at =
                publishedAt;
        }
    } else if (!partial) {
        data.published_at = null;
    }

    if (
        partial &&
        Object.keys(data).length === 0 &&
        errors.length === 0
    ) {
        errors.push(
            'At least one content field is required.'
        );
    }

    return {
        errors,
        data
    };
}

function validateSupportListQuery(query = {}) {
    const pagination =
        validatePagination(query);

    const errors = [
        ...pagination.errors
    ];

    const countryCode =
        typeof query.country_code ===
            'string'
            ? query.country_code
                .trim()
                .toUpperCase()
            : '';

    if (
        countryCode &&
        !/^[A-Z]{2}$/.test(countryCode)
    ) {
        errors.push(
            'country_code must contain two letters.'
        );
    }

    const regionName =
        typeof query.region_name ===
            'string'
            ? query.region_name.trim()
            : '';

    if (regionName.length > 120) {
        errors.push(
            'region_name is too long.'
        );
    }

    const resourceType =
        query.resource_type || null;

    if (
        resourceType &&
        !RESOURCE_TYPES.has(resourceType)
    ) {
        errors.push(
            'Invalid resource_type.'
        );
    }

    let isActive = null;

    if (query.is_active !== undefined) {
        isActive =
            parseBoolean(query.is_active);

        if (isActive === null) {
            errors.push(
                'is_active must be true or false.'
            );
        }
    }

    const search =
        typeof query.search === 'string'
            ? query.search.trim()
            : '';

    if (search.length > 100) {
        errors.push(
            'Search text is too long.'
        );
    }

    return {
        errors,
        data: {
            ...pagination.data,
            countryCode:
                countryCode || null,
            regionName:
                regionName || null,
            resourceType,
            isActive,
            search
        }
    };
}

function validateSupportPayload(
    body = {},
    partial = false
) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Support resource data must be an object.'
            ],
            data
        };
    }

    if (
        !partial ||
        hasOwn(body, 'country_code')
    ) {
        const countryCode =
            typeof body.country_code ===
                'string'
                ? body.country_code
                    .trim()
                    .toUpperCase()
                : '';

        if (
            !/^[A-Z]{2}$/.test(
                countryCode
            )
        ) {
            errors.push(
                'country_code must contain two letters.'
            );
        } else {
            data.country_code =
                countryCode;
        }
    }

    if (hasOwn(body, 'region_name')) {
        if (
            body.region_name === null ||
            body.region_name === ''
        ) {
            data.region_name = null;
        } else {
            const regionName =
                typeof body.region_name ===
                    'string'
                    ? body.region_name.trim()
                    : '';

            if (
                regionName.length < 2 ||
                regionName.length > 120
            ) {
                errors.push(
                    'region_name must contain 2–120 characters.'
                );
            } else {
                data.region_name =
                    regionName;
            }
        }
    } else if (!partial) {
        data.region_name = null;
    }

    if (
        !partial ||
        hasOwn(body, 'resource_type')
    ) {
        if (
            !RESOURCE_TYPES.has(
                body.resource_type
            )
        ) {
            errors.push(
                'Invalid resource_type.'
            );
        } else {
            data.resource_type =
                body.resource_type;
        }
    }

    if (
        !partial ||
        hasOwn(body, 'name')
    ) {
        const name =
            typeof body.name === 'string'
                ? body.name.trim()
                : '';

        if (
            name.length < 2 ||
            name.length > 200
        ) {
            errors.push(
                'Name must contain between 2 and 200 characters.'
            );
        } else {
            data.name = name;
        }
    }

    const nullableTextFields = [
        ['description', 1000],
        ['phone_number', 50],
        ['availability_text', 255]
    ];

    for (const [field, maxLength] of nullableTextFields) {
        if (hasOwn(body, field)) {
            if (
                body[field] === null ||
                body[field] === ''
            ) {
                data[field] = null;
            } else {
                const value =
                    typeof body[field] ===
                        'string'
                        ? body[field].trim()
                        : '';

                if (
                    value.length < 2 ||
                    value.length > maxLength
                ) {
                    errors.push(
                        `${field} must contain 2–${maxLength} characters.`
                    );
                } else {
                    data[field] = value;
                }
            }
        } else if (!partial) {
            data[field] = null;
        }
    }

    if (hasOwn(body, 'website_url')) {
        if (
            body.website_url === null ||
            body.website_url === ''
        ) {
            data.website_url = null;
        } else {
            const websiteUrl =
                typeof body.website_url ===
                    'string'
                    ? body.website_url.trim()
                    : '';

            if (
                websiteUrl.length > 1000 ||
                !isValidUrl(websiteUrl)
            ) {
                errors.push(
                    'website_url must be a valid HTTP or HTTPS URL.'
                );
            } else {
                data.website_url =
                    websiteUrl;
            }
        }
    } else if (!partial) {
        data.website_url = null;
    }

    if (hasOwn(body, 'supported_languages')) {
        if (
            body.supported_languages === null
        ) {
            data.supported_languages =
                null;
        } else if (
            !Array.isArray(
                body.supported_languages
            )
        ) {
            errors.push(
                'supported_languages must be an array or null.'
            );
        } else {
            const languages = [
                ...new Set(
                    body.supported_languages
                        .map((language) =>
                            typeof language ===
                                'string'
                                ? language
                                    .trim()
                                    .toLowerCase()
                                : ''
                        )
                        .filter(Boolean)
                )
            ];

            if (languages.length > 20) {
                errors.push(
                    'A maximum of 20 supported languages is allowed.'
                );
            }

            if (
                languages.some(
                    (language) =>
                        language.length > 30
                )
            ) {
                errors.push(
                    'Each supported language must contain no more than 30 characters.'
                );
            }

            data.supported_languages =
                languages;
        }
    } else if (!partial) {
        data.supported_languages =
            null;
    }

    if (
        !partial ||
        hasOwn(body, 'is_active')
    ) {
        const isActive =
            body.is_active === undefined
                ? true
                : parseBoolean(
                    body.is_active
                );

        if (isActive === null) {
            errors.push(
                'is_active must be true or false.'
            );
        } else {
            data.is_active =
                isActive;
        }
    }

    if (
        !partial ||
        hasOwn(body, 'display_order')
    ) {
        const displayOrder =
            body.display_order === undefined
                ? 0
                : Number(
                    body.display_order
                );

        if (
            !Number.isInteger(
                displayOrder
            ) ||
            displayOrder < 0 ||
            displayOrder > 65535
        ) {
            errors.push(
                'display_order must be an integer from 0 to 65535.'
            );
        } else {
            data.display_order =
                displayOrder;
        }
    }

    if (
        partial &&
        Object.keys(data).length === 0 &&
        errors.length === 0
    ) {
        errors.push(
            'At least one support-resource field is required.'
        );
    }

    return {
        errors,
        data
    };
}

module.exports = {
    validatePositiveId,
    validateContentListQuery,
    validateContentPayload,
    validateSupportListQuery,
    validateSupportPayload
};
