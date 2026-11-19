import { cors, requireUser } from './_auth.js';
// AI coach for WeighWell: weekly health insights and workout plan drafts.
// POST { task: "insights", summary: {...} }
//   → { headline, score, goingWell[], tryNext[], watchOut[] }
// POST { task: "plan", goal, daysPerWeek, place, level, minutes, exercises: [names] }
//   → { days: { "1": [{ name, sets, reps, weightKg, minutes }], ... }, notes }

const MODEL = process.env.COACH_MODEL || process.env.RECOGNIZE_MODEL || 'claude-sonnet-5-5';

const INSIGHTS_PROMPT = `You are a friendly, careful health coach inside a food and fitness app used by people of all ages.
Below is one week of the user's own logged data as JSON: food eaten (calories, protein, carbs, fat, food names), estimated calories burned, steps, walking distance, workouts, body weight, water, sleep and habits. Calorie burn numbers are estimates.

Write a short, encouraging review in plain, simple English (short sentences, no jargon).
Rules:
- Base every point on the data. If a day has no food logged, say data is missing rather than assuming they did not eat.
- Compare intake with their targets and goal. Mention protein.
- Mention activity (steps, workouts) and any weight trend if there are at least 2 weigh-ins.
- Give 2–3 small, practical next steps.
- Do NOT diagnose, name diseases, or give medication advice. Never recommend eating below 1200 kcal/day.
- If something looks worrying (very low intake several days, very rapid weight change, very little sleep), gently suggest talking to a doctor.
- score: 1–10 for how well the week supported their goal.
Reply with ONLY JSON in exactly this shape:
{"headline":"one sentence","score":7,"goingWell":["..."],"tryNext":["..."],"watchOut":["..."]}`;

const PLAN_PROMPT = `You are a certified personal trainer. Create a safe, balanced weekly exercise schedule.
Use ONLY exercise names from the provided list, spelled exactly.
Respect the requested number of training days, place (home = no machines or barbells; gym = anything), level and minutes per session. Leave the other days empty for rest.
For strength exercises give sets and reps; give weightKg only for gym level intermediate/advanced, otherwise null. For cardio and stretching give minutes and set sets to 1, reps to 0.
Beginners: 2–3 sets, mostly bodyweight and walking. Include warm-up cardio or stretching on training days.
Days are numbered 1 = Monday … 7 = Sunday.
Reply with ONLY JSON in exactly this shape:
{"days":{"1":[{"name":"Brisk walking (6.5 km/h)","sets":1,"reps":0,"weightKg":null,"minutes":10}],"2":[]},"notes":"one or two sentences"}`;


function extractJson(text) {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }
}

const strList = (v, max = 4) =>
  (Array.isArray(v) ? v : [])
    .filter((s) => typeof s === 'string' && s.trim())
    .slice(0, max)
    .map((s) => s.trim().slice(0, 240));

export function parseInsights(text) {
  const d = extractJson(text);
  if (!d) return null;
  const score = Number.isFinite(d.score) ? Math.max(1, Math.min(10, Math.round(d.score))) : null;
  return {
    headline: typeof d.headline === 'string' ? d.headline.trim().slice(0, 200) : '',
    score,
    goingWell: strList(d.goingWell),
    tryNext: strList(d.tryNext),
    watchOut: strList(d.watchOut, 3),
  };
}

export function parsePlan(text, allowedNames) {
  const d = extractJson(text);
  if (!d || typeof d.days !== 'object' || d.days === null) return null;
  const allowed = new Map(allowedNames.map((n) => [n.toLowerCase(), n]));
  const int = (v, lo, hi, def) => (Number.isFinite(v) ? Math.max(lo, Math.min(hi, Math.round(v))) : def);
  const days = {};
  for (let i = 1; i <= 7; i++) {
    const list = Array.isArray(d.days[String(i)]) ? d.days[String(i)] : [];
    days[String(i)] = list
      .filter((x) => x && typeof x.name === 'string' && allowed.has(x.name.trim().toLowerCase()))
      .slice(0, 8)
      .map((x) => ({
        name: allowed.get(x.name.trim().toLowerCase()),
        sets: int(x.sets, 1, 10, 3),
        reps: int(x.reps, 0, 100, 10),
        weightKg: Number.isFinite(x.weightKg) && x.weightKg > 0 ? Math.min(300, x.weightKg) : null,
        minutes: Number.isFinite(x.minutes) && x.minutes > 0 ? int(x.minutes, 1, 180, 10) : null,
      }));
  }
  return { days, notes: typeof d.notes === 'string' ? d.notes.trim().slice(0, 400) : '' };
}

async function askModel(key, prompt, payload, maxTokens) {
  const r = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: maxTokens,
      messages: [{ role: 'user', content: `${prompt}\n\nDATA:\n${JSON.stringify(payload)}` }],
    }),
  });
  if (!r.ok) {
    const detail = await r.text();
    console.error('Model error', r.status, detail.slice(0, 500));
    throw new Error('model');
  }
  const data = await r.json();
  return (data.content || []).filter((c) => c.type === 'text').map((c) => c.text).join('\n');
}

export default async function handler(req, res) {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Use POST' });
  if (!(await requireUser(req, res))) return;

  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) return res.status(500).json({ error: 'Server is missing ANTHROPIC_API_KEY' });

  let body;
  try {
    body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
  } catch {
    return res.status(400).json({ error: 'Bad JSON' });
  }
  if (JSON.stringify(body).length > 60000) return res.status(413).json({ error: 'Too much data' });

  try {
    if (body.task === 'insights') {
      if (!body.summary || !Array.isArray(body.summary.days)) {
        return res.status(400).json({ error: 'Send summary.days' });
      }
      const text = await askModel(key, INSIGHTS_PROMPT, body.summary, 900);
      const out = parseInsights(text);
      if (!out) return res.status(502).json({ error: 'Could not read the coach reply' });
      return res.status(200).json(out);
    }

    if (body.task === 'plan') {
      const names = Array.isArray(body.exercises) ? body.exercises.filter((n) => typeof n === 'string') : [];
      if (names.length === 0) return res.status(400).json({ error: 'Send exercises' });
      const request = {
        goal: String(body.goal || 'stay'),
        daysPerWeek: Math.max(1, Math.min(7, Number(body.daysPerWeek) || 3)),
        place: body.place === 'gym' ? 'gym' : 'home',
        level: ['beginner', 'intermediate', 'advanced'].includes(body.level) ? body.level : 'beginner',
        minutesPerSession: Math.max(10, Math.min(120, Number(body.minutes) || 30)),
        age: Number(body.age) || null,
        exercises: names.slice(0, 80),
      };
      const text = await askModel(key, PLAN_PROMPT, request, 1500);
      const out = parsePlan(text, names);
      if (!out) return res.status(502).json({ error: 'Could not read the plan' });
      return res.status(200).json(out);
    }

    return res.status(400).json({ error: 'Unknown task' });
  } catch (e) {
    console.error(e);
    return res.status(502).json({ error: 'Coach is not available right now' });
  }
}
