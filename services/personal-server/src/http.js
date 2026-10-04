const { bodyLimitBytes } = require('./config');
const { fail } = require('./errors');

function readJson(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let received = 0;
    let stopped = false;
    request.on('data', (chunk) => {
      if (stopped) return;
      const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      received += buffer.length;
      if (received > bodyLimitBytes) {
        stopped = true;
        reject(Object.assign(new Error('Request body is too large.'), {
          status: 413,
          code: 'request_too_large',
        }));
        return;
      }
      chunks.push(buffer);
    });
    request.on('end', () => {
      if (stopped) return;
      const body = Buffer.concat(chunks).toString('utf8');
      if (!body.trim()) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(body));
      } catch (_error) {
        try {
          fail(400, 'invalid_json', 'Request body must be valid JSON.');
        } catch (error) {
          reject(error);
        }
      }
    });
    request.on('error', reject);
  });
}

function writeJson(response, status, body, extraHeaders = {}) {
  const payload = status === 204 ? '' : JSON.stringify(body);
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(payload),
    ...extraHeaders,
  });
  response.end(payload);
}

module.exports = { readJson, writeJson };
