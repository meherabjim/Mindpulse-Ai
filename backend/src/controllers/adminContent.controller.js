const AppError =
    require('../utils/AppError');

const service =
    require('../services/adminContent.service');

const {
    validatePositiveId,
    validateContentListQuery,
    validateContentPayload,
    validateSupportListQuery,
    validateSupportPayload
} = require('../validators/adminContent.validator');

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

async function listContents(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateContentListQuery(
            req.query
        );

        throwValidation(
            'Content query is invalid.',
            errors
        );

        const result =
            await service.listContents(
                data
            );

        return res.status(200).json({
            success: true,
            message:
                'App contents retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function getContent(
    req,
    res,
    next
) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'Content ID'
            );

        throwValidation(
            'Content ID is invalid.',
            result.errors
        );

        const content =
            await service.getContentById(
                result.id
            );

        return res.status(200).json({
            success: true,
            message:
                'App content retrieved successfully.',
            data: {
                content
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function createContent(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateContentPayload(
            req.body,
            false
        );

        throwValidation(
            'App content validation failed.',
            errors
        );

        const content =
            await service.createContent(
                req.admin.id,
                data,
                getContext(req)
            );

        return res.status(201).json({
            success: true,
            message:
                'App content created successfully.',
            data: {
                content
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function updateContent(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id,
                'Content ID'
            );

        throwValidation(
            'Content ID is invalid.',
            idResult.errors
        );

        const {
            errors,
            data
        } = validateContentPayload(
            req.body,
            true
        );

        throwValidation(
            'App content validation failed.',
            errors
        );

        const content =
            await service.updateContent(
                req.admin.id,
                idResult.id,
                data,
                getContext(req)
            );

        return res.status(200).json({
            success: true,
            message:
                'App content updated successfully.',
            data: {
                content
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listPublicContents(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateContentListQuery({
            ...req.query,
            page: 1,
            limit: 100,
            is_active: true
        });

        throwValidation(
            'Public content query is invalid.',
            errors
        );

        const contents =
            await service
                .listPublicContents(data);

        return res.status(200).json({
            success: true,
            message:
                'Published app contents retrieved successfully.',
            data: {
                contents
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function getPublicContent(
    req,
    res,
    next
) {
    try {
        const contentKey =
            String(
                req.params.contentKey ||
                ''
            ).trim();

        const languageCode =
            typeof req.query.language_code ===
                'string'
                ? req.query.language_code
                    .trim()
                    .toLowerCase()
                : 'en';

        if (
            !contentKey ||
            contentKey.length > 150
        ) {
            throw new AppError(
                422,
                'Content key is invalid.'
            );
        }

        const content =
            await service.getPublicContent(
                contentKey,
                languageCode
            );

        return res.status(200).json({
            success: true,
            message:
                'Published app content retrieved successfully.',
            data: {
                content
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listSupportResources(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateSupportListQuery(
            req.query
        );

        throwValidation(
            'Support-resource query is invalid.',
            errors
        );

        const result =
            await service
                .listSupportResources(
                    data,
                    false
                );

        return res.status(200).json({
            success: true,
            message:
                'Support resources retrieved successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function getSupportResource(
    req,
    res,
    next
) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'Support resource ID'
            );

        throwValidation(
            'Support resource ID is invalid.',
            result.errors
        );

        const resource =
            await service
                .getSupportResourceById(
                    result.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Support resource retrieved successfully.',
            data: {
                resource
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function createSupportResource(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateSupportPayload(
            req.body,
            false
        );

        throwValidation(
            'Support-resource validation failed.',
            errors
        );

        const resource =
            await service
                .createSupportResource(
                    req.admin.id,
                    data,
                    getContext(req)
                );

        return res.status(201).json({
            success: true,
            message:
                'Support resource created successfully.',
            data: {
                resource
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function updateSupportResource(
    req,
    res,
    next
) {
    try {
        const idResult =
            validatePositiveId(
                req.params.id,
                'Support resource ID'
            );

        throwValidation(
            'Support resource ID is invalid.',
            idResult.errors
        );

        const {
            errors,
            data
        } = validateSupportPayload(
            req.body,
            true
        );

        throwValidation(
            'Support-resource validation failed.',
            errors
        );

        const resource =
            await service
                .updateSupportResource(
                    req.admin.id,
                    idResult.id,
                    data,
                    getContext(req)
                );

        return res.status(200).json({
            success: true,
            message:
                'Support resource updated successfully.',
            data: {
                resource
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listPublicSupportResources(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateSupportListQuery({
            ...req.query,
            page: 1,
            limit: 100,
            is_active: true
        });

        throwValidation(
            'Public support-resource query is invalid.',
            errors
        );

        const resources =
            await service
                .listSupportResources(
                    data,
                    true
                );

        return res.status(200).json({
            success: true,
            message:
                'Public support resources retrieved successfully.',
            data: {
                resources
            }
        });
    } catch (error) {
        return next(error);
    }
}

module.exports = {
    listContents,
    getContent,
    createContent,
    updateContent,
    listPublicContents,
    getPublicContent,
    listSupportResources,
    getSupportResource,
    createSupportResource,
    updateSupportResource,
    listPublicSupportResources
};
