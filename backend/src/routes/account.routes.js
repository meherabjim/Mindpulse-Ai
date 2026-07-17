const express = require('express');

const accountController =
    require('../controllers/account.controller');

const {
    authenticate
} = require('../middleware/auth.middleware');

const router = express.Router();

router.use(authenticate);

router.get(
    '/profile',
    accountController.getProfile
);

router.patch(
    '/profile',
    accountController.updateProfile
);

router.get(
    '/onboarding/status',
    accountController.getOnboardingStatus
);

router.post(
    '/onboarding/complete',
    accountController.completeOnboarding
);

router.get(
    '/settings',
    accountController.getSettings
);

router.patch(
    '/settings',
    accountController.updateSettings
);

router.get(
    '/emergency-contacts',
    accountController.listEmergencyContacts
);

router.post(
    '/emergency-contacts',
    accountController.createEmergencyContact
);

router.patch(
    '/emergency-contacts/:id',
    accountController.updateEmergencyContact
);

router.delete(
    '/emergency-contacts/:id',
    accountController.deleteEmergencyContact
);

module.exports = router;
