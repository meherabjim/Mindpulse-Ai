const AppError =
    require('../utils/AppError');

const reportPdfService =
    require('../services/reportPdf.service');

const {
    validatePositiveId
} = require('../validators/reportPdf.validator');

function throwValidation(
    message,
    errors
) {
    if (errors.length > 0) {
        throw new AppError(
            422,
            message,
            errors
        );
    }
}

async function generatePdf(
    req,
    res,
    next
) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'Report ID'
            );

        throwValidation(
            'Report ID is invalid.',
            result.errors
        );

        const file =
            await reportPdfService
                .generatePdf(
                    req.user.id,
                    result.id
                );

        return res.status(201).json({
            success: true,

            message:
                'Wellness report PDF generated successfully.',

            data: {
                file
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function listFiles(
    req,
    res,
    next
) {
    try {
        const result =
            validatePositiveId(
                req.params.id,
                'Report ID'
            );

        throwValidation(
            'Report ID is invalid.',
            result.errors
        );

        const files =
            await reportPdfService
                .listReportFiles(
                    req.user.id,
                    result.id
                );

        return res.status(200).json({
            success: true,

            message:
                'Report PDF files retrieved successfully.',

            data: {
                files
            }
        });
    } catch (error) {
        return next(error);
    }
}

async function downloadFile(
    req,
    res,
    next
) {
    try {
        const reportResult =
            validatePositiveId(
                req.params.reportId,
                'Report ID'
            );

        throwValidation(
            'Report ID is invalid.',
            reportResult.errors
        );

        const fileResult =
            validatePositiveId(
                req.params.fileId,
                'Report file ID'
            );

        throwValidation(
            'Report file ID is invalid.',
            fileResult.errors
        );

        const file =
            await reportPdfService
                .getReportFile(
                    req.user.id,
                    reportResult.id,
                    fileResult.id
                );

        res.setHeader(
            'Content-Type',
            'application/pdf'
        );

        res.setHeader(
            'Cache-Control',
            'private, no-store, max-age=0'
        );

        return res.download(
            file.absolute_path,
            file.file_name,
            (error) => {
                if (
                    error &&
                    !res.headersSent
                ) {
                    next(error);
                }
            }
        );
    } catch (error) {
        return next(error);
    }
}

module.exports = {
    generatePdf,
    listFiles,
    downloadFile
};
