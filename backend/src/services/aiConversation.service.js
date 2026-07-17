/*
AI_COACH_BACKEND_V1

Privacy and safety rules:
- Raw messages are stored only in ai_messages.
- Raw messages are never copied into ai_analysis_logs.
- The system never automatically calls or messages anyone.
- Automated responses are wellness support, not diagnosis.
*/

const database =
    require('../config/database');

const AppError =
    require('../utils/AppError');

const aiService =
    require('./ai.service');

const aiLogService =
    require('./aiLog.service');


const pool =
    database.pool || database;

const MODEL_NAME =
    'mindpulse-support-rules-v1';

const VALID_SEVERITIES =
    new Set([
        'low',
        'moderate',
        'high',
        'critical'
    ]);


function booleanValue(value) {
    return Boolean(Number(value));
}


function numberValue(value) {
    return Number(value || 0);
}


function normalizeSafety(result) {
    const severity =
        VALID_SEVERITIES.has(
            result?.severity
        )
            ? result.severity
            : 'low';

    return {
        flagged:
            Boolean(result?.flagged),

        severity,

        matched_signals:
            Array.isArray(
                result?.matched_signals
            )
                ? result.matched_signals
                    .filter(
                        (item) =>
                            typeof item ===
                                'string'
                    )
                    .slice(0, 20)
                : [],

        emergency_action_recommended:
            Boolean(
                result
                    ?.emergency_action_recommended
            ),

        guidance:
            Array.isArray(result?.guidance)
                ? result.guidance
                    .filter(
                        (item) =>
                            typeof item ===
                                'string'
                    )
                    .slice(0, 10)
                : []
    };
}


function isBengali(text) {
    return /[\u0980-\u09FF]/.test(
        String(text || '')
    );
}


function normalizedText(text) {
    return String(text || '')
        .trim()
        .toLowerCase()
        .replace(/\s+/g, ' ');
}


function getSafetyCategory(safety) {
    if (!safety.flagged) {
        return null;
    }

    if (
        safety.severity === 'critical' ||
        safety.severity === 'high'
    ) {
        return 'self_harm';
    }

    if (safety.severity === 'moderate') {
        return 'severe_distress';
    }

    return 'other';
}


