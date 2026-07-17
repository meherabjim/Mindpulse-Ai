const path = require('path');

require('dotenv').config({
    path: path.resolve(
        __dirname,
        '..',
        '.env'
    ),
    override: true
});

const database =
    require('../src/config/database');

const service =
    require(
        '../src/services/' +
        'recommendationSession.service'
    );

const pool =
    database.pool || database;

let createdSessionId = null;
let createdSessionKey = null;


function assertCondition(
    condition,
    message
) {
    if (!condition) {
        throw new Error(message);
    }
}


async function run() {
    const [users] =
        await pool.execute(
            `
            SELECT id
            FROM users
            WHERE
                account_status = 'active'
                AND deleted_at IS NULL
            ORDER BY id ASC
            LIMIT 1
            `
        );

    if (!users[0]) {
        throw new Error(
            'No active test user was found.'
        );
    }

    const userId =
        Number(users[0].id);

    createdSessionKey =
        `qa_${Date.now()}_${userId}`;

    const started =
        await service.startSession(
            userId,
            {
                client_session_key:
                    createdSessionKey,

                recommendation_source:
                    'ai_wellness',

                recommendation_category:
                    'stress',

                recommendation_title:
                    'Test calming break',

                recommendation_action:
                    'Practise slow breathing for five minutes.',

                priority_level:
                    'high',

                suggested_duration_seconds:
                    300,

                before_mood:
                    2,

                before_stress:
                    5,

                tracking_source:
                    'in_app_timer'
            }
        );

    createdSessionId =
        started.id;

    assertCondition(
        started.status === 'started',
        'Session did not start correctly.'
    );

    const finished =
        await service.finishSession(
            userId,
            createdSessionId,
            {
                status:
                    'completed',

                actual_duration_seconds:
                    285,

                after_mood:
                    3,

                after_stress:
                    3,

                feedback_type:
                    'helpful',

                feedback_note:
                    'QA test feedback'
            }
        );

    assertCondition(
        finished.status === 'completed',
        'Session did not finish correctly.'
    );

    assertCondition(
        finished.actual_duration_seconds ===
            285,
        'Actual duration was not saved.'
    );

    assertCondition(
        finished.feedback_type ===
            'helpful',
        'Feedback was not saved.'
    );

    const history =
        await service.listHistory(
            userId,
            {
                page: 1,
                limit: 10
            }
        );

    const savedSession =
        history.sessions.find(
            (session) =>
                session.id ===
                createdSessionId
        );

    assertCondition(
        Boolean(savedSession),
        'Saved session was not found in history.'
    );

    const summary =
        await service.getSummary(
            userId,
            7
        );

    console.log(
        JSON.stringify(
            {
                test_result:
                    'PASSED',

                user_id:
                    userId,

                session: {
                    id:
                        finished.id,

                    status:
                        finished.status,

                    suggested_seconds:
                        finished
                            .suggested_duration_seconds,

                    actual_seconds:
                        finished
                            .actual_duration_seconds,

                    before_mood:
                        finished.before_mood,

                    after_mood:
                        finished.after_mood,

                    before_stress:
                        finished.before_stress,

                    after_stress:
                        finished.after_stress,

                    feedback:
                        finished.feedback_type
                },

                seven_day_summary: {
                    total_sessions:
                        summary.total_sessions,

                    completed_sessions:
                        summary
                            .completed_sessions,

                    helpful_sessions:
                        summary
                            .helpful_sessions,

                    total_duration_seconds:
                        summary
                            .total_duration_seconds
                }
            },
            null,
            2
        )
    );

    console.log(
        'Recommendation follow-up runtime test passed.'
    );
}


run()
    .catch((error) => {
        console.error(
            'Recommendation follow-up runtime test failed.'
        );

        console.error(
            error.stack || error.message
        );

        process.exitCode = 1;
    })
    .finally(async () => {
        try {
            if (
                createdSessionId &&
                createdSessionKey
            ) {
                await pool.execute(
                    `
                    DELETE FROM
                        recommendation_sessions
                    WHERE
                        id = ?
                        AND client_session_key = ?
                    `,
                    [
                        createdSessionId,
                        createdSessionKey
                    ]
                );

                console.log(
                    'Temporary QA record removed.'
                );
            }
        } catch (cleanupError) {
            console.error(
                'QA cleanup failed:',
                cleanupError.message
            );

            process.exitCode = 1;
        }

        if (
            typeof pool.end ===
            'function'
        ) {
            await pool.end();
        }
    });
