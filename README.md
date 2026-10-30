# DOGGO — cloud + recognition foundation

This package extends the working DOGGO front-end with a safer production data model and a server-side candidate-matching endpoint. It is **not yet a live cloud deployment**: it requires a Supabase project, secrets, and a validated individual-dog re-identification model. No API keys are included or hard-coded.

## What is included

- `supabase/migrations/202610300001_doggo_cloud_foundation.sql`: vector storage for dog photo embeddings, similarity index, candidate search RPC, match-review records, claim requests, blocks, and access controls.
- `supabase/functions/match-dog/index.ts`: authenticated Edge Function. It verifies the signed-in user owns the uploaded photo, creates a short-lived private image URL, calls a configurable dog re-identification provider, validates the 768-dimensional embedding, and returns ranked candidate dogs for human confirmation.
- Existing responsive DOGGO front end, profile creation, breed list and community match-selection work are preserved.

## Architecture

- **Vercel**: web app hosting.
- **Supabase Auth**: user accounts and sessions.
- **Supabase Postgres + pgvector**: dog identities, albums, sightings and visual embeddings.
- **Supabase Storage**: private original photos; use signed URLs for access.
- **Supabase Edge Functions**: trusted upload/matching operations. Never put the service-role key in browser code.
- **Dog re-identification model**: must compare *individual dogs*, not just classify breed or describe an image.

## Setup — one-time infrastructure

1. Create a Supabase project in a region close to the first launch market.
2. In Supabase SQL Editor, run the existing `supabase/schema.sql` from this package.
3. Then run `supabase/migrations/202610300001_doggo_cloud_foundation.sql`.
4. In Supabase Storage, confirm the private `dog-photos` bucket exists. Keep it private.
5. Deploy the function:

   ```bash
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   supabase functions deploy match-dog --no-verify-jwt
   ```

6. Set function secrets (never commit real values):

   ```bash
   supabase secrets set APP_ORIGIN=https://doggo-app-pi.vercel.app
   supabase secrets set DOG_REID_ENDPOINT=https://YOUR-VALIDATED-PROVIDER-ENDPOINT
   supabase secrets set DOG_REID_API_KEY=YOUR_PROVIDER_KEY
   ```

   Supabase provides `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` to deployed Edge Functions in the project environment. Verify these are available in the function's secrets/environment before testing.

7. Add the Supabase project URL and anon/publishable key to Vercel environment variables before wiring the browser client. The service-role key belongs only in Supabase server-side secrets.

## Recognition provider contract

The Edge Function expects a provider endpoint accepting:

```json
{
  "image_url": "short-lived-signed-image-url",
  "task": "individual_dog_reidentification"
}
```

It must return:

```json
{
  "model": "provider-model-version",
  "embedding": [0.01, 0.02]
}
```

The real response must contain exactly **768 finite numbers**. This is a deliberate adapter contract, not a claim that a generic image model can identify individual dogs. Before launch, select and benchmark a dog re-identification model on a representative dataset (different angles, lighting, grooming, age, collars, and time gaps). Calibrate similarity thresholds on held-out dogs. A similarity score is not a probability. Keep user confirmation and a review queue; never auto-merge dog identities based on an unvalidated threshold.

## Critical next engineering steps before public launch

- Wire Supabase Auth into the sign-in/profile UI.
- Replace browser-only dog/photo/follow/reaction storage with Supabase queries and Storage uploads.
- Call `match-dog` after a photo upload and render candidates; save user confirmation/rejection into `dog_match_reviews`.
- Add moderation/admin workflows for pending community photos and claims.
- Add server-side location coarsening/jitter before publishing sightings. Never publish home-level coordinates or real-time tracking.
- Add rate limits, image MIME/size validation, malware/content moderation, abuse reporting review, retention/deletion workflows, backups and monitoring.
- Test every RLS policy with anonymous, normal user, owner, contributor and moderator roles before production.
- Add privacy policy, terms, consent and account/photo deletion flow.

## Important honesty about current status

The current browser app remains a front-end prototype. The new SQL and Edge Function are backend foundations; they do not activate shared cloud accounts or AI recognition until the Supabase project is created, migration/function are deployed, the provider is selected and the app UI is connected. The demo's sample dogs are not a real DOGGO community database.
