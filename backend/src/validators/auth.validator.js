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

// MINDPULSE BANGLADESH LOCAL PHONE V2
function normalizePhone(value) {
    if (typeof value !== 'string') {
        return '';
    }

    const compact = value.trim().replace(/[^0-9+]/g, '');

    if (/^01[3-9][0-9]{8}$/.test(compact)) {
        return `+88${compact}`;
    }

    if (/^8801[3-9][0-9]{8}$/.test(compact)) {
        return `+${compact}`;
    }

    return compact;
}

function parseDateOnly(value) {
    if (
        typeof value !== 'string' ||
        !/^\d{4}-\d{2}-\d{2}$/.test(value)
    ) {
        return null;
    }

    const date = new Date(`${value}T00:00:00.000Z`);

    if (Number.isNaN(date.getTime())) {
        return null;
    }

    return date.toISOString().slice(0, 10) === value
        ? date
        : null;
}

function ageOnDate(dateOfBirth, currentDate = new Date()) {
    let age =
        currentDate.getUTCFullYear() -
        dateOfBirth.getUTCFullYear();

    const beforeBirthday =
        currentDate.getUTCMonth() < dateOfBirth.getUTCMonth() ||
        (
            currentDate.getUTCMonth() === dateOfBirth.getUTCMonth() &&
            currentDate.getUTCDate() < dateOfBirth.getUTCDate()
        );

    if (beforeBirthday) {
        age -= 1;
    }

    return age;
}

function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function validateRegister(body = {}) {
    const fullName = normalizeName(body.full_name);
    const email = normalizeEmail(body.email);
    const phoneNumber = normalizePhone(body.phone_number);
    const dateOfBirthText =
        typeof body.date_of_birth === 'string'
            ? body.date_of_birth.trim()
            : '';
    const dateOfBirth = parseDateOnly(dateOfBirthText);
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

    if (!/^\+8801[3-9][0-9]{8}$/.test(phoneNumber)) {
        errors.push(
            'Enter an 11-digit Bangladesh phone number, for example 017XXXXXXXX.'
        );
    }

    if (!dateOfBirth) {
        errors.push('A valid date of birth is required.');
    } else {
        const age = ageOnDate(dateOfBirth);

        if (age < 13 || age > 120) {
            errors.push(
                'Registration currently supports ages 13 to 120.'
            );
        }
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
            phoneNumber,
            dateOfBirth: dateOfBirthText,
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
