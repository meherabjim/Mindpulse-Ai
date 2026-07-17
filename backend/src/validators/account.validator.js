const GENDERS = new Set([
    'male',
    'female',
    'other',
    'prefer_not_to_say'
]);

const USER_TYPES = new Set([
    'student',
    'employee',
    'self_employed',
    'other'
]);

const THEME_MODES = new Set([
    'system',
    'light',
    'dark'
]);

const TIME_FORMATS = new Set([
    '12_hour',
    '24_hour'
]);

const CONSENT_TYPES = [
    'terms',
    'privacy',
    'wellness_data',
    'ai_analysis',
    'journal_analysis',
    'analytics',
    'notifications'
];

const APP_SETTING_FIELDS = [
    'theme_mode',
    'language_code',
    'time_format',
    'ai_analysis_enabled',
    'journal_analysis_enabled',
    'analytics_enabled'
];

const NOTIFICATION_FIELDS = [
    'notifications_enabled',
    'checkin_reminders',
    'habit_reminders',
    'sleep_reminders',
    'recovery_reminders',
    'wellness_scan_reminders',
    'report_notifications',
    'achievement_notifications',
    'inactivity_reminders',
    'announcement_notifications',
    'quiet_hours_enabled',
    'quiet_hours_start',
    'quiet_hours_end',
    'timezone'
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

function normalizeString(value) {
    return typeof value === 'string'
        ? value.trim().replace(/\s+/g, ' ')
        : '';
}

function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function isValidUrl(value) {
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

function isValidLanguageCode(value) {
    return /^[a-z]{2,3}(?:-[A-Z]{2})?$/.test(value);
}

function isValidTime(value) {
    return /^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(
        value
    );
}

function readNullableString({
    object,
    field,
    label,
    maximumLength,
    minimumLength = 0,
    errors,
    data
}) {
    if (!hasOwn(object, field)) {
        return;
    }

    if (object[field] === null) {
        data[field] = null;
        return;
    }

    if (typeof object[field] !== 'string') {
        errors.push(`${label} must be a string or null.`);
        return;
    }

    const value = normalizeString(object[field]);

    if (!value) {
        data[field] = null;
        return;
    }

    if (
        value.length < minimumLength ||
        value.length > maximumLength
    ) {
        errors.push(
            `${label} must contain between ${minimumLength} and ${maximumLength} characters.`
        );

        return;
    }

    data[field] = value;
}

function validateProfileData(body = {}, requireField = true) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: ['Profile data must be an object.'],
            data
        };
    }

    if (hasOwn(body, 'full_name')) {
        const fullName = normalizeString(body.full_name);

        if (
            fullName.length < 2 ||
            fullName.length > 120
        ) {
            errors.push(
                'Full name must contain between 2 and 120 characters.'
            );
        } else {
            data.full_name = fullName;
        }
    }

    if (hasOwn(body, 'profile_photo_url')) {
        if (
            body.profile_photo_url === null ||
            body.profile_photo_url === ''
        ) {
            data.profile_photo_url = null;
        } else if (
            typeof body.profile_photo_url !== 'string' ||
            body.profile_photo_url.length > 500 ||
            !isValidUrl(body.profile_photo_url.trim())
        ) {
            errors.push(
                'Profile photo URL must be a valid HTTP or HTTPS URL.'
            );
        } else {
            data.profile_photo_url =
                body.profile_photo_url.trim();
        }
    }

    readNullableString({
        object: body,
        field: 'age_range',
        label: 'Age range',
        maximumLength: 30,
        errors,
        data
    });

    if (hasOwn(body, 'gender')) {
        if (body.gender === null || body.gender === '') {
            data.gender = null;
        } else if (!GENDERS.has(body.gender)) {
            errors.push(
                'Gender must be male, female, other, or prefer_not_to_say.'
            );
        } else {
            data.gender = body.gender;
        }
    }

    readNullableString({
        object: body,
        field: 'occupation',
        label: 'Occupation',
        maximumLength: 120,
        errors,
        data
    });

    if (hasOwn(body, 'user_type')) {
        if (
            body.user_type === null ||
            body.user_type === ''
        ) {
            data.user_type = null;
        } else if (!USER_TYPES.has(body.user_type)) {
            errors.push(
                'User type must be student, employee, self_employed, or other.'
            );
        } else {
            data.user_type = body.user_type;
        }
    }

    readNullableString({
        object: body,
        field: 'wellness_goal',
        label: 'Wellness goal',
        maximumLength: 150,
        errors,
        data
    });

    if (hasOwn(body, 'preferred_language')) {
        const language =
            typeof body.preferred_language === 'string'
                ? body.preferred_language.trim()
                : '';

        if (
            language.length > 10 ||
            !isValidLanguageCode(language)
        ) {
            errors.push(
                'Preferred language must be a valid language code such as en or bn.'
            );
        } else {
            data.preferred_language = language;
        }
    }

    if (hasOwn(body, 'timezone')) {
        const timezone =
            typeof body.timezone === 'string'
                ? body.timezone.trim()
                : '';

        if (
            timezone.length < 1 ||
            timezone.length > 60
        ) {
            errors.push(
                'Timezone must contain between 1 and 60 characters.'
            );
        } else {
            data.timezone = timezone;
        }
    }

    if (
        requireField &&
        Object.keys(data).length === 0 &&
        errors.length === 0
    ) {
        errors.push(
            'At least one valid profile field is required.'
        );
    }

    return {
        errors,
        data
    };
}

