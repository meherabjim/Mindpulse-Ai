const express = require('express');

const wellnessController =
    require('../controllers/wellness.controller');

const {
    authenticate
} = require('../middleware/auth.middleware');

const router = express.Router();

router.use(authenticate);

router.post(
    '/checkins',
    wellnessController.submitCheckin
);

router.get(
    '/checkins/today',
    wellnessController.getTodayCheckin
);

router.get(
    '/checkins/history',
    wellnessController.getCheckinHistory
);

router.get(
    '/wellness/questions',
    wellnessController.listQuestions
);

router.post(
    '/wellness/scans',
    wellnessController.submitScan
);

router.get(
    '/wellness/scans/latest',
    wellnessController.getLatestScan
);

router.get(
    '/wellness/scans/history',
    wellnessController.getScanHistory
);

router.get(
    '/wellness/scans/:id',
    wellnessController.getScanById
);

router.get(
    '/burnout/latest',
    wellnessController.getLatestBurnout
);

module.exports = router;
