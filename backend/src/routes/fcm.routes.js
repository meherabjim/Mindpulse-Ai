const express =
    require('express');

const fcmController =
    require('../controllers/fcm.controller');

const {
    authenticateAdmin,
    authorizeAdminRoles
} = require('../middleware/adminAuth.middleware');

const router =
    express.Router();

router.get(
    '/admin/fcm/status',
    authenticateAdmin,

    authorizeAdminRoles(
        'super_admin',
        'admin',
        'analyst'
    ),

    fcmController.getStatus
);

router.post(
    '/admin/fcm/test',
    authenticateAdmin,

    authorizeAdminRoles(
        'super_admin',
        'admin'
    ),

    fcmController.sendTest
);

router.post(
    '/admin/fcm/notifications/:id/send',
    authenticateAdmin,

    authorizeAdminRoles(
        'super_admin',
        'admin'
    ),

    fcmController.sendExisting
);

module.exports = router;
