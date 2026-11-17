import { test } from 'node:test';
import assert from 'node:assert/strict';
import handler, { parseFoods } from './api/recognize.js';

test('parses clean JSON', () => {
  const foods = parseFoods('{"foods":[{"name":"Banana","confidence":0.9,"kcalPer100":89,"proteinPer100":1.1,"carbsPer100":22.8,"fatPer100":0.3,"estimatedGrams":118}]}');
  assert.equal(foods.length, 1);
  assert.equal(foods[0].name, 'Banana');
  assert.equal(foods[0].kcalPer100, 89);
  assert.equal(foods[0].estimatedGrams, 118);
});

test('ignores prose around JSON and caps to 3 foods', () => {
  const text = 'Sure! {"foods":[{"name":"A"},{"name":"B"},{"name":"C"},{"name":"D"}]} hope that helps';
  const foods = parseFoods(text);
  assert.equal(foods.length, 3);
  assert.equal(foods[0].confidence, 0.5);
  assert.equal(foods[0].estimatedGrams, null);
});

test('rejects bad values', () => {
  const foods = parseFoods('{"foods":[{"name":"X","kcalPer100":-5,"proteinPer100":"lots","fatPer100":500}, {"name":""}]}');
  assert.equal(foods.length, 1);
  assert.equal(foods[0].kcalPer100, 0);
  assert.equal(foods[0].proteinPer100, 0);
  assert.equal(foods[0].fatPer100, 100);
});

test('garbage returns empty list', () => {
  assert.deepEqual(parseFoods('no json here'), []);
  assert.deepEqual(parseFoods('{bad json}'), []);
});

function mockRes() {
  return {
    code: 0, body: null, headers: {},
    setHeader(k, v) { this.headers[k] = v; },
    status(c) { this.code = c; return this; },
    json(b) { this.body = b; return this; },
    end() { return this; },
  };
}

test('handler: OPTIONS gives CORS 204', async () => {
  const res = mockRes();
  await handler({ method: 'OPTIONS' }, res);
  assert.equal(res.code, 204);
  assert.equal(res.headers['Access-Control-Allow-Origin'], '*');
});

test('handler: missing key gives 500, missing image gives 400', async () => {
  delete process.env.ANTHROPIC_API_KEY;
  let res = mockRes();
  await handler({ method: 'POST', body: {} }, res);
  assert.equal(res.code, 500);
  process.env.ANTHROPIC_API_KEY = 'test';
  res = mockRes();
  await handler({ method: 'POST', body: { image: 'abc' } }, res);
  assert.equal(res.code, 400);
});

test('handler: calls model and returns foods', async () => {
  process.env.ANTHROPIC_API_KEY = 'test';
  const realFetch = globalThis.fetch;
  let sent;
  globalThis.fetch = async (url, opts) => {
    sent = JSON.parse(opts.body);
    return { ok: true, json: async () => ({ content: [{ type: 'text', text: '{"foods":[{"name":"Apple","kcalPer100":52,"proteinPer100":0.3}]}' }] }) };
  };
  try {
    const res = mockRes();
    await handler({ method: 'POST', body: { image: 'A'.repeat(200), mimeType: 'image/png' } }, res);
    assert.equal(res.code, 200);
    assert.equal(res.body.foods[0].name, 'Apple');
    assert.equal(sent.messages[0].content[0].source.media_type, 'image/png');
  } finally {
    globalThis.fetch = realFetch;
  }
});
