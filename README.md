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


## DOGGO Supabase project configuration (2026-10-30)

The browser client is now configured with the supplied project URL and publishable key in `supabase-config.js`. This key is intended to be public; database safety depends on the Row Level Security policies in the SQL schema. Do not add a service-role key to this file or to Vercel.

**Important:** this step initializes the Supabase SDK but does not yet migrate DOGGO's profile, photo, follow, sighting, or feed features from localStorage to the cloud. It is not evidence that shared accounts or cloud dog profiles are active.

Next setup steps:
1. Open the Supabase SQL Editor for project `vgaszqqogqjmovepkgir`.
2. Run `supabase/schema.sql` first, then `supabase/migrations/202610300001_doggo_cloud_foundation.sql`.
3. Confirm the private `dog-photos` Storage bucket exists.
4. In Supabase Authentication settings, configure the allowed site URL as `https://doggo-app-pi.vercel.app` and add that URL to the redirect allow list.
5. Redeploy the updated project to Vercel.

The remaining application work is to add sign-in/sign-up UI and replace browser-only data operations with authenticated Supabase queries and Storage uploads. Individual-dog AI matching also remains inactive until a validated dog re-identification provider is selected and deployed.


## DOGGO cloud-connected app update

This build now connects the browser app to the configured Supabase project for:
- Email/password sign-up and sign-in using Supabase Auth.
- Loading public dog profiles from `public.dogs` (plus the clearly illustrative starter sample cards).
- Creating dog profiles in `public.dogs` for the signed-in user.
- Uploading an optional profile photo to the private `dog-photos` bucket and recording it in `public.dog_photos` as `pending` moderation.
- Creating/removing follows in `public.dog_follows`.

The browser uses only the public publishable key in `supabase-config.js`; never add a service-role key. The database and Storage RLS policies remain essential. Profile images are displayed using short-lived signed URLs.

### Deploy this app
Upload the **contents** of this folder to the root of the existing GitHub repository connected to Vercel, commit, and wait for Vercel to deploy. The Supabase URL and publishable key are already configured in `supabase-config.js`. No further SQL is required for these implemented flows because the base schema and cloud-foundation migration have already been applied in the project.

### Current limitations (not yet implemented)
- Individual-dog AI recognition is not active. The scan screen does not claim to identify a dog.
- Map-based discovery and real geolocation sightings are not active.
- Community album contributions beyond the initial profile photo, moderation/admin tools, account deletion, and full profile editing still need implementation.
- Starter sample dogs are illustrative local demo cards, not real community records.

Test with a new account: sign up, confirm the email if Supabase requests it, sign in, open Profile, create a dog profile, then refresh and confirm it remains visible. If the photo is pending moderation, it is visible to its contributor but not other users until approved.

## Community album update (2026-10-30)

This build adds user photo contributions to real community dog profiles. Uploads are stored in the private `dog-photos` bucket and inserted as `pending`. The dog creator or claimed owner can approve/reject pending contributions in the profile album. Approved photos are visible to signed-in community users through the existing RLS read policy; pending photos are visible to the contributor and dog owner only.

Before deploying this update, run `supabase/migrations/202610300002_community_album_moderation.sql` in the Supabase SQL Editor. This migration grants authenticated users update access only to the moderation status column and adds an owner-only moderation policy. Do not run the earlier schema or migration files again.

Limitations: there is not yet a platform-wide moderator/admin queue, photo content scanning, or automated dog identity recognition. Owners can moderate photos on their own dog profiles only.

## Trainer accounts and ownership attribution (2026-10-30)

Run `supabase/migrations/202610300003_trainer_accounts.sql` after the earlier schema and community album migration. It adds `profiles.account_type` (`owner` or `trainer`).

In the Profile page, a signed-in user can switch between Dog Owner and Trainer account modes. Trainer-created dog profiles are public, are created with `claimed_by = NULL` and `claim_status = 'unclaimed'`, and show that the owner has not yet claimed the profile. The creator is displayed as the trainer/manager. Owner-created dog profiles are immediately attributed to the signed-in user as `claimed_by` with `claim_status = 'verified'`.

Trainer status is currently self-selected and is not independently credential-verified. The current build supports the trainer role and attribution display, but a complete owner claim-request/review workflow and trainer verification process remain future work. Do not describe a trainer as professionally verified based solely on this role.
