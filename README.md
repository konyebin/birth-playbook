# Birth Playbook

A single-file companion app for a birth partner — prep, labor support, a contraction timer with "when to call" detection, a newborn feed/diaper tracker, and postpartum recovery, plus a one-tap warning-signs reference.

**Live:** https://konyebin.github.io/birth-playbook/

## How your data is handled

By default everything you enter (contraction logs, due date, GBS status, feeds, diapers, birth date, checklists) is stored **locally in your browser** via `localStorage` and goes nowhere else.

**Optional live sync** lets two phones share the same playbook in real time:

- Open the **Sync** card (top of the Prep tab) and tap **Start a shared room**, then send your partner the link.
- Once they open it, both devices stay in sync within a second or two.
- Synced data lives in a private **Supabase** (Postgres) project, protected by row-level security + anonymous accounts: **only devices that joined with your room link can read it.** No names, emails, or logins are collected.
- The Supabase URL and publishable key in the code are public by design — security comes from the row-level-security policies (see `supabase-setup.sql`), not from hiding the key.
- Each device keeps its own navigation and in-progress timers; only the shared data syncs.

Don't want sync? Just don't start or join a room — the app works fully on a single device.

## Backend setup (only needed to self-host the sync)

1. Create a free project at [supabase.com](https://supabase.com).
2. Enable **Authentication → Sign In / Providers → Allow anonymous sign-ins**.
3. Run `supabase-setup.sql` in the Supabase SQL editor.
4. Put your project URL + anon/publishable key into the `SUPA_URL` / `SUPA_KEY` constants near the top of the script in `index.html`.

## Use

Open the live link on your phone and add it to your home screen. It works offline once loaded (the web font falls back to a system typeface, and synced changes catch up when you reconnect).

## Disclaimer

This is a support and organization tool, not medical advice. The contraction-timer prompts are a convenience, not a substitute for your provider's instructions. When in doubt, call your midwife, OB, or emergency services.
