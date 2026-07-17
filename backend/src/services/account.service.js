const database = require('../config/database');
const AppError = require('../utils/AppError');

const pool = database.pool || database;

const APP_SETTING_COLUMNS = {
    theme_mode: 'theme_mode',
    language_code: 'language_code',
    time_format: 'time_format',
    ai_analysis_enabled: 'ai_analysis_enabled',
    journal_analysis_enabled: 'journal_analysis_enabled',
    analytics_enabled: 'analytics_enabled'
};

const NOTIFICATION_COLUMNS = {
    notifications_enabled: 'notifications_enabled',
    checkin_reminders: 'checkin_reminders',
    habit_reminders: 'habit_reminders',
    sleep_reminders: 'sleep_reminders',
    recovery_reminders: 'recovery_reminders',
    wellness_scan_reminders:
        'wellness_scan_reminders',
    report_notifications: 'report_notifications',
    achievement_notifications:
        'achievement_notifications',
    inactivity_reminders: 'inactivity_reminders',
    announcement_notifications:
        'announcement_notifications',
    quiet_hours_enabled: 'quiet_hours_enabled',
    quiet_hours_start: 'quiet_hours_start',
    quiet_hours_end: 'quiet_hours_end',
    timezone: 'timezone'
};

const PROFILE_COLUMNS = {
    full_name: 'full_name',
    profile_photo_url: 'profile_photo_url',
    age_range: 'age_range',
    gender: 'gender',
    occupation: 'occupation',
    user_type: 'user_type',
    wellness_goal: 'wellness_goal',
    preferred_language: 'preferred_language',
    timezone: 'timezone'
};

function booleanValue(value) {
    return Boolean(Number(value));
}

function mapProfile(row) {
    return {
        id: Number(row.id),
        email: row.email,
        full_name: row.full_name,
        profile_photo_url: row.profile_photo_url,
        age_range: row.age_range,
        gender: row.gender,
        occupation: row.occupation,
        user_type: row.user_type,
        wellness_goal: row.wellness_goal,
        preferred_language: row.preferred_language,
        timezone: row.timezone,
        account_status: row.account_status,
        onboarding_completed:
            booleanValue(row.onboarding_completed),
        email_verified:
            Boolean(row.email_verified_at),
        created_at: row.created_at,
        updated_at: row.updated_at
    };
}

function mapSettings(row) {
    return {
        app_settings: {
            theme_mode: row.theme_mode,
            language_code: row.language_code,
            time_format: row.time_format,
            ai_analysis_enabled:
                booleanValue(row.ai_analysis_enabled),
            journal_analysis_enabled:
                booleanValue(
                    row.journal_analysis_enabled
                ),
            analytics_enabled:
                booleanValue(row.analytics_enabled)
        },

        notification_preferences: {
            notifications_enabled:
                booleanValue(
                    row.notifications_enabled
                ),
            checkin_reminders:
                booleanValue(row.checkin_reminders),
            habit_reminders:
                booleanValue(row.habit_reminders),
            sleep_reminders:
                booleanValue(row.sleep_reminders),
            recovery_reminders:
                booleanValue(row.recovery_reminders),
            wellness_scan_reminders:
                booleanValue(
                    row.wellness_scan_reminders
                ),
            report_notifications:
                booleanValue(
                    row.report_notifications
                ),
            achievement_notifications:
                booleanValue(
                    row.achievement_notifications
                ),
            inactivity_reminders:
                booleanValue(
                    row.inactivity_reminders
                ),
            announcement_notifications:
                booleanValue(
                    row.announcement_notifications
                ),
            quiet_hours_enabled:
                booleanValue(
                    row.quiet_hours_enabled
                ),
            quiet_hours_start:
                row.quiet_hours_start,
            quiet_hours_end:
                row.quiet_hours_end,
            timezone:
                row.notification_timezone
        }
    };
}

