const crypto = require('crypto');
const jwt = require('jsonwebtoken');

function requireEnvironmentValue(name) {
    const value = process.env[name];

    if (!value) {
        throw new Error(
            `${name} environment variable is required.`
        );
    }

    return value;
}

function createAdminAccessToken(admin) {
    const secret =
        requireEnvironmentValue(
            'ADMIN_JWT_ACCESS_SECRET'
        );

    return jwt.sign(
        {
            type: 'admin_access',
            role: admin.role,
            email: admin.email
        },
        secret,
        {
            subject: String(admin.id),

            expiresIn:
                process.env
                    .ADMIN_JWT_ACCESS_EXPIRES_IN ||
                '15m',

            issuer:
                process.env.ADMIN_JWT_ISSUER ||
                'mindpulse-ai-admin',

            audience:
                process.env.ADMIN_JWT_AUDIENCE ||
                'mindpulse-admin-dashboard'
        }
    );
}

function verifyAdminAccessToken(token) {
    const secret =
        requireEnvironmentValue(
            'ADMIN_JWT_ACCESS_SECRET'
        );

    return jwt.verify(token, secret, {
        issuer:
            process.env.ADMIN_JWT_ISSUER ||
            'mindpulse-ai-admin',

        audience:
            process.env.ADMIN_JWT_AUDIENCE ||
            'mindpulse-admin-dashboard'
    });
}

function createRefreshToken() {
    return crypto
        .randomBytes(64)
        .toString('hex');
}

function hashRefreshToken(token) {
    return crypto
        .createHash('sha256')
        .update(token)
        .digest('hex');
}

function getRefreshExpiryDate() {
    const days =
        Number(
            process.env
                .ADMIN_REFRESH_TOKEN_DAYS ||
            30
        );

    return new Date(
        Date.now() +
        days * 24 * 60 * 60 * 1000
    );
}

module.exports = {
    createAdminAccessToken,
    verifyAdminAccessToken,
    createRefreshToken,
    hashRefreshToken,
    getRefreshExpiryDate
};
