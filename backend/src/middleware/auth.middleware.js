const AppError = require('../utils/AppError');
const { verifyAccessToken } = require('../utils/token');

function authenticate(req, res, next) {
    try {
        const authorization = req.get('authorization');

        if (!authorization) {
            throw new AppError(
                401,
                'Authentication token is required.'
            );
        }

        const [scheme, token] = authorization.split(' ');

        if (
            scheme?.toLowerCase() !== 'bearer' ||
            !token
        ) {
            throw new AppError(
                401,
                'Authorization header must use the Bearer scheme.'
            );
        }

        const payload = verifyAccessToken(token);

        if (
            payload.token_type !== 'access' ||
            !payload.sub
        ) {
            throw new AppError(
                401,
                'Invalid authentication token.'
            );
        }

        req.user = {
            id: Number(payload.sub),
            email: payload.email
        };

        next();
    } catch (error) {
        if (error instanceof AppError) {
            return next(error);
        }

        if (
            error.name === 'TokenExpiredError'
        ) {
            return next(
                new AppError(
                    401,
                    'Access token has expired.'
                )
            );
        }

        return next(
            new AppError(
                401,
                'Invalid authentication token.'
            )
        );
    }
}

module.exports = {
    authenticate
};
