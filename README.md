# DOGGO — Vercel starter

A responsive, installable PWA prototype for DOGGO. It is designed to deploy as a static site on Vercel and work on desktop and mobile browsers.

## What works in this starter
- Responsive DOGGO home screen and navigation
- Sample dog directory and community leaderboard
- Dog detail modal with sample album
- Photo picker / mobile camera capture entry point
- Demonstration scan → possible match → confirm flow
- Follow dogs and points persisted in browser local storage
- PWA manifest and service worker

## Important: prototype vs production
This is a front-end prototype. It does **not** yet have real user accounts, shared cloud uploads, live maps, AI individual-dog recognition, moderation, or cross-device data sync. The scan match is explicitly sample data. Do not present it as live AI or real location tracking.

## Deploy to Vercel
1. Create a GitHub repository and upload the contents of this folder.
2. In Vercel choose **Add New → Project**, import that repository.
3. Framework preset: **Other**. Build command: leave blank. Output directory: `.` (project root).
4. Deploy. Vercel will provide a preview URL; connect a custom domain later if desired.

Vercel Git deployments can create Preview deployments for branches and Production deployments from the production branch. See https://vercel.com/docs/git and https://vercel.com/docs/deployments.

## Next production build
Recommended architecture:
- Next.js (Vercel) for web app and server routes
- Supabase Auth, Postgres, Storage and Row Level Security
- Mapbox for maps and approximate sighting display
- Server-side vision pipeline + image embeddings/vector similarity for individual-dog candidate matching
- Human confirmation for uncertain matches
- Moderation queue and owner controls before public album publication

`supabase/schema.sql` is an initial relational schema sketch, not a production-ready security policy. Review and add RLS policies before connecting public clients.

## Local preview
You can serve this folder with any static server, e.g. `npx serve .` (Node.js required).
