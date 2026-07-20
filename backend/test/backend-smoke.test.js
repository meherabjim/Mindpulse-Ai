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