function mapEmergencyContact(row) {
    return {
        id: Number(row.id),
        full_name: row.full_name,
        relationship_name:
            row.relationship_name,
        phone_number: row.phone_number,
        email: row.email,
        is_primary:
            booleanValue(row.is_primary),
        created_at: row.created_at,
        updated_at: row.updated_at
    };
}

async function ensureActiveUser(
    executor,
    userId
) {
    const [rows] = await executor.execute(
        `
        SELECT
            id,
            account_status,
            deleted_at
        FROM users
        WHERE id = ?
        LIMIT 1
        `,
        [userId]
    );

    const user = rows[0];

    if (!user || user.deleted_at) {
        throw new AppError(
            404,
            'User account was not found.'
        );
    }

    if (user.account_status !== 'active') {
        throw new AppError(
            403,
            'This account is not currently active.'
        );
    }

    return user;
}

async function updateColumns({
    executor,
    table,
    userId,
    data,
    columnMap
}) {
    const entries = Object.entries(data)
        .filter(([key]) => columnMap[key]);

    if (entries.length === 0) {
        return;
    }

    const assignments = entries
        .map(
            ([key]) =>
                `${columnMap[key]} = ?`
        )
        .join(', ');

    const values = entries.map(([, value]) => {
        return typeof value === 'boolean'
            ? Number(value)
            : value;
    });

    await executor.execute(
        `
        UPDATE ${table}
        SET ${assignments}
        WHERE user_id = ?
        `,
        [
            ...values,
            userId
        ]
    );
}

async function updateProfileRow(
    executor,
    userId,
    data
) {
    await updateColumns({
        executor,
        table: 'user_profiles',
        userId,
        data,
        columnMap: PROFILE_COLUMNS
    });
}

async function ensureSettingsRows(
    executor,
    userId
) {
    await executor.execute(
        `
        INSERT IGNORE INTO user_settings (
            user_id
        )
        VALUES (?)
        `,
        [userId]
    );

    await executor.execute(
        `
        INSERT IGNORE INTO notification_preferences (
            user_id
        )
        VALUES (?)
        `,
        [userId]
    );
}

async function upsertConsent(
    executor,
    userId,
    consentType,
    isGranted,
    policyVersion = '1.0'
) {
    await executor.execute(
        `
        INSERT INTO user_consents (
            user_id,
            consent_type,
            is_granted,
            policy_version,
            granted_at,
            revoked_at
        )
        VALUES (
            ?,
            ?,
            ?,
            ?,
            CASE
                WHEN ? = 1
                THEN CURRENT_TIMESTAMP
                ELSE NULL
            END,
            CASE
                WHEN ? = 0
                THEN CURRENT_TIMESTAMP
                ELSE NULL
            END
        )
        ON DUPLICATE KEY UPDATE
            is_granted =
                VALUES(is_granted),

            policy_version =
                VALUES(policy_version),

            granted_at =
                CASE
                    WHEN VALUES(is_granted) = 1
                    THEN COALESCE(
                        granted_at,
                        CURRENT_TIMESTAMP
                    )
                    ELSE granted_at
                END,

            revoked_at =
                CASE
                    WHEN VALUES(is_granted) = 0
                    THEN CURRENT_TIMESTAMP
                    ELSE NULL
                END
        `,
        [
            userId,
            consentType,
            Number(isGranted),
            policyVersion,
            Number(isGranted),
            Number(isGranted)
        ]
    );
}

async function getProfile(userId) {
    await ensureActiveUser(pool, userId);

    const [rows] = await pool.execute(
        `
        SELECT
            u.id,
            u.email,
            u.account_status,
            u.onboarding_completed,
            u.email_verified_at,
            u.created_at,

            p.full_name,
            p.profile_photo_url,
            p.age_range,
            p.gender,
            p.occupation,
            p.user_type,
            p.wellness_goal,
            p.preferred_language,
            p.timezone,
            p.updated_at
        FROM users AS u
        INNER JOIN user_profiles AS p
            ON p.user_id = u.id
        WHERE
            u.id = ?
            AND u.deleted_at IS NULL
        LIMIT 1
        `,
        [userId]
    );

    if (!rows[0]) {
        throw new AppError(
            404,
            'User profile was not found.'
        );
    }

    return mapProfile(rows[0]);
}

