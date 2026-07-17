const bcrypt = require('bcrypt');
const database =
    require('../config/database');

const AppError =
    require('../utils/AppError');

const {
    createAdminAccessToken,
    createRefreshToken,
    hashRefreshToken,
    getRefreshExpiryDate
} = require('../utils/adminToken');

const pool = database.pool || database;

function mapAdmin(row) {
    return {
        id: Number(row.id),
        full_name: row.full_name,
        email: row.email,
        role: row.role,
        account_status:
            row.account_status,
        last_login_at:
            row.last_login_at,
        created_at:
            row.created_at
    };
}

function getRequestContext(context = {}) {
    return {
        ip_address:
            context.ip_address
                ? String(
                    context.ip_address
                ).slice(0, 45)
                : null,

        user_agent:
            context.user_agent
                ? String(
                    context.user_agent
                ).slice(0, 500)
                : null
    };
}

async function recordLoginAttempt(
    executor,
    {
        adminId,
        email,
        context,
        successful,
        failureReason
    }
) {
    const requestContext =
        getRequestContext(context);

    await executor.execute(
        `
        INSERT INTO admin_login_attempts (
            admin_user_id,
            email,
            ip_address,
            user_agent,
            was_successful,
            failure_reason
        )
        VALUES (?, ?, ?, ?, ?, ?)
        `,
        [
            adminId || null,
            email,
            requestContext.ip_address,
            requestContext.user_agent,
            Number(successful),
            failureReason || null
        ]
    );
}

async function issueTokenPair(
    executor,
    admin,
    context
) {
    const accessToken =
        createAdminAccessToken(admin);

    const refreshToken =
        createRefreshToken();

    const refreshTokenHash =
        hashRefreshToken(refreshToken);

    const expiresAt =
        getRefreshExpiryDate();

    const requestContext =
        getRequestContext(context);

    await executor.execute(
        `
        INSERT INTO admin_refresh_tokens (
            admin_user_id,
            token_hash,
            expires_at,
            ip_address,
            user_agent
        )
        VALUES (?, ?, ?, ?, ?)
        `,
        [
            admin.id,
            refreshTokenHash,
            expiresAt,
            requestContext.ip_address,
            requestContext.user_agent
        ]
    );

    return {
        access_token: accessToken,
        refresh_token: refreshToken,
        token_type: 'Bearer',
        access_expires_in:
            process.env
                .ADMIN_JWT_ACCESS_EXPIRES_IN ||
            '15m',
        refresh_expires_at:
            expiresAt
    };
}

async function login(
    email,
    password,
    context
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        const [rows] =
            await connection.execute(
                `
                SELECT
                    id,
                    full_name,
                    email,
                    password_hash,
                    role,
                    account_status,
                    last_login_at,
                    created_at,
                    deleted_at
                FROM admin_users
                WHERE email = ?
                LIMIT 1
                FOR UPDATE
                `,
                [email]
            );

        const admin = rows[0];

        if (
            !admin ||
            admin.deleted_at
        ) {
            await recordLoginAttempt(
                connection,
                {
                    adminId: null,
                    email,
                    context,
                    successful: false,
                    failureReason:
                        'invalid_credentials'
                }
            );

            await connection.commit();

            throw new AppError(
                401,
                'Invalid admin email or password.'
            );
        }

        const passwordMatches =
            await bcrypt.compare(
                password,
                admin.password_hash
            );

        if (!passwordMatches) {
            await recordLoginAttempt(
                connection,
                {
                    adminId: admin.id,
                    email,
                    context,
                    successful: false,
                    failureReason:
                        'invalid_credentials'
                }
            );

            await connection.commit();

            throw new AppError(
                401,
                'Invalid admin email or password.'
            );
        }

        if (
            admin.account_status !==
            'active'
        ) {
            await recordLoginAttempt(
                connection,
                {
                    adminId: admin.id,
                    email,
                    context,
                    successful: false,
                    failureReason:
                        `account_${admin.account_status}`
                }
            );

            await connection.commit();

            throw new AppError(
                403,
                'Admin account is not active.'
            );
        }

        const tokens =
            await issueTokenPair(
                connection,
                admin,
                context
            );

        await connection.execute(
            `
            UPDATE admin_users
            SET last_login_at =
                CURRENT_TIMESTAMP
            WHERE id = ?
            `,
            [admin.id]
        );

        await recordLoginAttempt(
            connection,
            {
                adminId: admin.id,
                email,
                context,
                successful: true,
                failureReason: null
            }
        );

        await connection.execute(
            `
            INSERT INTO audit_logs (
                admin_user_id,
                actor_type,
                action,
                entity_type,
                entity_id,
                metadata,
                ip_address,
                user_agent
            )
            VALUES (
                ?,
                'admin',
                'admin_login',
                'admin_user',
                ?,
                ?,
                ?,
                ?
            )
            `,
            [
                admin.id,
                admin.id,
                JSON.stringify({
                    role: admin.role
                }),
                getRequestContext(
                    context
                ).ip_address,
                getRequestContext(
                    context
                ).user_agent
            ]
        );

        await connection.commit();

        return {
            admin: mapAdmin(admin),
            tokens
        };
    } catch (error) {
        if (
            connection.connection &&
            connection.connection
                ._closing !== true
        ) {
            try {
                await connection.rollback();
            } catch {
                // No action required.
            }
        }

        throw error;
    } finally {
        connection.release();
    }
}

