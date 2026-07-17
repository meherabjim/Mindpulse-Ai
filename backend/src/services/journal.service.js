const database = require('../config/database');
const AppError = require('../utils/AppError');

const pool = database.pool || database;

function booleanValue(value) {
    return Boolean(Number(value));
}

function parseJson(value, fallback = null) {
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

async function ensureActiveUser(
    executor,
    userId
) {
    const [rows] = await executor.execute(
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
            'This account is not currently active.'
        );
    }
}

async function getUserTimezone(userId) {
    const [rows] = await pool.execute(
        `
        SELECT
            COALESCE(
                p.timezone,
                'Asia/Dhaka'
            ) AS timezone
        FROM users AS u
        LEFT JOIN user_profiles AS p
            ON p.user_id = u.id
        WHERE u.id = ?
        LIMIT 1
        `,
        [userId]
    );

    return rows[0]?.timezone || 'Asia/Dhaka';
}

function getDateInTimezone(timezone) {
    try {
        const formatter =
            new Intl.DateTimeFormat(
                'en-US',
                {
                    timeZone: timezone,
                    year: 'numeric',
                    month: '2-digit',
                    day: '2-digit'
                }
            );

        const parts =
            formatter.formatToParts(
                new Date()
            );

        const values = {};

        parts.forEach((part) => {
            values[part.type] =
                part.value;
        });

        return `${values.year}-${values.month}-${values.day}`;
    } catch {
        return new Date()
            .toISOString()
            .slice(0, 10);
    }
}

function mapJournal(row) {
    return {
        id: Number(row.id),
        title: row.title,
        content: row.content,
        entry_date: row.entry_date,
        mood_score:
            row.mood_score === null
                ? null
                : Number(row.mood_score),
        is_private:
            booleanValue(row.is_private),
        is_favorite:
            booleanValue(row.is_favorite),
        analysis_status:
            row.analysis_status,
        tags: row.tags || [],
        analysis:
            row.analysis || null,
        created_at:
            row.created_at,
        updated_at:
            row.updated_at
    };
}

async function attachTags(
    rows,
    userId,
    executor = pool
) {
    if (rows.length === 0) {
        return rows;
    }

    const journalIds =
        rows.map((row) => Number(row.id));

    const placeholders =
        journalIds.map(() => '?').join(',');

    const [tagRows] =
        await executor.execute(
            `
            SELECT
                jtm.journal_id,
                jt.id,
                jt.name
            FROM journal_tag_mappings
                AS jtm
            INNER JOIN journal_tags AS jt
                ON jt.id = jtm.tag_id
            WHERE
                jt.user_id = ?
                AND jtm.journal_id IN (
                    ${placeholders}
                )
            ORDER BY jt.name ASC
            `,
            [
                userId,
                ...journalIds
            ]
        );

    const tagsByJournal =
        new Map();

    tagRows.forEach((tag) => {
        const journalId =
            Number(tag.journal_id);

        if (!tagsByJournal.has(journalId)) {
            tagsByJournal.set(
                journalId,
                []
            );
        }

        tagsByJournal
            .get(journalId)
            .push({
                id: Number(tag.id),
                name: tag.name
            });
    });

    rows.forEach((row) => {
        row.tags =
            tagsByJournal.get(
                Number(row.id)
            ) || [];
    });

    return rows;
}

async function synchronizeTags(
    executor,
    userId,
    journalId,
    tagNames
) {
    await executor.execute(
        `
        DELETE FROM journal_tag_mappings
        WHERE journal_id = ?
        `,
        [journalId]
    );

    for (const tagName of tagNames) {
        const [tagResult] =
            await executor.execute(
                `
                INSERT INTO journal_tags (
                    user_id,
                    name
                )
                VALUES (?, ?)

                ON DUPLICATE KEY UPDATE
                    id = LAST_INSERT_ID(id)
                `,
                [
                    userId,
                    tagName
                ]
            );

        const tagId =
            tagResult.insertId;

        await executor.execute(
            `
            INSERT IGNORE INTO journal_tag_mappings (
                journal_id,
                tag_id
            )
            VALUES (?, ?)
            `,
            [
                journalId,
                tagId
            ]
        );
    }
}

