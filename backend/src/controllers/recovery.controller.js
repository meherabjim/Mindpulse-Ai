const AppError = require('../utils/AppError');

const recoveryService =
    require('../services/recovery.service');

const {
    validateActivityLog,
    validatePlanCreate,
    validatePlanStatus,
    validateTaskUpdate,
    validateProgress,
    validateHistoryQuery,
    validatePositiveId
} = require('../validators/recovery.validator');

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

async function listActivities(
    req,
    res,
    next
) {
    try {
        const activities =
            await recoveryService
                .listActivities(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Recovery activities retrieved successfully.',
            data: {
                activities,
                total:
                    activities.length
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function saveActivityLog(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id,
                'Recovery activity ID'
            );

        throwValidation(
            'Recovery activity ID is invalid.',
            idResult.errors
        );

        const {
            errors,
            data
        } = validateActivityLog(
            req.body
        );

        throwValidation(
            'Recovery activity log validation failed.',
            errors
        );

        const log =
            await recoveryService
                .saveActivityLog(
                    req.user.id,
                    idResult.id,
                    data
                );

        return res.status(201).json({
            success: true,
            message:
                'Recovery activity log saved successfully.',
            data: {
                log
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listActivityLogs(
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
            'Activity log query is invalid.',
            errors
        );

        const result =
            await recoveryService
                .listActivityLogs(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Recovery activity logs retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function createPlan(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validatePlanCreate(
            req.body
        );

        throwValidation(
            'Recovery plan validation failed.',
            errors
        );

        const plan =
            await recoveryService
                .createPlan(
                    req.user.id,
                    data
                );

        return res.status(201).json({
            success: true,
            message:
                'Recovery plan created successfully.',
            data: {
                plan
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listPlans(req, res, next) {
    try {
        const plans =
            await recoveryService.listPlans(
                req.user.id
            );

        return res.status(200).json({
            success: true,
            message:
                'Recovery plans retrieved successfully.',
            data: {
                plans,
                total: plans.length
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function getActivePlan(
    req,
    res,
    next
) {
    try {
        const plan =
            await recoveryService
                .getActivePlan(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                plan
                    ? 'Active recovery plan retrieved successfully.'
                    : 'No active recovery plan is available.',
            data: {
                plan
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function getPlan(req, res, next) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'Recovery plan ID'
            );

        throwValidation(
            'Recovery plan ID is invalid.',
            result.errors
        );

        const plan =
            await recoveryService
                .getPlanById(
                    req.user.id,
                    result.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Recovery plan retrieved successfully.',
            data: {
                plan
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function updatePlanStatus(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id,
                'Recovery plan ID'
            );

        throwValidation(
            'Recovery plan ID is invalid.',
            idResult.errors
        );

        const {
            errors,
            data
        } = validatePlanStatus(
            req.body
        );

        throwValidation(
            'Recovery plan status is invalid.',
            errors
        );

        const plan =
            await recoveryService
                .updatePlanStatus(
                    req.user.id,
                    idResult.id,
                    data.status
                );

        return res.status(200).json({
            success: true,
            message:
                'Recovery plan status updated successfully.',
            data: {
                plan
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function updateTask(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id,
                'Recovery task ID'
            );

        throwValidation(
            'Recovery task ID is invalid.',
            idResult.errors
        );

        const {
            errors,
            data
        } = validateTaskUpdate(
            req.body
        );

        throwValidation(
            'Recovery task validation failed.',
            errors
        );

        const task =
            await recoveryService
                .updateTask(
                    req.user.id,
                    idResult.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Recovery task updated successfully.',
            data: {
                task
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function saveProgress(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateProgress(
            req.body
        );

        throwValidation(
            'Recovery progress validation failed.',
            errors
        );

        const progress =
            await recoveryService
                .saveProgress(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Recovery progress saved successfully.',
            data: {
                progress
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listProgress(
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
            'Recovery progress query is invalid.',
            errors
        );

        const result =
            await recoveryService
                .listProgress(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Recovery progress retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

module.exports = {
    listActivities,
    saveActivityLog,
    listActivityLogs,
    createPlan,
    listPlans,
    getActivePlan,
    getPlan,
    updatePlanStatus,
    updateTask,
    saveProgress,
    listProgress
};
