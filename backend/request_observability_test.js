const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const test = require('node:test');

process.env.JWT_SECRET ||= 'request-observability-test-secret';

const { createFeatureGate, createRequestObservability } = require('./src/app');

test('request observability returns a request id and emits structured timing data', () => {
  const messages = [];
  const middleware = createRequestObservability({
    logger: { info: (message) => messages.push(JSON.parse(message)) },
    now: (() => {
      const values = [1000, 1027];
      return () => values.shift();
    })(),
    createId: () => 'generated-request-id',
  });
  const response = new EventEmitter();
  response.statusCode = 201;
  response.setHeader = (name, value) => {
    response.headers = { ...response.headers, [name]: value };
  };
  let nextCalled = false;

  middleware(
    { headers: {}, method: 'POST', originalUrl: '/api/example' },
    response,
    () => { nextCalled = true; },
  );
  response.emit('finish');

  assert.equal(nextCalled, true);
  assert.equal(response.headers['X-Request-Id'], 'generated-request-id');
  assert.deepEqual(messages, [{
    event: 'http_request',
    requestId: 'generated-request-id',
    method: 'POST',
    path: '/api/example',
    statusCode: 201,
    durationMs: 27,
  }]);
});

test('request observability preserves a valid caller request id', () => {
  const middleware = createRequestObservability({
    logger: { info: () => {} },
    now: () => 0,
    createId: () => 'unused-generated-id',
  });
  const response = new EventEmitter();
  response.statusCode = 200;
  response.setHeader = (name, value) => {
    response.headers = { ...response.headers, [name]: value };
  };

  middleware(
    { headers: { 'x-request-id': 'client-request-123' }, method: 'GET', url: '/api/health' },
    response,
    () => {},
  );

  assert.equal(response.headers['X-Request-Id'], 'client-request-123');
});

test('feature gate disables only configured API prefixes', () => {
  const middleware = createFeatureGate(['/api/campaigns']);
  const response = {
    headers: {},
    setHeader(name, value) { this.headers[name] = value; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
  let nextCalled = false;

  middleware(
    { path: '/api/campaigns/active', requestId: 'request-123' },
    response,
    () => { nextCalled = true; },
  );

  assert.equal(nextCalled, false);
  assert.equal(response.statusCode, 503);
  assert.equal(response.headers['Retry-After'], '60');
  assert.deepEqual(response.body, {
    error: 'feature_temporarily_unavailable',
    requestId: 'request-123',
  });
});

test('feature gate passes unrelated paths through', () => {
  const middleware = createFeatureGate(['/api/campaigns']);
  let nextCalled = false;

  middleware(
    { path: '/api/rewards' },
    {},
    () => { nextCalled = true; },
  );

  assert.equal(nextCalled, true);
});