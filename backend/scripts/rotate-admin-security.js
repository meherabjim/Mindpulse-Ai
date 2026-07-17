require('dotenv').config();

const fs = require('fs');
const crypto = require('crypto');
const bcrypt = require('bcrypt');

const database =
    require('../src/config/database');

const pool =
    database.pool || database;

async function rotateSecurity() {
    const email =
        process.env.RESET_ADMIN_EMAIL
            ?.trim()
            .toLowerCase();

    const password =
        process.env.RESET_ADMIN_PASSWORD;

    if (
        !email ||
        !password ||
        password.length < 12 ||
        password.length > 128
    ) {
        throw new Error(
            'A valid admin email and 12–128 character password are required.'
        );
    }

    const envPath = '.env';

    let envContent =
        fs.readFileSync(
            envPath,
            'utf8'
        );

    const newJwtSecret =
        crypto
            .randomBytes(64)
            .toString('hex');

    if (
        /^ADMIN_JWT_ACCESS_SECRET=/m.test(
            envContent
        )
    ) {
        envContent =
            envContent.replace(
                /^ADMIN_JWT_ACCESS_SECRET=.*$/m,
                `ADMIN_JWT_ACCESS_SECRET=${newJwtSecret}`
            );
    } else {
        envContent +=
            `\nADMIN_JWT_ACCESS_SECRET=${newJwtSecret}\n`;
    }

    fs.writeFileSync(
        envPath,
        envContent,
        'utf8'
    );

    const rounds =
        Number(
            process.env.ADMIN_BCRYPT_ROUNDS ||
            12
        );

    const passwordHash =
        await bcrypt.hash(
            password,
            rounds
        );

    const connection =
        await pool.getConnection();

    try {
        await connection.beginTransaction();

        const [adminRows] =
            await connection.execute(
                `
                SELECT id
                FROM admin_users
                WHERE
                    email = ?
                    AND deleted_at IS NULL
                LIMIT 1
                FOR UPDATE
                `,
                [email]
            );

        const admin =
            adminRows[0];

        if (!admin) {
            throw new Error(
                'Admin account was not found.'
            );
        }

        await connection.execute(
            `
            UPDATE admin_users
            SET
                password_hash = ?,
                account_status = 'active'
            WHERE id = ?
            `,
            [
                passwordHash,
                admin.id
            ]
        );

        await connection.execute(
            `
            UPDATE admin_refresh_tokens
            SET revoked_at =
                COALESCE(
                    revoked_at,
                    CURRENT_TIMESTAMP
                )
            WHERE
                admin_user_id = ?
                AND revoked_at IS NULL
            `,
            [admin.id]
        );

        await connection.commit();

        console.log(
            'Admin password, JWT secret, and refresh sessions rotated successfully.'
        );
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

rotateSecurity()
    .catch((error) => {
        console.error(
            'Security rotation failed:',
            error.message
        );

        process.exitCode = 1;
    })
    .finally(async () => {
        if (
            pool &&
            typeof pool.end === 'function'
        ) {
            await pool.end();
        }
    });
