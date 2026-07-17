const AppError =
    require('../utils/AppError');

const recommendationSessionService =
    require(
        '../services/' +
        'recommendationSession.service'
    );

const {
    validateStart,
    validateFinish,
    validatePositiveId,
    validateHistoryQuery,
    validateSummaryQuery
} = require(
    '../validators/' +
    'recommendationSession.validator'
);


function throwValidation(
    message,
    errors
) {
    if (
        errors.length > 0
    ) {
        throw new AppError(
            422,
            message,
            errors
        );
    }
}


async function startSession(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateStart(
            req.body
        );

        throwValidation(
            'Recommendation session validation failed.',
            errors
        );

        const session =
            await recommendationSessionService
                .startSession(
                    req.user.id,
                    data
                );

        return res.status(201).json({
            success: true,

            message:
                'Recommendation follow-up started.',

            data: {
                session
            }
        });
    } catch (error) {
        return next(error);
    }
}


async function finishSession(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id
            );

        throwValidation(
            'Recommendation session ID is invalid.',
            idResult.errors
        );

        const {
            errors,
            data
        } = validateFinish(
            req.body
        );

        throwValidation(
            'Recommendation follow-up validation failed.',
            errors
        );

        const session =
            await recommendationSessionService
                .finishSession(
                    req.user.id,
                    idResult.id,
                    data
                );

        return res.status(200).json({
            success: true,

            message:
                'Recommendation follow-up saved.',

            data: {
                session
            }
        });
    } catch (error) {
        return next(error);
    }
}


async function listHistory(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateHistoryQuery(
            req.query
        );

        throwValidation(
            'Recommendation history query is invalid.',
            errors
        );

        const result =
            await recommendationSessionService
                .listHistory(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,

            message:
                'Recommendation follow-up history retrieved.',

            data: result
        });
    } catch (error) {
        return next(error);
    }
}


async function getSummary(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateSummaryQuery(
            req.query
        );

        throwValidation(
            'Recommendation summary query is invalid.',
            errors
        );

        const summary =
            await recommendationSessionService
                .getSummary(
                    req.user.id,
                    data.days
                );

        return res.status(200).json({
            success: true,

            message:
                'Recommendation follow-up summary retrieved.',

            data: {
                summary
            }
        });
    } catch (error) {
        return next(error);
    }
}


module.exports = {
    startSession,
    finishSession,
    listHistory,
    getSummary
};
