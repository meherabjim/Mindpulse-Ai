const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const PDFDocument = require('pdfkit');

const database =
    require('../config/database');

const AppError =
    require('../utils/AppError');

const pool =
    database.pool || database;

const backendRoot =
    path.resolve(__dirname, '../..');

const storageRoot =
    path.resolve(
        backendRoot,
        process.env.REPORT_STORAGE_DIR ||
            'uploads/reports'
    );

function parseJson(value, fallback = {}) {
    if (!value) {
        return fallback;
    }

    if (typeof value === 'object') {
        return value;
    }

    try {
        return JSON.parse(value);
    } catch {
        return fallback;
    }
}

function numberValue(value) {
    return Number(value || 0);
}

function displayValue(value) {
    if (
        value === null ||
        value === undefined ||
        value === ''
    ) {
        return 'Not recorded';
    }

    return String(value);
}

function safePath(filePath) {
    const resolved =
        path.resolve(filePath);

    const rootWithSeparator =
        `${storageRoot}${path.sep}`;

    if (
        resolved !== storageRoot &&
        !resolved.startsWith(
            rootWithSeparator
        )
    ) {
        throw new AppError(
            500,
            'Unsafe report file path detected.'
        );
    }

    return resolved;
}

function sanitizeFileName(value) {
    return String(value)
        .replace(
            /[^a-zA-Z0-9._-]+/g,
            '-'
        )
        .replace(/-+/g, '-')
        .replace(/^-|-$/g, '');
}

async function ensureActiveUser(userId) {
    const [rows] =
        await pool.execute(
            `
            SELECT
                id,
                account_status,
                deleted_at
            FROM users
            WHERE id = ?
            LIMIT 1
            `,
            [userId]
        );

    const user = rows[0];

    if (!user || user.deleted_at) {
        throw new AppError(
            404,
            'User account was not found.'
        );
    }

    if (user.account_status !== 'active') {
        throw new AppError(
            403,
            'User account is not active.'
        );
    }
}

async function getOwnedReport(
    userId,
    reportId
) {
    const [rows] =
        await pool.execute(
            `
            SELECT
                r.*,

                DATE_FORMAT(
                    r.period_start,
                    '%Y-%m-%d'
                ) AS formatted_period_start,

                DATE_FORMAT(
                    r.period_end,
                    '%Y-%m-%d'
                ) AS formatted_period_end,

                u.email,
                p.full_name

            FROM reports AS r

            INNER JOIN users AS u
                ON u.id = r.user_id

            LEFT JOIN user_profiles AS p
                ON p.user_id = u.id

            WHERE
                r.id = ?
                AND r.user_id = ?
                AND u.deleted_at IS NULL

            LIMIT 1
            `,
            [
                reportId,
                userId
            ]
        );

    const report = rows[0];

    if (!report) {
        throw new AppError(
            404,
            'Wellness report was not found.'
        );
    }

    if (report.status !== 'completed') {
        throw new AppError(
            422,
            'Only completed reports can be converted to PDF.'
        );
    }

    return {
        ...report,

        period_start:
            report.formatted_period_start,

        period_end:
            report.formatted_period_end,

        metrics:
            parseJson(
                report.metrics,
                {}
            )
    };
}

async function getDisclaimer() {
    const [rows] =
        await pool.execute(
            `
            SELECT content
            FROM app_contents
            WHERE
                content_type =
                    'wellness_disclaimer'
                AND is_active = TRUE
            ORDER BY
                published_at DESC,
                id DESC
            LIMIT 1
            `
        );

    return (
        rows[0]?.content ||
        'MindPulse AI provides wellness information and self-management support. It does not provide medical diagnosis, emergency care, or a replacement for professional healthcare.'
    );
}

async function calculateChecksum(
    filePath
) {
    return new Promise(
        (resolve, reject) => {
            const hash =
                crypto.createHash(
                    'sha256'
                );

            const stream =
                fs.createReadStream(
                    filePath
                );

            stream.on(
                'error',
                reject
            );

            stream.on(
                'data',
                (chunk) => {
                    hash.update(chunk);
                }
            );

            stream.on(
                'end',
                () => {
                    resolve(
                        hash.digest('hex')
                    );
                }
            );
        }
    );
}

