# juru.lol

A dark/violet site for hosting a single Roblox loadstring, with:

- A public page: loadstring + copy button, live status, version, info, and supported executors
- A raw-script endpoint at `/script/loader/juru.lua`, gated so only Roblox's HTTP client can read it (normal browsers get a 404)
- A `/login` page that checks a single 16-character key, and an `/admin` dashboard to edit the script, version, status, info, executor list, and video URL — all stored in Neon Postgres
- A showcase video section using a native `<video>` tag (not an iframe), so the browser's own fullscreen prompt shows **juru.lol**, not a third-party site

## 1. Create the database (Neon)

1. Go to [neon.tech](https://neon.tech), create a free project.
2. Copy the connection string from the dashboard (**Connection Details**). It looks like:
   `postgres://user:password@ep-xxxx.region.aws.neon.tech/dbname?sslmode=require`
3. Open the **SQL Editor** in Neon, paste in the contents of `schema.sql`, and run it.
   (Alternatively, once you've set `DATABASE_URL` locally, run `npm install && npm run seed`.)

This creates one table, `site_data`, with a single row (id = 1) holding everything the site shows — script content, version, status, info text, executor list, and the video URL.

## 2. Set your admin key

Pick a 16-character string for logging into `/admin` — this is the "password" for the whole site, so make it random. Example (run locally, don't share the output):

```bash
openssl rand -hex 8
```

That produces exactly 16 hex characters, e.g. `9f2a7c1e4b8d0f3a`.

You'll also need a separate, longer secret that signs the admin session cookie:

```bash
openssl rand -hex 32
```

## 3. Configure environment variables

Copy `.env.example` to `.env.local` for local dev, and fill in:

```
DATABASE_URL=<your Neon connection string>
ADMIN_KEY=<your 16-character key>
SESSION_SECRET=<your long random secret>
```

## 4. Run locally

```bash
npm install
npm run dev
```

Visit `http://localhost:3000` for the public site, and `http://localhost:3000/login` to sign in with your `ADMIN_KEY`.

## 5. Deploy to Vercel

1. Push this project to a GitHub repo (or run `vercel` directly from this folder with the Vercel CLI).
2. Import the repo in [vercel.com/new](https://vercel.com/new).
3. In the Vercel project's **Settings → Environment Variables**, add `DATABASE_URL`, `ADMIN_KEY`, and `SESSION_SECRET` (same values as your `.env.local`).
4. Deploy. Then in **Settings → Domains**, add `juru.lol` and point your DNS at Vercel per their instructions.

## 6. Set the real loadstring content

Log into `/admin` and paste your actual script into the **Script contents** box, then set the version, status, info blurb, and executor list, and hit **Save changes**. The public loadstring itself never changes — it always points at:

```lua
loadstring(game:HttpGet("https://juru.lol/script/loader/juru.lua"))()
```

— what changes is the content that endpoint returns, which you control from `/admin`.

### Why the raw script is "hidden" from browsers

`/script/loader/juru.lua` checks the request's `User-Agent` header. Roblox's `HttpGet` (and every executor's HTTP client) sends a user agent containing `Roblox`; ordinary browsers don't. Requests without that get a plain 404. This isn't bulletproof (a user-agent header can be spoofed by anyone determined to), but it stops casual browser visits from being able to just open the link and read the script.

## 7. Hosting the video

YouTube embeds live in an iframe, so a viewer's fullscreen prompt shows `youtube.com`. To have it show **juru.lol** instead, the video needs to be a same-origin (or at least directly-linked) `<video>` element rather than an iframe embed. Options that give you a direct, embeddable file URL:

- **Bunny Stream** (bunny.net) — cheap, fast, built for this exact use case, gives you an MP4/HLS URL.
- **Cloudflare R2** — S3-compatible object storage; put the `.mp4` in a public bucket and use the public URL directly.
- **Cloudflare Stream** — like Bunny Stream, also gives a direct playback URL.

Whichever you use, paste the direct video URL into the **Video URL** field in `/admin`. The site uses a plain `<video>` tag pointed at that URL, so clicking "Fullscreen" triggers the browser's native fullscreen on your own page — the on-screen fullscreen notice will read `juru.lol`.

## Project structure

```
app/
  page.tsx                     public landing page
  login/page.tsx                admin login
  admin/page.tsx                admin dashboard (protected)
  script/loader/[file]/route.ts raw .lua endpoint, Roblox-only
  api/status/route.ts           public status JSON (version/status/executors/video)
  api/admin/login/route.ts      login + logout
  api/admin/data/route.ts       read/update site data (protected)
lib/
  db.ts                         Neon queries
  auth.ts                       signed session cookie helpers
middleware.ts                   redirects unauthenticated /admin requests to /login
schema.sql                      Neon table definition + seed row
scripts/seed.mjs                convenience script to apply schema.sql
```
