const express = require('express');

const engagementController =
    require('../controllers/engagement.controller');

const {
    authenticate
} = require('../middleware/auth.middleware');

const router = express.Router();

router.use(authenticate);

router.post(
    '/achievements/sync',
    engagementController.syncAchievements
);

router.get(
    '/achievements',
    engagementController.getAchievements
);

router.get(
    '/notifications/unread-count',
    engagementController.getUnreadCount
);

router.patch(
    '/notifications/read-all',
    engagementController.markAllRead
);

router.get(
    '/notifications',
    engagementController.listNotifications
);

router.patch(
    '/notifications/:id/read',
    engagementController.markNotificationRead
);

router.delete(
    '/notifications/:id',
    engagementController.deleteNotification
);

router.post(
    '/devices',
    engagementController.registerDevice
);

router.delete(
    '/devices/:id',
    engagementController.unregisterDevice
);

router.post(
    '/reports/generate',
    engagementController.generateReport
);

router.get(
    '/reports',
    engagementController.listReports
);

router.get(
    '/reports/:id',
    engagementController.getReport
);

module.exports = router;