function ensurePageSpace(
    document,
    requiredHeight = 70
) {
    const bottomLimit =
        document.page.height -
        document.page.margins.bottom -
        20;

    if (
        document.y + requiredHeight >
        bottomLimit
    ) {
        document.addPage();
    }
}

function addSection(
    document,
    title
) {
    ensurePageSpace(document, 75);

    document
        .moveDown(0.6)
        .fillColor('#17324D')
        .font('Helvetica-Bold')
        .fontSize(14)
        .text(title);

    document
        .moveDown(0.25)
        .strokeColor('#CBD5DF')
        .lineWidth(0.7)
        .moveTo(
            document.page.margins.left,
            document.y
        )
        .lineTo(
            document.page.width -
                document.page.margins.right,
            document.y
        )
        .stroke();

    document.moveDown(0.5);
}

function addParagraph(
    document,
    text
) {
    ensurePageSpace(document, 75);

    document
        .fillColor('#222222')
        .font('Helvetica')
        .fontSize(10.5)
        .text(
            text || 'Not available.',
            {
                lineGap: 3
            }
        );

    document.moveDown(0.4);
}

function addMetric(
    document,
    label,
    value
) {
    ensurePageSpace(document, 28);

    const left =
        document.page.margins.left;

    const width =
        document.page.width -
        document.page.margins.left -
        document.page.margins.right;

    const startY =
        document.y;

    document
        .fillColor('#333333')
        .font('Helvetica')
        .fontSize(10)
        .text(
            label,
            left,
            startY,
            {
                width:
                    width * 0.68
            }
        );

    document
        .font('Helvetica-Bold')
        .text(
            displayValue(value),
            left + width * 0.68,
            startY,
            {
                width:
                    width * 0.32,
                align: 'right'
            }
        );

    document.y =
        Math.max(
            document.y,
            startY + 16
        );

    document
        .moveDown(0.25)
        .strokeColor('#E7EBEF')
        .lineWidth(0.4)
        .moveTo(left, document.y)
        .lineTo(
            left + width,
            document.y
        )
        .stroke();

    document.moveDown(0.35);
}

