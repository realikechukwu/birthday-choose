# MzMichyE Birthday Shortlist

Mobile-first Manchester restaurant shortlist with a side-by-side comparison, interactive map, drag-and-drop ranking, public results and a Supabase-backed vote path.

## Setup

1. For a **new database only**, run [supabase/001_birthday_votes.sql](/Users/ikechukwuchukwudi/Documents/coding_projects/birthday-choose/supabase/001_birthday_votes.sql) in the Supabase SQL editor.
2. Copy \`.env.example\` to \`.env.local\` and set \`VITE_SUPABASE_URL\` and \`VITE_SUPABASE_ANON_KEY\` to the public project URL and anon key.
3. Run \`npm install\`, then \`npm run dev\`.

Without those environment variables the site runs in local demo mode, storing votes in the current browser only. The live schema uses a public read policy and a security-definer RPC for writes. A browser token is hashed in \`birthday_vote_owners\`, so a visitor cannot overwrite another person's vote just by entering their name.

## Editing restaurant content

All restaurant content, official links, images, prices, estimates and comparison copy live in [data/restaurants.ts](/Users/ikechukwuchukwudi/Documents/coding_projects/birthday-choose/data/restaurants.ts). Change the structured records there rather than editing the page component.

The current facts were checked against the official venue pages and menus on 8 September 2026. “Comfortable birthday budget”, walking times and editorial comparisons are explicitly labelled estimates; re-check them when the event date is set.

## Deploying to Vercel

Use the existing \`npm run build\` output with Vercel's Next.js/Vinext detection, and add the two \`VITE_\` variables in the Vercel project settings. The current static configuration is in \`next.config.ts\` and \`.openai/hosting.json\`.

## Six-restaurant restart

For the existing database, run `supabase/002_six_restaurants_reset.sql` **once** in the SQL editor. It atomically removes votes and ownership records, updates the ranking constraint, and replaces the RPC with six-ID validation. Do not rerun 001 against existing tables. For a fresh database, apply 001 then 002 before collecting votes. Browser-token ownership, public reads and RPC-only writes remain in place.

The frontend awards 6–5–4–3–2–1 points. Drafts and submission markers use a new session-storage namespace, so old five-choice drafts do not look submitted in the restarted vote.

Validation: `npx tsc --noEmit`, `node --test tests/votes.test.mjs`, `npm run lint`, `npm run build`. `tests/database.sql` exercises anonymous submissions, own-browser updates, cross-browser rejection and direct-access restrictions; run it with `psql -v ON_ERROR_STOP=1` against a disposable database after migrations 001 and 002. Its writes roll back.
