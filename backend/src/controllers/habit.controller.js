const AppError = require('../utils/AppError');

const habitService =
    require('../services/habit.service');

const {
    validateHabitCreate,
    validateHabitUpdate,
    validateHabitLog,
    validateHabitHistoryQuery,
    validatePositiveId
} = require('../validators/habit.validator');

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

async function listTemplates(
    req,
    res,
    next
) {
    try {
        const templates =
            await habitService
                .listTemplates(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Habit templates retrieved successfully.',
            data: {
                templates,
                total:
                    templates.length
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function createHabit(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateHabitCreate(
            req.body
        );

        throwValidation(
            'Habit validation failed.',
            errors
        );

        const habit =
            await habitService
                .createHabit(
                    req.user.id,
                    data
                );

        return res.status(201).json({
            success: true,
            message:
                'Habit created successfully.',
            data: {
                habit
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listHabits(
    req,
    res,
    next
) {
    try {
        const habits =
            await habitService.listHabits(
                req.user.id
            );

        return res.status(200).json({
            success: true,
            message:
                'Habits retrieved successfully.',
            data: {
                habits,
                total: habits.length
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listTodayHabits(
    req,
    res,
    next
) {
    try {
        const result =
            await habitService
                .listTodayHabits(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Today’s habits retrieved successfully.',
            data: {
                ...result,
                total:
                    result.habits.length
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function getHabit(
    req,
    res,
    next
) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'Habit ID'
            );

        throwValidation(
            'Habit ID is invalid.',
            result.errors
        );

        const habit =
            await habitService
                .getHabitById(
                    req.user.id,
                    result.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Habit retrieved successfully.',
            data: {
                habit
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function updateHabit(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id,
                'Habit ID'
            );

        throwValidation(
            'Habit ID is invalid.',
            idResult.errors
        );

        const {
            errors,
            data
        } = validateHabitUpdate(
            req.body
        );

        throwValidation(
            'Habit validation failed.',
            errors
        );

        const habit =
            await habitService
                .updateHabit(
                    req.user.id,
                    idResult.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Habit updated successfully.',
            data: {
                habit
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function saveHabitLog(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id,
                'Habit ID'
            );

        throwValidation(
            'Habit ID is invalid.',
            idResult.errors
        );

        const {
            errors,
            data
        } = validateHabitLog(
            req.body
        );

        throwValidation(
            'Habit log validation failed.',
            errors
        );

        const log =
            await habitService
                .saveHabitLog(
                    req.user.id,
                    idResult.id,
                    data
                );

        const habit =
            await habitService
                .getHabitById(
                    req.user.id,
                    idResult.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Habit log saved successfully.',
            data: {
                log,
                habit
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function getHabitLogs(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id,
                'Habit ID'
            );

        throwValidation(
            'Habit ID is invalid.',
            idResult.errors
        );

        const {
            errors,
            data
        } = validateHabitHistoryQuery(
            req.query
        );

        throwValidation(
            'Habit log query is invalid.',
            errors
        );

        const result =
            await habitService
                .getHabitLogs(
                    req.user.id,
                    idResult.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Habit logs retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function archiveHabit(
    req,
    res,
    next
) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'Habit ID'
            );

        throwValidation(
            'Habit ID is invalid.',
            result.errors
        );

        await habitService.archiveHabit(
            req.user.id,
            result.id
        );

        return res.status(200).json({
            success: true,
            message:
                'Habit archived successfully.'
        });
    } catch (error) {
        return next(error);
    }
}

module.exports = {
    listTemplates,
    createHabit,
    listHabits,
    listTodayHabits,
    getHabit,
    updateHabit,
    saveHabitLog,
    getHabitLogs,
    archiveHabit
};
