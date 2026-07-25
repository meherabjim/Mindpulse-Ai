const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const bcrypt = require('bcrypt');
const mysql = require('mysql2/promise');

const CONFIRMATION_PHRASE =
  'RESET ALL MINDPULSE DATA';

const RESET_LOCK =
  'mindpulse_admin_factory_reset';

const PRESERVED_TABLES = new Set([
  'admin_users',
  'app_contents',
  'badges',
  'habit_templates',
  'levels',
  'notification_templates',
  'recovery_activities',
  'support_resources',
  'wellness_questions',
  'migrations',
  'schema_migrations',
  'knex_migrations',
  'knex_migrations_lock',
  'sequelize_meta'
]);

function environmentValue(
  names,
  fallback = ''
) {
  for (const name of names) {
    const value = process.env[name];

    if (
      value !== undefined &&
      String(value).trim() !== ''
    ) {
      return String(value).trim();
    }
  }

  return fallback;
}

function databaseConfig() {
  return {
    host: environmentValue(
      ['DB_HOST', 'MYSQL_HOST'],
      '127.0.0.1'
    ),

    port: Number(
      environmentValue(
        ['DB_PORT', 'MYSQL_PORT'],
        '3306'
      )
    ),

    user: environmentValue(
      ['DB_USER', 'MYSQL_USER'],
      'root'
    ),

    password: environmentValue(
      ['DB_PASSWORD', 'MYSQL_PASSWORD'],
      ''
    ),

    database: environmentValue(
      [
        'DB_NAME',
        'DB_DATABASE',
        'MYSQL_DATABASE'
      ],
      'mindpulse_ai'
    )
  };
}

function resetEnabled() {
  if (process.env.NODE_ENV !== 'production') {
    return true;
  }

  return (
    process.env.ALLOW_ADMIN_FACTORY_RESET ===
    'true'
  );
}

function createHttpError(
  statusCode,
  message
) {
  const error = new Error(message);

  error.statusCode = statusCode;

  return error;
}

function sendError(
  response,
  error
) {
  const statusCode =
    Number(error.statusCode) || 500;

  response.status(statusCode).json({
    success: false,
    message: error.message ||
      'Factory reset failed.'
  });
}

function escapeIdentifier(value) {
  return String(value).replace(/`/g, '``');
}

function adminIdentity(request) {
  const candidates = [
    request.admin,
    request.adminUser,
    request.auth,
    request.user
  ].filter(Boolean);

  for (const candidate of candidates) {
    const id =
      candidate.id ??
      candidate.adminId ??
      candidate.admin_id ??
      candidate.adminUserId ??
      candidate.admin_user_id ??
      candidate.sub;

    const email =
      candidate.email ??
      candidate.adminEmail ??
      candidate.admin_email;

    if (id || email) {
      return {
        id: id || null,
        email: email || null
      };
    }
  }

  return {
    id:
      request.adminId ??
      request.admin_id ??
      null,

    email:
      request.adminEmail ??
      request.admin_email ??
      null
  };
}

async function createConnection() {
  return mysql.createConnection(
    databaseConfig()
  );
}

async function loadCurrentAdmin(
  connection,
  request
) {
  const identity =
    adminIdentity(request);

  let rows = [];

  if (identity.id) {
    [rows] = await connection.execute(
      `
        SELECT
          id,
          email,
          role,
          password_hash
        FROM admin_users
        WHERE id = ?
        LIMIT 1
      `,
      [identity.id]
    );
  } else if (identity.email) {
    [rows] = await connection.execute(
      `
        SELECT
          id,
          email,
          role,
          password_hash
        FROM admin_users
        WHERE email = ?
        LIMIT 1
      `,
      [identity.email]
    );
  }

  if (!rows.length) {
    throw createHttpError(
      401,
      'Authenticated Admin account was not found.'
    );
  }

  const admin = rows[0];

  if (admin.role !== 'super_admin') {
    throw createHttpError(
      403,
      'Only a Super Admin can run Factory Reset.'
    );
  }

  return admin;
}

async function loadAllTables(
  connection
) {
  const config =
    databaseConfig();

  const [rows] =
    await connection.execute(
      `
        SELECT
          TABLE_NAME AS table_name
        FROM information_schema.TABLES
        WHERE
          TABLE_SCHEMA = ?
          AND TABLE_TYPE = 'BASE TABLE'
        ORDER BY TABLE_NAME
      `,
      [config.database]
    );

  return rows.map(
    (row) => row.table_name
  );
}

async function countRows(
  connection,
  tableName
) {
  const escaped =
    escapeIdentifier(tableName);

  const [rows] =
    await connection.query(
      `
        SELECT COUNT(*) AS total
        FROM \`${escaped}\`
      `
    );

  return Number(rows[0].total);
}

