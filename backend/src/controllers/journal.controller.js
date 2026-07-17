const AppError = require('../utils/AppError');

const journalService =
    require('../services/journal.service');

const {
    validateJournalCreate,
    validateJournalUpdate,
    validateJournalQuery,
    validateTagCreate,
    validatePositiveId
} = require('../validators/journal.validator');

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

async function createJournal(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateJournalCreate(
            req.body
        );

        throwValidation(
            'Journal validation failed.',
            errors
        );

        const journal =
            await journalService
                .createJournal(
                    req.user.id,
                    data
                );

        return res.status(201).json({
            success: true,
            message:
                'Journal entry created successfully.',
            data: {
                journal
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listJournals(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateJournalQuery(
            req.query
        );

        throwValidation(
            'Journal query is invalid.',
            errors
        );

        const result =
            await journalService
                .listJournals(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Journal entries retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function getJournal(
    req,
    res,
    next
) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'Journal ID'
            );

        throwValidation(
            'Journal ID is invalid.',
            result.errors
        );

        const journal =
            await journalService
                .getJournalById(
                    req.user.id,
                    result.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Journal entry retrieved successfully.',
            data: {
                journal
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function updateJournal(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id,
                'Journal ID'
            );

        throwValidation(
            'Journal ID is invalid.',
            idResult.errors
        );

        const {
            errors,
            data
        } = validateJournalUpdate(
            req.body
        );

        throwValidation(
            'Journal validation failed.',
            errors
        );

        const journal =
            await journalService
                .updateJournal(
                    req.user.id,
                    idResult.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Journal entry updated successfully.',
            data: {
                journal
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function deleteJournal(
    req,
    res,
    next
) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'Journal ID'
            );

        throwValidation(
            'Journal ID is invalid.',
            result.errors
        );

        await journalService
            .deleteJournal(
                req.user.id,
                result.id
            );

        return res.status(200).json({
            success: true,
            message:
                'Journal entry deleted successfully.'
        });
    } catch (error) {
        return next(error);
    }
}

async function listTags(req, res, next) {
    try {
        const tags =
            await journalService.listTags(
                req.user.id
            );

        return res.status(200).json({
            success: true,
            message:
                'Journal tags retrieved successfully.',
            data: {
                tags,
                total: tags.length
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function createTag(req, res, next) {
    try {
        const {
            errors,
            data
        } = validateTagCreate(req.body);

        throwValidation(
            'Journal tag validation failed.',
            errors
        );

        const tag =
            await journalService.createTag(
                req.user.id,
                data.name
            );

        return res.status(201).json({
            success: true,
            message:
                'Journal tag created successfully.',
            data: {
                tag
            }
        });
    } catch (error) {
        return next(error);
    }
}

module.exports = {
    createJournal,
    listJournals,
    getJournal,
    updateJournal,
    deleteJournal,
    listTags,
    createTag
};
