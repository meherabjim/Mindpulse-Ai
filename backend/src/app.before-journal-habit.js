const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const AppError = require('./utils/AppError');
const authRoutes = require('./routes/auth.routes');
const accountRoutes = require('./routes/account.routes');
const wellnessRoutes = require('./routes/wellness.routes');

const app = express();

app.disable('x-powered-by');

function getCorsOptions() {
    const configuredOrigin =
        process.env.CORS_ORIGIN || '*';

    if (configuredOrigin === '*') {
        return {
            origin: true
        };
    }

    const allowedOrigins =
        configuredOrigin
            .split(',')
            .map((origin) => origin.trim())
            .filter(Boolean);

    return {
        origin(origin, callback) {
            if (
                !origin ||
                allowedOrigins.includes(origin)
            ) {
                return callback(null, true);
            }

            return callback(
                new AppError(
                    403,
                    'This origin is not allowed by CORS.'
                )
            );
        }
    };
}

app.use(helmet());
app.use(cors(getCorsOptions()));

app.use(
    morgan(
        process.env.NODE_ENV === 'production'
            ? 'combined'
            : 'dev'
    )
);

app.use(
    express.json({
        limit: '1mb'
    })
);

app.use(
    express.urlencoded({
        extended: true,
        limit: '1mb'
    })
);

const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 300,
    standardHeaders: 'draft-7',
    legacyHeaders: false,

    message: {
        success: false,
        message:
            'Too many API requests. Please try again later.'
    }
});

app.use('/api', apiLimiter);

app.get('/', (req, res) => {
    return res.status(200).json({
        success: true,
        message:
            'Welcome to MindPulse AI API',
        data: {
            version: '1.0.0'
        }
    });
});

app.get('/api/v1/health', (req, res) => {
    return res.status(200).json({
        success: true,
        message:
            'MindPulse AI API is healthy',
        data: {
            environment:
                process.env.NODE_ENV ||
                'development',

            timestamp:
                new Date().toISOString()
        }
    });
});

app.use(
    '/api/v1/auth',
    authRoutes
);

app.use('/api/v1', accountRoutes);

app.use('/api/v1', wellnessRoutes);

app.use((req, res, next) => {
    return next(
        new AppError(
            404,
            `Route not found: ${req.method} ${req.originalUrl}`
        )
    );
});

app.use((error, req, res, next) => {
    if (
        error instanceof SyntaxError &&
        error.status === 400 &&
        'body' in error
    ) {
        error = new AppError(
            400,
            'Request body contains invalid JSON.'
        );
    }

    if (error.code === 'ER_DUP_ENTRY') {
        error = new AppError(
            409,
            'The submitted information already exists.'
        );
    }

    const statusCode =
        error.statusCode || 500;

    const isProduction =
        process.env.NODE_ENV === 'production';

    if (statusCode >= 500) {
        console.error(error);
    }

    const response = {
        success: false,

        message:
            statusCode >= 500 && isProduction
                ? 'An unexpected server error occurred.'
                : error.message ||
                  'An unexpected error occurred.'
    };

    if (error.details) {
        response.errors =
            error.details;
    }

    if (!isProduction && statusCode >= 500) {
        response.stack =
            error.stack;
    }

    return res
        .status(statusCode)
        .json(response);
});

module.exports = app;
