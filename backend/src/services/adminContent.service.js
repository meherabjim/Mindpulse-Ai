const database =
    require('../config/database');

const AppError =
    require('../utils/AppError');

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

function normalizeContext(context = {}) {
    return {
        ip_address:
            context.ip_address
                ? String(
                    context.ip_address
                ).slice(0, 45)
                : null,

        user_agent:
            context.user_agent
                ? String(
                    context.user_agent
                ).slice(0, 500)
                : null
    };
}

async function insertAudit(
    executor,
    {
        adminId,
        action,
        entityType,
        entityId,
        oldValues,
        newValues,
        metadata,
        context
    }
) {
    const requestContext =
        normalizeContext(context);

    await executor.execute(
        `
        INSERT INTO audit_logs (
            admin_user_id,
            actor_type,
            action,
            entity_type,
            entity_id,
            old_values,
            new_values,
            metadata,
            ip_address,
            user_agent
        )
        VALUES (
            ?,
            'admin',
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?
        )
        `,
        [
            adminId,
            action,
            entityType,
            entityId || null,

            oldValues
                ? JSON.stringify(oldValues)
                : null,

            newValues
                ? JSON.stringify(newValues)
                : null,

            metadata
                ? JSON.stringify(metadata)
                : null,

            requestContext.ip_address,
            requestContext.user_agent
        ]
    );
}

function mapContent(row) {
    return {
        id: Number(row.id),
        content_key:
            row.content_key,
        content_type:
            row.content_type,
        title: row.title,
        content: row.content,
        version: row.version,
        language_code:
            row.language_code,
        is_active:
            booleanValue(
                row.is_active
            ),
        published_at:
            row.published_at,
        updated_by_admin_id:
            row.updated_by_admin_id ===
            null
                ? null
                : Number(
                    row
                        .updated_by_admin_id
                ),
        updated_by_admin_name:
            row.updated_by_admin_name ||
            null,
        created_at:
            row.created_at,
        updated_at:
            row.updated_at
    };
}

