# Setup Guide — AI Course Audit Tracker

This guide walks you through deploying the audit tracker on **GitHub Pages** with **Supabase** as the backend. Estimated time: 20–30 minutes.

---

## Part 1 — Supabase Setup

### 1.1 Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign in (or create a free account).
2. Click **New project**.
3. Choose your organisation, give the project a name (e.g. `ai-audit-tracker`), set a strong database password, and pick a region close to Singapore (e.g. **Southeast Asia (Singapore)**).
4. Click **Create new project** and wait ~2 minutes for provisioning.

---

### 1.2 Disable Email Confirmation

By default Supabase requires users to verify their email before they can log in. Disable this so testers can sign up immediately.

1. In your project dashboard, go to **Authentication → Providers → Email**.
2. Toggle **Confirm email** to **OFF**.
3. Click **Save**.

---

### 1.3 Run the Schema

1. In the left sidebar, click **SQL Editor**.
2. Click **New query**.
3. Open the file `supabase_schema.sql` from this repo and paste the entire contents into the editor.
4. Click **Run** (or press `Ctrl+Enter` / `Cmd+Enter`).
5. You should see `Success. No rows returned` (or similar) — this means all tables, policies, triggers, and seed data were created successfully.

> **Tip:** If you see an error about a policy already existing, it is safe to ignore — the script drops and recreates them.

#### Already deployed? Apply the critical RLS patch

If the project was set up **before** the security hardening, run **`supabase_critical_rls_patch.sql`** once in the SQL Editor (in addition to keeping schema in sync). That patch:

- Stops non-admins from editing course details (they may still update **status** when claiming)
- Blocks users from setting `is_admin` on themselves
- Restricts **audit/evaluation** reads to **owner + admin**

---

### 1.4 Get Your API Credentials

1. In the left sidebar, go to **Project Settings → API**.
2. Copy two values:
   - **Project URL** — looks like `https://xxxxxxxxxxxx.supabase.co`
   - **anon / public key** — a long JWT string under *Project API keys*

You'll paste these into `index.html` in Part 3.

---

### 1.5 Configure Allowed Redirect URLs (for GitHub Pages)

1. Still in **Project Settings**, go to **Authentication → URL Configuration**.
2. In the **Site URL** field, enter your future GitHub Pages URL:
   ```
   https://<your-github-username>.github.io/<your-repo-name>
   ```
   Example: `https://janesmith.github.io/ai-audit-tracker`
3. Under **Redirect URLs**, click **Add URL** and add the same URL.
4. Click **Save**.

> **Note:** You can update this later once you know your exact GitHub Pages URL.

---

## Part 2 — GitHub Repository Setup

### 2.1 Create a New Repository

1. Go to [github.com](https://github.com) and sign in.
2. Click **New repository** (the `+` icon → New repository).
3. Name it something like `ai-audit-tracker`.
4. Set it to **Public** (GitHub Pages requires a public repo on the free plan).
5. Leave everything else as default and click **Create repository**.

---

### 2.2 Upload the Files

You have two options:

**Option A — Via the GitHub web UI (no Git needed):**

1. On the new empty repo page, click **Add file → Upload files**.
2. Drag and drop `index.html`, `supabase_schema.sql`, and `SETUP_GUIDE.md`.
3. Scroll down, add a commit message like `Initial commit`, and click **Commit changes**.

**Option B — Via Git CLI:**

```bash
git clone https://github.com/<your-username>/<your-repo-name>.git
cd <your-repo-name>
# Copy your three files into this folder, then:
git add .
git commit -m "Initial commit"
git push
```

---

## Part 3 — Configure the App

### 3.1 Edit index.html with Your Supabase Credentials

1. Open `index.html` in a text editor.
2. Near the top of the `<script>` section, find these two lines:
   ```javascript
   const SUPABASE_URL      = 'YOUR_SUPABASE_URL';
   const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
   ```
3. Replace the placeholder strings with your values from Part 1.4:
   ```javascript
   const SUPABASE_URL      = 'https://xxxxxxxxxxxx.supabase.co';
   const SUPABASE_ANON_KEY = 'eyJhbGci...your-long-anon-key...';
   ```
4. Save the file and commit/push the change to GitHub (or re-upload via the web UI).

---

## Part 4 — Enable GitHub Pages

1. In your GitHub repository, go to **Settings → Pages** (in the left sidebar under *Code and automation*).
2. Under **Source**, select **Deploy from a branch**.
3. Set the branch to **main** (or **master** if that's what your repo uses) and the folder to **/ (root)**.
4. Click **Save**.
5. After about 1–2 minutes, GitHub will show a banner:
   > *Your site is live at `https://<your-username>.github.io/<your-repo-name>`*
6. Visit that URL to confirm the app loads.

> **If the page is blank or shows an error:** Open your browser's developer console (F12 → Console tab). A message like `Invalid API key` means the Supabase credentials weren't saved correctly. A CORS error means you need to re-check the Site URL in Supabase (Part 1.5).

---

## Part 5 — Set the Admin User

The admin tab is hidden from regular users. To grant admin access to an account:

1. First, **register** on the live app using the email address you want as admin.
2. In the Supabase dashboard, go to **Table Editor → profiles**.
3. Find the row with your admin user's email (you can cross-reference with **Authentication → Users** to match the `id`).
4. Click the row to edit it, set `is_admin` to `true`, and save.

That's it — the next time that user logs in, the **Admin** tab will appear.

> **Alternative via SQL Editor:**
> ```sql
> UPDATE profiles
> SET is_admin = true
> WHERE id = (
>   SELECT id FROM auth.users WHERE email = 'your-admin@email.com'
> );
> ```

---

## Part 6 — Invite Other Users

Share the GitHub Pages URL with your team. They can self-register with any email and password — no confirmation email is required (you disabled that in Part 1.2).

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Blank page | JS error in console | Check Supabase URL/key in index.html |
| "Failed to fetch" | Wrong Supabase URL | Double-check the Project URL (no trailing slash) |
| Login succeeds but data doesn't load | RLS or anon key issue | Re-run supabase_schema.sql; check anon key is correct |
| Admin tab not visible | `is_admin` not set | Follow Part 5 to update the profiles table |
| "Only admins can edit course details" | Expected for non-admins | Only admins edit names/fees/stars; claim still updates status |
| Cannot set myself as admin from the app | Expected | Set `is_admin` only in Supabase Table Editor / SQL (Part 5) |
| Progress auditor table empty for me | Expected for non-admins | Full workload is admin-only after audit privacy RLS |
| Redirect loop after login | Site URL mismatch | Update Site URL in Supabase Auth settings (Part 1.5) |
| Course dates show as one option | `next_run` format issue | Dates are comma-separated in DB — e.g. `3 May, 9 May` |

---

## File Reference

| File | Purpose |
|---|---|
| `index.html` | Complete single-page application (edit for credentials) |
| `supabase_schema.sql` | Database schema, RLS policies, seed data — run once in SQL Editor |
| `SETUP_GUIDE.md` | This guide |

---

## Quick Checklist

- [ ] Supabase project created
- [ ] Email confirmation disabled
- [ ] `supabase_schema.sql` executed successfully
- [ ] API URL and anon key copied
- [ ] GitHub Pages URL added to Supabase Redirect URLs
- [ ] `index.html` updated with Supabase credentials
- [ ] Files committed to GitHub repo
- [ ] GitHub Pages enabled (branch: main, folder: root)
- [ ] App loads at GitHub Pages URL
- [ ] Admin user registered and `is_admin = true` set in profiles table
