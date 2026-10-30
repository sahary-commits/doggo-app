import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': Deno.env.get('APP_ORIGIN') ?? 'https://doggo-app-pi.vercel.app',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, 'Content-Type': 'application/json' },
});

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const url = Deno.env.get('SUPABASE_URL');
  const anon = Deno.env.get('SUPABASE_ANON_KEY');
  const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const providerUrl = Deno.env.get('DOG_REID_ENDPOINT');
  const providerKey = Deno.env.get('DOG_REID_API_KEY');
  if (!url || !anon || !service) return json({ error: 'Supabase function secrets are incomplete.' }, 503);
  if (!providerUrl || !providerKey) return json({
    status: 'recognition_not_configured',
    message: 'Cloud profiles are ready, but individual-dog recognition is not activated until a validated dog re-identification model is configured.'
  }, 503);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Sign in is required.' }, 401);
  const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: authError } = await userClient.auth.getUser();
  if (authError || !userData.user) return json({ error: 'Invalid session.' }, 401);

  let body: { photo_id?: string; storage_path?: string; dog_id?: string };
  try { body = await req.json(); } catch { return json({ error: 'Invalid JSON body.' }, 400); }
  if (!body.photo_id || !body.storage_path) return json({ error: 'photo_id and storage_path are required.' }, 400);

  const admin = createClient(url, service);
  const { data: photo, error: photoError } = await admin.from('dog_photos')
    .select('id, contributor_id, storage_path, dog_id').eq('id', body.photo_id).single();
  if (photoError || !photo || photo.contributor_id !== userData.user.id || photo.storage_path !== body.storage_path) {
    return json({ error: 'Photo not found or not owned by this account.' }, 403);
  }
  const { data: signed, error: signedError } = await admin.storage.from('dog-photos').createSignedUrl(photo.storage_path, 90);
  if (signedError || !signed?.signedUrl) return json({ error: 'Could not access uploaded photo.' }, 500);

  // Provider contract: POST { image_url } with Bearer API key; return { embedding: number[768], model: string }.
  // The provider must be validated for individual-dog re-identification, not merely breed classification.
  let provider: Response;
  try {
    provider = await fetch(providerUrl, {
      method: 'POST', headers: { Authorization: `Bearer ${providerKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ image_url: signed.signedUrl, task: 'individual_dog_reidentification' }),
    });
  } catch { return json({ error: 'Recognition provider could not be reached.' }, 502); }
  if (!provider.ok) return json({ error: 'Recognition provider failed.', provider_status: provider.status }, 502);
  const result = await provider.json();
  const embedding = result?.embedding;
  if (!Array.isArray(embedding) || embedding.length !== 768 || embedding.some((n: unknown) => typeof n !== 'number' || !Number.isFinite(n))) {
    return json({ error: 'Recognition provider returned an invalid embedding. Expected 768 numeric values.' }, 502);
  }
  const vector = `[${embedding.join(',')}]`;
  const { data: candidates, error: matchError } = await admin.rpc('find_dog_candidates', {
    query_embedding: vector, match_limit: 5, min_similarity: 0.72,
  });
  if (matchError) return json({ error: 'Candidate search failed.' }, 500);
  return json({
    status: 'candidates_found',
    candidates: candidates ?? [],
    requires_user_confirmation: true,
    model: String(result.model ?? 'configured-dog-reid-model'),
    note: 'Similarity is not a probability. Never auto-assign a dog from this score alone.',
  });
});
