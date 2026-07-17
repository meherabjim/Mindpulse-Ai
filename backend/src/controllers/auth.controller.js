const AppError = require('../utils/AppError');

const {
    validateRegister,
    validateLogin,
    validateRefreshToken
} = require('../validators/auth.validator');

const authService =
    require('../services/auth.service');

function getRequestMeta(req) {
    return {
        ipAddress:
            req.ip ||
            req.socket?.remoteAddress ||
            null,

        userAgent:
            req.get('user-agent') ||
            null
    };
}

async function register(req, res, next) {
    try {
        const {
            errors,
            data
        } = validateRegister(req.body);

        if (errors.length > 0) {
            throw new AppError(
                422,
                'Registration validation failed.',
                errors
            );
        }

        const result =
            await authService.register(
                data,
                getRequestMeta(req)
            );

        return res.status(201).json({
            success: true,
            message:
                'Account registered successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function login(req, res, next) {
    try {
        const {
            errors,
            data
        } = validateLogin(req.body);

        if (errors.length > 0) {
            throw new AppError(
                422,
                'Login validation failed.',
                errors
            );
        }

        const result =
            await authService.login(
                data,
                getRequestMeta(req)
            );

        return res.status(200).json({
            success: true,
            message:
                'Login successful.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function refresh(req, res, next) {
    try {
        const {
            errors,
            data
        } = validateRefreshToken(req.body);

        if (errors.length > 0) {
            throw new AppError(
                422,
                'Refresh token validation failed.',
                errors
            );
        }

        const result =
            await authService.refreshSession(
                data.refreshToken,
                getRequestMeta(req)
            );

        return res.status(200).json({
            success: true,
            message:
                'Authentication tokens refreshed successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function logout(req, res, next) {
    try {
        const {
            errors,
            data
        } = validateRefreshToken(req.body);

        if (errors.length > 0) {
            throw new AppError(
                422,
                'Refresh token validation failed.',
                errors
            );
        }

        await authService.logout(
            data.refreshToken
        );

        return res.status(200).json({
            success: true,
            message:
                'Logout successful.'
        });
    } catch (error) {
        return next(error);
    }
}

async function logoutAll(req, res, next) {
    try {
        await authService.logoutAll(
            req.user.id
        );

        return res.status(200).json({
            success: true,
            message:
                'Logged out from all devices successfully.'
        });
    } catch (error) {
        return next(error);
    }
}

async function me(req, res, next) {
    try {
        const user =
            await authService.getCurrentUser(
                req.user.id
            );

        return res.status(200).json({
            success: true,
            message:
                'Current user retrieved successfully.',
            data: {
                user
            }
        });
    } catch (error) {
        return next(error);
    }
}

module.exports = {
    register,
    login,
    refresh,
    logout,
    logoutAll,
    me
};
