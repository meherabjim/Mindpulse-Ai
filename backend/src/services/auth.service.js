const bcrypt = require('bcrypt');

const database = require('../config/database');
const AppError = require('../utils/AppError');

const {
    createAccessToken,
    createRefreshToken,
    hashToken,
    getRefreshTokenExpiry
} = require('../utils/token');

const pool = database.pool || database;

function sanitizeMeta(meta = {}) {
    const rawIp =
        typeof meta.ipAddress === 'string'
            ? meta.ipAddress
            : '';

    const rawUserAgent =
        typeof meta.userAgent === 'string'
            ? meta.userAgent
            : '';

    return {
        ipAddress:
            rawIp
                .replace(/^::ffff:/, '')
                .slice(0, 45) || null,

        userAgent:
            rawUserAgent.slice(0, 500) || null
    };
}

function buildUserResponse(user) {
    return {
        id: Number(user.id),
        email: user.email,
        full_name: user.full_name || null,

        account_status:
            user.account_status,

        onboarding_completed:
            Boolean(user.onboarding_completed),

        email_verified:
            Boolean(user.email_verified_at),

        created_at:
            user.created_at || null
    };
}

async function createTokenSession(
    executor,
    user,
    meta = {}
) {
    const cleanMeta = sanitizeMeta(meta);

    const refreshToken = createRefreshToken();
    const refreshTokenHash = hashToken(refreshToken);
    const expiresAt = getRefreshTokenExpiry();

    await executor.execute(
        `
        INSERT INTO refresh_tokens (
            user_id,
            token_hash,
            expires_at,
            ip_address,
            user_agent
        )
        VALUES (?, ?, ?, ?, ?)
        `,
        [
            user.id,
            refreshTokenHash,
            expiresAt,
            cleanMeta.ipAddress,
            cleanMeta.userAgent
        ]
    );

    return {
        token_type: 'Bearer',

        access_token:
            createAccessToken(user),

        access_token_expires_in:
            process.env.JWT_ACCESS_EXPIRES_IN || '15m',

        refresh_token:
            refreshToken,

        refresh_token_expires_at:
            expiresAt.toISOString()
    };
}

async function recordLoginAttempt({
    email,
    successful,
    failureReason = null,
    meta = {}
}) {
    const cleanMeta = sanitizeMeta(meta);

    try {
        await pool.execute(
            `
            INSERT INTO login_attempts (
                email,
                ip_address,
                user_agent,
                was_successful,
                failure_reason
            )
            VALUES (?, ?, ?, ?, ?)
            `,
            [
                email,
                cleanMeta.ipAddress,
                cleanMeta.userAgent,
                successful,
                failureReason
            ]
        );
    } catch (error) {
        console.error(
            'Failed to record login attempt:',
            error.message
        );
    }
}

async function register(
    registrationData,
    meta = {}
) {
    const {
        fullName,
        email,
        password
    } = registrationData;

    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        const [existingRows] =
            await connection.execute(
                `
                SELECT id
                FROM users
                WHERE email = ?
                LIMIT 1
                `,
                [email]
            );

        if (existingRows.length > 0) {
            throw new AppError(
                409,
                'An account already exists with this email address.'
            );
        }

        const configuredRounds =
            Number(process.env.BCRYPT_ROUNDS || 12);

        const bcryptRounds =
            Number.isInteger(configuredRounds) &&
            configuredRounds >= 10 &&
            configuredRounds <= 15
                ? configuredRounds
                : 12;

        const passwordHash =
            await bcrypt.hash(
                password,
                bcryptRounds
            );

        const [userResult] =
            await connection.execute(
                `
                INSERT INTO users (
                    email,
                    password_hash,
                    account_status,
                    onboarding_completed
                )
                VALUES (?, ?, 'active', FALSE)
                `,
                [
                    email,
                    passwordHash
                ]
            );

        const userId =
            userResult.insertId;

        await connection.execute(
            `
            INSERT INTO user_profiles (
                user_id,
                full_name,
                preferred_language,
                timezone
            )
            VALUES (?, ?, 'en', 'Asia/Dhaka')
            `,
            [
                userId,
                fullName
            ]
        );

        const user = {
            id: userId,
            email,
            full_name: fullName,
            account_status: 'active',
            onboarding_completed: false,
            email_verified_at: null,
            created_at: new Date()
        };

        const tokens =
            await createTokenSession(
                connection,
                user,
                meta
            );

        await connection.commit();

        return {
            user: buildUserResponse(user),
            tokens
        };
    } catch (error) {
        await connection.rollback();

        if (error.code === 'ER_DUP_ENTRY') {
            throw new AppError(
                409,
                'An account already exists with this email address.'
            );
        }

        throw error;
    } finally {
        connection.release();
    }
}

