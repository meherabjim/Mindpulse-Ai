const AppError =
    require('../utils/AppError');

const service =
    require('../services/aiConversation.service');

const {
    validateConversationCreate,
    validateMessage,
    validateConversationStatus,
    validateQuery,
    validatePositiveId
} = require('../validators/ai.validator');


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


function getConversationId(value) {
    const result =
        validatePositiveId(
            value,
            'Conversation ID'
        );

    throwValidation(
        'Conversation ID is invalid.',
        result.errors
    );

    return result.id;
}


async function createConversation(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateConversationCreate(
            req.body
        );

        throwValidation(
            'AI conversation validation failed.',
            errors
        );

        const conversation =
            await service
                .createConversation(
                    req.user.id,
                    data
                );

        return res.status(201).json({
            success: true,

            message:
                'AI conversation created successfully.',

            data: {
                conversation
            }
        });
    } catch (error) {
        return next(error);
    }
}


async function listConversations(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateQuery(
            req.query
        );

        throwValidation(
            'AI conversation query is invalid.',
            errors
        );

        const result =
            await service
                .listConversations(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,

            message:
                'AI conversations retrieved successfully.',

            data: result
        });
    } catch (error) {
        return next(error);
    }
}


async function listMessages(
    req,
    res,
    next
) {
    try {
        const conversationId =
            getConversationId(
                req.params.id
            );

        const {
            errors,
            data
        } = validateQuery(
            req.query
        );

        throwValidation(
            'AI message query is invalid.',
            errors
        );

        const result =
            await service
                .listMessages(
                    req.user.id,
                    conversationId,
                    data
                );

        return res.status(200).json({
            success: true,

            message:
                'AI conversation messages retrieved successfully.',

            data: result
        });
    } catch (error) {
        return next(error);
    }
}


async function updateConversationStatus(
    req,
    res,
    next
) {
    try {
        const conversationId =
            getConversationId(
                req.params.id
            );

        const {
            errors,
            data
        } = validateConversationStatus(
            req.body
        );

        throwValidation(
            'AI conversation status is invalid.',
            errors
        );

        const conversation =
            await service
                .updateConversationStatus(
                    req.user.id,
                    conversationId,
                    data.status
                );

        return res.status(200).json({
            success: true,

            message:
                'AI conversation status updated successfully.',

            data: {
                conversation
            }
        });
    } catch (error) {
        return next(error);
    }
}


async function sendMessage(
    req,
    res,
    next
) {
    try {
        const conversationId =
            getConversationId(
                req.params.id
            );

        const {
            errors,
            data
        } = validateMessage(
            req.body
        );

        throwValidation(
            'AI message validation failed.',
            errors
        );

        const result =
            await service
                .sendMessage(
                    req.user.id,
                    conversationId,
                    data.content
                );

        return res.status(201).json({
            success: true,

            message:
                'AI Coach response generated successfully.',

            data: result
        });
    } catch (error) {
        return next(error);
    }
}


module.exports = {
    createConversation,
    listConversations,
    listMessages,
    updateConversationStatus,
    sendMessage
};