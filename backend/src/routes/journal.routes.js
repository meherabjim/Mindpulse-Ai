const express = require('express');

const journalController =
    require('../controllers/journal.controller');

const {
    authenticate
} = require('../middleware/auth.middleware');

const router = express.Router();

router.use(authenticate);

router.get(
    '/journals/tags',
    journalController.listTags
);

router.post(
    '/journals/tags',
    journalController.createTag
);

router.get(
    '/journals',
    journalController.listJournals
);

router.post(
    '/journals',
    journalController.createJournal
);

router.get(
    '/journals/:id',
    journalController.getJournal
);

router.patch(
    '/journals/:id',
    journalController.updateJournal
);

router.delete(
    '/journals/:id',
    journalController.deleteJournal
);

module.exports = router;
