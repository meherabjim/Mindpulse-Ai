const AppError =
    require('../utils/AppError');

const adminAuthService =
    require('../services/adminAuth.service');

const {
    validateLogin,
    validateRefreshToken
} = require('../validators/adminAuth.validator');

function throwValidation(
    message,
    errors
) {
    if (errors.length > 0) {
        throw new AppError(
            422,
            message,
            errors
        );
    }
}

function getContext(req) {
    return {
        ip_address: req.ip,
        user_agent:
            req.headers['user-agent'] ||
            null
    };
}

async function login(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateLogin(req.body);

        throwValidation(
            'Admin login validation failed.',
            errors
        );

        const result =
            await adminAuthService.login(
                data.email,
                data.password,
                getContext(req)
            );

        return res.status(200).json({
            success: true,
            message:
                'Admin login successful.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function refresh(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateRefreshToken(
            req.body
        );

        throwValidation(
            'Admin refresh token validation failed.',
            errors
        );

        const tokens =
            await adminAuthService.refresh(
                data.refresh_token,
                getContext(req)
            );

        return res.status(200).json({
            success: true,
            message:
                'Admin tokens refreshed successfully.',
            data: {
                tokens
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function logout(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateRefreshToken(
            req.body
        );

        throwValidation(
            'Admin logout validation failed.',
            errors
        );

        await adminAuthService.logout(
            data.refresh_token
        );

        return res.status(200).json({
            success: true,
            message:
                'Admin logged out successfully.'
        });
    } catch (error) {
        return next(error);
    }
}

async function logoutAll(
    req,
    res,
    next
) {
    try {
        const revokedCount =
            await adminAuthService
                .logoutAll(
                    req.admin.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Admin logged out from all sessions successfully.',
            data: {
                revoked_sessions:
                    revokedCount
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function me(req, res) {
    return res.status(200).json({
        success: true,
        message:
            'Admin account retrieved successfully.',
        data: {
            admin: req.admin
        }
    });
}

module.exports = {
    login,
    refresh,
    logout,
    logoutAll,
    me
};
