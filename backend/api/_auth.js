// Shared sign-in check. Files starting with "_" are not routes on Vercel.
//
// When SUPABASE_URL and SUPABASE_ANON_KEY are set in Vercel, every request
// must carry a valid "Authorization: Bearer <token>" from a signed-in user.
// Without them (early testing), requests are allowed.

export async function requireUser(req, res) {
  const url = process.env.SUPABASE_URL;
  const anon = process.env.SUPABASE_ANON_KEY;
  if (!url || !anon) return { id: null, open: true };

  const header = req.headers?.authorization || req.headers?.Authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) {
    res.status(401).json({ error: 'Please sign in' });
    return null;
  }
  try {
    const r = await fetch(`${url.replace(/\/+$/, '')}/auth/v1/user`, {
      headers: { apikey: anon, Authorization: `Bearer ${token}` },
    });
    if (!r.ok) {
      res.status(401).json({ error: 'Please sign in again' });
      return null;
    }
    const user = await r.json();
    if (!user?.id) {
      res.status(401).json({ error: 'Please sign in again' });
      return null;
    }
    return { id: user.id, open: false };
  } catch (e) {
    console.error('Auth check failed', e);
    res.status(503).json({ error: 'Sign-in check failed, try again' });
    return null;
  }
}

export function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', process.env.ALLOWED_ORIGIN || '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}
