import { test } from 'node:test';
import assert from 'node:assert/strict';
import handler, { parseInsights, parsePlan } from './api/coach.js';

test('parseInsights clamps score and trims lists', () => {
  const out = parseInsights('Here: {"headline":"Good week","score":14,"goingWell":["a","b","c","d","e"],"tryNext":["x"],"watchOut":[]}');
  assert.equal(out.headline, 'Good week');
  assert.equal(out.score, 10);
  assert.equal(out.goingWell.length, 4);
  assert.deepEqual(out.tryNext, ['x']);
});

test('parseInsights returns null on garbage', () => {
  assert.equal(parseInsights('nope'), null);
});

test('parsePlan keeps only allowed exercises and fixes numbers', () => {
  const allowed = ['Squats', 'Brisk walking (6.5 km/h)'];
  const out = parsePlan(
    JSON.stringify({
      days: {
        1: [
          { name: 'squats', sets: 30, reps: 12, weightKg: -2 },
          { name: 'Moon jumps', sets: 3, reps: 10 },
          { name: 'Brisk walking (6.5 km/h)', sets: 1, reps: 0, minutes: 20 },
        ],
        3: 'bad',
      },
      notes: 'Rest on other days',
    }),
    allowed,
  );
  assert.equal(out.days['1'].length, 2);
  assert.equal(out.days['1'][0].name, 'Squats');
  assert.equal(out.days['1'][0].sets, 10);
  assert.equal(out.days['1'][0].weightKg, null);
  assert.equal(out.days['1'][1].minutes, 20);
  assert.deepEqual(out.days['3'], []);
  assert.deepEqual(out.days['7'], []);
  assert.equal(out.notes, 'Rest on other days');
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

test('handler validates input', async () => {
  process.env.ANTHROPIC_API_KEY = 'test';
  let res = mockRes();
  await handler({ method: 'POST', body: { task: 'insights' } }, res);
  assert.equal(res.code, 400);
  res = mockRes();
  await handler({ method: 'POST', body: { task: 'plan', exercises: [] } }, res);
  assert.equal(res.code, 400);
  res = mockRes();
  await handler({ method: 'POST', body: { task: 'other' } }, res);
  assert.equal(res.code, 400);
});

test('handler: insights round trip', async () => {
  process.env.ANTHROPIC_API_KEY = 'test';
  const realFetch = globalThis.fetch;
  let prompt;
  globalThis.fetch = async (url, opts) => {
    prompt = JSON.parse(opts.body).messages[0].content;
    return { ok: true, json: async () => ({ content: [{ type: 'text', text: '{"headline":"Nice","score":7,"goingWell":["Protein on target"],"tryNext":["Walk 10 more minutes"],"watchOut":[]}' }] }) };
  };
  try {
    const res = mockRes();
    await handler({ method: 'POST', body: { task: 'insights', summary: { days: [{ date: '2026-11-17', kcalEaten: 1800 }] } } }, res);
    assert.equal(res.code, 200);
    assert.equal(res.body.score, 7);
    assert.ok(prompt.includes('1800'));
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('handler: plan round trip', async () => {
  process.env.ANTHROPIC_API_KEY = 'test';
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () => ({ ok: true, json: async () => ({ content: [{ type: 'text', text: '{"days":{"1":[{"name":"Squats","sets":3,"reps":10}]},"notes":"ok"}' }] }) });
  try {
    const res = mockRes();
    await handler({ method: 'POST', body: { task: 'plan', exercises: ['Squats'], daysPerWeek: 3 } }, res);
    assert.equal(res.code, 200);
    assert.equal(res.body.days['1'][0].name, 'Squats');
  } finally {
    globalThis.fetch = realFetch;
  }
});
