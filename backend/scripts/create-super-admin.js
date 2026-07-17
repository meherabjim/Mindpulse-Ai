require('dotenv').config();

const bcrypt = require('bcrypt');
const database =
    require('../src/config/database');

const pool = database.pool || database;

async function createSuperAdmin() {
    const fullName =
        process.env.SUPER_ADMIN_NAME;

    const email =
        process.env.SUPER_ADMIN_EMAIL
            ?.trim()
            .toLowerCase();

    const password =
        process.env.SUPER_ADMIN_PASSWORD;

    if (!fullName || !email || !password) {
        throw new Error(
            'SUPER_ADMIN_NAME, SUPER_ADMIN_EMAIL and SUPER_ADMIN_PASSWORD are required.'
        );
    }

    if (password.length < 12) {
        throw new Error(
            'Super Admin password must contain at least 12 characters.'
        );
    }

    const [existingRows] =
        await pool.execute(
            `
            SELECT id, email
            FROM admin_users
            WHERE email = ?
            LIMIT 1
            `,
            [email]
        );

    if (existingRows[0]) {
        console.log(
            `Admin already exists: ${email}`
        );

        return;
    }

    const rounds =
        Number(
            process.env
                .ADMIN_BCRYPT_ROUNDS ||
            12
        );

    const passwordHash =
        await bcrypt.hash(
            password,
            rounds
        );

    const [result] =
        await pool.execute(
            `
            INSERT INTO admin_users (
                full_name,
                email,
                password_hash,
                role,
                account_status
            )
            VALUES (
                ?,
                ?,
                ?,
                'super_admin',
                'active'
            )
            `,
            [
                fullName,
                email,
                passwordHash
            ]
        );

    console.log(
        'Super Admin created successfully.'
    );

    console.log({
        id: Number(result.insertId),
        full_name: fullName,
        email,
        role: 'super_admin'
    });
}

createSuperAdmin()
    .catch((error) => {
        console.error(
            'Super Admin creation failed:',
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
