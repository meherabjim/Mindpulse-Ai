const crypto = require('crypto');
const jwt = require('jsonwebtoken');

function getJwtSecret() {
    const secret = process.env.JWT_ACCESS_SECRET;

    if (!secret) {
        throw new Error('JWT_ACCESS_SECRET is missing from the environment.');
    }

    return secret;
}

function createAccessToken(user) {
    return jwt.sign(
        {
            sub: String(user.id),
            email: user.email,
            token_type: 'access'
        },
        getJwtSecret(),
        {
            expiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
            issuer: process.env.JWT_ISSUER || 'mindpulse-ai',
            audience: process.env.JWT_AUDIENCE || 'mindpulse-mobile'
        }
    );
}

function verifyAccessToken(token) {
    return jwt.verify(token, getJwtSecret(), {
        issuer: process.env.JWT_ISSUER || 'mindpulse-ai',
        audience: process.env.JWT_AUDIENCE || 'mindpulse-mobile'
    });
}

function createRefreshToken() {
    return crypto.randomBytes(64).toString('hex');
}

function hashToken(token) {
    return crypto
        .createHash('sha256')
        .update(token)
        .digest('hex');
}

function getRefreshTokenExpiry() {
    const configuredDays = Number(process.env.REFRESH_TOKEN_DAYS || 30);

    const days =
        Number.isFinite(configuredDays) && configuredDays > 0
            ? configuredDays
            : 30;

    const expiry = new Date();

    expiry.setDate(expiry.getDate() + days);

    return expiry;
}

module.exports = {
    createAccessToken,
    verifyAccessToken,
    createRefreshToken,
    hashToken,
    getRefreshTokenExpiry
};