async function refresh(
    refreshToken,
    context
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        const currentTokenHash =
            hashRefreshToken(
                refreshToken
            );

        const [rows] =
            await connection.execute(
                `
                SELECT
                    art.id AS refresh_id,
                    art.admin_user_id,
                    art.expires_at,
                    art.revoked_at,

                    au.id,
                    au.full_name,
                    au.email,
                    au.role,
                    au.account_status,
                    au.last_login_at,
                    au.created_at,
                    au.deleted_at

                FROM admin_refresh_tokens
                    AS art

                INNER JOIN admin_users AS au
                    ON au.id =
                        art.admin_user_id

                WHERE
                    art.token_hash = ?
                LIMIT 1
                FOR UPDATE
                `,
                [currentTokenHash]
            );

        const tokenRecord = rows[0];

        if (
            !tokenRecord ||
            tokenRecord.revoked_at ||
            tokenRecord.deleted_at ||
            new Date(
                tokenRecord.expires_at
            ).getTime() <= Date.now()
        ) {
            throw new AppError(
                401,
                'Admin refresh token is invalid or expired.'
            );
        }

        if (
            tokenRecord.account_status !==
            'active'
        ) {
            throw new AppError(
                403,
                'Admin account is not active.'
            );
        }

        const newRefreshToken =
            createRefreshToken();

        const newRefreshTokenHash =
            hashRefreshToken(
                newRefreshToken
            );

        const newExpiry =
            getRefreshExpiryDate();

        const requestContext =
            getRequestContext(context);

        await connection.execute(
            `
            UPDATE admin_refresh_tokens
            SET
                revoked_at =
                    CURRENT_TIMESTAMP,
                replaced_by_token_hash = ?
            WHERE id = ?
            `,
            [
                newRefreshTokenHash,
                tokenRecord.refresh_id
            ]
        );

        await connection.execute(
            `
            INSERT INTO admin_refresh_tokens (
                admin_user_id,
                token_hash,
                expires_at,
                ip_address,
                user_agent
            )
            VALUES (?, ?, ?, ?, ?)
            `,
            [
                tokenRecord.admin_user_id,
                newRefreshTokenHash,
                newExpiry,
                requestContext.ip_address,
                requestContext.user_agent
            ]
        );

        const accessToken =
            createAdminAccessToken(
                tokenRecord
            );

        await connection.commit();

        return {
            access_token:
                accessToken,
            refresh_token:
                newRefreshToken,
            token_type: 'Bearer',
            access_expires_in:
                process.env
                    .ADMIN_JWT_ACCESS_EXPIRES_IN ||
                '15m',
            refresh_expires_at:
                newExpiry
        };
    } catch (error) {
        try {
            await connection.rollback();
        } catch {
            // No action required.
        }

        throw error;
    } finally {
        connection.release();
    }
}

async function logout(refreshToken) {
    const tokenHash =
        hashRefreshToken(refreshToken);

    await pool.execute(
        `
        UPDATE admin_refresh_tokens
        SET revoked_at =
            COALESCE(
                revoked_at,
                CURRENT_TIMESTAMP
            )
        WHERE token_hash = ?
        `,
        [tokenHash]
    );
}

async function logoutAll(adminId) {
    const [result] =
        await pool.execute(
            `
            UPDATE admin_refresh_tokens
            SET revoked_at =
                CURRENT_TIMESTAMP
            WHERE
                admin_user_id = ?
                AND revoked_at IS NULL
            `,
            [adminId]
        );

    return Number(result.affectedRows);
}

module.exports = {
    login,
    refresh,
    logout,
    logoutAll
};
