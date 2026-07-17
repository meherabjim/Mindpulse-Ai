const AppError =
    require('../utils/AppError');

const achievementService =
    require('../services/achievement.service');

const notificationService =
    require('../services/notification.service');

const reportService =
    require('../services/report.service');

const {
    validatePositiveId,
    validatePagination,
    validateDeviceToken,
    validateReportRequest
} = require('../validators/engagement.validator');

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

async function syncAchievements(
    req,
    res,
    next
) {
    try {
        const result =
            await achievementService
                .syncAchievements(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Achievements synchronized successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function getAchievements(
    req,
    res,
    next
) {
    try {
        const result =
            await achievementService
                .getAchievementSummary(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Achievement summary retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function listNotifications(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validatePagination(
            req.query
        );

        throwValidation(
            'Notification query is invalid.',
            errors
        );

        const result =
            await notificationService
                .listNotifications(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Notifications retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function getUnreadCount(
    req,
    res,
    next
) {
    try {
        const unreadCount =
            await notificationService
                .getUnreadCount(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Unread notification count retrieved successfully.',
            data: {
                unread_count:
                    unreadCount
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function markNotificationRead(
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

        await notificationService
            .markRead(
                req.user.id,
                result.id
            );

        return res.status(200).json({
            success: true,
            message:
                'Notification marked as read.'
        });
    } catch (error) {
        return next(error);
    }
}

async function markAllRead(
    req,
    res,
    next
) {
    try {
        const updatedCount =
            await notificationService
                .markAllRead(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                'All notifications marked as read.',
            data: {
                updated_count:
                    updatedCount
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function deleteNotification(
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

        await notificationService
            .cancelNotification(
                req.user.id,
                result.id
            );

        return res.status(200).json({
            success: true,
            message:
                'Notification removed successfully.'
        });
    } catch (error) {
        return next(error);
    }
}

async function registerDevice(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateDeviceToken(
            req.body
        );

        throwValidation(
            'Device token validation failed.',
            errors
        );

        const device =
            await notificationService
                .registerDevice(
                    req.user.id,
                    data
                );

        return res.status(201).json({
            success: true,
            message:
                'Device token registered successfully.',
            data: {
                device
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function unregisterDevice(
    req,
    res,
    next
) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'Device ID'
            );

        throwValidation(
            'Device ID is invalid.',
            result.errors
        );

        await notificationService
            .unregisterDevice(
                req.user.id,
                result.id
            );

        return res.status(200).json({
            success: true,
            message:
                'Device token unregistered successfully.'
        });
    } catch (error) {
        return next(error);
    }
}

async function generateReport(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateReportRequest(
            req.body
        );

        throwValidation(
            'Report validation failed.',
            errors
        );

        const report =
            await reportService
                .generateReport(
                    req.user.id,
                    data
                );

        return res.status(201).json({
            success: true,
            message:
                'Wellness report generated successfully.',
            data: {
                report
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listReports(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validatePagination(
            req.query
        );

        throwValidation(
            'Report query is invalid.',
            errors
        );

        const result =
            await reportService
                .listReports(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Reports retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function getReport(
    req,
    res,
    next
) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'Report ID'
            );

        throwValidation(
            'Report ID is invalid.',
            result.errors
        );

        const report =
            await reportService
                .getReportById(
                    req.user.id,
                    result.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Report retrieved successfully.',
            data: {
                report
            }
        });
    } catch (error) {
        return next(error);
    }
}

module.exports = {
    syncAchievements,
    getAchievements,
    listNotifications,
    getUnreadCount,
    markNotificationRead,
    markAllRead,
    deleteNotification,
    registerDevice,
    unregisterDevice,
    generateReport,
    listReports,
    getReport
};