function validateAppSettings(
    body = {},
    requireField = false
) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: ['App settings must be an object.'],
            data
        };
    }

    if (hasOwn(body, 'theme_mode')) {
        if (!THEME_MODES.has(body.theme_mode)) {
            errors.push(
                'Theme mode must be system, light, or dark.'
            );
        } else {
            data.theme_mode = body.theme_mode;
        }
    }

    if (hasOwn(body, 'language_code')) {
        const language =
            typeof body.language_code === 'string'
                ? body.language_code.trim()
                : '';

        if (
            language.length > 10 ||
            !isValidLanguageCode(language)
        ) {
            errors.push(
                'Language code must be valid, such as en or bn.'
            );
        } else {
            data.language_code = language;
        }
    }

    if (hasOwn(body, 'time_format')) {
        if (!TIME_FORMATS.has(body.time_format)) {
            errors.push(
                'Time format must be 12_hour or 24_hour.'
            );
        } else {
            data.time_format = body.time_format;
        }
    }

    [
        'ai_analysis_enabled',
        'journal_analysis_enabled',
        'analytics_enabled'
    ].forEach((field) => {
        if (!hasOwn(body, field)) {
            return;
        }

        if (typeof body[field] !== 'boolean') {
            errors.push(`${field} must be a boolean.`);
        } else {
            data[field] = body[field];
        }
    });

    if (
        requireField &&
        Object.keys(data).length === 0 &&
        errors.length === 0
    ) {
        errors.push(
            'At least one valid app setting is required.'
        );
    }

    return {
        errors,
        data
    };
}

function validateNotificationPreferences(
    body = {},
    requireField = false
) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Notification preferences must be an object.'
            ],
            data
        };
    }

    const booleanFields = [
        'notifications_enabled',
        'checkin_reminders',
        'habit_reminders',
        'sleep_reminders',
        'recovery_reminders',
        'wellness_scan_reminders',
        'report_notifications',
        'achievement_notifications',
        'inactivity_reminders',
        'announcement_notifications',
        'quiet_hours_enabled'
    ];

    booleanFields.forEach((field) => {
        if (!hasOwn(body, field)) {
            return;
        }

        if (typeof body[field] !== 'boolean') {
            errors.push(`${field} must be a boolean.`);
        } else {
            data[field] = body[field];
        }
    });

    [
        'quiet_hours_start',
        'quiet_hours_end'
    ].forEach((field) => {
        if (!hasOwn(body, field)) {
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
            typeof body[field] !== 'string' ||
            !isValidTime(body[field])
        ) {
            errors.push(
                `${field} must use HH:MM or HH:MM:SS format.`
            );
        } else {
            data[field] = body[field];
        }
    });

    if (hasOwn(body, 'timezone')) {
        const timezone =
            typeof body.timezone === 'string'
                ? body.timezone.trim()
                : '';

        if (
            timezone.length < 1 ||
            timezone.length > 60
        ) {
            errors.push(
                'Notification timezone must contain between 1 and 60 characters.'
            );
        } else {
            data.timezone = timezone;
        }
    }

    if (
        requireField &&
        Object.keys(data).length === 0 &&
        errors.length === 0
    ) {
        errors.push(
            'At least one valid notification preference is required.'
        );
    }

    return {
        errors,
        data
    };
}

function validateProfilePatch(body = {}) {
    return validateProfileData(body, true);
}

function validateSettingsPatch(body = {}) {
    const errors = [];

    if (!isPlainObject(body)) {
        return {
            errors: ['Settings request body must be an object.'],
            data: {}
        };
    }

    const appResult = hasOwn(body, 'app_settings')
        ? validateAppSettings(body.app_settings, false)
        : { errors: [], data: {} };

    const notificationResult =
        hasOwn(body, 'notification_preferences')
            ? validateNotificationPreferences(
                body.notification_preferences,
                false
            )
            : { errors: [], data: {} };

    errors.push(
        ...appResult.errors,
        ...notificationResult.errors
    );

    const totalFields =
        Object.keys(appResult.data).length +
        Object.keys(notificationResult.data).length;

    if (totalFields === 0 && errors.length === 0) {
        errors.push(
            'Provide app_settings or notification_preferences to update.'
        );
    }

    return {
        errors,
        data: {
            appSettings: appResult.data,
            notificationPreferences:
                notificationResult.data
        }
    };
}

