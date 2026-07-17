function normalizeEmail(value) {
    return typeof value === 'string'
        ? value.trim().toLowerCase()
        : '';
}

function normalizeName(value) {
    return typeof value === 'string'
        ? value.trim().replace(/\s+/g, ' ')
        : '';
}

function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function validateRegister(body = {}) {
    const fullName = normalizeName(body.full_name);
    const email = normalizeEmail(body.email);
    const password =
        typeof body.password === 'string'
            ? body.password
            : '';

    const errors = [];

    if (fullName.length < 2 || fullName.length > 120) {
        errors.push(
            'Full name must contain between 2 and 120 characters.'
        );
    }

    if (!isValidEmail(email) || email.length > 191) {
        errors.push('A valid email address is required.');
    }

    if (password.length < 8 || password.length > 72) {
        errors.push(
            'Password must contain between 8 and 72 characters.'
        );
    }

    if (!/[A-Za-z]/.test(password)) {
        errors.push('Password must contain at least one letter.');
    }

    if (!/[0-9]/.test(password)) {
        errors.push('Password must contain at least one number.');
    }

    return {
        errors,
        data: {
            fullName,
            email,
            password
        }
    };
}

function validateLogin(body = {}) {
    const email = normalizeEmail(body.email);
    const password =
        typeof body.password === 'string'
            ? body.password
            : '';

    const errors = [];

    if (!isValidEmail(email)) {
        errors.push('A valid email address is required.');
    }

    if (!password) {
        errors.push('Password is required.');
    }

    return {
        errors,
        data: {
            email,
            password
        }
    };
}

function validateRefreshToken(body = {}) {
    const refreshToken =
        typeof body.refresh_token === 'string'
            ? body.refresh_token.trim()
            : '';

    const errors = [];

    if (!refreshToken) {
        errors.push('Refresh token is required.');
    }

    return {
        errors,
        data: {
            refreshToken
        }
    };
}

module.exports = {
    validateRegister,
    validateLogin,
    validateRefreshToken
};
