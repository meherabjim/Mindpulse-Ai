const express = require('express');

const controller =
    require('../controllers/adminContent.controller');

const {
    authenticateAdmin,
    authorizeAdminRoles
} = require('../middleware/adminAuth.middleware');

const router = express.Router();

/*
Public routes
*/
router.get(
    '/public/contents',
    controller.listPublicContents
);

router.get(
    '/public/contents/:contentKey',
    controller.getPublicContent
);

router.get(
    '/public/support-resources',
    controller.listPublicSupportResources
);

/*
Protected admin routes
*/
router.use('/admin', authenticateAdmin);

router.get(
    '/admin/contents',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'content_manager',
        'analyst'
    ),
    controller.listContents
);

router.get(
    '/admin/contents/:id',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'content_manager',
        'analyst'
    ),
    controller.getContent
);

router.post(
    '/admin/contents',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'content_manager'
    ),
    controller.createContent
);

router.patch(
    '/admin/contents/:id',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'content_manager'
    ),
    controller.updateContent
);

router.get(
    '/admin/support-resources',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'content_manager',
        'analyst'
    ),
    controller.listSupportResources
);

router.get(
    '/admin/support-resources/:id',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'content_manager',
        'analyst'
    ),
    controller.getSupportResource
);

router.post(
    '/admin/support-resources',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'content_manager'
    ),
    controller.createSupportResource
);

router.patch(
    '/admin/support-resources/:id',
    authorizeAdminRoles(
        'super_admin',
        'admin',
        'content_manager'
    ),
    controller.updateSupportResource
);

module.exports = router;