function createSupportResponse(
    content,
    safety
) {
    const bengali =
        isBengali(content);

    if (safety.severity === 'critical') {
        return bengali
            ? (
                'আপনি খুব কঠিন একটি সময়ের মধ্যে আছেন বলে মনে হচ্ছে। ' +
                'আপনার নিরাপত্তা এখন সবচেয়ে গুরুত্বপূর্ণ। ' +
                'নিজেকে আঘাত করতে ব্যবহার করা যেতে পারে এমন কিছু থেকে দূরে যান, ' +
                'বিশ্বস্ত একজন মানুষের সঙ্গে থাকুন এবং এখনই স্থানীয় জরুরি বা ' +
                'যোগ্য সংকটকালীন সহায়তার সঙ্গে যোগাযোগ করুন। ' +
                'MindPulse জরুরি চিকিৎসা দিতে পারে না এবং নিজে থেকে কাউকে যোগাযোগ করে না।'
            )
            : (
                'I am sorry you are facing this. Your safety is the priority. ' +
                'Move away from anything that could be used for harm, stay with ' +
                'a trusted person, and contact local emergency or qualified crisis ' +
                'support now. MindPulse cannot provide emergency care and does not ' +
                'contact anyone automatically.'
            );
    }

    if (safety.severity === 'high') {
        return bengali
            ? (
                'আপনাকে এখন একা এই পরিস্থিতি সামলাতে হবে না। ' +
                'বিশ্বস্ত একজন মানুষকে এখনই জানান এবং নিরাপদ জায়গায় থাকুন। ' +
                'তাৎক্ষণিক বিপদের আশঙ্কা থাকলে স্থানীয় জরুরি বা যোগ্য পেশাগত ' +
                'সহায়তা নিন। MindPulse নিজে থেকে কাউকে call বা message করে না।'
            )
            : (
                'You do not need to handle this alone. Tell a trusted person now ' +
                'and stay somewhere safer. Seek local emergency or qualified ' +
                'professional support if there may be immediate danger. MindPulse ' +
                'does not automatically call or message anyone.'
            );
    }

    if (safety.severity === 'moderate') {
        return bengali
            ? (
                'এটি খুব ভারী অনুভূতি হতে পারে। এখন একটি ছোট নিরাপদ পদক্ষেপ নিন: ' +
                'বিশ্বস্ত কাউকে জানান, ধীরে শ্বাস নিন এবং একা না থাকার চেষ্টা করুন। ' +
                'এই অনুভূতি চলতে থাকলে যোগ্য পেশাগত সহায়তা বিবেচনা করুন।'
            )
            : (
                'That sounds very heavy. Take one safe step now: tell a trusted ' +
                'person, slow your breathing, and try not to remain isolated. ' +
                'Consider qualified professional support if this continues.'
            );
    }

    const text =
        normalizedText(content);

    const hasSleep =
        /sleep|insomnia|bed|ঘুম/.test(text);

    const hasStress =
        /stress|pressure|exam|study|work|চাপ|টেনশন|পরীক্ষা|পড়াশোনা/.test(
            text
        );

    const hasAnxiety =
        /anxious|anxiety|worried|panic|fear|দুশ্চিন্তা|ভয়|আতঙ্ক/.test(
            text
        );

    const hasSadness =
        /sad|lonely|cry|unhappy|দুঃখ|একাকী|কান্না|মন খারাপ/.test(
            text
        );

    const hasFocus =
        /focus|concentrat|distract|মনোযোগ/.test(
            text
        );

    if (bengali) {
        if (hasSleep) {
            return (
                'ঘুমের সমস্যা কষ্টকর হতে পারে। আজ একটি বাস্তবসম্মত ঘুমের সময় ঠিক করুন, ' +
                'ঘুমের আগে উত্তেজক screen use কমান এবং শরীরকে শান্ত হওয়ার সময় দিন। ' +
                'দীর্ঘদিন সমস্যা থাকলে যোগ্য পেশাগত পরামর্শ নিন।'
            );
        }

        if (hasStress) {
            return (
                'চাপের সময় পুরো কাজটি একসঙ্গে ভাবার বদলে পরবর্তী সবচেয়ে ছোট কাজটি বেছে নিন। ' +
                '৩ থেকে ৫ মিনিট ধীরে শ্বাস নিন, তারপর শুধু সেই একটি কাজ শুরু করুন।'
            );
        }

        if (hasAnxiety) {
            return (
                'এই মুহূর্তে শরীরকে স্থির হতে সাহায্য করুন। ধীরে শ্বাস নিন এবং আপনার চারপাশে ' +
                'দেখতে পাওয়া পাঁচটি জিনিস লক্ষ্য করুন। এরপর বিশ্বস্ত কাউকে আপনার অনুভূতি জানান।'
            );
        }

        if (hasSadness) {
            return (
                'আপনার অনুভূতিটি গুরুত্বপূর্ণ। আজ একজন বিশ্বস্ত মানুষকে সংক্ষেপে জানান যে ' +
                'সময়টি কঠিন যাচ্ছে এবং নিজের জন্য একটি কম-চাপের কাজ বেছে নিন।'
            );
        }

        if (hasFocus) {
            return (
                'মনোযোগ ফেরাতে একটি কাজ নির্বাচন করুন, notification কমিয়ে ১০ মিনিটের timer দিন ' +
                'এবং timer শেষ না হওয়া পর্যন্ত শুধু সেই কাজটি করুন।'
            );
        }

        return (
            'আপনার কথাটি শেয়ার করার জন্য ধন্যবাদ। এখন এমন একটি ছোট পদক্ষেপ বেছে নিন যা ' +
            'নিরাপদ, বাস্তবসম্মত এবং আজই করা সম্ভব। MindPulse-এর response তথ্যভিত্তিক wellness ' +
            'support; এটি diagnosis নয়।'
        );
    }

    if (hasSleep) {
        return (
            'Sleep difficulty can be exhausting. Choose a realistic bedtime, ' +
            'reduce stimulating screen use before bed, and give your body a ' +
            'quiet transition period. Seek qualified advice if the problem persists.'
        );
    }

    if (hasStress) {
        return (
            'Instead of solving everything at once, choose the smallest useful ' +
            'next step. Breathe slowly for three to five minutes, then begin only ' +
            'that one step.'
        );
    }

    if (hasAnxiety) {
        return (
            'Help your body settle first. Slow your breathing and name five things ' +
            'you can see around you. Then tell a trusted person how you are feeling.'
        );
    }

    if (hasSadness) {
        return (
            'Your feelings matter. Consider telling one trusted person that today ' +
            'has been difficult and choose one low-demand act of care for yourself.'
        );
    }

    if (hasFocus) {
        return (
            'Choose one task, reduce notifications, set a ten-minute timer, and ' +
            'work only on that task until the timer ends.'
        );
    }

    return (
        'Thank you for sharing that. Choose one small action that is safe, realistic, ' +
        'and possible today. MindPulse provides informational wellness support and ' +
        'does not provide a diagnosis.'
    );
}