async function findPreservedDependencies(
  connection,
  resetTables
) {
  const config =
    databaseConfig();

  const [rows] =
    await connection.execute(
      `
        SELECT
          TABLE_NAME AS child_table,
          COLUMN_NAME AS child_column,
          REFERENCED_TABLE_NAME AS parent_table,
          REFERENCED_COLUMN_NAME AS parent_column
        FROM information_schema.KEY_COLUMN_USAGE
        WHERE
          TABLE_SCHEMA = ?
          AND REFERENCED_TABLE_NAME IS NOT NULL
      `,
      [config.database]
    );

  const resetSet =
    new Set(resetTables);

  return rows.filter((relation) =>
    PRESERVED_TABLES.has(
      relation.child_table
    ) &&
    resetSet.has(
      relation.parent_table
    )
  );
}

async function buildResetPlan(
  connection
) {
  const allTables =
    await loadAllTables(connection);

  if (!allTables.includes('admin_users')) {
    throw createHttpError(
      500,
      'The admin_users table was not found.'
    );
  }

  const preservedTables =
    allTables.filter((tableName) =>
      PRESERVED_TABLES.has(tableName)
    );

  const resetTables =
    allTables.filter((tableName) =>
      !PRESERVED_TABLES.has(tableName)
    );

  const dependencyProblems =
    await findPreservedDependencies(
      connection,
      resetTables
    );

  if (dependencyProblems.length) {
    const description =
      dependencyProblems
        .map((item) =>
          `${item.child_table}.${item.child_column}` +
          ` -> ${item.parent_table}.${item.parent_column}`
        )
        .join(', ');

    throw createHttpError(
      409,
      'Factory Reset blocked by protected table dependencies: ' +
      description
    );
  }

  const resetDetails = [];

  for (const tableName of resetTables) {
    resetDetails.push({
      table: tableName,
      rows:
        await countRows(
          connection,
          tableName
        )
    });
  }

  const preservedDetails = [];

  for (const tableName of preservedTables) {
    preservedDetails.push({
      table: tableName,
      rows:
        await countRows(
          connection,
          tableName
        )
    });
  }

  const totalRows =
    resetDetails.reduce(
      (total, item) =>
        total + item.rows,
      0
    );

  return {
    confirmationPhrase:
      CONFIRMATION_PHRASE,

    totalRows,
    resetTables: resetDetails,
    preservedTables: preservedDetails,

    safeguards: {
      superAdminOnly: true,
      passwordRequired: true,
      sqlBackupRequired: true,
      adminUsersPreserved: true,
      resetEnabled:
        resetEnabled()
    }
  };
}

function runProcess(
  executable,
  argumentsList,
  environment
) {
  return new Promise(
    (resolve, reject) => {
      const child = spawn(
        executable,
        argumentsList,
        {
          env: environment,
          windowsHide: true
        }
      );

      let errorOutput = '';

      child.stderr.on(
        'data',
        (chunk) => {
          errorOutput +=
            chunk.toString();
        }
      );

      child.on(
        'error',
        reject
      );

      child.on(
        'close',
        (exitCode) => {
          if (exitCode === 0) {
            resolve();
            return;
          }

          reject(
            new Error(
              errorOutput.trim() ||
              `mysqldump exited with code ${exitCode}.`
            )
          );
        }
      );
    }
  );
}

