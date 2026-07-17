const {
    applicationDefault,
    getApp,
    initializeApp
} = require('firebase-admin/app');

const {
    getMessaging
} = require('firebase-admin/messaging');

const AppError =
    require('../utils/AppError');

const APP_NAME =
    'mindpulse-fcm';

function getFcmMode() {
    const mode =
        String(
            process.env.FCM_MODE ||
            'mock'
        )
            .trim()
            .toLowerCase();

    return mode === 'live'
        ? 'live'
        : 'mock';
}

function isDryRun() {
    return (
        String(
            process.env.FCM_DRY_RUN ||
            'false'
        ).toLowerCase() === 'true'
    );
}

function getFirebaseStatus() {
    const credentialPath =
        String(
            process.env
                .GOOGLE_APPLICATION_CREDENTIALS ||
            ''
        ).trim();

    return {
        mode: getFcmMode(),
        dry_run: isDryRun(),

        firebase_project_id:
            process.env
                .FIREBASE_PROJECT_ID ||
            null,

        credential_configured:
            Boolean(credentialPath),

        android_channel_id:
            process.env
                .FCM_ANDROID_CHANNEL_ID ||
            'mindpulse_default'
    };
}

function getFirebaseApp() {
    if (getFcmMode() !== 'live') {
        throw new AppError(
            503,
            'Firebase is currently running in mock mode.'
        );
    }

    const credentialPath =
        String(
            process.env
                .GOOGLE_APPLICATION_CREDENTIALS ||
            ''
        ).trim();

    if (!credentialPath) {
        throw new AppError(
            503,
            'Firebase service-account credentials are not configured.'
        );
    }

    try {
        return getApp(APP_NAME);
    } catch {
        const options = {
            credential:
                applicationDefault()
        };

        const projectId =
            String(
                process.env
                    .FIREBASE_PROJECT_ID ||
                ''
            ).trim();

        if (projectId) {
            options.projectId =
                projectId;
        }

        return initializeApp(
            options,
            APP_NAME
        );
    }
}

function getFirebaseMessaging() {
    return getMessaging(
        getFirebaseApp()
    );
}

module.exports = {
    getFcmMode,
    isDryRun,
    getFirebaseStatus,
    getFirebaseMessaging
};
