import { test } from 'node:test';
import assert from 'node:assert/strict';
import { requireUser } from './api/_auth.js';
import deleteAccount from './api/delete-account.js';

function mockRes() {
  return {
    code: 0, body: null, headers: {},
    setHeader(k, v) { this.headers[k] = v; },
    status(c) { this.code = c; return this; },
    json(b) { this.body = b; return this; },
    end() { return this; },
  };
}

function withEnv(vars, fn) {
  const old = {};
  for (const k of Object.keys(vars)) { old[k] = process.env[k]; if (vars[k] == null) delete process.env[k]; else process.env[k] = vars[k]; }
  return fn().finally(() => { for (const k of Object.keys(old)) { if (old[k] == null) delete process.env[k]; else process.env[k] = old[k]; } });
}

test('open when Supabase not configured', () => withEnv({ SUPABASE_URL: null, SUPABASE_ANON_KEY: null }, async () => {
  const u = await requireUser({ headers: {} }, mockRes());
  assert.equal(u.open, true);
}));

test('401 without token, 401 with bad token, ok with good token', () => withEnv({ SUPABASE_URL: 'https://x.supabase.co', SUPABASE_ANON_KEY: 'anon' }, async () => {
  let res = mockRes();
  assert.equal(await requireUser({ headers: {} }, res), null);
  assert.equal(res.code, 401);

  const realFetch = globalThis.fetch;
  try {
    globalThis.fetch = async () => ({ ok: false, status: 401 });
    res = mockRes();
    assert.equal(await requireUser({ headers: { authorization: 'Bearer bad' } }, res), null);
    assert.equal(res.code, 401);

    let seen;
    globalThis.fetch = async (url, opts) => { seen = { url, opts }; return { ok: true, json: async () => ({ id: 'u1' }) }; };
    const u = await requireUser({ headers: { authorization: 'Bearer good' } }, mockRes());
    assert.equal(u.id, 'u1');
    assert.equal(seen.url, 'https://x.supabase.co/auth/v1/user');
    assert.equal(seen.opts.headers.Authorization, 'Bearer good');
  } finally {
    globalThis.fetch = realFetch;
  }
}));

test('delete-account removes the signed-in user with the service key', () => withEnv({ SUPABASE_URL: 'https://x.supabase.co', SUPABASE_ANON_KEY: 'anon', SUPABASE_SERVICE_ROLE_KEY: 'svc' }, async () => {
  const realFetch = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (url, opts) => {
    calls.push({ url, opts });
    if (url.endsWith('/auth/v1/user')) return { ok: true, json: async () => ({ id: 'u1' }) };
    return { ok: true, status: 200, text: async () => '' };
  };
  try {
    const res = mockRes();
    await deleteAccount({ method: 'POST', headers: { authorization: 'Bearer good' } }, res);
    assert.equal(res.code, 200);
    assert.equal(calls[1].url, 'https://x.supabase.co/auth/v1/admin/users/u1');
    assert.equal(calls[1].opts.method, 'DELETE');
    assert.equal(calls[1].opts.headers.apikey, 'svc');
  } finally {
    globalThis.fetch = realFetch;
  }
}));
