const express =
    require('express');

const reportPdfController =
    require('../controllers/reportPdf.controller');

const {
    authenticate
} = require('../middleware/auth.middleware');

const router =
    express.Router();

router.post(
    '/reports/:id/pdf',
    authenticate,
    reportPdfController.generatePdf
);

router.get(
    '/reports/:id/files',
    authenticate,
    reportPdfController.listFiles
);

router.get(
    '/reports/:reportId/files/:fileId/download',
    authenticate,
    reportPdfController.downloadFile
);

module.exports = router;