async function login(
    credentials,
    meta = {}
) {
    const {
        email,
        password
    } = credentials;

    const [rows] =
        await pool.execute(
            `
            SELECT
                u.id,
                u.email,
                u.password_hash,
                u.account_status,
                u.onboarding_completed,
                u.email_verified_at,
                u.created_at,
                p.full_name
            FROM users AS u
            LEFT JOIN user_profiles AS p
                ON p.user_id = u.id
            WHERE
                u.email = ?
                AND u.deleted_at IS NULL
            LIMIT 1
            `,
            [email]
        );

    const user = rows[0];

    if (!user) {
        await recordLoginAttempt({
            email,
            successful: false,
            failureReason: 'account_not_found',
            meta
        });

        throw new AppError(
            401,
            'Invalid email or password.'
        );
    }

    if (user.account_status !== 'active') {
        await recordLoginAttempt({
            email,
            successful: false,
            failureReason:
                `account_${user.account_status}`,
            meta
        });

        throw new AppError(
            403,
            'This account is not currently active.'
        );
    }

    const passwordMatches =
        await bcrypt.compare(
            password,
            user.password_hash
        );

    if (!passwordMatches) {
        await recordLoginAttempt({
            email,
            successful: false,
            failureReason: 'invalid_password',
            meta
        });

        throw new AppError(
            401,
            'Invalid email or password.'
        );
    }

    await pool.execute(
        `
        UPDATE users
        SET last_login_at = CURRENT_TIMESTAMP
        WHERE id = ?
        `,
        [user.id]
    );

    const tokens =
        await createTokenSession(
            pool,
            user,
            meta
        );

    await recordLoginAttempt({
        email,
        successful: true,
        meta
    });

    delete user.password_hash;

    return {
        user: buildUserResponse(user),
        tokens
    };
}

async function refreshSession(
    rawRefreshToken,
    meta = {}
) {
    const oldTokenHash =
        hashToken(rawRefreshToken);

    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        const [rows] =
            await connection.execute(
                `
                SELECT
                    rt.id AS refresh_token_id,
                    rt.user_id,
                    rt.expires_at,
                    rt.revoked_at,

                    u.id,
                    u.email,
                    u.account_status,
                    u.onboarding_completed,
                    u.email_verified_at,
                    u.created_at,
                    u.deleted_at,

                    p.full_name
                FROM refresh_tokens AS rt
                INNER JOIN users AS u
                    ON u.id = rt.user_id
                LEFT JOIN user_profiles AS p
                    ON p.user_id = u.id
                WHERE rt.token_hash = ?
                LIMIT 1
                FOR UPDATE
                `,
                [oldTokenHash]
            );

        const session = rows[0];

        const tokenIsExpired =
            session &&
            new Date(session.expires_at).getTime()
                <= Date.now();

        if (
            !session ||
            session.revoked_at ||
            tokenIsExpired ||
            session.deleted_at ||
            session.account_status !== 'active'
        ) {
            throw new AppError(
                401,
                'Invalid or expired refresh token.'
            );
        }

        const cleanMeta =
            sanitizeMeta(meta);

        const newRefreshToken =
            createRefreshToken();

        const newRefreshTokenHash =
            hashToken(newRefreshToken);

        const newExpiresAt =
            getRefreshTokenExpiry();

        await connection.execute(
            `
            INSERT INTO refresh_tokens (
                user_id,
                token_hash,
                expires_at,
                ip_address,
                user_agent
            )
            VALUES (?, ?, ?, ?, ?)
            `,
            [
                session.user_id,
                newRefreshTokenHash,
                newExpiresAt,
                cleanMeta.ipAddress,
                cleanMeta.userAgent
            ]
        );

        await connection.execute(
            `
            UPDATE refresh_tokens
            SET
                revoked_at = CURRENT_TIMESTAMP,
                replaced_by_token_hash = ?
            WHERE id = ?
            `,
            [
                newRefreshTokenHash,
                session.refresh_token_id
            ]
        );

        const user = {
            id: session.user_id,
            email: session.email,
            full_name: session.full_name,
            account_status:
                session.account_status,
            onboarding_completed:
                session.onboarding_completed,
            email_verified_at:
                session.email_verified_at,
            created_at:
                session.created_at
        };

        const accessToken =
            createAccessToken(user);

        await connection.commit();

        return {
            user: buildUserResponse(user),

            tokens: {
                token_type: 'Bearer',

                access_token:
                    accessToken,

                access_token_expires_in:
                    process.env.JWT_ACCESS_EXPIRES_IN ||
                    '15m',

                refresh_token:
                    newRefreshToken,

                refresh_token_expires_at:
                    newExpiresAt.toISOString()
            }
        };
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function logout(rawRefreshToken) {
    const tokenHash =
        hashToken(rawRefreshToken);

    await pool.execute(
        `
        UPDATE refresh_tokens
        SET revoked_at = COALESCE(
            revoked_at,
            CURRENT_TIMESTAMP
        )
        WHERE token_hash = ?
        `,
        [tokenHash]
    );
}

async function logoutAll(userId) {
    await pool.execute(
        `
        UPDATE refresh_tokens
        SET revoked_at = COALESCE(
            revoked_at,
            CURRENT_TIMESTAMP
        )
        WHERE
            user_id = ?
            AND revoked_at IS NULL
        `,
        [userId]
    );
}

async function getCurrentUser(userId) {
    const [rows] =
        await pool.execute(
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
                p.timezone
            FROM users AS u
            LEFT JOIN user_profiles AS p
                ON p.user_id = u.id
            WHERE
                u.id = ?
                AND u.deleted_at IS NULL
            LIMIT 1
            `,
            [userId]
        );

    const user = rows[0];

    if (!user) {
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

    return {
        id: Number(user.id),
        email: user.email,
        full_name: user.full_name,

        profile_photo_url:
            user.profile_photo_url,

        age_range:
            user.age_range,

        gender:
            user.gender,

        occupation:
            user.occupation,

        user_type:
            user.user_type,

        wellness_goal:
            user.wellness_goal,

        preferred_language:
            user.preferred_language,

        timezone:
            user.timezone,

        account_status:
            user.account_status,

        onboarding_completed:
            Boolean(user.onboarding_completed),

        email_verified:
            Boolean(user.email_verified_at),

        created_at:
            user.created_at
    };
}

module.exports = {
    register,
    login,
    refreshSession,
    logout,
    logoutAll,
    getCurrentUser
};
