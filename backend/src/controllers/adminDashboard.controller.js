const AppError =
    require('../utils/AppError');

const adminDashboardService =
    require('../services/adminDashboard.service');

const {
    validatePositiveId,
    validateTrendQuery,
    validateUserListQuery,
    validateUserStatus,
    validateSafetyListQuery,
    validateSafetyReview,
    validateReportListQuery,
    validateAnnouncement,
    validateAuditLogQuery,
    validateSystemLogQuery
} = require('../validators/adminDashboard.validator');

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

async function getSummary(
    req,
    res,
    next
) {
    try {
        const summary =
            await adminDashboardService
                .getDashboardSummary();

        return res.status(200).json({
            success: true,
            message:
                'Admin dashboard summary retrieved successfully.',
            data: {
                summary
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function getTrends(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateTrendQuery(
            req.query
        );

        throwValidation(
            'Dashboard trend query is invalid.',
            errors
        );

        const result =
            await adminDashboardService
                .getDashboardTrends(
                    data.days
                );

        return res.status(200).json({
            success: true,
            message:
                'Admin dashboard trends retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function listUsers(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateUserListQuery(
            req.query
        );

        throwValidation(
            'Admin user query is invalid.',
            errors
        );

        const result =
            await adminDashboardService
                .listUsers(data);

        return res.status(200).json({
            success: true,
            message:
                'Users retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function getUser(
    req,
    res,
    next
) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'User ID'
            );

        throwValidation(
            'User ID is invalid.',
            result.errors
        );

        const user =
            await adminDashboardService
                .getUserById(
                    result.id
                );

        return res.status(200).json({
            success: true,
            message:
                'User details retrieved successfully.',
            data: {
                user
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function updateUserStatus(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id,
                'User ID'
            );

        throwValidation(
            'User ID is invalid.',
            idResult.errors
        );

        const {
            errors,
            data
        } = validateUserStatus(
            req.body
        );

        throwValidation(
            'User status validation failed.',
            errors
        );

        const user =
            await adminDashboardService
                .updateUserStatus(
                    req.admin.id,
                    idResult.id,
                    data,
                    getContext(req)
                );

        return res.status(200).json({
            success: true,
            message:
                'User account status updated successfully.',
            data: {
                user
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listSafetyEvents(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateSafetyListQuery(
            req.query
        );

        throwValidation(
            'Safety event query is invalid.',
            errors
        );

        const result =
            await adminDashboardService
                .listSafetyEvents(data);

        return res.status(200).json({
            success: true,
            message:
                'Safety events retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function getSafetyEvent(
    req,
    res,
    next
) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'Safety event ID'
            );

        throwValidation(
            'Safety event ID is invalid.',
            result.errors
        );

        const event =
            await adminDashboardService
                .getSafetyEventById(
                    result.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Safety event retrieved successfully.',
            data: {
                event
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function reviewSafetyEvent(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id,
                'Safety event ID'
            );

        throwValidation(
            'Safety event ID is invalid.',
            idResult.errors
        );

        const {
            errors,
            data
        } = validateSafetyReview(
            req.body
        );

        throwValidation(
            'Safety review validation failed.',
            errors
        );

        const event =
            await adminDashboardService
                .reviewSafetyEvent(
                    req.admin.id,
                    idResult.id,
                    data,
                    getContext(req)
                );

        return res.status(200).json({
            success: true,
            message:
                'Safety event review updated successfully.',
            data: {
                event
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
        } = validateReportListQuery(
            req.query
        );

        throwValidation(
            'Admin report query is invalid.',
            errors
        );

        const result =
            await adminDashboardService
                .listReports(data);

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
            await adminDashboardService
                .getReportById(
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

async function createAnnouncement(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateAnnouncement(
            req.body
        );

        throwValidation(
            'Announcement validation failed.',
            errors
        );

        const announcement =
            await adminDashboardService
                .createAnnouncement(
                    req.admin.id,
                    data,
                    getContext(req)
                );

        return res.status(201).json({
            success: true,
            message:
                'Announcement created successfully.',
            data: {
                announcement
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listAuditLogs(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateAuditLogQuery(
            req.query
        );

        throwValidation(
            'Audit log query is invalid.',
            errors
        );

        const result =
            await adminDashboardService
                .listAuditLogs(data);

        return res.status(200).json({
            success: true,
            message:
                'Audit logs retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function listSystemLogs(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateSystemLogQuery(
            req.query
        );

        throwValidation(
            'System log query is invalid.',
            errors
        );

        const result =
            await adminDashboardService
                .listSystemLogs(data);

        return res.status(200).json({
            success: true,
            message:
                'System logs retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

module.exports = {
    getSummary,
    getTrends,
    listUsers,
    getUser,
    updateUserStatus,
    listSafetyEvents,
    getSafetyEvent,
    reviewSafetyEvent,
    listReports,
    getReport,
    createAnnouncement,
    listAuditLogs,
    listSystemLogs
};
