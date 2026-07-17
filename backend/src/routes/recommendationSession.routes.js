const express =
    require('express');

const recommendationSessionController =
    require(
        '../controllers/' +
        'recommendationSession.controller'
    );

const {
    authenticate
} = require(
    '../middleware/auth.middleware'
);


const router =
    express.Router();


router.use(
    authenticate
);


router.post(
    '/recommendation-sessions',
    recommendationSessionController
        .startSession
);


router.patch(
    '/recommendation-sessions/:id',
    recommendationSessionController
        .finishSession
);


router.get(
    '/recommendation-sessions/history',
    recommendationSessionController
        .listHistory
);


router.get(
    '/recommendation-sessions/summary',
    recommendationSessionController
        .getSummary
);


module.exports =
    router;