function mapConversation(row) {
    return {
        id:
            Number(row.id),

        title:
            row.title,

        status:
            row.status,

        last_message_at:
            row.last_message_at,

        message_count:
            row.message_count ===
                undefined
                ? undefined
                : numberValue(
                    row.message_count
                ),

        created_at:
            row.created_at,

        updated_at:
            row.updated_at
    };
}


function mapMessage(row) {
    return {
        id:
            Number(row.id),

        conversation_id:
            Number(
                row.conversation_id
            ),

        message_role:
            row.message_role,

        content:
            row.content,

        safety_flag:
            booleanValue(
                row.safety_flag
            ),

        safety_category:
            row.safety_category,

        model_name:
            row.model_name,

        response_time_ms:
            row.response_time_ms ===
                null
                ? null
                : Number(
                    row.response_time_ms
                ),

        created_at:
            row.created_at
    };
}


async function writeLogSafely(payload) {
    try {
        return await aiLogService
            .createAiAnalysisLog(
                payload
            );
    } catch (error) {
        console.error(
            'AI Coach analysis log failed:',
            error.message
        );

        return null;
    }
}


async function ensureUserCanUseAi(
    executor,
    userId
) {
    const [rows] =
        await executor.execute(
            `
            SELECT
                u.id,
                u.account_status,
                u.deleted_at,

                COALESCE(
                    us.ai_analysis_enabled,
                    0
                ) AS ai_analysis_enabled,

                consent.is_granted
                    AS consent_granted

            FROM users AS u

            LEFT JOIN user_settings AS us
                ON us.user_id = u.id

            LEFT JOIN user_consents AS consent
                ON
                    consent.user_id = u.id
                    AND consent.consent_type =
                        'ai_analysis'

            WHERE u.id = ?
            LIMIT 1
            `,
            [userId]
        );

    const user =
        rows[0];

    if (
        !user ||
        user.deleted_at
    ) {
        throw new AppError(
            404,
            'User account was not found.'
        );
    }

    if (
        user.account_status !==
        'active'
    ) {
        throw new AppError(
            403,
            'This account is not currently active.'
        );
    }

    const settingEnabled =
        booleanValue(
            user.ai_analysis_enabled
        );

    const explicitlyRevoked =
        user.consent_granted !== null &&
        user.consent_granted !== undefined &&
        !booleanValue(
            user.consent_granted
        );

    if (
        !settingEnabled ||
        explicitlyRevoked
    ) {
        throw new AppError(
            403,
            'AI analysis is disabled in your privacy settings.'
        );
    }
}


