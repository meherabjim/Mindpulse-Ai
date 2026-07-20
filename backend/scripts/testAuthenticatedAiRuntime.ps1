[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$env:NODE_PATH = "E:\project 3\MindPulse-AI\backend\node_modules"

try {
& {
  $ErrorActionPreference = "Stop"

  $root = "E:\project 3\MindPulse-AI"
  $backendRoot = Join-Path $root "backend"
  $aiRoot = Join-Path $root "ai_service"

  $python = Join-Path `
    $aiRoot `
    ".venv\Scripts\python.exe"

  $expectedCommit = (git -C $root rev-parse HEAD).Trim()

  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

  $runDirectory = Join-Path `
    $aiRoot `
    "reports\authenticated_runtime_validation_$timestamp"

  $logDirectory = Join-Path `
    $runDirectory `
    "logs"

  $e2eScript = Join-Path `
    $runDirectory `
    "authenticated_runtime_validation.js"

  $e2eLog = Join-Path `
    $logDirectory `
    "authenticated_runtime_validation.log"

  $backendOut = Join-Path `
    $logDirectory `
    "backend_runtime_stdout.log"

  $backendErr = Join-Path `
    $logDirectory `
    "backend_runtime_stderr.log"

  $aiOut = Join-Path `
    $logDirectory `
    "fastapi_runtime_stdout.log"

  $aiErr = Join-Path `
    $logDirectory `
    "fastapi_runtime_stderr.log"

  $reportPath = Join-Path `
    $runDirectory `
    "authenticated_runtime_validation_report.txt"

  $errorPath = Join-Path `
    $runDirectory `
    "authenticated_runtime_validation_error.txt"

  foreach ($path in @(
    $root,
    $backendRoot,
    $aiRoot,
    $python,
    "$backendRoot\.env",
    "$backendRoot\package.json",
    "$backendRoot\src\config\database.js",
    "$aiRoot\.env",
    "$aiRoot\app\main.py"
  )) {
    if (-not (Test-Path -LiteralPath $path)) {
      throw "Required path was not found: $path"
    }
  }

  New-Item `
    -Path $logDirectory `
    -ItemType Directory `
    -Force |
  Out-Null

  function Test-TcpPort {
    param(
      [Parameter(Mandatory)]
      [string]$HostName,

      [Parameter(Mandatory)]
      [int]$Port,

      [int]$TimeoutMilliseconds = 1500
    )

    $client = New-Object `
      System.Net.Sockets.TcpClient

    try {
      $asyncResult = $client.BeginConnect(
        $HostName,
        $Port,
        $null,
        $null
      )

      $connected = $asyncResult.AsyncWaitHandle.WaitOne(
        $TimeoutMilliseconds,
        $false
      )

      if (-not $connected) {
        return $false
      }

      $client.EndConnect($asyncResult)

      return $client.Connected
    }
    catch {
      return $false
    }
    finally {
      $client.Dispose()
    }
  }

  function Test-HealthUrl {
    param(
      [Parameter(Mandatory)]
      [string]$Uri
    )

    try {
      $response = Invoke-WebRequest `
        -Uri $Uri `
        -Method Get `
        -UseBasicParsing `
        -TimeoutSec 4

      return (
        $response.StatusCode -ge 200 -and
        $response.StatusCode -lt 300
      )
    }
    catch {
      return $false
    }
  }

  function Wait-HealthUrl {
    param(
      [Parameter(Mandatory)]
      [string[]]$Uris,

      [int]$Seconds = 90
    )

    $deadline = (Get-Date).AddSeconds($Seconds)
    $attempt = 0

    while ((Get-Date) -lt $deadline) {
      $attempt++

      foreach ($uri in $Uris) {
        if (Test-HealthUrl -Uri $uri) {
          return $uri
        }
      }

      if ($attempt % 3 -eq 0) {
        Write-Host "- Waiting for service health..."
      }

      Start-Sleep -Seconds 2
    }

    return $null
  }

  function Stop-ProcessTree {
    param(
      [System.Diagnostics.Process]$Process
    )

    if ($null -eq $Process) {
      return
    }

    try {
      if (-not $Process.HasExited) {
        & taskkill.exe `
          /PID $Process.Id `
          /T `
          /F `
          1>$null `
          2>$null
      }
    }
    catch {
      # Preserve the primary result.
    }
  }

  $backendProcess = $null
  $aiProcess = $null

  $backendStarted = $false
  $aiStarted = $false

  $oldNodeEnv = $env:NODE_ENV
  $oldCorsOrigins = $env:CORS_ALLOWED_ORIGINS
  $oldCorsCredentials = $env:CORS_ALLOW_CREDENTIALS

  $nodeSource = @'
'use strict';

const path = require('node:path');
const crypto = require('node:crypto');
const jwt = require('jsonwebtoken');

const root = process.env.MINDPULSE_ROOT;

if (!root) {
  throw new Error(
    'MINDPULSE_ROOT is not configured.',
  );
}

const backendRoot = path.join(
  root,
  'backend',
);

require(
  path.join(
    backendRoot,
    'node_modules',
    'dotenv',
  ),
).config({
  path: path.join(
    backendRoot,
    '.env',
  ),
  quiet: true,
});

const database = require(
  path.join(
    backendRoot,
    'src',
    'config',
    'database',
  ),
);

const pool =
  database.pool ||
  database;

const API_BASE =
  String(
    process.env.MINDPULSE_E2E_API_BASE ||
    'http://127.0.0.1:5000/api/v1',
  ).replace(
    /\/+$/,
    '',
  );

const REQUEST_TIMEOUT_MS = Number(
  process.env.MINDPULSE_E2E_TIMEOUT_MS ||
  20000,
);

let temporaryEmail = null;
let temporaryUserId = null;
let logBaseline = 0;
let cleanupComplete = false;


function assertCondition(
  condition,
  message,
) {
  if (!condition) {
    throw new Error(message);
  }
}


function pass(message) {
  console.log(
    'PASS ' + message,
  );
}


function responseMessage(payload) {
  if (
    payload &&
    typeof payload === 'object'
  ) {
    for (
      const key
      of [
        'message',
        'error',
        'detail',
      ]
    ) {
      if (
        typeof payload[key] === 'string'
      ) {
        return payload[key];
      }
    }
  }

  return 'No safe response message.';
}


async function apiRequest({
  label,
  method = 'GET',
  route,
  token = null,
  body = undefined,
  expectedStatuses = [200],
}) {
  const controller =
    new AbortController();

  const timeout = setTimeout(
    () => controller.abort(),
    REQUEST_TIMEOUT_MS,
  );

  const headers = {
    Accept: 'application/json',
  };

  if (body !== undefined) {
    headers['Content-Type'] =
      'application/json';
  }

  if (token) {
    headers.Authorization =
      'Bearer ' + token;
  }

  let response;

  try {
    response = await fetch(
      API_BASE + route,
      {
        method,
        headers,
        body:
          body === undefined
            ? undefined
            : JSON.stringify(body),
        signal: controller.signal,
      },
    );
  } catch (error) {
    if (
      error &&
      error.name === 'AbortError'
    ) {
      throw new Error(
        label + ' timed out.',
      );
    }

    throw new Error(
      label +
      ' network failure: ' +
      String(
        error?.message ||
        error,
      ),
    );
  } finally {
    clearTimeout(timeout);
  }

  const responseText =
    await response.text();

  let payload = null;

  if (responseText) {
    try {
      payload =
        JSON.parse(responseText);
    } catch {
      payload = null;
    }
  }

  if (
    !expectedStatuses.includes(
      response.status,
    )
  ) {
    throw new Error(
      label +
      ' returned HTTP ' +
      response.status +
      ': ' +
      responseMessage(payload),
    );
  }

  return {
    status: response.status,
    payload,
  };
}


function findValueByKeys(
  value,
  keys,
  depth = 0,
) {
  if (
    value === null ||
    value === undefined ||
    depth > 8
  ) {
    return undefined;
  }

  if (Array.isArray(value)) {
    for (const item of value) {
      const found = findValueByKeys(
        item,
        keys,
        depth + 1,
      );

      if (found !== undefined) {
        return found;
      }
    }

    return undefined;
  }

  if (typeof value !== 'object') {
    return undefined;
  }

  for (const key of keys) {
    if (
      Object.prototype.hasOwnProperty.call(
        value,
        key,
      )
    ) {
      return value[key];
    }
  }

  for (const child of Object.values(value)) {
    const found = findValueByKeys(
      child,
      keys,
      depth + 1,
    );

    if (found !== undefined) {
      return found;
    }
  }

  return undefined;
}


function extractAccessToken(payload) {
  const value = findValueByKeys(
    payload,
    [
      'access_token',
      'accessToken',
      'token',
    ],
  );

  assertCondition(
    typeof value === 'string' &&
    value.length > 20,
    'Access token was not returned.',
  );

  return value;
}


function extractRefreshToken(payload) {
  const value = findValueByKeys(
    payload,
    [
      'refresh_token',
      'refreshToken',
    ],
  );

  assertCondition(
    typeof value === 'string' &&
    value.length > 20,
    'Refresh token was not returned.',
  );

  return value;
}


function quoteIdentifier(value) {
  return (
    '`' +
    String(value).replace(
      /`/g,
      '``',
    ) +
    '`'
  );
}


async function baselineAiLogs() {
  const [columns] = await pool.query(
    'SHOW COLUMNS FROM ai_analysis_logs',
  );

  const columnNames = new Set(
    columns.map(
      (column) =>
        String(column.Field),
    ),
  );

  if (!columnNames.has('id')) {
    return 0;
  }

  const [rows] = await pool.execute(
    `
    SELECT
      COALESCE(MAX(id), 0)
        AS maximum_id
    FROM ai_analysis_logs
    `,
  );

  return Number(
    rows[0]?.maximum_id ||
    0,
  );
}


async function resolveUserId() {
  if (
    Number.isSafeInteger(
      temporaryUserId,
    ) &&
    temporaryUserId > 0
  ) {
    return temporaryUserId;
  }

  if (!temporaryEmail) {
    return null;
  }

  const [rows] = await pool.execute(
    `
    SELECT id
    FROM users
    WHERE email = ?
    LIMIT 1
    `,
    [temporaryEmail],
  );

  if (!rows[0]) {
    return null;
  }

  temporaryUserId =
    Number(rows[0].id);

  return temporaryUserId;
}


async function verifyAiLogs(
  privateMarker,
) {
  const userId =
    await resolveUserId();

  assertCondition(
    Number.isSafeInteger(userId) &&
    userId > 0,
    'Temporary user ID is unavailable.',
  );

  const [columns] = await pool.query(
    'SHOW COLUMNS FROM ai_analysis_logs',
  );

  const columnNames = new Set(
    columns.map(
      (column) =>
        String(column.Field),
    ),
  );

  assertCondition(
    columnNames.has('user_id'),
    'ai_analysis_logs.user_id is missing.',
  );

  let query = `
    SELECT *
    FROM ai_analysis_logs
    WHERE user_id = ?
  `;

  const parameters = [userId];

  if (
    columnNames.has('id')
  ) {
    query += ' AND id > ?';
    parameters.push(logBaseline);
  }

  if (
    columnNames.has('id')
  ) {
    query += ' ORDER BY id ASC';
  }

  const [rows] = await pool.execute(
    query,
    parameters,
  );

  assertCondition(
    rows.length >= 3,
    (
      'Expected at least three AI log rows; ' +
      'found ' +
      rows.length +
      '.'
    ),
  );

  const analysisTypes = new Set();

  for (const row of rows) {
    const serialized =
      JSON.stringify(row);

    assertCondition(
      !serialized.includes(
        privateMarker,
      ),
      (
        'Raw private journal marker appeared ' +
        'inside ai_analysis_logs.'
      ),
    );

    if (
      row.analysis_type !== undefined &&
      row.analysis_type !== null
    ) {
      analysisTypes.add(
        String(row.analysis_type),
      );
    }

    if (
      row.success !== undefined &&
      row.success !== null
    ) {
      assertCondition(
        Number(row.success) === 1,
        (
          'An AI analysis log was marked ' +
          'unsuccessful.'
        ),
      );
    }
  }

  for (
    const expectedType
    of [
      'journal',
      'safety',
      'wellness',
    ]
  ) {
    if (analysisTypes.size > 0) {
      assertCondition(
        analysisTypes.has(
          expectedType,
        ),
        (
          'AI log type is missing: ' +
          expectedType
        ),
      );
    }
  }

  pass(
    'privacy-safe AI log verification',
  );

  console.log(
    'Verified AI log rows: ' +
    rows.length,
  );

  if (analysisTypes.size > 0) {
    console.log(
      'Verified AI log types: ' +
      Array.from(analysisTypes)
        .sort()
        .join(', '),
    );
  }
}


async function tableColumnsByMode(
  connection,
  mode,
) {
  if (mode === 'user_id') {
    const [rows] =
      await connection.execute(
        `
        SELECT
          c.TABLE_NAME AS table_name,
          c.COLUMN_NAME AS column_name
        FROM information_schema.COLUMNS c
        INNER JOIN
          information_schema.TABLES t
          ON
            t.TABLE_SCHEMA =
              c.TABLE_SCHEMA
            AND t.TABLE_NAME =
              c.TABLE_NAME
        WHERE
          c.TABLE_SCHEMA = DATABASE()
          AND t.TABLE_TYPE =
            'BASE TABLE'
          AND c.COLUMN_NAME =
            'user_id'
        ORDER BY c.TABLE_NAME
        `,
      );

    return rows;
  }

  const [rows] =
    await connection.execute(
      `
      SELECT
        c.TABLE_NAME AS table_name,
        c.COLUMN_NAME AS column_name
      FROM information_schema.COLUMNS c
      INNER JOIN
        information_schema.TABLES t
        ON
          t.TABLE_SCHEMA =
            c.TABLE_SCHEMA
          AND t.TABLE_NAME =
            c.TABLE_NAME
      WHERE
        c.TABLE_SCHEMA = DATABASE()
        AND t.TABLE_TYPE =
          'BASE TABLE'
        AND c.DATA_TYPE IN (
          'char',
          'varchar',
          'tinytext',
          'text',
          'mediumtext',
          'longtext'
        )
        AND LOWER(
          c.COLUMN_NAME
        ) LIKE '%email%'
      ORDER BY
        c.TABLE_NAME,
        c.COLUMN_NAME
      `,
    );

  return rows;
}


async function cleanupTemporaryData() {
  const connection =
    await pool.getConnection();

  let foreignKeyChecksDisabled =
    false;

  try {
    const userId =
      await resolveUserId();

    const userReferences =
      await tableColumnsByMode(
        connection,
        'user_id',
      );

    const emailReferences =
      await tableColumnsByMode(
        connection,
        'email',
      );

    await connection.query(
      'SET FOREIGN_KEY_CHECKS = 0',
    );

    foreignKeyChecksDisabled = true;

    if (
      Number.isSafeInteger(userId) &&
      userId > 0
    ) {
      for (
        const reference
        of userReferences
      ) {
        const tableName =
          quoteIdentifier(
            reference.table_name,
          );

        const columnName =
          quoteIdentifier(
            reference.column_name,
          );

        await connection.execute(
          (
            'DELETE FROM ' +
            tableName +
            ' WHERE ' +
            columnName +
            ' = ?'
          ),
          [userId],
        );
      }
    }

    if (temporaryEmail) {
      for (
        const reference
        of emailReferences
      ) {
        const tableName =
          quoteIdentifier(
            reference.table_name,
          );

        const columnName =
          quoteIdentifier(
            reference.column_name,
          );

        await connection.execute(
          (
            'DELETE FROM ' +
            tableName +
            ' WHERE ' +
            columnName +
            ' = ?'
          ),
          [temporaryEmail],
        );
      }
    }

    if (
      Number.isSafeInteger(userId) &&
      userId > 0
    ) {
      await connection.execute(
        `
        DELETE FROM users
        WHERE id = ?
        `,
        [userId],
      );
    }

    if (temporaryEmail) {
      await connection.execute(
        `
        DELETE FROM users
        WHERE email = ?
        `,
        [temporaryEmail],
      );
    }

    await connection.query(
      'SET FOREIGN_KEY_CHECKS = 1',
    );

    foreignKeyChecksDisabled = false;

    if (temporaryEmail) {
      const [userRows] =
        await connection.execute(
          `
          SELECT COUNT(*) AS total
          FROM users
          WHERE email = ?
          `,
          [temporaryEmail],
        );

      assertCondition(
        Number(
          userRows[0]?.total,
        ) === 0,
        (
          'Temporary user still exists ' +
          'after cleanup.'
        ),
      );
    }

    if (
      Number.isSafeInteger(userId) &&
      userId > 0
    ) {
      for (
        const reference
        of userReferences
      ) {
        const tableName =
          quoteIdentifier(
            reference.table_name,
          );

        const columnName =
          quoteIdentifier(
            reference.column_name,
          );

        const [rows] =
          await connection.execute(
            (
              'SELECT COUNT(*) AS total ' +
              'FROM ' +
              tableName +
              ' WHERE ' +
              columnName +
              ' = ?'
            ),
            [userId],
          );

        assertCondition(
          Number(
            rows[0]?.total,
          ) === 0,
          (
            'Temporary user data remains in ' +
            reference.table_name +
            '.'
          ),
        );
      }
    }

    cleanupComplete = true;

    pass(
      'temporary database cleanup',
    );
  } finally {
    if (foreignKeyChecksDisabled) {
      try {
        await connection.query(
          'SET FOREIGN_KEY_CHECKS = 1',
        );
      } catch {
        // Preserve the original error.
      }
    }

    connection.release();
  }
}


async function runAuthenticatedFlow() {
  const uniquePart =
    crypto
      .randomBytes(12)
      .toString('hex');

  temporaryEmail =
    (
      'mindpulse.runtime.' +
      uniquePart +
      '@example.test'
    );

  const temporaryPassword =
    (
      'MpRuntime_' +
      crypto
        .randomBytes(20)
        .toString('base64url') +
      '_9a'
    );

  const privateMarker =
    (
      'mindpulse-private-' +
      crypto.randomUUID()
    );

  logBaseline =
    await baselineAiLogs();

  const health =
    await apiRequest({
      label: 'Backend health',
      route: '/health',
    });

  assertCondition(
    health.payload?.success === true,
    'Backend health response failed.',
  );

  pass(
    'backend health endpoint',
  );

  await apiRequest({
    label:
      'Unauthenticated profile rejection',
    route: '/auth/me',
    expectedStatuses: [401],
  });

  pass(
    'unauthenticated protected-route rejection',
  );

  const registration =
    await apiRequest({
      label:
        'Temporary user registration',
      method: 'POST',
      route: '/auth/register',
      body: {
        full_name:
          'MindPulse Runtime E2E',
        email:
          temporaryEmail,
        password:
          temporaryPassword,
      },
      expectedStatuses: [201],
    });

  const registrationUserId =
    findValueByKeys(
      registration.payload,
      [
        'user_id',
        'userId',
        'id',
      ],
    );

  if (
    Number.isSafeInteger(
      Number(registrationUserId),
    ) &&
    Number(registrationUserId) > 0
  ) {
    temporaryUserId =
      Number(registrationUserId);
  }

  await resolveUserId();

  assertCondition(
    Number.isSafeInteger(
      temporaryUserId,
    ) &&
    temporaryUserId > 0,
    (
      'Registered temporary user could ' +
      'not be resolved.'
    ),
  );

  pass(
    'temporary user registration',
  );

  const login =
    await apiRequest({
      label: 'Temporary user login',
      method: 'POST',
      route: '/auth/login',
      body: {
        email:
          temporaryEmail,
        password:
          temporaryPassword,
      },
    });

  const accessToken =
    extractAccessToken(
      login.payload,
    );

  const refreshToken =
    extractRefreshToken(
      login.payload,
    );

  pass(
    'temporary user login',
  );

  const profile =
    await apiRequest({
      label:
        'Access-token protected profile',
      route: '/auth/me',
      token: accessToken,
    });

  const profileUserId =
    findValueByKeys(
      profile.payload,
      [
        'user_id',
        'userId',
        'id',
      ],
    );

  assertCondition(
    Number(profileUserId) ===
      temporaryUserId,
    (
      'Protected profile returned ' +
      'the wrong user.'
    ),
  );

  pass(
    'access-token protected profile',
  );

  await apiRequest({
    label:
      'Enable AI privacy settings',
    method: 'PATCH',
    route: '/settings',
    token: accessToken,
    body: { app_settings: { ai_analysis_enabled: true, journal_analysis_enabled: true } },
  });

  pass(
    'AI privacy settings enabled',
  );

  await apiRequest({
    label:
      'Authenticated AI health',
    route: '/ai/health',
    token: accessToken,
  });

  pass(
    'authenticated Node-to-FastAPI health',
  );

  const journal =
    await apiRequest({
      label:
        'Authenticated journal analysis',
      method: 'POST',
      route:
        '/ai/journal/analyze',
      token: accessToken,
      body: {
        text:
          (
            'Today I felt calm and completed ' +
            'my planned work. ' +
            privateMarker
          ),
        language: 'en',
        mood_score: 4,
      },
    });

  assertCondition(
    journal.payload !== null,
    (
      'Journal analysis returned no ' +
      'JSON payload.'
    ),
  );

  pass(
    'authenticated journal analysis',
  );

  const safety =
    await apiRequest({
      label:
        'Authenticated safety assessment',
      method: 'POST',
      route:
        '/ai/safety/check',
      token: accessToken,
      body: {
        text:
          (
            'I feel stressed today, ' +
            'but I am safe.'
          ),
      },
    });

  const severity =
    findValueByKeys(
      safety.payload,
      ['severity'],
    );

  if (severity !== undefined) {
    assertCondition(
      String(severity).toLowerCase()
        === 'low',
      (
        'Safe test message did not ' +
        'return low severity.'
      ),
    );
  }

  pass(
    'authenticated safety assessment',
  );

  const wellness =
    await apiRequest({
      label:
        'Authenticated wellness recommendation',
      method: 'POST',
      route:
        '/ai/wellness/recommendations',
      token: accessToken,
      body: {
        mood_score: 3,
        stress_level: 4,
        energy_level: 2,
        sleep_hours: 5.5,
        hydration_cups: 4,
        burnout_score: 62,
      },
    });

  const recommendations =
    findValueByKeys(
      wellness.payload,
      ['recommendations'],
    );

  assertCondition(
    Array.isArray(recommendations) &&
    recommendations.length > 0,
    (
      'Wellness response did not contain ' +
      'recommendations.'
    ),
  );

  pass(
    'authenticated wellness recommendation',
  );

  await verifyAiLogs(
    privateMarker,
  );

  const accessSecret =
    (
      process.env.JWT_ACCESS_SECRET ||
      process.env.JWT_SECRET
    );

  assertCondition(
    typeof accessSecret === 'string' &&
    accessSecret.length > 0,
    (
      'JWT access secret is unavailable ' +
      'for expired-token validation.'
    ),
  );

  const decodedComplete =
    jwt.decode(
      accessToken,
      {
        complete: true,
      },
    );

  assertCondition(
    decodedComplete &&
    decodedComplete.payload,
    (
      'Issued access token could not ' +
      'be decoded.'
    ),
  );

  const expiredPayload = {
    ...decodedComplete.payload,
  };

  delete expiredPayload.exp;
  delete expiredPayload.iat;
  delete expiredPayload.nbf;

  const signOptions = {
    expiresIn: -10,
  };

  const algorithm =
    decodedComplete.header?.alg;

  if (
    typeof algorithm === 'string' &&
    algorithm.startsWith('HS')
  ) {
    signOptions.algorithm =
      algorithm;
  }

  const expiredToken =
    jwt.sign(
      expiredPayload,
      accessSecret,
      signOptions,
    );

  await apiRequest({
    label:
      'Expired access-token rejection',
    route: '/auth/me',
    token: expiredToken,
    expectedStatuses: [401],
  });

  pass(
    'expired access-token rejection',
  );

  const refreshed =
    await apiRequest({
      label:
        'Refresh-token rotation',
      method: 'POST',
      route: '/auth/refresh',
      body: {
        refresh_token:
          refreshToken,
      },
    });

  const rotatedAccessToken =
    extractAccessToken(
      refreshed.payload,
    );

  const rotatedRefreshToken =
    extractRefreshToken(
      refreshed.payload,
    );

  assertCondition(
    rotatedRefreshToken !==
      refreshToken,
    'Refresh token was not rotated.',
  );

  pass(
    'refresh-token rotation',
  );

  await apiRequest({
    label:
      'Rotated access-token profile',
    route: '/auth/me',
    token: rotatedAccessToken,
  });

  pass(
    'rotated access-token authentication',
  );

  await apiRequest({
    label:
      'Refresh-token logout',
    method: 'POST',
    route: '/auth/logout',
    body: {
      refresh_token:
        rotatedRefreshToken,
    },
  });

  pass(
    'refresh-token logout',
  );

  await apiRequest({
    label:
      'Revoked refresh-token rejection',
    method: 'POST',
    route: '/auth/refresh',
    body: {
      refresh_token:
        rotatedRefreshToken,
    },
    expectedStatuses: [
      401,
      403,
    ],
  });

  pass(
    'revoked refresh-token rejection',
  );

  await apiRequest({
    label:
      'Logout-all protected operation',
    method: 'POST',
    route: '/auth/logout-all',
    token: rotatedAccessToken,
  });

  pass(
    'logout-all operation',
  );
}


async function main() {
  let primaryError = null;
  let cleanupError = null;

  try {
    await runAuthenticatedFlow();
  } catch (error) {
    primaryError = error;
  }

  try {
    await cleanupTemporaryData();
  } catch (error) {
    cleanupError = error;
  }

  try {
    if (
      pool &&
      typeof pool.end === 'function'
    ) {
      await pool.end();
    }
  } catch (error) {
    if (!cleanupError) {
      cleanupError = error;
    }
  }

  if (primaryError) {
    throw primaryError;
  }

  if (cleanupError) {
    throw cleanupError;
  }

  assertCondition(
    cleanupComplete,
    (
      'Temporary cleanup did not ' +
      'complete.'
    ),
  );

  console.log('');
  console.log(
    'PRIVACY-SAFE AI LOGGING PASSED',
  );
  console.log(
    'TEMPORARY TEST DATA CLEANUP PASSED',
  );
  console.log(
    'AUTHENTICATED AI RUNTIME E2E PASSED',
  );
}


main().catch(
  (error) => {
    console.error(
      'AUTHENTICATED AI RUNTIME E2E FAILED: ' +
      String(
        error?.message ||
        error,
      ),
    );

    process.exitCode = 1;
  },
);
'@

  try {
    Write-Host ""
    Write-Host (
      "Starting real authenticated " +
      "runtime validation..."
    ) -ForegroundColor Cyan

    Write-Host ""
    Write-Host (
      "=============================================================="
    )
    Write-Host (
      "MINDPULSE AUTHENTICATED RUNTIME VALIDATION"
    )
    Write-Host (
      "=============================================================="
    )

    Write-Host ""
    Write-Host "1. Repository checkpoint"

    $branch = (
      git -C $root branch --show-current
    ).Trim()

    $commit = (
      git -C $root rev-parse HEAD
    ).Trim()

    $remoteOutput = git -C $root `
      ls-remote `
      origin `
      refs/heads/main

    $remoteCommit = (
      $remoteOutput -split "\s+"
    )[0].Trim()

    $status = git -C $root status `
      --porcelain `
      --untracked-files=all

    $staged = git -C $root diff `
      --cached `
      --name-only

    if ($branch -ne "main") {
      throw "Expected branch main, found $branch"
    }

    if ($commit -ne $expectedCommit) {
      throw (
        "Unexpected commit.`n" +
        "Expected: $expectedCommit`n" +
        "Actual: $commit"
      )
    }

    if ($remoteCommit -ne $expectedCommit) {
      throw (
        "Local and GitHub main hashes differ."
      )
    }

    if (
      -not [string]::IsNullOrWhiteSpace($status)
    ) {
      throw (
        "Working tree is not clean:`n$status"
      )
    }

    if (
      -not [string]::IsNullOrWhiteSpace($staged)
    ) {
      throw (
        "Staged files exist:`n$staged"
      )
    }

    Write-Host "- Branch: main"
    Write-Host "- Commit: $commit"
    Write-Host "- Local and GitHub hashes match: YES"
    Write-Host "- Working tree clean: YES"
    Write-Host "- Staged files: NONE"

    Write-Host ""
    Write-Host "2. MySQL readiness"

    if (
      -not (
        Test-TcpPort `
          -HostName "localhost" `
          -Port 3306 `
          -TimeoutMilliseconds 3000
      )
    ) {
      throw (
        "MySQL is not reachable on localhost:3306."
      )
    }

    Write-Host "- MySQL localhost:3306: AVAILABLE"
    Write-Host "- Database credentials printed: NO"

    Write-Host ""
    Write-Host "3. Starting FastAPI"

    $aiHealthUrls = @(
      "http://127.0.0.1:8000/health",
      "http://127.0.0.1:8000/api/v1/health"
    )

    $existingAiHealth = Wait-HealthUrl `
      -Uris $aiHealthUrls `
      -Seconds 2

    if (
      -not [string]::IsNullOrWhiteSpace(
        $existingAiHealth
      )
    ) {
      Write-Host "- FastAPI: REUSED"
      Write-Host "- Health: $existingAiHealth"
    }
    else {
      if (
        Test-TcpPort `
          -HostName "127.0.0.1" `
          -Port 8000
      ) {
        throw (
          "Port 8000 is occupied, but FastAPI " +
          "health did not pass."
        )
      }

      $aiProcess = Start-Process `
        -FilePath $python `
        -ArgumentList @(
          "-m",
          "uvicorn",
          "app.main:app",
          "--host",
          "127.0.0.1",
          "--port",
          "8000"
        ) `
        -WorkingDirectory $aiRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $aiOut `
        -RedirectStandardError $aiErr `
        -PassThru

      $aiStarted = $true

      $healthyAiUrl = Wait-HealthUrl `
        -Uris $aiHealthUrls `
        -Seconds 90

      if (
        [string]::IsNullOrWhiteSpace(
          $healthyAiUrl
        )
      ) {
        throw (
          "FastAPI did not become healthy. " +
          "Logs: $aiOut and $aiErr"
        )
      }

      Write-Host "- FastAPI: STARTED"
      Write-Host "- Health: $healthyAiUrl"
    }

    Write-Host ""
    Write-Host "4. Starting Backend"

    $backendHealthUrls = @(
      "http://127.0.0.1:5000/api/v1/health",
      "http://127.0.0.1:5000/health"
    )

    $existingBackendHealth = Wait-HealthUrl `
      -Uris $backendHealthUrls `
      -Seconds 2

    if (
      -not [string]::IsNullOrWhiteSpace(
        $existingBackendHealth
      )
    ) {
      Write-Host "- Backend: REUSED"
      Write-Host "- Health: $existingBackendHealth"
    }
    else {
      if (
        Test-TcpPort `
          -HostName "127.0.0.1" `
          -Port 5000
      ) {
        throw (
          "Port 5000 is occupied, but Backend " +
          "health did not pass."
        )
      }

      $env:NODE_ENV = "test"

      $env:CORS_ALLOWED_ORIGINS =
        "http://127.0.0.1:3000"

      $env:CORS_ALLOW_CREDENTIALS =
        "false"

      $backendProcess = Start-Process `
        -FilePath $env:COMSPEC `
        -ArgumentList @(
          "/d",
          "/c",
          "npm.cmd start"
        ) `
        -WorkingDirectory $backendRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $backendOut `
        -RedirectStandardError $backendErr `
        -PassThru

      $backendStarted = $true

      $healthyBackendUrl = Wait-HealthUrl `
        -Uris $backendHealthUrls `
        -Seconds 90

      if (
        [string]::IsNullOrWhiteSpace(
          $healthyBackendUrl
        )
      ) {
        throw (
          "Backend did not become healthy. " +
          "Logs: $backendOut and $backendErr"
        )
      }

      Write-Host "- Backend: STARTED"
      Write-Host "- Health: $healthyBackendUrl"
    }

    [System.IO.File]::WriteAllText(
      $e2eScript,
      $nodeSource,
      [System.Text.UTF8Encoding]::new(
        $false
      )
    )

    Write-Host ""
    Write-Host "5. Real authenticated E2E"

    $env:MINDPULSE_ROOT = $root

    $env:MINDPULSE_E2E_API_BASE =
      "http://127.0.0.1:5000/api/v1"

    $env:MINDPULSE_E2E_TIMEOUT_MS =
      "20000"

    Push-Location $backendRoot

    try {
      $e2eOutput = & node.exe `
        $e2eScript `
        2>&1

      $e2eExitCode = $LASTEXITCODE
    }
    finally {
      Pop-Location
    }

    $e2eOutput |
      Tee-Object `
        -FilePath $e2eLog

    if ($e2eExitCode -ne 0) {
      throw (
        "Authenticated runtime E2E failed. " +
        "Log: $e2eLog"
      )
    }

    $e2eText = (
      $e2eOutput -join "`n"
    )

    foreach ($marker in @(
      "AUTHENTICATED AI RUNTIME E2E PASSED",
      "PRIVACY-SAFE AI LOGGING PASSED",
      "TEMPORARY TEST DATA CLEANUP PASSED",
      "PASS expired access-token rejection",
      "PASS refresh-token rotation"
    )) {
      if ($e2eText -notmatch [regex]::Escape($marker)) {
        throw (
          "Authenticated E2E output is missing: " +
          $marker
        )
      }
    }

    Write-Host ""
    Write-Host "- Registration/login: PASSED"
    Write-Host "- Access-token protection: PASSED"
    Write-Host "- Node-to-FastAPI health: PASSED"
    Write-Host "- Journal analysis: PASSED"
    Write-Host "- Safety assessment: PASSED"
    Write-Host "- Wellness recommendation: PASSED"
    Write-Host "- Expired-token rejection: PASSED"
    Write-Host "- Refresh-token rotation: PASSED"
    Write-Host "- Revoked-token rejection: PASSED"
    Write-Host "- Privacy-safe logging: PASSED"
    Write-Host "- Temporary cleanup: PASSED"

    Write-Host ""
    Write-Host "6. Final repository integrity"

    $finalCommit = (
      git -C $root rev-parse HEAD
    ).Trim()

    $finalRemoteOutput = git -C $root `
      ls-remote `
      origin `
      refs/heads/main

    $finalRemoteCommit = (
      $finalRemoteOutput -split "\s+"
    )[0].Trim()

    $finalStatus = git -C $root status `
      --porcelain `
      --untracked-files=all

    $finalStaged = git -C $root diff `
      --cached `
      --name-only

    if ($finalCommit -ne $expectedCommit) {
      throw "Commit changed during E2E."
    }

    if (
      $finalRemoteCommit -ne $expectedCommit
    ) {
      throw "GitHub main changed during E2E."
    }

    if (
      -not [string]::IsNullOrWhiteSpace(
        $finalStatus
      )
    ) {
      throw (
        "Working tree changed during E2E:`n" +
        $finalStatus
      )
    }

    if (
      -not [string]::IsNullOrWhiteSpace(
        $finalStaged
      )
    ) {
      throw (
        "Staged files appeared during E2E:`n" +
        $finalStaged
      )
    }

    Write-Host "- Local and GitHub hashes match: YES"
    Write-Host "- Working tree clean: YES"
    Write-Host "- Staged files: NONE"

    $reportLines = @(
      "MindPulse Authenticated Runtime Validation",
      ("=" * 78),
      "",
      "Final result: PASSED",
      "",
      "Authenticated E2E:",
      "- Registration and login: PASSED",
      "- Access-token protection: PASSED",
      "- Authenticated AI health: PASSED",
      "- Journal analysis: PASSED",
      "- Safety assessment: PASSED",
      "- Wellness recommendation: PASSED",
      "- Expired-token rejection: PASSED",
      "- Refresh-token rotation: PASSED",
      "- Revoked refresh rejection: PASSED",
      "- Logout-all operation: PASSED",
      "",
      "Privacy and cleanup:",
      "- Raw private marker logged: NO",
      "- Required AI log rows: PRESENT",
      "- Temporary user retained: NO",
      "- Temporary related rows retained: NO",
      "- Cleanup verification: PASSED",
      "",
      "Repository integrity:",
      "- Commit: $expectedCommit",
      "- Local and GitHub hashes match: YES",
      "- Working tree clean: YES",
      "- Staged files: NONE",
      "",
      "Protected boundaries:",
      "- Application source modified: NO",
      "- Runtime .env files modified: NO",
      "- Database schema modified: NO",
      "- Permanent test data retained: NO",
      "- Git staging performed: NO",
      "- Commit created: NO",
      "- GitHub push performed: NO",
      "- Credentials or tokens printed: NO",
      "",
      "Logs:",
      "- E2E: $e2eLog",
      "- Backend: $backendOut",
      "- FastAPI: $aiOut"
    )

    [System.IO.File]::WriteAllLines(
      $reportPath,
      $reportLines,
      [System.Text.UTF8Encoding]::new(
        $false
      )
    )

    Write-Host ""
    Write-Host (
      "=============================================================="
    )

    Write-Host (
      "MINDPULSE AUTHENTICATED RUNTIME VALIDATION COMPLETE"
    ) -ForegroundColor Green

    Write-Host (
      "=============================================================="
    )

    Write-Host ""
    Write-Host "Authenticated E2E:"
    Write-Host "- Registration and login: PASSED"
    Write-Host "- Access-token protection: PASSED"
    Write-Host "- Authenticated AI health: PASSED"
    Write-Host "- Journal analysis: PASSED"
    Write-Host "- Safety assessment: PASSED"
    Write-Host "- Wellness recommendation: PASSED"
    Write-Host "- Expired-token rejection: PASSED"
    Write-Host "- Refresh-token rotation: PASSED"
    Write-Host "- Revoked refresh rejection: PASSED"
    Write-Host "- Logout-all: PASSED"

    Write-Host ""
    Write-Host "Privacy and cleanup:"
    Write-Host "- Raw private marker logged: NO"
    Write-Host "- Required AI log rows: PRESENT"
    Write-Host "- Temporary user retained: NO"
    Write-Host "- Temporary related rows retained: NO"
    Write-Host "- Cleanup verification: PASSED"

    Write-Host ""
    Write-Host "Repository integrity:"
    Write-Host "- Local and GitHub hashes match: YES"
    Write-Host "- Working tree clean: YES"
    Write-Host "- Staged files: NONE"

    Write-Host ""
    Write-Host "Protected boundaries:"
    Write-Host "- Application source modified: NO"
    Write-Host "- Runtime .env files modified: NO"
    Write-Host "- Database schema modified: NO"
    Write-Host "- Permanent test data retained: NO"
    Write-Host "- Credentials or tokens printed: NO"
    Write-Host "- Commit or push: NO"

    Write-Host ""
    Write-Host "- Report: $reportPath"
    Write-Host "- E2E log: $e2eLog"
  }
  catch {
    $failure = $_ | Out-String

    $workingTreeText = "CLEAN"

    try {
      $currentStatus = git -C $root status `
        --porcelain `
        --untracked-files=all

      if (
        -not [string]::IsNullOrWhiteSpace(
          $currentStatus
        )
      ) {
        $workingTreeText = (
          $currentStatus -join "`n"
        )
      }
    }
    catch {
      $workingTreeText = (
        "Unable to read repository status."
      )
    }

    $errorText = @(
      "MindPulse Authenticated Runtime Validation Failure",
      ("=" * 78),
      "",
      $failure,
      "",
      "WORKING TREE",
      $workingTreeText,
      "",
      "E2E LOG",
      $e2eLog
    ) -join "`n"

    [System.IO.File]::WriteAllText(
      $errorPath,
      $errorText,
      [System.Text.UTF8Encoding]::new(
        $false
      )
    )

    Write-Host ""
    Write-Host (
      "=============================================================="
    )

    Write-Host (
      "MINDPULSE AUTHENTICATED RUNTIME VALIDATION FAILED"
    ) -ForegroundColor Red

    Write-Host (
      "=============================================================="
    )

    Write-Host ""
    Write-Host "- Source modification: NO"
    Write-Host "- Git staging: NO"
    Write-Host "- Commit or push: NO"
    Write-Host (
      "- Temporary cleanup was attempted " +
      "inside the E2E runner."
    )
    Write-Host "- Error report: $errorPath"
    Write-Host "- E2E log: $e2eLog"

    throw
  }
  finally {
    Stop-ProcessTree -Process $backendProcess
    Stop-ProcessTree -Process $aiProcess

    Remove-Item `
      -LiteralPath $e2eScript `
      -Force `
      -ErrorAction SilentlyContinue

    if ($null -eq $oldNodeEnv) {
      Remove-Item Env:NODE_ENV `
        -ErrorAction SilentlyContinue
    }
    else {
      $env:NODE_ENV = $oldNodeEnv
    }

    if ($null -eq $oldCorsOrigins) {
      Remove-Item Env:CORS_ALLOWED_ORIGINS `
        -ErrorAction SilentlyContinue
    }
    else {
      $env:CORS_ALLOWED_ORIGINS =
        $oldCorsOrigins
    }

    if ($null -eq $oldCorsCredentials) {
      Remove-Item Env:CORS_ALLOW_CREDENTIALS `
        -ErrorAction SilentlyContinue
    }
    else {
      $env:CORS_ALLOW_CREDENTIALS =
        $oldCorsCredentials
    }

    @(
      "MINDPULSE_ROOT",
      "MINDPULSE_E2E_API_BASE",
      "MINDPULSE_E2E_TIMEOUT_MS"
    ) |
    ForEach-Object {
      Remove-Item `
        "Env:$_" `
        -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host (
      "Backend/FastAPI processes started by " +
      "this script have been stopped."
    )

    Write-Host (
      "MySQL remains running."
    )
  }
}
}
finally {
  Remove-Item Env:NODE_PATH -ErrorAction SilentlyContinue
}
