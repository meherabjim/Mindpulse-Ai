const express =
    require('express');

const aiController =
    require('../controllers/ai.controller');

const aiConversationController =
    require('../controllers/aiConversation.controller');

const authModule =
    require('../middleware/auth.middleware');


const authenticateUser =
    typeof authModule === 'function'
        ? authModule
        : (
            authModule.authenticate ||
            authModule.authenticateUser ||
            authModule.protect ||
            authModule.requireAuth ||
            authModule.verifyAccessToken
        );


if (
    typeof authenticateUser !==
    'function'
) {
    throw new Error(
        'Compatible user authentication middleware was not found.'
    );
}


const router =
    express.Router();


router.get(
    '/health',
    authenticateUser,
    aiController.health
);


router.post(
    '/journal/analyze',
    authenticateUser,
    aiController.analyzeJournal
);


router.post(
    '/safety/check',
    authenticateUser,
    aiController.checkSafety
);


router.post(
    '/wellness/recommendations',
    authenticateUser,
    aiController.getRecommendations
);


router.post(
    '/wellness/predict',
    authenticateUser,
    aiController.predictWellness
);


router.post(
    '/reading/plan',
    authenticateUser,
    aiController.generateReadingPlan
);


/*
AI Coach conversation routes
*/

router.post(
    '/conversations',
    authenticateUser,
    aiConversationController
        .createConversation
);


router.get(
    '/conversations',
    authenticateUser,
    aiConversationController
        .listConversations
);


router.get(
    '/conversations/:id/messages',
    authenticateUser,
    aiConversationController
        .listMessages
);


router.post(
    '/conversations/:id/messages',
    authenticateUser,
    aiConversationController
        .sendMessage
);


router.patch(
    '/conversations/:id/status',
    authenticateUser,
    aiConversationController
        .updateConversationStatus
);


module.exports =
    router;
