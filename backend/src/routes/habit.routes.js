const express = require('express');

const habitController =
    require('../controllers/habit.controller');

const {
    authenticate
} = require('../middleware/auth.middleware');

const router = express.Router();

router.use(authenticate);

router.get(
    '/habit-templates',
    habitController.listTemplates
);

router.get(
    '/habits/today',
    habitController.listTodayHabits
);

router.get(
    '/habits',
    habitController.listHabits
);

router.post(
    '/habits',
    habitController.createHabit
);

router.get(
    '/habits/:id/logs',
    habitController.getHabitLogs
);

router.post(
    '/habits/:id/logs',
    habitController.saveHabitLog
);

router.get(
    '/habits/:id',
    habitController.getHabit
);

router.patch(
    '/habits/:id',
    habitController.updateHabit
);

router.delete(
    '/habits/:id',
    habitController.archiveHabit
);

module.exports = router;
