'use strict';

process.env.NODE_ENV = 'test';

const http = require('node:http');
const assert = require('node:assert/strict');
const test = require('node:test');

const app = require('../src/app');


function requestApp(path, options = {}) {
  const method = options.method || 'GET';
  const headers = {
    connection: 'close',
    ...(options.headers || {}),
  };

  return new Promise((resolve, reject) => {
    const server = http.createServer(app);
    let completed = false;

    const finish = (error, value) => {
      if (completed) {
        return;
      }

      completed = true;

      server.close(() => {
        if (error) {
          reject(error);
          return;
        }

        resolve(value);
      });
    };

    server.once('error', (error) => {
      finish(error);
    });

    server.listen(0, '127.0.0.1', () => {
      const address = server.address();

      if (
        address === null
        || typeof address === 'string'
      ) {
        finish(
          new Error(
            'Could not resolve the temporary test port.',
          ),
        );
        return;
      }

      const request = http.request(
        {
          hostname: '127.0.0.1',
          port: address.port,
          path,
          method,
          headers,
        },
        (response) => {
          const chunks = [];

          response.on('data', (chunk) => {
            chunks.push(chunk);
          });

          response.on('error', (error) => {
            finish(error);
          });

          response.on('end', () => {
            const bodyText = Buffer
              .concat(chunks)
              .toString('utf8');

            let body = null;

            if (bodyText.length > 0) {
              try {
                body = JSON.parse(bodyText);
              } catch {
                body = null;
              }
            }

            finish(
              null,
              {
                statusCode: response.statusCode,
                headers: response.headers,
                bodyText,
                body,
              },
            );
          });
        },
      );

      request.setTimeout(5000, () => {
        request.destroy(
          new Error('Backend smoke request timed out.'),
        );
      });

      request.once('error', (error) => {
        finish(error);
      });

      request.end();
    });
  });
}


test(
  'Express app exports a request handler',
  () => {
    assert.equal(typeof app, 'function');
  },
);


test(
  'GET /api/v1/health returns a JSON success response',
  async () => {
    const response = await requestApp(
      '/api/v1/health',
    );

    assert.equal(
      response.statusCode,
      200,
      response.bodyText,
    );

    assert.match(
      String(
        response.headers['content-type'] || '',
      ),
      /application\/json/i,
    );

    assert.ok(
      response.body !== null
      && typeof response.body === 'object',
      'Health response must contain a JSON object.',
    );
  },
);


test(
  'protected admin profile rejects an unauthenticated request',
  async () => {
    const candidatePaths = [
      '/api/v1/admin/auth/me',
      '/admin/auth/me',
    ];

    const observations = [];

    for (const path of candidatePaths) {
      const response = await requestApp(path);

      observations.push(
        `${path} => ${response.statusCode}`,
      );

      if (
        response.statusCode === 401
        || response.statusCode === 403
      ) {
        assert.match(
          String(
            response.headers['content-type'] || '',
          ),
          /application\/json/i,
        );

        return;
      }

      assert.notEqual(
        response.statusCode,
        500,
        (
          `Protected route returned 500: ${path}\n`
          + response.bodyText
        ),
      );
    }

    assert.fail(
      (
        'No protected route candidate rejected the '
        + 'unauthenticated request with 401 or 403.\n'
        + observations.join('\n')
      ),
    );
  },
);

// MINDPULSE_CORS_POLICY_TESTS_V2
const {
  test: corsPolicyTest,
} = require('node:test');

const corsPolicyAssert = require(
  'node:assert/strict',
);

const corsPolicyHttp = require('node:http');

const {
  DEFAULT_DEVELOPMENT_ORIGINS,
  buildCorsOptions,
  parseAllowedOrigins,
  parseBoolean,
} = require('../src/config/cors');

const corsRuntimeApp = require('../src/app');

function invokeOriginCallback(options, origin) {
  return new Promise((resolve, reject) => {
    options.origin(origin, (error, allowed) => {
      if (error) {
        reject(error);
        return;
      }

      resolve(allowed);
    });
  });
}

function requestRuntimeApp(origin) {
  return new Promise((resolve, reject) => {
    const server = corsPolicyHttp.createServer(
      corsRuntimeApp,
    );

    let finished = false;

    function complete(error, result) {
      if (finished) {
        return;
      }

      finished = true;

      server.close(() => {
        if (error) {
          reject(error);
          return;
        }

        resolve(result);
      });
    }

    server.once('error', (error) => {
      complete(error);
    });

    server.listen(0, '127.0.0.1', () => {
      const address = server.address();

      if (
        !address ||
        typeof address === 'string'
      ) {
        complete(
          new Error(
            'Could not resolve temporary test port.',
          ),
        );
        return;
      }

      const headers = {};

      if (origin) {
        headers.Origin = origin;
      }

      const request = corsPolicyHttp.request(
        {
          hostname: '127.0.0.1',
          port: address.port,
          path: '/api/v1/health',
          method: 'GET',
          headers,
        },
        (response) => {
          const chunks = [];

          response.on('data', (chunk) => {
            chunks.push(chunk);
          });

          response.on('end', () => {
            complete(null, {
              statusCode: response.statusCode,
              headers: response.headers,
              body: Buffer.concat(chunks)
                .toString('utf8'),
            });
          });
        },
      );

      request.once('error', (error) => {
        complete(error);
      });

      request.end();
    });
  });
}

