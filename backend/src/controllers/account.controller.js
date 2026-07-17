const AppError = require('../utils/AppError');

const accountService =
    require('../services/account.service');

const {
    validateProfilePatch,
    validateSettingsPatch,
    validateOnboarding,
    validateEmergencyContact,
    validateContactId
} = require('../validators/account.validator');

async function getProfile(req, res, next) {
    try {
        const profile =
            await accountService.getProfile(
                req.user.id
            );

        return res.status(200).json({
            success: true,
            message:
                'Profile retrieved successfully.',
            data: {
                profile
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function updateProfile(req, res, next) {
    try {
        const {
            errors,
            data
        } = validateProfilePatch(req.body);

        if (errors.length > 0) {
            throw new AppError(
                422,
                'Profile validation failed.',
                errors
            );
        }

        const profile =
            await accountService.updateProfile(
                req.user.id,
                data
            );

        return res.status(200).json({
            success: true,
            message:
                'Profile updated successfully.',
            data: {
                profile
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function getOnboardingStatus(
    req,
    res,
    next
) {
    try {
        const onboarding =
            await accountService
                .getOnboardingStatus(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Onboarding status retrieved successfully.',
            data: {
                onboarding
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function completeOnboarding(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateOnboarding(req.body);

        if (errors.length > 0) {
            throw new AppError(
                422,
                'Onboarding validation failed.',
                errors
            );
        }

        const result =
            await accountService
                .completeOnboarding(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Onboarding completed successfully.',
            data: result
        });
    } catch (error) {
        return next(error);
    }
}

async function getSettings(req, res, next) {
    try {
        const settings =
            await accountService.getSettings(
                req.user.id
            );

        return res.status(200).json({
            success: true,
            message:
                'Settings retrieved successfully.',
            data: {
                settings
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function updateSettings(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateSettingsPatch(req.body);

        if (errors.length > 0) {
            throw new AppError(
                422,
                'Settings validation failed.',
                errors
            );
        }

        const settings =
            await accountService
                .updateSettings(
                    req.user.id,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Settings updated successfully.',
            data: {
                settings
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listEmergencyContacts(
    req,
    res,
    next
) {
    try {
        const contacts =
            await accountService
                .listEmergencyContacts(
                    req.user.id
                );

        return res.status(200).json({
            success: true,
            message:
                'Emergency contacts retrieved successfully.',
            data: {
                contacts,
                total: contacts.length
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function createEmergencyContact(
    req,
    res,
    next
) {
    try {
        const {
            errors,
            data
        } = validateEmergencyContact(
            req.body,
            false
        );

        if (errors.length > 0) {
            throw new AppError(
                422,
                'Emergency contact validation failed.',
                errors
            );
        }

        const contact =
            await accountService
                .createEmergencyContact(
                    req.user.id,
                    data
                );

        return res.status(201).json({
            success: true,
            message:
                'Emergency contact created successfully.',
            data: {
                contact
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function updateEmergencyContact(
    req,
    res,
    next
) {
    try {
        const idResult =
            validateContactId(req.params.id);

        if (idResult.errors.length > 0) {
            throw new AppError(
                422,
                'Emergency contact ID is invalid.',
                idResult.errors
            );
        }

        const {
            errors,
            data
        } = validateEmergencyContact(
            req.body,
            true
        );

        if (errors.length > 0) {
            throw new AppError(
                422,
                'Emergency contact validation failed.',
                errors
            );
        }

        const contact =
            await accountService
                .updateEmergencyContact(
                    req.user.id,
                    idResult.contactId,
                    data
                );

        return res.status(200).json({
            success: true,
            message:
                'Emergency contact updated successfully.',
            data: {
                contact
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function deleteEmergencyContact(
    req,
    res,
    next
) {
    try {
        const idResult =
            validateContactId(req.params.id);

        if (idResult.errors.length > 0) {
            throw new AppError(
                422,
                'Emergency contact ID is invalid.',
                idResult.errors
            );
        }

        await accountService
            .deleteEmergencyContact(
                req.user.id,
                idResult.contactId
            );

        return res.status(200).json({
            success: true,
            message:
                'Emergency contact deleted successfully.'
        });
    } catch (error) {
        return next(error);
    }
}

module.exports = {
    getProfile,
    updateProfile,
    getOnboardingStatus,
    completeOnboarding,
    getSettings,
    updateSettings,
    listEmergencyContacts,
    createEmergencyContact,
    updateEmergencyContact,
    deleteEmergencyContact
};
