# 悦享按摩 / Yuexiang Massage

React + Vite + Supabase bilingual massage booking app. Includes a public booking form and owner dashboard.

## Run locally

1. Install Node.js 20+.
2. `npm install`
3. `npm run dev` — without environment variables this runs a UI-only demo (real bookings are disabled).

## Activate real bookings

1. Create a project at https://supabase.com and run `schema.sql` in SQL Editor **once on a new project**.
2. In Supabase Authentication, create an email/password user for the owner. Disable public sign-ups if not needed.
3. Replace `OWNER_EMAIL@example.com` in the final SQL comment with the owner's email, remove the `--` prefix, and execute that single `insert into public.admin_users...` statement in SQL Editor.
4. Copy `.env.example` to `.env.local` and fill the Supabase project URL and **publishable/anon** key. **Never put the service_role key in the frontend.**
5. Restart `npm run dev`. Test booking and dashboard login. To publish, push the folder to GitHub, import it into Vercel, add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in Vercel project environment variables, and deploy (Vite preset, build `npm run build`, output `dist`).
6. Configure the production site URL and allowed redirect URLs in Supabase Auth. Set up a custom domain and HTTPS in Vercel.

## Important limitations before taking public bookings

- This is an **MVP**, not a fully production-hardened appointment system. The database transaction prevents double-booking for the same therapist, but the UI does not fetch booked slots before showing times. Conflicts return an error at submission.
- Time conversion is based on Los Angeles timezone and must be tested carefully across daylight saving transitions; use a robust timezone library or server-side conversion before launch.
- Staff shifts, days off, holiday closures, service buffers, appointment rescheduling, customer self-service cancellation, and SMS/email notifications are not yet implemented.
- The booking RPC is publicly callable. Add CAPTCHA, rate limiting (preferably via an edge function), abuse monitoring, and a privacy policy before sharing publicly. Phone numbers and names are visible only to authorized admin users via RLS; configure retention and backup policies.
- Owner access is explicitly granted through `admin_users`, not merely by having an account.
- Payment is in store only; no online payment integration.
- Change sample service prices, staff names, and business contact details to real values before launch.
