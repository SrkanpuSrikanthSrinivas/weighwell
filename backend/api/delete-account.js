// Deletes the signed-in user's account (Apple and Google require apps that
// let people sign up to also let them delete their account).
// Needs SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY in Vercel.
// The service-role key must ONLY ever live here on the server.
import { cors, requireUser } from './_auth.js';

export default async function handler(req, res) {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Use POST' });

  const url = process.env.SUPABASE_URL;
  const service = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !service || !process.env.SUPABASE_ANON_KEY) {
    return res.status(500).json({ error: 'Server is missing Supabase settings' });
  }

  const user = await requireUser(req, res);
  if (!user) return;

  try {
    const base = url.replace(/\/+$/, '');
    // Data rows are removed automatically (records.user_id … on delete cascade).
    const r = await fetch(`${base}/auth/v1/admin/users/${encodeURIComponent(user.id)}`, {
      method: 'DELETE',
      headers: { apikey: service, Authorization: `Bearer ${service}` },
    });
    if (!r.ok && r.status !== 404) {
      console.error('Delete user failed', r.status, (await r.text()).slice(0, 300));
      return res.status(502).json({ error: 'Could not delete the account' });
    }
    return res.status(200).json({ deleted: true });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Could not delete the account' });
  }
}