async function getOwnedConversation(
    executor,
    userId,
    conversationId,
    {
        lock = false
    } = {}
) {
    const lockClause =
        lock
            ? 'FOR UPDATE'
            : '';

    const [rows] =
        await executor.execute(
            `
            SELECT
                id,
                user_id,
                title,
                status,
                last_message_at,
                created_at,
                updated_at
            FROM ai_conversations
            WHERE
                id = ?
                AND user_id = ?
                AND deleted_at IS NULL
            LIMIT 1
            ${lockClause}
            `,
            [
                conversationId,
                userId
            ]
        );

    if (!rows[0]) {
        throw new AppError(
            404,
            'AI conversation was not found.'
        );
    }

    return rows[0];
}


async function getMessageById(
    messageId
) {
    const [rows] =
        await pool.execute(
            `
            SELECT
                id,
                conversation_id,
                message_role,
                content,
                safety_flag,
                safety_category,
                model_name,
                response_time_ms,
                created_at
            FROM ai_messages
            WHERE id = ?
            LIMIT 1
            `,
            [messageId]
        );

    return rows[0]
        ? mapMessage(rows[0])
        : null;
}


async function createConversation(
    userId,
    data
) {
    await ensureUserCanUseAi(
        pool,
        userId
    );

    const title =
        data.title ||
        'Wellness conversation';

    const [result] =
        await pool.execute(
            `
            INSERT INTO ai_conversations (
                user_id,
                title,
                status
            )
            VALUES (?, ?, 'active')
            `,
            [
                userId,
                title
            ]
        );

    const conversation =
        await getOwnedConversation(
            pool,
            userId,
            result.insertId
        );

    return mapConversation(
        conversation
    );
}


async function listConversations(
    userId,
    options
) {
    await ensureUserCanUseAi(
        pool,
        userId
    );

    const offset =
        (
            options.page - 1
        ) *
        options.limit;

    const [countRows] =
        await pool.execute(
            `
            SELECT COUNT(*) AS total
            FROM ai_conversations
            WHERE
                user_id = ?
                AND deleted_at IS NULL
            `,
            [userId]
        );

    const [rows] =
        await pool.execute(
            `
            SELECT
                c.id,
                c.title,
                c.status,
                c.last_message_at,
                c.created_at,
                c.updated_at,

                COUNT(m.id)
                    AS message_count

            FROM ai_conversations AS c

            LEFT JOIN ai_messages AS m
                ON m.conversation_id =
                    c.id

            WHERE
                c.user_id = ?
                AND c.deleted_at IS NULL

            GROUP BY
                c.id,
                c.title,
                c.status,
                c.last_message_at,
                c.created_at,
                c.updated_at

            ORDER BY
                COALESCE(
                    c.last_message_at,
                    c.created_at
                ) DESC,
                c.id DESC

            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            [userId]
        );

    const total =
        numberValue(
            countRows[0].total
        );

    return {
        conversations:
            rows.map(
                mapConversation
            ),

        pagination: {
            page:
                options.page,

            limit:
                options.limit,

            total,

            total_pages:
                Math.ceil(
                    total /
                    options.limit
                )
        }
    };
}


async function listMessages(
    userId,
    conversationId,
    options
) {
    await ensureUserCanUseAi(
        pool,
        userId
    );

    const conversation =
        await getOwnedConversation(
            pool,
            userId,
            conversationId
        );

    const offset =
        (
            options.page - 1
        ) *
        options.limit;

    const [countRows] =
        await pool.execute(
            `
            SELECT COUNT(*) AS total
            FROM ai_messages
            WHERE conversation_id = ?
            `,
            [conversationId]
        );

    const [rows] =
        await pool.execute(
            `
            SELECT
                id,
                conversation_id,
                message_role,
                content,
                safety_flag,
                safety_category,
                model_name,
                response_time_ms,
                created_at
            FROM ai_messages
            WHERE conversation_id = ?
            ORDER BY
                created_at ASC,
                id ASC
            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            [conversationId]
        );

    const total =
        numberValue(
            countRows[0].total
        );

    return {
        conversation:
            mapConversation(
                conversation
            ),

        messages:
            rows.map(
                mapMessage
            ),

        pagination: {
            page:
                options.page,

            limit:
                options.limit,

            total,

            total_pages:
                Math.ceil(
                    total /
                    options.limit
                )
        }
    };
}


