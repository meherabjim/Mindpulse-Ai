function isPlainObject(value) {
    return (
        value !== null &&
        typeof value === 'object' &&
        !Array.isArray(value)
    );
}

function isValidEmail(value) {
    return (
        typeof value === 'string' &&
        /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(
            value
        )
    );
}

function validateLogin(body = {}) {
    const errors = [];
    const data = {};

    if (!isPlainObject(body)) {
        return {
            errors: [
                'Admin login data must be an object.'
            ],
            data
        };
    }

    const email =
        typeof body.email === 'string'
            ? body.email
                .trim()
                .toLowerCase()
            : '';

    if (!isValidEmail(email)) {
        errors.push(
            'A valid admin email address is required.'
        );
    } else {
        data.email = email;
    }

    if (
        typeof body.password !== 'string' ||
        body.password.length < 8 ||
        body.password.length > 128
    ) {
        errors.push(
            'Admin password must contain between 8 and 128 characters.'
        );
    } else {
        data.password = body.password;
    }

    return {
        errors,
        data
    };
}

function validateRefreshToken(body = {}) {
    const errors = [];

    const refreshToken =
        typeof body.refresh_token ===
            'string'
            ? body.refresh_token.trim()
            : '';

    if (
        refreshToken.length < 40 ||
        refreshToken.length > 500
    ) {
        errors.push(
            'A valid admin refresh token is required.'
        );
    }

    return {
        errors,
        data: {
            refresh_token: refreshToken
        }
    };
}

module.exports = {
    validateLogin,
    validateRefreshToken
};