corsPolicyTest(
  'CORS parser trims and removes duplicate origins',
  () => {
    const origins = parseAllowedOrigins(
      ' https://app.example.com,'
        + 'https://admin.example.com,'
        + 'https://app.example.com ',
      'production',
    );

    corsPolicyAssert.deepEqual(origins, [
      'https://app.example.com',
      'https://admin.example.com',
    ]);
  },
);

corsPolicyTest(
  'CORS wildcard configuration is rejected',
  () => {
    corsPolicyAssert.throws(
      () => parseAllowedOrigins(
        'https://app.example.com,*',
        'production',
      ),
      /must not contain a wildcard/,
    );
  },
);

corsPolicyTest(
  'production requires an explicit CORS allowlist',
  () => {
    corsPolicyAssert.throws(
      () => parseAllowedOrigins(
        '',
        'production',
      ),
      /is required in production/,
    );
  },
);

corsPolicyTest(
  'development receives non-wildcard local defaults',
  () => {
    const origins = parseAllowedOrigins(
      '',
      'development',
    );

    corsPolicyAssert.deepEqual(
      origins,
      [...DEFAULT_DEVELOPMENT_ORIGINS],
    );

    corsPolicyAssert.equal(
      origins.includes('*'),
      false,
    );
  },
);

corsPolicyTest(
  'CORS boolean parser validates supported values',
  () => {
    corsPolicyAssert.equal(
      parseBoolean('true'),
      true,
    );

    corsPolicyAssert.equal(
      parseBoolean('0'),
      false,
    );

    corsPolicyAssert.throws(
      () => parseBoolean('maybe'),
      /must be a boolean value/,
    );
  },
);

corsPolicyTest(
  'CORS policy preserves safe base options',
  () => {
    const options = buildCorsOptions(
      {
        methods: ['GET', 'POST'],
        allowedHeaders: [
          'Content-Type',
          'Authorization',
        ],
      },
      {
        rawOrigins: 'https://app.example.com',
        nodeEnv: 'production',
        allowCredentials: 'false',
      },
    );

    corsPolicyAssert.deepEqual(
      options.methods,
      ['GET', 'POST'],
    );

    corsPolicyAssert.deepEqual(
      options.allowedHeaders,
      [
        'Content-Type',
        'Authorization',
      ],
    );

    corsPolicyAssert.equal(
      options.credentials,
      false,
    );
  },
);

corsPolicyTest(
  'CORS callback accepts configured and non-browser requests',
  async () => {
    const options = buildCorsOptions(
      {},
      {
        rawOrigins: 'https://app.example.com',
        nodeEnv: 'production',
        allowCredentials: 'false',
      },
    );

    corsPolicyAssert.equal(
      await invokeOriginCallback(
        options,
        'https://app.example.com',
      ),
      true,
    );

    corsPolicyAssert.equal(
      await invokeOriginCallback(
        options,
        undefined,
      ),
      true,
    );

    corsPolicyAssert.equal(
      await invokeOriginCallback(
        options,
        'https://blocked.example.com',
      ),
      false,
    );
  },
);

corsPolicyTest(
  'runtime app emits CORS header only for allowed origins',
  async () => {
    const allowedOrigin = (
      'http://localhost:3000'
    );

    const allowedResponse = (
      await requestRuntimeApp(
        allowedOrigin,
      )
    );

    corsPolicyAssert.equal(
      allowedResponse.statusCode,
      200,
    );

    corsPolicyAssert.equal(
      allowedResponse.headers[
        'access-control-allow-origin'
      ],
      allowedOrigin,
    );

    const blockedResponse = (
      await requestRuntimeApp(
        'https://blocked.example.com',
      )
    );

    corsPolicyAssert.equal(
      blockedResponse.statusCode,
      200,
    );

    corsPolicyAssert.equal(
      blockedResponse.headers[
        'access-control-allow-origin'
      ],
      undefined,
    );

    const noOriginResponse = (
      await requestRuntimeApp()
    );

    corsPolicyAssert.equal(
      noOriginResponse.statusCode,
      200,
    );
  },
);

test(
  'reading plan route is protected',
  async () => {
    const response = await requestApp(
      '/api/v1/ai/reading/plan',
      { method: 'POST' },
    );

    assert.ok(
      response.statusCode === 401
      || response.statusCode === 403,
      response.bodyText,
    );
  },
);


test(
  'AI service exports the reading-plan proxy',
  () => {
    const service = require(
      '../src/services/ai.service',
    );

    assert.equal(
      typeof service.generateReadingPlan,
      'function',
    );
  },
);