async function createSqlBackup() {
  const config =
    databaseConfig();

  const dumpTool =
    environmentValue(
      ['MINDPULSE_MYSQLDUMP_PATH'],
      'C:\\xampp\\mysql\\bin\\mysqldump.exe'
    );

  if (!fs.existsSync(dumpTool)) {
    throw createHttpError(
      503,
      'MySQL backup tool was not found.'
    );
  }

  const backendRoot =
    path.resolve(__dirname, '../..');

  const backupDirectory =
    path.join(
      backendRoot,
      'backups',
      'admin-resets'
    );

  fs.mkdirSync(
    backupDirectory,
    {
      recursive: true
    }
  );

  const timestamp =
    new Date()
      .toISOString()
      .replace(/[:.]/g, '-');

  const backupFile =
    path.join(
      backupDirectory,
      `mindpulse-before-factory-reset-${timestamp}.sql`
    );

  const argumentsList = [
    `--host=${config.host}`,
    `--port=${config.port}`,
    `--user=${config.user}`,
    '--protocol=tcp',
    '--single-transaction',
    '--quick',
    '--skip-lock-tables',
    '--default-character-set=utf8mb4',
    `--result-file=${backupFile}`,
    config.database
  ];

  await runProcess(
    dumpTool,
    argumentsList,
    {
      ...process.env,
      MYSQL_PWD: config.password
    }
  );

  const statistics =
    fs.statSync(backupFile);

  if (statistics.size < 100) {
    throw createHttpError(
      500,
      'Database backup file is empty or invalid.'
    );
  }

  return {
    absolutePath: backupFile,

    relativePath:
      path.relative(
        backendRoot,
        backupFile
      ),

    sizeBytes:
      statistics.size,

    backupDirectory
  };
}

function writeResetReceipt(
  backup,
  admin,
  resetResult,
  request
) {
  const timestamp =
    new Date().toISOString();

  const safeTimestamp =
    timestamp.replace(/[:.]/g, '-');

  const receiptFile =
    path.join(
      backup.backupDirectory,
      `factory-reset-receipt-${safeTimestamp}.json`
    );

  const receipt = {
    resetAt: timestamp,

    admin: {
      id: admin.id,
      email: admin.email,
      role: admin.role
    },

    client: {
      ipAddress:
        request.ip || null,

      userAgent:
        request.get('user-agent') || null
    },

    backup: {
      file: backup.relativePath,
      sizeBytes: backup.sizeBytes
    },

    deletedRows:
      resetResult.totalDeletedRows,

    deletedTables:
      resetResult.deletedTables,

    adminInformationPreserved: true
  };

  try {
    fs.writeFileSync(
      receiptFile,
      JSON.stringify(
        receipt,
        null,
        2
      ),
      'utf8'
    );

    return path.relative(
      path.resolve(__dirname, '../..'),
      receiptFile
    );
  } catch {
    return null;
  }
}

async function performReset(
  connection,
  plan
) {
  const deletedTables = [];
  let totalDeletedRows = 0;

  await connection.query(
    'SET FOREIGN_KEY_CHECKS = 0'
  );

  for (
    const item of
    plan.resetTables
  ) {
    const escaped =
      escapeIdentifier(item.table);

    const [result] =
      await connection.query(
        `DELETE FROM \`${escaped}\``
      );

    const deletedRows =
      Number(result.affectedRows || 0);

    deletedTables.push({
      table: item.table,
      rows: deletedRows
    });

    totalDeletedRows += deletedRows;
  }

  await connection.query(
    'SET FOREIGN_KEY_CHECKS = 1'
  );

  return {
    deletedTables,
    totalDeletedRows
  };
}

