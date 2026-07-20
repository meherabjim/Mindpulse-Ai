'use strict';

const js = require('@eslint/js');
const globals = require('globals');

const modernNodeGlobals = {
  ...(globals.node || {}),
  ...(globals.nodeBuiltin || {}),

  AbortController: 'readonly',
  AbortSignal: 'readonly',
  Blob: 'readonly',
  BroadcastChannel: 'readonly',
  CompressionStream: 'readonly',
  crypto: 'readonly',
  DecompressionStream: 'readonly',
  DOMException: 'readonly',
  Event: 'readonly',
  EventTarget: 'readonly',
  fetch: 'readonly',
  File: 'readonly',
  FormData: 'readonly',
  Headers: 'readonly',
  MessageChannel: 'readonly',
  MessagePort: 'readonly',
  navigator: 'readonly',
  performance: 'readonly',
  queueMicrotask: 'readonly',
  ReadableStream: 'readonly',
  Request: 'readonly',
  Response: 'readonly',
  structuredClone: 'readonly',
  TextDecoder: 'readonly',
  TextEncoder: 'readonly',
  TransformStream: 'readonly',
  URL: 'readonly',
  URLSearchParams: 'readonly',
  WebSocket: 'readonly',
  WritableStream: 'readonly',
};

module.exports = [
  {
    ignores: [
      'node_modules/**',
      'coverage/**',
      'build/**',
      'dist/**',

      '**/app.before-*.js',
      '**/*.before-*.js',
      '**/*.before_*.js',
      '**/*.after-*.js',
      '**/*.after_*.js',
      '**/*.backup.js',
      '**/*.bak.js',
      '**/*.old.js',
      '**/*.copy.js',
    ],
  },

  js.configs.recommended,

  {
    files: [
      'server.js',
      'src/**/*.js',
      'test/**/*.js',
    ],

    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'commonjs',
      globals: modernNodeGlobals,
    },

    linterOptions: {
      reportUnusedDisableDirectives: 'error',
    },

    rules: {
      /*
       * Existing production logging is retained during
       * the correctness-focused baseline.
       */
      'no-console': 'off',

      /*
       * Legacy unused-variable cleanup will be handled
       * separately to avoid unrelated mass source edits.
       */
      'no-unused-vars': 'off',
    },
  },
];
