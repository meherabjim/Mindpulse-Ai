const AppError = require('../utils/AppError');

const wellnessService =
    require('../services/wellness.service');

const {
    validateCheckin,
    validateScanSubmission,
    validateHistoryQuery,
    validatePositiveId
} = require('../validators/wellness.validator');

function throwValidationError(
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

async function submitCheckin(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateCheckin(req.body);

        throwValidationError(
            'Daily check-in validation failed.',
            errors
        );

        const checkin =
            await wellnessService
                .submitCheckin(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Daily check-in saved successfully.',
            data: {
                checkin
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function getTodayCheckin(
    req,
    res,
    next
) {
    try {
        const result =
            await wellnessService
                .getTodayCheckin(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                result.has_checkin
                    ? 'Today’s check-in retrieved successfully.'
                    : 'No check-in has been submitted today.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function getCheckinHistory(
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

        throwValidationError(
            'Check-in history query is invalid.',
            errors
        );

        const result =
            await wellnessService
                .getCheckinHistory(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Check-in history retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function listQuestions(
    req,
    res,
    next
) {
    try {
        const questions =
            await wellnessService
                .listQuestions(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Wellness questions retrieved successfully.',
            data: {
                questions,
                total:
                    questions.length
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function submitScan(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateScanSubmission(
            req.body
        );

        throwValidationError(
            'Wellness scan validation failed.',
            errors
        );

        const scan =
            await wellnessService
                .submitScan(
                    req.user.id,
                    data.answers
                );

        return res.status(201).json({
            success: true,
            message:
                'Wellness scan completed successfully.',
            data: {
                scan
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function getLatestScan(
    req,
    res,
    next
) {
    try {
        const scan =
            await wellnessService
                .getLatestScan(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                scan
                    ? 'Latest wellness scan retrieved successfully.'
                    : 'No wellness scan is available.',
            data: {
                scan
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function getScanHistory(
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

        throwValidationError(
            'Wellness scan history query is invalid.',
            errors
        );

        const result =
            await wellnessService
                .getScanHistory(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Wellness scan history retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function getScanById(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id,
                'Wellness scan ID'
            );

        throwValidationError(
            'Wellness scan ID is invalid.',
            idResult.errors
        );

        const scan =
            await wellnessService
                .getScanById(
                    req.user.id,
                    idResult.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Wellness scan retrieved successfully.',
            data: {
                scan
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function getLatestBurnout(
    req,
    res,
    next
) {
    try {
        const assessment =
            await wellnessService
                .getLatestBurnout(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                assessment
                    ? 'Latest burnout assessment retrieved successfully.'
                    : 'No burnout assessment is available.',
            data: {
                assessment
            }
        });
    } catch (error) {
        return next(error);
    }
}

module.exports = {
    submitCheckin,
    getTodayCheckin,
    getCheckinHistory,
    listQuestions,
    submitScan,
    getLatestScan,
    getScanHistory,
    getScanById,
    getLatestBurnout
};
