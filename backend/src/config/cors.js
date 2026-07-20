'use strict';

const DEFAULT_DEVELOPMENT_ORIGINS = Object.freeze([
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  'http://localhost:8080',
  'http://127.0.0.1:8080',
]);

const DEFAULT_ALLOW_CREDENTIALS = false;

function parseBoolean(value, fallback = false) {
  if (
    value === undefined ||
    value === null ||
    String(value).trim() === ''
  ) {
    return fallback;
  }

  const normalized = String(value)
    .trim()
    .toLowerCase();

  if (['true', '1', 'yes', 'on'].includes(normalized)) {
    return true;
  }

  if (['false', '0', 'no', 'off'].includes(normalized)) {
    return false;
  }

  throw new Error(
    'CORS_ALLOW_CREDENTIALS must be a boolean value.',
  );
}

function parseAllowedOrigins(
  rawValue,
  nodeEnv = 'development',
) {
  const configuredOrigins = String(rawValue || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);

  const allowedOrigins = [
    ...new Set(configuredOrigins),
  ];

  if (allowedOrigins.includes('*')) {
    throw new Error(
      'CORS_ALLOWED_ORIGINS must not contain a wildcard.',
    );
  }

  if (allowedOrigins.length > 0) {
    return allowedOrigins;
  }

  if (nodeEnv === 'production') {
    throw new Error(
      'CORS_ALLOWED_ORIGINS is required in production.',
    );
  }

  return [...DEFAULT_DEVELOPMENT_ORIGINS];
}

function buildCorsOptions(
  baseOptions = {},
  environment = {},
) {
  const nodeEnv = (
    environment.nodeEnv
    ?? process.env.NODE_ENV
    ?? 'development'
  );

  const rawOrigins = (
    environment.rawOrigins
    ?? process.env.CORS_ALLOWED_ORIGINS
  );

  const rawCredentials = (
    environment.allowCredentials
    ?? process.env.CORS_ALLOW_CREDENTIALS
  );

  const allowedOrigins = parseAllowedOrigins(
    rawOrigins,
    nodeEnv,
  );

  const credentials = parseBoolean(
    rawCredentials,
    DEFAULT_ALLOW_CREDENTIALS,
  );

  return {
    ...baseOptions,

    origin(origin, callback) {
      if (
        !origin ||
        allowedOrigins.includes(origin)
      ) {
        callback(null, true);
        return;
      }

      callback(null, false);
    },

    credentials,

    optionsSuccessStatus: (
      baseOptions.optionsSuccessStatus
      ?? 204
    ),
  };
}

module.exports = {
  DEFAULT_DEVELOPMENT_ORIGINS,
  DEFAULT_ALLOW_CREDENTIALS,
  parseBoolean,
  parseAllowedOrigins,
  buildCorsOptions,
};
