const fs =
    require('fs');

const path =
    require('path');

const mysql =
    require('mysql2/promise');


require('dotenv').config({
    path: path.resolve(
        __dirname,
        '..',
        '.env'
    ),
    override: true
});


async function run() {
    const sqlPath =
        path.resolve(
            __dirname,
            '..',
            '..',
            'database',
            'recommendation_sessions.sql'
        );

    const sql =
        fs.readFileSync(
            sqlPath,
            'utf8'
        );

    const connection =
        await mysql.createConnection({
            host:
                process.env.DB_HOST ||
                '127.0.0.1',

            port:
                Number(
                    process.env.DB_PORT ||
                    3306
                ),

            user:
                process.env.DB_USER ||
                'root',

            password:
                process.env.DB_PASSWORD ||
                '',

            database:
                process.env.DB_NAME ||
                'mindpulse_ai',

            charset:
                'utf8mb4',

            multipleStatements:
                true
        });

    try {
        await connection.query(
            sql
        );

        const [rows] =
            await connection.execute(
                `
                SELECT
                    COUNT(*) AS column_count

                FROM information_schema.columns

                WHERE
                    table_schema =
                        DATABASE()

                    AND table_name =
                        'recommendation_sessions'
                `
            );

        console.log(
            'Recommendation session migration completed.'
        );

        console.log(
            'Table: recommendation_sessions'
        );

        console.log(
            'Column count:',
            Number(
                rows[0].column_count
            )
        );
    } finally {
        await connection.end();
    }
}


run().catch((error) => {
    console.error(
        'Recommendation session migration failed.'
    );

    console.error(
        error.message
    );

    process.exit(1);
});