async function previewFactoryReset(
  request,
  response
) {
  if (!resetEnabled()) {
    response.status(403).json({
      success: false,
      message:
        'Factory Reset is disabled in production.'
    });

    return;
  }

  let connection;

  try {
    connection =
      await createConnection();

    await loadCurrentAdmin(
      connection,
      request
    );

    const plan =
      await buildResetPlan(connection);

    response.json({
      success: true,
      message:
        'Factory Reset preview generated.',
      data: plan
    });
  } catch (error) {
    sendError(response, error);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

async function executeFactoryReset(
  request,
  response
) {
  if (!resetEnabled()) {
    response.status(403).json({
      success: false,
      message:
        'Factory Reset is disabled in production.'
    });

    return;
  }

  const password =
    typeof request.body?.password ===
      'string'
      ? request.body.password
      : '';

  const confirmationPhrase =
    typeof request.body?.confirmationPhrase ===
      'string'
      ? request.body.confirmationPhrase.trim()
      : '';

  if (!password) {
    response.status(400).json({
      success: false,
      message:
        'Admin password is required.'
    });

    return;
  }

  if (
    confirmationPhrase !==
    CONFIRMATION_PHRASE
  ) {
    response.status(400).json({
      success: false,
      message:
        'Confirmation phrase is incorrect.'
    });

    return;
  }

  let connection;
  let lockAcquired = false;
  let transactionStarted = false;

  try {
    connection =
      await createConnection();

    const [lockRows] =
      await connection.execute(
        'SELECT GET_LOCK(?, 0) AS acquired',
        [RESET_LOCK]
      );

    lockAcquired =
      Number(lockRows[0].acquired) === 1;

    if (!lockAcquired) {
      throw createHttpError(
        409,
        'Another Factory Reset is already running.'
      );
    }

    const admin =
      await loadCurrentAdmin(
        connection,
        request
      );

    const passwordMatches =
      await bcrypt.compare(
        password,
        admin.password_hash
      );

    if (!passwordMatches) {
      throw createHttpError(
        401,
        'Admin password is incorrect.'
      );
    }

    const plan =
      await buildResetPlan(connection);

    const backup =
      await createSqlBackup();

    await connection.beginTransaction();
    transactionStarted = true;

    const resetResult =
      await performReset(
        connection,
        plan
      );

    await connection.commit();
    transactionStarted = false;

    const [adminRows] =
      await connection.execute(
        `
          SELECT
            id,
            email,
            role
          FROM admin_users
          WHERE id = ?
          LIMIT 1
        `,
        [admin.id]
      );

    if (!adminRows.length) {
      throw createHttpError(
        500,
        'Admin preservation check failed.'
      );
    }

    const receiptFile =
      writeResetReceipt(
        backup,
        admin,
        resetResult,
        request
      );

    response.json({
      success: true,
      message:
        'MindPulse Factory Reset completed.',

      data: {
        deletedRows:
          resetResult.totalDeletedRows,

        deletedTables:
          resetResult.deletedTables,

        backupFile:
          backup.relativePath,

        backupSizeBytes:
          backup.sizeBytes,

        receiptFile,

        adminInformationPreserved: true,
        referenceDataPreserved: true,
        allSessionsRevoked: true
      }
    });
  } catch (error) {
    if (connection) {
      try {
        await connection.query(
          'SET FOREIGN_KEY_CHECKS = 1'
        );
      } catch {
        // Continue cleanup.
      }
    }

    if (
      connection &&
      transactionStarted
    ) {
      try {
        await connection.rollback();
      } catch {
        // Preserve original error.
      }
    }

    sendError(response, error);
  } finally {
    if (
      connection &&
      lockAcquired
    ) {
      try {
        await connection.execute(
          'SELECT RELEASE_LOCK(?)',
          [RESET_LOCK]
        );
      } catch {
        // Continue connection cleanup.
      }
    }

    if (connection) {
      await connection.end();
    }
  }
}

module.exports = {
  previewFactoryReset,
  executeFactoryReset
};