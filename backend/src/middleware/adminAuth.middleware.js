const database =
    require('../config/database');

const AppError =
    require('../utils/AppError');

const {
    verifyAdminAccessToken
} = require('../utils/adminToken');

const pool = database.pool || database;

async function authenticateAdmin(
    req,
    res,
    next
) {
    try {
        const authorization =
            req.headers.authorization || '';

        const [scheme, token] =
            authorization.split(' ');

        if (
            scheme !== 'Bearer' ||
            !token
        ) {
            throw new AppError(
                401,
                'Admin authentication is required.'
            );
        }

        let payload;

        try {
            payload =
                verifyAdminAccessToken(
                    token
                );
        } catch {
            throw new AppError(
                401,
                'Admin access token is invalid or expired.'
            );
        }

        if (
            payload.type !==
                'admin_access' ||
            !payload.sub
        ) {
            throw new AppError(
                401,
                'Invalid admin access token.'
            );
        }

        const adminId =
            Number(payload.sub);

        if (
            !Number.isSafeInteger(adminId) ||
            adminId <= 0
        ) {
            throw new AppError(
                401,
                'Invalid admin account identity.'
            );
        }

        const [rows] =
            await pool.execute(
                `
                SELECT
                    id,
                    full_name,
                    email,
                    role,
                    account_status,
                    last_login_at,
                    created_at
                FROM admin_users
                WHERE
                    id = ?
                    AND deleted_at IS NULL
                LIMIT 1
                `,
                [adminId]
            );

        const admin = rows[0];

        if (!admin) {
            throw new AppError(
                401,
                'Admin account was not found.'
            );
        }

        if (
            admin.account_status !==
            'active'
        ) {
            throw new AppError(
                403,
                'Admin account is not active.'
            );
        }

        req.admin = {
            id: Number(admin.id),
            full_name:
                admin.full_name,
            email: admin.email,
            role: admin.role,
            account_status:
                admin.account_status,
            last_login_at:
                admin.last_login_at,
            created_at:
                admin.created_at
        };

        return next();
    } catch (error) {
        return next(error);
    }
}

function authorizeAdminRoles(
    ...allowedRoles
) {
    return function roleAuthorization(
        req,
        res,
        next
    ) {
        if (!req.admin) {
            return next(
                new AppError(
                    401,
                    'Admin authentication is required.'
                )
            );
        }

        if (
            !allowedRoles.includes(
                req.admin.role
            )
        ) {
            return next(
                new AppError(
                    403,
                    'You do not have permission to perform this admin action.'
                )
            );
        }

        return next();
    };
}

module.exports = {
    authenticateAdmin,
    authorizeAdminRoles
};
