const express = require('express');

const adminDashboardController =
    require('../controllers/adminDashboard.controller');

const {
    authenticateAdmin,
    authorizeAdminRoles
} = require('../middleware/adminAuth.middleware');

const router = express.Router();

router.use('/admin', authenticateAdmin);

router.get(
    '/admin/dashboard/summary',
    adminDashboardController.getSummary
);

router.get(
    '/admin/dashboard/trends',
    adminDashboardController.getTrends
);

router.get(
    '/admin/users',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'analyst'
    ),
    adminDashboardController.listUsers
);

router.get(
    '/admin/users/:id',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'analyst'
    ),
    adminDashboardController.getUser
);

router.patch(
    '/admin/users/:id/status',
    authorizeAdminRoles(
        'super_admin',
        'admin'
    ),
    adminDashboardController
        .updateUserStatus
);

router.get(
    '/admin/safety-events',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'analyst'
    ),
    adminDashboardController
        .listSafetyEvents
);

router.get(
    '/admin/safety-events/:id',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'analyst'
    ),
    adminDashboardController
        .getSafetyEvent
);

router.patch(
    '/admin/safety-events/:id/review',
    authorizeAdminRoles(
        'super_admin',
        'admin'
    ),
    adminDashboardController
        .reviewSafetyEvent
);

router.get(
    '/admin/reports',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'analyst'
    ),
    adminDashboardController.listReports
);

router.get(
    '/admin/reports/:id',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'analyst'
    ),
    adminDashboardController.getReport
);

router.post(
    '/admin/announcements',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'content_manager'
    ),
    adminDashboardController
        .createAnnouncement
);

router.get(
    '/admin/audit-logs',
    authorizeAdminRoles(
        'super_admin',
        'admin'
    ),
    adminDashboardController
        .listAuditLogs
);

router.get(
    '/admin/system-logs',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'analyst'
    ),
    adminDashboardController
        .listSystemLogs
);

module.exports = router;
