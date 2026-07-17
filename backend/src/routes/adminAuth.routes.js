const express = require('express');

const adminAuthController =
    require('../controllers/adminAuth.controller');

const {
    authenticateAdmin
} = require('../middleware/adminAuth.middleware');

const router = express.Router();

router.post(
    '/admin/auth/login',
    adminAuthController.login
);

router.post(
    '/admin/auth/refresh',
    adminAuthController.refresh
);

router.post(
    '/admin/auth/logout',
    adminAuthController.logout
);

router.get(
    '/admin/auth/me',
    authenticateAdmin,
    adminAuthController.me
);

router.post(
    '/admin/auth/logout-all',
    authenticateAdmin,
    adminAuthController.logoutAll
);

module.exports = router;