async function updateConversationStatus(
    userId,
    conversationId,
    status
) {
    const connection =
        await pool.getConnection();

    try {
        await connection
            .beginTransaction();

        await ensureUserCanUseAi(
            connection,
            userId
        );

        await getOwnedConversation(
            connection,
            userId,
            conversationId,
            {
                lock: true
            }
        );

        await connection.execute(
            `
            UPDATE ai_conversations
            SET status = ?
            WHERE
                id = ?
                AND user_id = ?
            `,
            [
                status,
                conversationId,
                userId
            ]
        );

        await connection.commit();
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }

    const conversation =
        await getOwnedConversation(
            pool,
            userId,
            conversationId
        );

    return mapConversation(
        conversation
    );
}


async function sendMessage(
    userId,
    conversationId,
    content
) {
    await ensureUserCanUseAi(
        pool,
        userId
    );

    const existingConversation =
        await getOwnedConversation(
            pool,
            userId,
            conversationId
        );

    if (
        existingConversation.status !==
        'active'
    ) {
        throw new AppError(
            409,
            'Messages can only be sent to an active conversation.'
        );
    }

    const startedAt =
        Date.now();

    let safety;

    try {
        safety =
            normalizeSafety(
                await aiService
                    .checkSafety({
                        text: content
                    })
            );
    } catch (error) {
        await writeLogSafely({
            userId,

            analysisType:
                'coach',

            requestSummary: {
                conversation_id:
                    conversationId,

                text_length:
                    content.length
            },

            success: false,

            errorCode:
                error.code ||
                'AI_SAFETY_UNAVAILABLE',

            processingTimeMs:
                Date.now() -
                startedAt
        });

        throw new AppError(
            error.statusCode || 503,
            (
                'AI Coach safety service is temporarily unavailable. ' +
                'Your message was not saved. Please try again shortly.'
            )
        );
    }

    const assistantContent =
        createSupportResponse(
            content,
            safety
        );

    const safetyCategory =
        getSafetyCategory(
            safety
        );

    const responseTimeMs =
        Math.max(
            0,
            Date.now() -
            startedAt
        );

    const connection =
        await pool.getConnection();

    let userMessageId;
    let assistantMessageId;
    let safetyEventId = null;

    try {
        await connection
            .beginTransaction();

        await ensureUserCanUseAi(
            connection,
            userId
        );

        const conversation =
            await getOwnedConversation(
                connection,
                userId,
                conversationId,
                {
                    lock: true
                }
            );

        if (
            conversation.status !==
            'active'
        ) {
            throw new AppError(
                409,
                'Messages can only be sent to an active conversation.'
            );
        }

        const [userResult] =
            await connection.execute(
                `
                INSERT INTO ai_messages (
                    conversation_id,
                    message_role,
                    content,
                    safety_flag,
                    safety_category,
                    model_name,
                    response_time_ms
                )
                VALUES (
                    ?,
                    'user',
                    ?,
                    ?,
                    ?,
                    NULL,
                    NULL
                )
                `,
                [
                    conversationId,
                    content,
                    Number(
                        safety.flagged
                    ),
                    safetyCategory
                ]
            );

        userMessageId =
            userResult.insertId;

        const [assistantResult] =
            await connection.execute(
                `
                INSERT INTO ai_messages (
                    conversation_id,
                    message_role,
                    content,
                    safety_flag,
                    safety_category,
                    model_name,
                    response_time_ms
                )
                VALUES (
                    ?,
                    'assistant',
                    ?,
                    ?,
                    ?,
                    ?,
                    ?
                )
                `,
                [
                    conversationId,
                    assistantContent,
                    Number(
                        safety.flagged
                    ),
                    safetyCategory,
                    MODEL_NAME,
                    responseTimeMs
                ]
            );

        assistantMessageId =
            assistantResult.insertId;

        if (safety.flagged) {
            const eventType =
                safetyCategory ===
                    'self_harm'
                    ? 'self_harm'
                    : safetyCategory ===
                        'severe_distress'
                        ? 'severe_distress'
                        : 'other';

            const [eventResult] =
                await connection.execute(
                    `
                    INSERT INTO ai_safety_events (
                        user_id,
                        conversation_id,
                        message_id,
                        event_type,
                        severity_level,
                        matched_terms,
                        redacted_excerpt,
                        action_taken,
                        emergency_contact_shown,
                        review_status
                    )
                    VALUES (
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        0,
                        'unreviewed'
                    )
                    `,
                    [
                        userId,
                        conversationId,
                        userMessageId,
                        eventType,
                        safety.severity,

                        JSON.stringify(
                            safety
                                .matched_signals
                        ),

                        (
                            '[Sensitive message content ' +
                            'detected and redacted]'
                        ),

                        (
                            'Returned safety-focused in-app guidance. ' +
                            'Recommended trusted, qualified professional, ' +
                            'or emergency support when appropriate. ' +
                            'No automatic contact was initiated.'
                        )
                    ]
                );

            safetyEventId =
                eventResult.insertId;
        }

        await connection.execute(
            `
            UPDATE ai_conversations
            SET
                last_message_at =
                    CURRENT_TIMESTAMP
            WHERE
                id = ?
                AND user_id = ?
            `,
            [
                conversationId,
                userId
            ]
        );

        await connection.commit();
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }

    const [
        conversation,
        userMessage,
        assistantMessage
    ] = await Promise.all([
        getOwnedConversation(
            pool,
            userId,
            conversationId
        ),

        getMessageById(
            userMessageId
        ),

        getMessageById(
            assistantMessageId
        )
    ]);

    const log =
        await writeLogSafely({
            userId,

            analysisType:
                'coach',

            requestSummary: {
                conversation_id:
                    conversationId,

                text_length:
                    content.length
            },

            responseSummary: {
                assistant_length:
                    assistantContent.length,

                model_name:
                    MODEL_NAME,

                safety_flagged:
                    safety.flagged,

                safety_severity:
                    safety.severity,

                emergency_action_recommended:
                    safety
                        .emergency_action_recommended
            },

            safetyFlagged:
                safety.flagged,

            severity:
                safety.severity,

            success: true,

            processingTimeMs:
                responseTimeMs
        });

    return {
        conversation:
            mapConversation(
                conversation
            ),

        user_message:
            userMessage,

        assistant_message:
            assistantMessage,

        safety: {
            ...safety,

            show_emergency_support:
                safety.severity ===
                    'high' ||
                safety.severity ===
                    'critical',

            automatic_contact_attempted:
                false,

            safety_event_id:
                safetyEventId
        },

        meta: {
            model_name:
                MODEL_NAME,

            analysis_log_id:
                log?.id ?? null,

            response_time_ms:
                responseTimeMs
        },

        disclaimer: (
            'MindPulse provides automated informational wellness support. ' +
            'It is not a diagnosis, therapist, or emergency service.'
        )
    };
}


module.exports = {
    createConversation,
    listConversations,
    listMessages,
    updateConversationStatus,
    sendMessage
};