function validateOnboarding(body = {}) {
    const errors = [];

    if (!isPlainObject(body)) {
        return {
            errors: ['Onboarding request body must be an object.'],
            data: {}
        };
    }

    const profileResult = hasOwn(body, 'profile')
        ? validateProfileData(body.profile, false)
        : { errors: [], data: {} };

    const appResult = hasOwn(body, 'app_settings')
        ? validateAppSettings(body.app_settings, false)
        : { errors: [], data: {} };

    const notificationResult =
        hasOwn(body, 'notification_preferences')
            ? validateNotificationPreferences(
                body.notification_preferences,
                false
            )
            : { errors: [], data: {} };

    errors.push(
        ...profileResult.errors,
        ...appResult.errors,
        ...notificationResult.errors
    );

    if (!isPlainObject(body.consents)) {
        errors.push(
            'Consents must be provided as an object.'
        );
    }

    const consents = {};

    CONSENT_TYPES.forEach((type) => {
        const value = body.consents?.[type];

        if (
            value !== undefined &&
            typeof value !== 'boolean'
        ) {
            errors.push(
                `Consent ${type} must be a boolean.`
            );
        }

        consents[type] = value === true;
    });

    [
        'terms',
        'privacy',
        'wellness_data'
    ].forEach((requiredConsent) => {
        if (consents[requiredConsent] !== true) {
            errors.push(
                `${requiredConsent} consent is required to complete onboarding.`
            );
        }
    });

    const policyVersion =
        typeof body.policy_version === 'string' &&
        body.policy_version.trim().length > 0 &&
        body.policy_version.trim().length <= 30
            ? body.policy_version.trim()
            : '1.0';

    return {
        errors,
        data: {
            profile: profileResult.data,
            appSettings: appResult.data,
            notificationPreferences:
                notificationResult.data,
            consents,
            policyVersion
        }
    };
}

function validateEmergencyContact(
    body = {},
    isUpdate = false
) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Emergency contact data must be an object.'
            ],
            data
        };
    }

    if (!isUpdate || hasOwn(body, 'full_name')) {
        const fullName = normalizeString(body.full_name);

        if (
            fullName.length < 2 ||
            fullName.length > 120
        ) {
            errors.push(
                'Contact full name must contain between 2 and 120 characters.'
            );
        } else {
            data.full_name = fullName;
        }
    }

    readNullableString({
        object: body,
        field: 'relationship_name',
        label: 'Relationship',
        maximumLength: 80,
        errors,
        data
    });

    if (!isUpdate || hasOwn(body, 'phone_number')) {
        const phoneNumber =
            typeof body.phone_number === 'string'
                ? body.phone_number.trim()
                : '';

        if (
            !/^[0-9+()\-\s]{6,30}$/.test(phoneNumber)
        ) {
            errors.push(
                'A valid phone number is required.'
            );
        } else {
            data.phone_number = phoneNumber;
        }
    }

    if (hasOwn(body, 'email')) {
        if (body.email === null || body.email === '') {
            data.email = null;
        } else {
            const email =
                typeof body.email === 'string'
                    ? body.email.trim().toLowerCase()
                    : '';

            if (
                email.length > 191 ||
                !isValidEmail(email)
            ) {
                errors.push(
                    'Emergency contact email must be valid.'
                );
            } else {
                data.email = email;
            }
        }
    }

    if (hasOwn(body, 'is_primary')) {
        if (typeof body.is_primary !== 'boolean') {
            errors.push(
                'is_primary must be a boolean.'
            );
        } else {
            data.is_primary = body.is_primary;
        }
    }

    if (
        isUpdate &&
        Object.keys(data).length === 0 &&
        errors.length === 0
    ) {
        errors.push(
            'At least one emergency contact field is required.'
        );
    }

    return {
        errors,
        data
    };
}

function validateContactId(value) {
    const contactId = Number(value);

    if (
        !Number.isSafeInteger(contactId) ||
        contactId <= 0
    ) {
        return {
            errors: [
                'Emergency contact ID must be a positive integer.'
            ],
            contactId: null
        };
    }

    return {
        errors: [],
        contactId
    };
}

module.exports = {
    APP_SETTING_FIELDS,
    NOTIFICATION_FIELDS,
    CONSENT_TYPES,
    validateProfilePatch,
    validateSettingsPatch,
    validateOnboarding,
    validateEmergencyContact,
    validateContactId
};