async function createJournal(
    userId,
    journalData
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        let entryDate =
            journalData.entry_date;

        if (!entryDate) {
            const timezone =
                await getUserTimezone(userId);

            entryDate =
                getDateInTimezone(timezone);
        }

        const [result] =
            await connection.execute(
                `
                INSERT INTO journals (
                    user_id,
                    title,
                    content,
                    entry_date,
                    mood_score,
                    is_private,
                    is_favorite,
                    analysis_status
                )
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?,
                    'not_requested'
                )
                `,
                [
                    userId,
                    journalData.title,
                    journalData.content,
                    entryDate,
                    journalData.mood_score,
                    Number(
                        journalData.is_private
                    ),
                    Number(
                        journalData.is_favorite
                    )
                ]
            );

        await synchronizeTags(
            connection,
            userId,
            result.insertId,
            journalData.tags
        );

        await connection.commit();

        return getJournalById(
            userId,
            result.insertId
        );
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function getJournalById(
    userId,
    journalId
) {
    await ensureActiveUser(pool, userId);

    const [rows] = await pool.execute(
        `
        SELECT
            j.id,
            j.title,
            j.content,
            DATE_FORMAT(
                j.entry_date,
                '%Y-%m-%d'
            ) AS entry_date,
            j.mood_score,
            j.is_private,
            j.is_favorite,
            j.analysis_status,
            j.created_at,
            j.updated_at
        FROM journals AS j
        WHERE
            j.id = ?
            AND j.user_id = ?
            AND j.deleted_at IS NULL
        LIMIT 1
        `,
        [
            journalId,
            userId
        ]
    );

    if (!rows[0]) {
        throw new AppError(
            404,
            'Journal entry was not found.'
        );
    }

    await attachTags(
        rows,
        userId
    );

    const [analysisRows] =
        await pool.execute(
            `
            SELECT
                sentiment_label,
                sentiment_score,
                stress_level,
                emotional_themes,
                summary,
                reflection_prompt,
                safety_flag,
                safety_category,
                model_version,
                analyzed_at
            FROM journal_analyses
            WHERE journal_id = ?
            LIMIT 1
            `,
            [journalId]
        );

    if (analysisRows[0]) {
        const analysis =
            analysisRows[0];

        rows[0].analysis = {
            sentiment_label:
                analysis.sentiment_label,

            sentiment_score:
                analysis.sentiment_score === null
                    ? null
                    : Number(
                        analysis.sentiment_score
                    ),

            stress_level:
                analysis.stress_level,

            emotional_themes:
                parseJson(
                    analysis.emotional_themes,
                    []
                ),

            summary:
                analysis.summary,

            reflection_prompt:
                analysis.reflection_prompt,

            safety_flag:
                booleanValue(
                    analysis.safety_flag
                ),

            safety_category:
                analysis.safety_category,

            model_version:
                analysis.model_version,

            analyzed_at:
                analysis.analyzed_at
        };
    }

    return mapJournal(rows[0]);
}

async function listJournals(
    userId,
    options
) {
    await ensureActiveUser(pool, userId);

    const conditions = [
        'j.user_id = ?',
        'j.deleted_at IS NULL'
    ];

    const parameters = [userId];

    if (options.search) {
        conditions.push(
            '(j.title LIKE ? OR j.content LIKE ?)'
        );

        const searchValue =
            `%${options.search}%`;

        parameters.push(
            searchValue,
            searchValue
        );
    }

    if (options.favorite !== null) {
        conditions.push(
            'j.is_favorite = ?'
        );

        parameters.push(
            Number(options.favorite)
        );
    }

    if (options.fromDate) {
        conditions.push(
            'j.entry_date >= ?'
        );

        parameters.push(
            options.fromDate
        );
    }

    if (options.toDate) {
        conditions.push(
            'j.entry_date <= ?'
        );

        parameters.push(
            options.toDate
        );
    }

    if (options.tag) {
        conditions.push(
            `
            EXISTS (
                SELECT 1
                FROM journal_tag_mappings
                    AS filter_mapping
                INNER JOIN journal_tags
                    AS filter_tag
                    ON filter_tag.id =
                        filter_mapping.tag_id
                WHERE
                    filter_mapping.journal_id =
                        j.id
                    AND filter_tag.user_id = ?
                    AND filter_tag.name = ?
            )
            `
        );

        parameters.push(
            userId,
            options.tag
        );
    }

    const whereClause =
        conditions.join(' AND ');

    const [countRows] =
        await pool.execute(
            `
            SELECT COUNT(*) AS total
            FROM journals AS j
            WHERE ${whereClause}
            `,
            parameters
        );

    const offset =
        (options.page - 1) *
        options.limit;

    const [rows] =
        await pool.execute(
            `
            SELECT
                j.id,
                j.title,
                j.content,
                DATE_FORMAT(
                    j.entry_date,
                    '%Y-%m-%d'
                ) AS entry_date,
                j.mood_score,
                j.is_private,
                j.is_favorite,
                j.analysis_status,
                j.created_at,
                j.updated_at
            FROM journals AS j
            WHERE ${whereClause}
            ORDER BY
                j.entry_date DESC,
                j.id DESC
            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            parameters
        );

    await attachTags(
        rows,
        userId
    );

    const total =
        Number(countRows[0].total);

    return {
        journals:
            rows.map(mapJournal),

        pagination: {
            page: options.page,
            limit: options.limit,
            total,
            total_pages:
                Math.ceil(
                    total /
                    options.limit
                )
        }
    };
}

async function updateJournal(
    userId,
    journalId,
    journalData
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        await ensureActiveUser(
            connection,
            userId
        );

        const [existingRows] =
            await connection.execute(
                `
                SELECT id
                FROM journals
                WHERE
                    id = ?
                    AND user_id = ?
                    AND deleted_at IS NULL
                LIMIT 1
                FOR UPDATE
                `,
                [
                    journalId,
                    userId
                ]
            );

        if (!existingRows[0]) {
            throw new AppError(
                404,
                'Journal entry was not found.'
            );
        }

        const columnMap = {
            title: 'title',
            content: 'content',
            entry_date: 'entry_date',
            mood_score: 'mood_score',
            is_private: 'is_private',
            is_favorite: 'is_favorite'
        };

        const entries =
            Object.entries(journalData)
                .filter(
                    ([key]) =>
                        columnMap[key]
                );

        if (entries.length > 0) {
            const assignments =
                entries
                    .map(
                        ([key]) =>
                            `${columnMap[key]} = ?`
                    )
                    .join(', ');

            const values =
                entries.map(
                    ([, value]) =>
                        typeof value === 'boolean'
                            ? Number(value)
                            : value
                );

            await connection.execute(
                `
                UPDATE journals
                SET ${assignments}
                WHERE
                    id = ?
                    AND user_id = ?
                `,
                [
                    ...values,
                    journalId,
                    userId
                ]
            );
        }

        if (
            Object.prototype.hasOwnProperty.call(
                journalData,
                'tags'
            )
        ) {
            await synchronizeTags(
                connection,
                userId,
                journalId,
                journalData.tags
            );
        }

        if (
            Object.prototype.hasOwnProperty.call(
                journalData,
                'content'
            )
        ) {
            await connection.execute(
                `
                UPDATE journals
                SET analysis_status =
                    'not_requested'
                WHERE id = ?
                `,
                [journalId]
            );

            await connection.execute(
                `
                DELETE FROM journal_analyses
                WHERE journal_id = ?
                `,
                [journalId]
            );
        }

        await connection.commit();

        return getJournalById(
            userId,
            journalId
        );
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function deleteJournal(
    userId,
    journalId
) {
    await ensureActiveUser(pool, userId);

    const [result] =
        await pool.execute(
            `
            UPDATE journals
            SET deleted_at =
                CURRENT_TIMESTAMP
            WHERE
                id = ?
                AND user_id = ?
                AND deleted_at IS NULL
            `,
            [
                journalId,
                userId
            ]
        );

    if (result.affectedRows === 0) {
        throw new AppError(
            404,
            'Journal entry was not found.'
        );
    }
}

async function listTags(userId) {
    await ensureActiveUser(pool, userId);

    const [rows] = await pool.execute(
        `
        SELECT
            jt.id,
            jt.name,
            COUNT(jtm.id) AS journal_count,
            jt.created_at
        FROM journal_tags AS jt
        LEFT JOIN journal_tag_mappings
            AS jtm
            ON jtm.tag_id = jt.id
        LEFT JOIN journals AS j
            ON j.id = jtm.journal_id
            AND j.deleted_at IS NULL
        WHERE jt.user_id = ?
        GROUP BY
            jt.id,
            jt.name,
            jt.created_at
        ORDER BY jt.name ASC
        `,
        [userId]
    );

    return rows.map((row) => ({
        id: Number(row.id),
        name: row.name,
        journal_count:
            Number(row.journal_count),
        created_at:
            row.created_at
    }));
}

async function createTag(
    userId,
    name
) {
    await ensureActiveUser(pool, userId);

    const [result] =
        await pool.execute(
            `
            INSERT INTO journal_tags (
                user_id,
                name
            )
            VALUES (?, ?)

            ON DUPLICATE KEY UPDATE
                id = LAST_INSERT_ID(id)
            `,
            [
                userId,
                name
            ]
        );

    const [rows] = await pool.execute(
        `
        SELECT
            id,
            name,
            created_at
        FROM journal_tags
        WHERE
            id = ?
            AND user_id = ?
        LIMIT 1
        `,
        [
            result.insertId,
            userId
        ]
    );

    return {
        id: Number(rows[0].id),
        name: rows[0].name,
        journal_count: 0,
        created_at:
            rows[0].created_at
    };
}

module.exports = {
    createJournal,
    getJournalById,
    listJournals,
    updateJournal,
    deleteJournal,
    listTags,
    createTag
};
