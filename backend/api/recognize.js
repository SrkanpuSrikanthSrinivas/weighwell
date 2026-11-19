import { cors, requireUser } from './_auth.js';
// Photo → food recognition for WeighWell.
// Deploy this folder to Vercel. Set ANTHROPIC_API_KEY in the Vercel project
// settings. The app sends { image: <base64>, mimeType } and gets back
// { foods: [{ name, confidence, kcalPer100, proteinPer100, carbsPer100,
// fatPer100, estimatedGrams }] }.

const MODEL = process.env.RECOGNIZE_MODEL || 'claude-sonnet-5-5';
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

const PROMPT = `You are a nutrition assistant inside a food-weighing app.
Look at the photo and list the distinct foods you can see (at most 3), most prominent first.
For each food give typical nutrition PER 100 GRAMS (use USDA-style values for the food as prepared in the photo) and your best estimate of the grams shown.
If the photo does not show food, return an empty list.
Reply with ONLY JSON, no prose, in exactly this shape:
{"foods":[{"name":"Banana","confidence":0.9,"kcalPer100":89,"proteinPer100":1.1,"carbsPer100":22.8,"fatPer100":0.3,"estimatedGrams":118}]}
Use short, plain food names that anyone understands.`;


export function parseFoods(text) {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return [];
  let data;
  try {
    data = JSON.parse(text.slice(start, end + 1));
  } catch {
    return [];
  }
  const num = (v, d = 0) => (typeof v === 'number' && Number.isFinite(v) && v >= 0 ? v : d);
  return (Array.isArray(data.foods) ? data.foods : [])
    .filter((f) => f && typeof f.name === 'string' && f.name.trim())
    .slice(0, 3)
    .map((f) => ({
      name: f.name.trim().slice(0, 60),
      confidence: Math.min(1, num(f.confidence, 0.5)),
      kcalPer100: Math.min(900, num(f.kcalPer100)),
      proteinPer100: Math.min(100, num(f.proteinPer100)),
      carbsPer100: Math.min(100, num(f.carbsPer100)),
      fatPer100: Math.min(100, num(f.fatPer100)),
      estimatedGrams: f.estimatedGrams == null ? null : Math.min(3000, num(f.estimatedGrams)),
    }));
}

export default async function handler(req, res) {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Use POST' });
  if (!(await requireUser(req, res))) return;

  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) return res.status(500).json({ error: 'Server is missing ANTHROPIC_API_KEY' });

  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
  const image = body.image;
  const mimeType = ALLOWED_TYPES.includes(body.mimeType) ? body.mimeType : 'image/jpeg';
  if (typeof image !== 'string' || image.length < 100) {
    return res.status(400).json({ error: 'Send a base64 image' });
  }
  if ((image.length * 3) / 4 > MAX_IMAGE_BYTES) {
    return res.status(413).json({ error: 'Image too large (max 5 MB)' });
  }

  try {
    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 600,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'image', source: { type: 'base64', media_type: mimeType, data: image } },
              { type: 'text', text: PROMPT },
            ],
          },
        ],
      }),
    });
    if (!r.ok) {
      const detail = await r.text();
      console.error('Model error', r.status, detail.slice(0, 500));
      return res.status(502).json({ error: 'Recognition service error' });
    }
    const data = await r.json();
    const text = (data.content || []).filter((c) => c.type === 'text').map((c) => c.text).join('\n');
    return res.status(200).json({ foods: parseFoods(text) });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Could not recognize the photo' });
  }
}