function createPdf(
    report,
    disclaimer,
    filePath
) {
    return new Promise(
        (resolve, reject) => {
            const document =
                new PDFDocument({
                    size: 'A4',

                    margins: {
                        top: 45,
                        right: 50,
                        bottom: 50,
                        left: 50
                    },

                    info: {
                        Title:
                            'MindPulse AI Wellness Report',

                        Author:
                            'MindPulse AI',

                        Subject:
                            'Personal wellness progress report'
                    }
                });

            const output =
                fs.createWriteStream(
                    filePath
                );

            output.on(
                'finish',
                resolve
            );

            output.on(
                'error',
                reject
            );

            document.on(
                'error',
                reject
            );

            document.pipe(output);

            document
                .fillColor('#17324D')
                .font('Helvetica-Bold')
                .fontSize(23)
                .text(
                    'MindPulse AI',
                    {
                        align: 'center'
                    }
                );

            document
                .moveDown(0.2)
                .fontSize(15)
                .text(
                    'Personal Wellness Report',
                    {
                        align: 'center'
                    }
                );

            document
                .moveDown(0.8)
                .fillColor('#222222')
                .font('Helvetica')
                .fontSize(10.5);

            document.text(
                `Prepared for: ${
                    report.full_name ||
                    'MindPulse User'
                }`
            );

            document.text(
                `Email: ${report.email}`
            );

            document.text(
                `Report type: ${report.report_type}`
            );

            document.text(
                `Reporting period: ${report.period_start} to ${report.period_end}`
            );

            document.text(
                `Report ID: ${report.id}`
            );

            addSection(
                document,
                'Report Summary'
            );

            addParagraph(
                document,
                report.summary
            );

            const metrics =
                report.metrics || {};

            const checkins =
                metrics.checkins || {};

            addSection(
                document,
                'Daily Check-in Summary'
            );

            addMetric(
                document,
                'Completed check-ins',
                numberValue(
                    checkins.count
                )
            );

            addMetric(
                document,
                'Average mood score',
                checkins.average_mood
            );

            addMetric(
                document,
                'Average stress level',
                checkins.average_stress
            );

            addMetric(
                document,
                'Average energy level',
                checkins.average_energy
            );

            addMetric(
                document,
                'Average sleep hours',
                checkins
                    .average_sleep_hours
            );

            addMetric(
                document,
                'Hydration target days',
                numberValue(
                    checkins
                        .hydration_target_days
                )
            );

            addMetric(
                document,
                'Healthy sleep target days',
                numberValue(
                    checkins
                        .sleep_target_days
                )
            );

            const wellness =
                metrics.wellness || {};

            const burnout =
                metrics.burnout || {};

            addSection(
                document,
                'Wellness and Burnout'
            );

            addMetric(
                document,
                'Wellness scans',
                numberValue(
                    wellness.scan_count
                )
            );

            addMetric(
                document,
                'Average wellness strain indicator',
                wellness
                    .average_risk_score
            );

            addMetric(
                document,
                'Average burnout score',
                burnout.average_score
            );

            addMetric(
                document,
                'Latest wellness support level',
                burnout
                    .latest_risk_level
            );

            const habits =
                metrics.habits || {};

            const recovery =
                metrics.recovery || {};

            const journals =
                metrics.journals || {};

            addSection(
                document,
                'Habits and Recovery'
            );

            addMetric(
                document,
                'Habit logs',
                numberValue(
                    habits.total_logs
                )
            );

            addMetric(
                document,
                'Completed habit logs',
                numberValue(
                    habits.completed_logs
                )
            );

            addMetric(
                document,
                'Habit completion',
                `${
                    numberValue(
                        habits
                            .completion_percent
                    )
                }%`
            );

            addMetric(
                document,
                'Recovery activities completed',
                numberValue(
                    recovery
                        .completed_activities
                )
            );

            addMetric(
                document,
                'Average recovery score',
                recovery
                    .average_recovery_score
            );

            addMetric(
                document,
                'Journal entries',
                numberValue(
                    journals.count
                )
            );

            addSection(
                document,
                'Recommended Next Steps'
            );

            addParagraph(
                document,
                report.recommendations
            );

            addSection(
                document,
                'Important Disclaimer'
            );

            addParagraph(
                document,
                disclaimer
            );

            document
                .moveDown(0.8)
                .fillColor('#777777')
                .font('Helvetica')
                .fontSize(8.5)
                .text(
                    'Generated securely by MindPulse AI.',
                    {
                        align: 'center'
                    }
                );

            document.end();
        }
    );
}

function calculateExpiry() {
    const configuredDays =
        Number(
            process.env
                .REPORT_FILE_EXPIRY_DAYS ||
            365
        );

    const days =
        Number.isFinite(
            configuredDays
        ) &&
        configuredDays > 0
            ? configuredDays
            : 365;

    return new Date(
        Date.now() +
        days *
            24 *
            60 *
            60 *
            1000
    );
}

function mapFile(row) {
    return {
        id: Number(row.id),

        report_id:
            Number(row.report_id),

        file_name:
            row.file_name,

        mime_type:
            row.mime_type,

        file_size_bytes:
            row.file_size_bytes === null
                ? null
                : Number(
                    row.file_size_bytes
                ),

        storage_type:
            row.storage_type,

        checksum_sha256:
            row.checksum_sha256,

        expires_at:
            row.expires_at,

        created_at:
            row.created_at
    };
}