async function updateProfile(
    userId,
    profileData
) {
    await ensureActiveUser(pool, userId);

    await updateProfileRow(
        pool,
        userId,
        profileData
    );

    return getProfile(userId);
}

async function getOnboardingStatus(
    userId
) {
    await ensureActiveUser(pool, userId);

    const [userRows] = await pool.execute(
        `
        SELECT
            u.onboarding_completed,
            p.full_name,
            p.age_range,
            p.gender,
            p.occupation,
            p.user_type,
            p.wellness_goal
        FROM users AS u
        LEFT JOIN user_profiles AS p
            ON p.user_id = u.id
        WHERE u.id = ?
        LIMIT 1
        `,
        [userId]
    );

    const [consentRows] = await pool.execute(
        `
        SELECT
            consent_type,
            is_granted,
            policy_version,
            granted_at,
            revoked_at
        FROM user_consents
        WHERE user_id = ?
        ORDER BY consent_type
        `,
        [userId]
    );

    const consentMap = {};

    consentRows.forEach((consent) => {
        consentMap[consent.consent_type] = {
            is_granted:
                booleanValue(consent.is_granted),
            policy_version:
                consent.policy_version,
            granted_at:
                consent.granted_at,
            revoked_at:
                consent.revoked_at
        };
    });

    const requiredConsentTypes = [
        'terms',
        'privacy',
        'wellness_data'
    ];

    const missingRequiredConsents =
        requiredConsentTypes.filter(
            (type) =>
                consentMap[type]?.is_granted !== true
        );

    const profile = userRows[0];

    return {
        onboarding_completed:
            booleanValue(
                profile.onboarding_completed
            ),

        required_consents_completed:
            missingRequiredConsents.length === 0,

        missing_required_consents:
            missingRequiredConsents,

        profile_summary: {
            full_name: profile.full_name,
            age_range: profile.age_range,
            gender: profile.gender,
            occupation: profile.occupation,
            user_type: profile.user_type,
            wellness_goal:
                profile.wellness_goal
        },

        consents: consentMap
    };
}

