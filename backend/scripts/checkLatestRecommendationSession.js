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


async function run() {
    const [rows] =
        await pool.execute(
            `
            SELECT
                id,
                user_id,
                recommendation_category,
                recommendation_title,
                suggested_duration_seconds,
                actual_duration_seconds,
                status,
                before_mood,
                after_mood,
                before_stress,
                after_stress,
                feedback_type,
                tracking_source,
                started_at,
                ended_at
            FROM recommendation_sessions
            ORDER BY
                started_at DESC,
                id DESC
            LIMIT 1
            `
        );

    if (!rows[0]) {
        throw new Error(
            'No recommendation session was found.'
        );
    }

    const latest = rows[0];

    const summary =
        await service.getSummary(
            Number(latest.user_id),
            7
        );

    console.log(
        JSON.stringify(
            {
                latest_session: {
                    id:
                        Number(latest.id),

                    user_id:
                        Number(latest.user_id),

                    category:
                        latest
                            .recommendation_category,

                    title:
                        latest
                            .recommendation_title,

                    status:
                        latest.status,

                    suggested_seconds:
                        Number(
                            latest
                                .suggested_duration_seconds
                        ),

                    actual_seconds:
                        Number(
                            latest
                                .actual_duration_seconds
                        ),

                    before_mood:
                        latest.before_mood,

                    after_mood:
                        latest.after_mood,

                    before_stress:
                        latest.before_stress,

                    after_stress:
                        latest.after_stress,

                    feedback:
                        latest.feedback_type,

                    tracking_source:
                        latest.tracking_source,

                    started_at:
                        latest.started_at,

                    ended_at:
                        latest.ended_at
                },

                seven_day_summary: {
                    total_sessions:
                        summary.total_sessions,

                    completed_sessions:
                        summary
                            .completed_sessions,

                    abandoned_sessions:
                        summary
                            .abandoned_sessions,

                    remind_later_sessions:
                        summary
                            .remind_later_sessions,

                    helpful_sessions:
                        summary
                            .helpful_sessions,

                    not_useful_sessions:
                        summary
                            .not_useful_sessions,

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
        'Latest recommendation follow-up verified.'
    );
}


run()
    .catch((error) => {
        console.error(
            'Recommendation verification failed.'
        );

        console.error(
            error.stack || error.message
        );

        process.exitCode = 1;
    })
    .finally(async () => {
        if (
            typeof pool.end ===
            'function'
        ) {
            await pool.end();
        }
    });