async function generatePdf(
    userId,
    reportId
) {
    await ensureActiveUser(userId);

    const report =
        await getOwnedReport(
            userId,
            reportId
        );

    const disclaimer =
        await getDisclaimer();

    const userDirectory =
        safePath(
            path.join(
                storageRoot,
                `user-${userId}`
            )
        );

    await fs.promises.mkdir(
        userDirectory,
        {
            recursive: true
        }
    );

    const timeStamp =
        new Date()
            .toISOString()
            .replace(/[:.]/g, '-');

    const fileName =
        sanitizeFileName(
            `mindpulse-${report.report_type}-report-${reportId}-${timeStamp}`
        ) + '.pdf';

    const absolutePath =
        safePath(
            path.join(
                userDirectory,
                fileName
            )
        );

    try {
        await createPdf(
            report,
            disclaimer,
            absolutePath
        );

        const statistics =
            await fs.promises.stat(
                absolutePath
            );

        const checksum =
            await calculateChecksum(
                absolutePath
            );

        const relativePath =
            path
                .relative(
                    backendRoot,
                    absolutePath
                )
                .split(path.sep)
                .join('/');

        const [result] =
            await pool.execute(
                `
                INSERT INTO report_files (
                    report_id,
                    file_name,
                    file_path,
                    mime_type,
                    file_size_bytes,
                    storage_type,
                    checksum_sha256,
                    expires_at
                )
                VALUES (
                    ?,
                    ?,
                    ?,
                    'application/pdf',
                    ?,
                    'local',
                    ?,
                    ?
                )
                `,
                [
                    reportId,
                    fileName,
                    relativePath,
                    statistics.size,
                    checksum,
                    calculateExpiry()
                ]
            );

        const file =
            await getReportFile(
                userId,
                reportId,
                result.insertId
            );

        return {
            ...file,

            absolute_path:
                undefined,

            download_endpoint:
                `/api/v1/reports/${reportId}/files/${result.insertId}/download`
        };
    } catch (error) {
        try {
            await fs.promises.unlink(
                absolutePath
            );
        } catch {
            // No file cleanup was required.
        }

        throw error;
    }
}

async function listReportFiles(
    userId,
    reportId
) {
    await ensureActiveUser(userId);

    await getOwnedReport(
        userId,
        reportId
    );

    const [rows] =
        await pool.execute(
            `
            SELECT *
            FROM report_files
            WHERE report_id = ?
            ORDER BY
                created_at DESC,
                id DESC
            `,
            [reportId]
        );

    return rows.map((row) => ({
        ...mapFile(row),

        is_expired:
            row.expires_at !== null &&
            new Date(
                row.expires_at
            ).getTime() <
                Date.now(),

        download_endpoint:
            `/api/v1/reports/${reportId}/files/${row.id}/download`
    }));
}

async function getReportFile(
    userId,
    reportId,
    fileId
) {
    await ensureActiveUser(userId);

    const [rows] =
        await pool.execute(
            `
            SELECT rf.*
            FROM report_files AS rf

            INNER JOIN reports AS r
                ON r.id = rf.report_id

            WHERE
                rf.id = ?
                AND rf.report_id = ?
                AND r.user_id = ?

            LIMIT 1
            `,
            [
                fileId,
                reportId,
                userId
            ]
        );

    const row = rows[0];

    if (!row) {
        throw new AppError(
            404,
            'Report PDF file was not found.'
        );
    }

    if (
        row.expires_at &&
        new Date(
            row.expires_at
        ).getTime() <
            Date.now()
    ) {
        throw new AppError(
            410,
            'This report PDF has expired.'
        );
    }

    const absolutePath =
        safePath(
            path.resolve(
                backendRoot,
                row.file_path
            )
        );

    try {
        const statistics =
            await fs.promises.stat(
                absolutePath
            );

        if (!statistics.isFile()) {
            throw new Error(
                'Invalid file'
            );
        }
    } catch {
        throw new AppError(
            404,
            'The report PDF is missing from storage.'
        );
    }

    return {
        ...mapFile(row),
        absolute_path:
            absolutePath
    };
}

module.exports = {
    generatePdf,
    listReportFiles,
    getReportFile
};
