const express = require('express');

const recoveryController =
    require('../controllers/recovery.controller');

const {
    authenticate
} = require('../middleware/auth.middleware');

const router = express.Router();

router.use(authenticate);

router.get(
    '/recovery/activities',
    recoveryController.listActivities
);

router.post(
    '/recovery/activities/:id/logs',
    recoveryController.saveActivityLog
);

router.get(
    '/recovery/activity-logs',
    recoveryController.listActivityLogs
);

router.get(
    '/recovery/plans/active',
    recoveryController.getActivePlan
);

router.get(
    '/recovery/plans',
    recoveryController.listPlans
);

router.post(
    '/recovery/plans',
    recoveryController.createPlan
);

router.get(
    '/recovery/plans/:id',
    recoveryController.getPlan
);

router.patch(
    '/recovery/plans/:id/status',
    recoveryController.updatePlanStatus
);

router.patch(
    '/recovery/tasks/:id',
    recoveryController.updateTask
);

router.get(
    '/recovery/progress',
    recoveryController.listProgress
);

router.post(
    '/recovery/progress',
    recoveryController.saveProgress
);

module.exports = router;