async function completeOnboarding(
    userId,
    onboardingData
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        await updateProfileRow(
            connection,
            userId,
            onboardingData.profile
        );

        await ensureSettingsRows(
            connection,
            userId
        );

        await updateColumns({
            executor: connection,
            table: 'user_settings',
            userId,
            data:
                onboardingData.appSettings,
            columnMap:
                APP_SETTING_COLUMNS
        });

        await updateColumns({
            executor: connection,
            table:
                'notification_preferences',
            userId,
            data:
                onboardingData
                    .notificationPreferences,
            columnMap:
                NOTIFICATION_COLUMNS
        });

        for (
            const [
                consentType,
                isGranted
            ] of Object.entries(
                onboardingData.consents
            )
        ) {
            await upsertConsent(
                connection,
                userId,
                consentType,
                isGranted,
                onboardingData.policyVersion
            );
        }

        await connection.execute(
            `
            UPDATE users
            SET onboarding_completed = TRUE
            WHERE id = ?
            `,
            [userId]
        );

        await connection.commit();

        const [
            profile,
            settings,
            onboarding
        ] = await Promise.all([
            getProfile(userId),
            getSettings(userId),
            getOnboardingStatus(userId)
        ]);

        return {
            profile,
            settings,
            onboarding
        };
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function getSettings(userId) {
    await ensureActiveUser(pool, userId);

    await ensureSettingsRows(
        pool,
        userId
    );

    const [rows] = await pool.execute(
        `
        SELECT
            us.theme_mode,
            us.language_code,
            us.time_format,
            us.ai_analysis_enabled,
            us.journal_analysis_enabled,
            us.analytics_enabled,

            np.notifications_enabled,
            np.checkin_reminders,
            np.habit_reminders,
            np.sleep_reminders,
            np.recovery_reminders,
            np.wellness_scan_reminders,
            np.report_notifications,
            np.achievement_notifications,
            np.inactivity_reminders,
            np.announcement_notifications,
            np.quiet_hours_enabled,
            np.quiet_hours_start,
            np.quiet_hours_end,
            np.timezone AS notification_timezone

        FROM user_settings AS us

        INNER JOIN notification_preferences AS np
            ON np.user_id = us.user_id

        WHERE us.user_id = ?
        LIMIT 1
        `,
        [userId]
    );

    return mapSettings(rows[0]);
}

async function updateSettings(
    userId,
    settingsData
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        await ensureSettingsRows(
            connection,
            userId
        );

        await updateColumns({
            executor: connection,
            table: 'user_settings',
            userId,
            data:
                settingsData.appSettings,
            columnMap:
                APP_SETTING_COLUMNS
        });

        await updateColumns({
            executor: connection,
            table:
                'notification_preferences',
            userId,
            data:
                settingsData
                    .notificationPreferences,
            columnMap:
                NOTIFICATION_COLUMNS
        });

        if (
            settingsData
                .appSettings
                .language_code
        ) {
            await connection.execute(
                `
                UPDATE user_profiles
                SET preferred_language = ?
                WHERE user_id = ?
                `,
                [
                    settingsData
                        .appSettings
                        .language_code,
                    userId
                ]
            );
        }

        const consentMappings = [
            [
                'ai_analysis_enabled',
                'ai_analysis'
            ],
            [
                'journal_analysis_enabled',
                'journal_analysis'
            ],
            [
                'analytics_enabled',
                'analytics'
            ]
        ];

        for (
            const [
                settingField,
                consentType
            ] of consentMappings
        ) {
            if (
                Object.prototype.hasOwnProperty.call(
                    settingsData.appSettings,
                    settingField
                )
            ) {
                await upsertConsent(
                    connection,
                    userId,
                    consentType,
                    settingsData
                        .appSettings[
                            settingField
                        ],
                    '1.0'
                );
            }
        }

        if (
            Object.prototype.hasOwnProperty.call(
                settingsData
                    .notificationPreferences,
                'notifications_enabled'
            )
        ) {
            await upsertConsent(
                connection,
                userId,
                'notifications',
                settingsData
                    .notificationPreferences
                    .notifications_enabled,
                '1.0'
            );
        }

        await connection.commit();

        return getSettings(userId);
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function getEmergencyContactById(
    userId,
    contactId,
    executor = pool
) {
    const [rows] = await executor.execute(
        `
        SELECT
            id,
            full_name,
            relationship_name,
            phone_number,
            email,
            is_primary,
            created_at,
            updated_at
        FROM emergency_contacts
        WHERE
            id = ?
            AND user_id = ?
        LIMIT 1
        `,
        [
            contactId,
            userId
        ]
    );

    return rows[0]
        ? mapEmergencyContact(rows[0])
        : null;
}

async function listEmergencyContacts(
    userId
) {
    await ensureActiveUser(pool, userId);

    const [rows] = await pool.execute(
        `
        SELECT
            id,
            full_name,
            relationship_name,
            phone_number,
            email,
            is_primary,
            created_at,
            updated_at
        FROM emergency_contacts
        WHERE user_id = ?
        ORDER BY
            is_primary DESC,
            created_at ASC
        `,
        [userId]
    );

    return rows.map(mapEmergencyContact);
}

async function createEmergencyContact(
    userId,
    contactData
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        const [countRows] =
            await connection.execute(
                `
                SELECT COUNT(*) AS total
                FROM emergency_contacts
                WHERE user_id = ?
                FOR UPDATE
                `,
                [userId]
            );

        const total =
            Number(countRows[0].total);

        if (total >= 5) {
            throw new AppError(
                409,
                'A maximum of five emergency contacts is allowed.'
            );
        }

        const shouldBePrimary =
            total === 0 ||
            contactData.is_primary === true;

        if (shouldBePrimary) {
            await connection.execute(
                `
                UPDATE emergency_contacts
                SET is_primary = FALSE
                WHERE user_id = ?
                `,
                [userId]
            );
        }

        const [result] =
            await connection.execute(
                `
                INSERT INTO emergency_contacts (
                    user_id,
                    full_name,
                    relationship_name,
                    phone_number,
                    email,
                    is_primary
                )
                VALUES (?, ?, ?, ?, ?, ?)
                `,
                [
                    userId,
                    contactData.full_name,
                    contactData.relationship_name ??
                        null,
                    contactData.phone_number,
                    contactData.email ?? null,
                    Number(shouldBePrimary)
                ]
            );

        await connection.commit();

        return getEmergencyContactById(
            userId,
            result.insertId
        );
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function updateEmergencyContact(
    userId,
    contactId,
    contactData
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        const [existingRows] =
            await connection.execute(
                `
                SELECT id
                FROM emergency_contacts
                WHERE
                    id = ?
                    AND user_id = ?
                LIMIT 1
                FOR UPDATE
                `,
                [
                    contactId,
                    userId
                ]
            );

        if (!existingRows[0]) {
            throw new AppError(
                404,
                'Emergency contact was not found.'
            );
        }

        if (contactData.is_primary === true) {
            await connection.execute(
                `
                UPDATE emergency_contacts
                SET is_primary = FALSE
                WHERE user_id = ?
                `,
                [userId]
            );
        }

        const allowedColumns = {
            full_name: 'full_name',
            relationship_name:
                'relationship_name',
            phone_number: 'phone_number',
            email: 'email',
            is_primary: 'is_primary'
        };

        const entries =
            Object.entries(contactData);

        const assignments = entries
            .map(
                ([key]) =>
                    `${allowedColumns[key]} = ?`
            )
            .join(', ');

        const values = entries.map(
            ([, value]) =>
                typeof value === 'boolean'
                    ? Number(value)
                    : value
        );

        await connection.execute(
            `
            UPDATE emergency_contacts
            SET ${assignments}
            WHERE
                id = ?
                AND user_id = ?
            `,
            [
                ...values,
                contactId,
                userId
            ]
        );

        const [primaryRows] =
            await connection.execute(
                `
                SELECT COUNT(*) AS total
                FROM emergency_contacts
                WHERE
                    user_id = ?
                    AND is_primary = TRUE
                `,
                [userId]
            );

        if (
            Number(primaryRows[0].total) === 0
        ) {
            await connection.execute(
                `
                UPDATE emergency_contacts
                SET is_primary = TRUE
                WHERE
                    user_id = ?
                ORDER BY created_at ASC
                LIMIT 1
                `,
                [userId]
            );
        }

        await connection.commit();

        return getEmergencyContactById(
            userId,
            contactId
        );
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function deleteEmergencyContact(
    userId,
    contactId
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        const [rows] =
            await connection.execute(
                `
                SELECT
                    id,
                    is_primary
                FROM emergency_contacts
                WHERE
                    id = ?
                    AND user_id = ?
                LIMIT 1
                FOR UPDATE
                `,
                [
                    contactId,
                    userId
                ]
            );

        const contact = rows[0];

        if (!contact) {
            throw new AppError(
                404,
                'Emergency contact was not found.'
            );
        }

        await connection.execute(
            `
            DELETE FROM emergency_contacts
            WHERE
                id = ?
                AND user_id = ?
            `,
            [
                contactId,
                userId
            ]
        );

        if (booleanValue(contact.is_primary)) {
            await connection.execute(
                `
                UPDATE emergency_contacts
                SET is_primary = TRUE
                WHERE
                    user_id = ?
                ORDER BY created_at ASC
                LIMIT 1
                `,
                [userId]
            );
        }

        await connection.commit();
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

module.exports = {
    getProfile,
    updateProfile,
    getOnboardingStatus,
    completeOnboarding,
    getSettings,
    updateSettings,
    listEmergencyContacts,
    createEmergencyContact,
    updateEmergencyContact,
    deleteEmergencyContact
};
