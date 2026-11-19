# Turn on sign-in, cloud backup, photo recognition and the AI coach

Everything is switched on by filling in **one file**, `lib/config.dart`. You don't need any Codemagic variables. This takes about 20 minutes, and you only do it once.

## Part 1 — Backend on Vercel (photo recognition + AI coach)

1. Deploy the `backend/` folder:
   ```bash
   cd backend
   npx vercel        # first time: answer the questions, accept the defaults
   npx vercel --prod
   ```
   Note the address it prints, e.g. `https://weighwell-backend.vercel.app`.
2. In Vercel, go to the project → **Settings → Environment Variables** and add:

   | Name | Value |
   |---|---|
   | `ANTHROPIC_API_KEY` | your Anthropic API key |
   | `SUPABASE_URL` | from Part 2 |
   | `SUPABASE_ANON_KEY` | from Part 2 |
   | `SUPABASE_SERVICE_ROLE_KEY` | from Part 2 (secret — only ever here) |

   Then **Redeploy**. Once the Supabase values are set, only signed-in users can use the AI, so strangers can't run up your bill.
3. In `lib/config.dart`, set:
   ```dart
   static const String _apiBase = 'https://weighwell-backend.vercel.app/api';
   ```

## Part 2 — Supabase (accounts + cloud backup)

1. Create a free project at https://supabase.com.
2. Open **SQL Editor → New query**, paste the contents of `backend/supabase.sql`, and click **Run**.
3. Go to **Project Settings → API** and copy:
   - **Project URL** → `_supabaseUrl` in `lib/config.dart`, and `SUPABASE_URL` in Vercel
   - **anon public** key → `_supabaseAnonKey` in `lib/config.dart`, and `SUPABASE_ANON_KEY` in Vercel
   - **service_role** key → `SUPABASE_SERVICE_ROLE_KEY` in **Vercel only**. Never put it in the app.
4. Go to **Authentication → URL Configuration**:
   - **Site URL**: your web app address (or `http://localhost:3000` for now)
   - **Redirect URLs**: add `com.aiqeacademy.weighwell://login-callback/` and your web app address

## Part 3 — Google sign-in

1. In https://console.cloud.google.com, create a project (or reuse the one from Petition Binder).
2. Go to **APIs & Services → OAuth consent screen**. Set it up as **External**, with the app name WeighWell and your support email.
3. Go to **Credentials → Create credentials → OAuth client ID → Web application**:
   - **Authorised redirect URI**: `https://YOUR-PROJECT.supabase.co/auth/v1/callback`
   - Copy the **Client ID** and **Client secret**.
4. In Supabase, go to **Authentication → Providers → Google**. Turn it on and paste the client ID and secret.

**Email sign-in links** work out of the box. Supabase's built-in email sender is rate-limited, so before launch add your own SMTP under Authentication → Emails. Resend works well.

## Part 4 — Push and build

```bash
git add lib/config.dart
git commit -m "Turn on accounts, photo recognition and AI coach"
git push
```

Codemagic builds automatically. On first launch you'll see **Continue with Google** and **Continue with email**.

### What happens to data

- Everything you log is saved on the phone straight away and uploaded within a couple of seconds. Offline changes upload when you're back online.
- Signing in on the website or another phone brings all your data there.
- Anything logged before first sign-in on a device is added to the account.
- **Sign out** removes the data from that device, but it stays in the account.
- **Delete my account** permanently removes the account and all its data (Apple and Google require this option).

### Before publishing to the App Store

Apple requires **Sign in with Apple** in any app that offers Google sign-in (App Review guideline 4.8). It's not needed for TestFlight testing. When you're ready to publish, ask Claude to add it. Supabase supports it.