async function listContents(options) {
    const conditions = ['1 = 1'];
    const parameters = [];

    if (options.contentType) {
        conditions.push(
            'ac.content_type = ?'
        );

        parameters.push(
            options.contentType
        );
    }

    if (options.languageCode) {
        conditions.push(
            'ac.language_code = ?'
        );

        parameters.push(
            options.languageCode
        );
    }

    if (options.isActive !== null) {
        conditions.push(
            'ac.is_active = ?'
        );

        parameters.push(
            Number(options.isActive)
        );
    }

    if (options.search) {
        conditions.push(
            `
            (
                ac.content_key LIKE ?
                OR ac.title LIKE ?
                OR ac.content LIKE ?
            )
            `
        );

        const value =
            `%${options.search}%`;

        parameters.push(
            value,
            value,
            value
        );
    }

    const whereClause =
        conditions.join(' AND ');

    const [countRows] =
        await pool.execute(
            `
            SELECT COUNT(*) AS total
            FROM app_contents AS ac
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
                ac.*,
                au.full_name AS
                    updated_by_admin_name
            FROM app_contents AS ac
            LEFT JOIN admin_users AS au
                ON au.id =
                    ac.updated_by_admin_id
            WHERE ${whereClause}
            ORDER BY
                ac.updated_at DESC,
                ac.id DESC
            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            parameters
        );

    const total =
        Number(countRows[0].total || 0);

    return {
        contents:
            rows.map(mapContent),

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

async function getContentById(contentId) {
    const [rows] =
        await pool.execute(
            `
            SELECT
                ac.*,
                au.full_name AS
                    updated_by_admin_name
            FROM app_contents AS ac
            LEFT JOIN admin_users AS au
                ON au.id =
                    ac.updated_by_admin_id
            WHERE ac.id = ?
            LIMIT 1
            `,
            [contentId]
        );

    if (!rows[0]) {
        throw new AppError(
            404,
            'App content was not found.'
        );
    }

    return mapContent(rows[0]);
}

async function createContent(
    adminId,
    contentData,
    context
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        const [result] =
            await connection.execute(
                `
                INSERT INTO app_contents (
                    content_key,
                    content_type,
                    title,
                    content,
                    version,
                    language_code,
                    is_active,
                    published_at,
                    updated_by_admin_id
                )
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
                `,
                [
                    contentData.content_key,
                    contentData.content_type,
                    contentData.title,
                    contentData.content,
                    contentData.version,
                    contentData.language_code,
                    Number(
                        contentData.is_active
                    ),
                    contentData.published_at,
                    adminId
                ]
            );

        await insertAudit(
            connection,
            {
                adminId,
                action:
                    'app_content_created',
                entityType:
                    'app_content',
                entityId:
                    result.insertId,
                oldValues: null,
                newValues:
                    contentData,
                metadata: null,
                context
            }
        );

        await connection.commit();

        return getContentById(
            result.insertId
        );
    } catch (error) {
        await connection.rollback();

        if (
            error.code ===
            'ER_DUP_ENTRY'
        ) {
            throw new AppError(
                409,
                'Content key, version, and language combination already exists.'
            );
        }

        throw error;
    } finally {
        connection.release();
    }
}

async function updateContent(
    adminId,
    contentId,
    contentData,
    context
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        const [rows] =
            await connection.execute(
                `
                SELECT *
                FROM app_contents
                WHERE id = ?
                LIMIT 1
                FOR UPDATE
                `,
                [contentId]
            );

        const current = rows[0];

        if (!current) {
            throw new AppError(
                404,
                'App content was not found.'
            );
        }

        const fields = [];
        const values = [];

        for (
            const [key, value]
            of Object.entries(contentData)
        ) {
            fields.push(`${key} = ?`);

            if (key === 'is_active') {
                values.push(
                    Number(value)
                );
            } else {
                values.push(value);
            }
        }

        fields.push(
            'updated_by_admin_id = ?'
        );

        values.push(adminId);
        values.push(contentId);

        await connection.execute(
            `
            UPDATE app_contents
            SET ${fields.join(', ')}
            WHERE id = ?
            `,
            values
        );

        await insertAudit(
            connection,
            {
                adminId,
                action:
                    'app_content_updated',
                entityType:
                    'app_content',
                entityId:
                    contentId,
                oldValues: {
                    content_key:
                        current.content_key,
                    content_type:
                        current.content_type,
                    title:
                        current.title,
                    version:
                        current.version,
                    language_code:
                        current.language_code,
                    is_active:
                        booleanValue(
                            current.is_active
                        ),
                    published_at:
                        current.published_at
                },
                newValues:
                    contentData,
                metadata: null,
                context
            }
        );

        await connection.commit();

        return getContentById(
            contentId
        );
    } catch (error) {
        await connection.rollback();

        if (
            error.code ===
            'ER_DUP_ENTRY'
        ) {
            throw new AppError(
                409,
                'Content key, version, and language combination already exists.'
            );
        }

        throw error;
    } finally {
        connection.release();
    }
}

async function listPublicContents(options) {
    const conditions = [
        'ac.is_active = TRUE',
        'ac.published_at IS NOT NULL',
        'ac.published_at <= CURRENT_TIMESTAMP'
    ];

    const parameters = [];

    if (options.contentType) {
        conditions.push(
            'ac.content_type = ?'
        );

        parameters.push(
            options.contentType
        );
    }

    if (options.languageCode) {
        conditions.push(
            'ac.language_code = ?'
        );

        parameters.push(
            options.languageCode
        );
    }

    const [rows] =
        await pool.execute(
            `
            SELECT ac.*
            FROM app_contents AS ac
            WHERE ${conditions.join(
                ' AND '
            )}
            ORDER BY
                ac.content_type ASC,
                ac.published_at DESC,
                ac.id DESC
            `,
            parameters
        );

    return rows.map(mapContent);
}

async function getPublicContent(
    contentKey,
    languageCode = 'en'
) {
    const [rows] =
        await pool.execute(
            `
            SELECT *
            FROM app_contents
            WHERE
                content_key = ?
                AND language_code = ?
                AND is_active = TRUE
                AND published_at
                    IS NOT NULL
                AND published_at <=
                    CURRENT_TIMESTAMP
            ORDER BY
                published_at DESC,
                id DESC
            LIMIT 1
            `,
            [
                contentKey,
                languageCode
            ]
        );

    if (!rows[0]) {
        throw new AppError(
            404,
            'Published app content was not found.'
        );
    }

    return mapContent(rows[0]);
}

function mapSupportResource(row) {
    return {
        id: Number(row.id),
        country_code:
            row.country_code,
        region_name:
            row.region_name,
        resource_type:
            row.resource_type,
        name: row.name,
        description:
            row.description,
        phone_number:
            row.phone_number,
        website_url:
            row.website_url,
        availability_text:
            row.availability_text,
        supported_languages:
            parseJson(
                row.supported_languages,
                []
            ),
        is_active:
            booleanValue(
                row.is_active
            ),
        display_order:
            Number(
                row.display_order || 0
            ),
        updated_by_admin_id:
            row.updated_by_admin_id ===
            null
                ? null
                : Number(
                    row
                        .updated_by_admin_id
                ),
        updated_by_admin_name:
            row.updated_by_admin_name ||
            null,
        created_at:
            row.created_at,
        updated_at:
            row.updated_at
    };
}

async function listSupportResources(
    options,
    publicOnly = false
) {
    const conditions = ['1 = 1'];
    const parameters = [];

    if (publicOnly) {
        conditions.push(
            'sr.is_active = TRUE'
        );
    } else if (
        options.isActive !== null
    ) {
        conditions.push(
            'sr.is_active = ?'
        );

        parameters.push(
            Number(options.isActive)
        );
    }

    if (options.countryCode) {
        conditions.push(
            'sr.country_code = ?'
        );

        parameters.push(
            options.countryCode
        );
    }

    if (options.regionName) {
        conditions.push(
            'sr.region_name LIKE ?'
        );

        parameters.push(
            `%${options.regionName}%`
        );
    }

    if (options.resourceType) {
        conditions.push(
            'sr.resource_type = ?'
        );

        parameters.push(
            options.resourceType
        );
    }

    if (
        options.search &&
        !publicOnly
    ) {
        conditions.push(
            `
            (
                sr.name LIKE ?
                OR sr.description LIKE ?
                OR sr.phone_number LIKE ?
            )
            `
        );

        const value =
            `%${options.search}%`;

        parameters.push(
            value,
            value,
            value
        );
    }

    const whereClause =
        conditions.join(' AND ');

    if (publicOnly) {
        const [rows] =
            await pool.execute(
                `
                SELECT
                    sr.*,
                    NULL AS
                        updated_by_admin_name
                FROM support_resources
                    AS sr
                WHERE ${whereClause}
                ORDER BY
                    sr.display_order ASC,
                    sr.name ASC,
                    sr.id ASC
                `,
                parameters
            );

        return rows.map(
            mapSupportResource
        );
    }

    const [countRows] =
        await pool.execute(
            `
            SELECT COUNT(*) AS total
            FROM support_resources AS sr
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
                sr.*,
                au.full_name AS
                    updated_by_admin_name
            FROM support_resources AS sr
            LEFT JOIN admin_users AS au
                ON au.id =
                    sr.updated_by_admin_id
            WHERE ${whereClause}
            ORDER BY
                sr.display_order ASC,
                sr.name ASC,
                sr.id ASC
            LIMIT ${options.limit}
            OFFSET ${offset}
            `,
            parameters
        );

    const total =
        Number(countRows[0].total || 0);

    return {
        resources:
            rows.map(
                mapSupportResource
            ),

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

async function getSupportResourceById(
    resourceId
) {
    const [rows] =
        await pool.execute(
            `
            SELECT
                sr.*,
                au.full_name AS
                    updated_by_admin_name
            FROM support_resources AS sr
            LEFT JOIN admin_users AS au
                ON au.id =
                    sr.updated_by_admin_id
            WHERE sr.id = ?
            LIMIT 1
            `,
            [resourceId]
        );

    if (!rows[0]) {
        throw new AppError(
            404,
            'Support resource was not found.'
        );
    }

    return mapSupportResource(
        rows[0]
    );
}

async function createSupportResource(
    adminId,
    resourceData,
    context
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        const [result] =
            await connection.execute(
                `
                INSERT INTO support_resources (
                    country_code,
                    region_name,
                    resource_type,
                    name,
                    description,
                    phone_number,
                    website_url,
                    availability_text,
                    supported_languages,
                    is_active,
                    display_order,
                    updated_by_admin_id
                )
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?
                )
                `,
                [
                    resourceData.country_code,
                    resourceData.region_name,
                    resourceData.resource_type,
                    resourceData.name,
                    resourceData.description,
                    resourceData.phone_number,
                    resourceData.website_url,
                    resourceData
                        .availability_text,

                    resourceData
                        .supported_languages ===
                    null
                        ? null
                        : JSON.stringify(
                            resourceData
                                .supported_languages
                        ),

                    Number(
                        resourceData.is_active
                    ),

                    resourceData.display_order,
                    adminId
                ]
            );

        await insertAudit(
            connection,
            {
                adminId,
                action:
                    'support_resource_created',
                entityType:
                    'support_resource',
                entityId:
                    result.insertId,
                oldValues: null,
                newValues:
                    resourceData,
                metadata: null,
                context
            }
        );

        await connection.commit();

        return getSupportResourceById(
            result.insertId
        );
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

async function updateSupportResource(
    adminId,
    resourceId,
    resourceData,
    context
) {
    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        const [rows] =
            await connection.execute(
                `
                SELECT *
                FROM support_resources
                WHERE id = ?
                LIMIT 1
                FOR UPDATE
                `,
                [resourceId]
            );

        const current = rows[0];

        if (!current) {
            throw new AppError(
                404,
                'Support resource was not found.'
            );
        }

        const fields = [];
        const values = [];

        for (
            const [key, value]
            of Object.entries(resourceData)
        ) {
            fields.push(`${key} = ?`);

            if (
                key ===
                'supported_languages'
            ) {
                values.push(
                    value === null
                        ? null
                        : JSON.stringify(value)
                );
            } else if (
                key === 'is_active'
            ) {
                values.push(
                    Number(value)
                );
            } else {
                values.push(value);
            }
        }

        fields.push(
            'updated_by_admin_id = ?'
        );

        values.push(adminId);
        values.push(resourceId);

        await connection.execute(
            `
            UPDATE support_resources
            SET ${fields.join(', ')}
            WHERE id = ?
            `,
            values
        );

        await insertAudit(
            connection,
            {
                adminId,
                action:
                    'support_resource_updated',
                entityType:
                    'support_resource',
                entityId:
                    resourceId,
                oldValues: {
                    country_code:
                        current.country_code,
                    region_name:
                        current.region_name,
                    resource_type:
                        current.resource_type,
                    name:
                        current.name,
                    is_active:
                        booleanValue(
                            current.is_active
                        ),
                    display_order:
                        Number(
                            current
                                .display_order
                        )
                },
                newValues:
                    resourceData,
                metadata: null,
                context
            }
        );

        await connection.commit();

        return getSupportResourceById(
            resourceId
        );
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

module.exports = {
    listContents,
    getContentById,
    createContent,
    updateContent,
    listPublicContents,
    getPublicContent,
    listSupportResources,
    getSupportResourceById,
    createSupportResource,
    updateSupportResource
};
