const express = require('express');
const rateLimit = require('express-rate-limit');

const authController =
    require('../controllers/auth.controller');

const {
    authenticate
} = require('../middleware/auth.middleware');

const router = express.Router();

const credentialLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 30,
    standardHeaders: 'draft-7',
    legacyHeaders: false,

    message: {
        success: false,
        message:
            'Too many authentication requests. Please try again later.'
    }
});

router.post(
    '/register',
    credentialLimiter,
    authController.register
);

router.post(
    '/login',
    credentialLimiter,
    authController.login
);

router.post(
    '/refresh',
    credentialLimiter,
    authController.refresh
);

router.post(
    '/logout',
    authController.logout
);

router.post(
    '/logout-all',
    authenticate,
    authController.logoutAll
);

router.get(
    '/me',
    authenticate,
    authController.me
);

module.exports = router;
