const AppError =
    require('../utils/AppError');

const fcmService =
    require('../services/fcm.service');

const {
    validatePositiveId,
    validateTestPayload
} = require('../validators/fcm.validator');

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

async function getStatus(
    req,
    res,
    next
) {
    try {
        const status =
            fcmService
                .getFirebaseStatus();

        return res.status(200).json({
            success: true,

            message:
                'FCM status retrieved successfully.',

            data: {
                status
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function sendTest(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateTestPayload(
            req.body
        );

        throwValidation(
            'FCM test validation failed.',
            errors
        );

        const result =
            await fcmService
                .createAndSendTest(
                    req.admin.id,
                    data
                );

        return res.status(201).json({
            success: true,

            message:
                result.delivery.simulated
                    ? 'FCM test simulated successfully.'
                    : 'FCM notification processed successfully.',

            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function sendExisting(
    req,
    res,
    next
) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'Notification ID'
            );

        throwValidation(
            'Notification ID is invalid.',
            result.errors
        );

        const delivery =
            await fcmService
                .sendNotification(
                    result.id,
                    {
                        respectQuietHours:
                            true
                    }
                );

        return res.status(200).json({
            success: true,

            message:
                delivery.simulated
                    ? 'FCM delivery simulated successfully.'
                    : 'FCM delivery processed successfully.',

            data: {
                delivery
            }
        });
    } catch (error) {
        return next(error);
    }
}

module.exports = {
    getStatus,
    sendTest,
    sendExisting
};
