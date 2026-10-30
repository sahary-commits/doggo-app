-- DOGGO cloud foundation: run after the existing schema.sql.
-- Vector size is intentionally 768; the selected dog re-identification model must emit 768 dimensions.
create extension if not exists vector with schema extensions;

alter table public.dogs
  add column if not exists slug text,
  add column if not exists avatar_photo_id uuid,
  add column if not exists profile_completeness smallint not null default 0,
  add column if not exists updated_at timestamptz not null default now();

alter table public.dog_photos
  add column if not exists is_profile_photo boolean not null default false,
  add column if not exists image_width integer,
  add column if not exists image_height integer,
  add column if not exists file_size_bytes bigint,
  add column if not exists content_hash text;

create unique index if not exists dog_photos_content_hash_idx
  on public.dog_photos(contributor_id, content_hash) where content_hash is not null;

create table if not exists public.dog_embeddings (
  photo_id uuid primary key references public.dog_photos(id) on delete cascade,
  dog_id uuid not null references public.dogs(id) on delete cascade,
  model_key text not null,
  embedding extensions.vector(768) not null,
  quality_score real,
  created_at timestamptz not null default now()
);
create index if not exists dog_embeddings_dog_idx on public.dog_embeddings(dog_id);
create index if not exists dog_embeddings_vector_idx
  on public.dog_embeddings using hnsw (embedding extensions.vector_cosine_ops);

create table if not exists public.dog_match_reviews (
  id uuid primary key default gen_random_uuid(),
  photo_id uuid not null references public.dog_photos(id) on delete cascade,
  candidate_dog_id uuid not null references public.dogs(id) on delete cascade,
  similarity real not null,
  status text not null default 'pending' check(status in ('pending','confirmed','rejected','expired')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  unique(photo_id,candidate_dog_id)
);

create table if not exists public.dog_claim_requests (
  id uuid primary key default gen_random_uuid(),
  dog_id uuid not null references public.dogs(id) on delete cascade,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  message text,
  evidence_path text,
  status text not null default 'pending' check(status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  unique(dog_id,requester_id)
);

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id,blocked_id),
  check(blocker_id <> blocked_id)
);

alter table public.dog_embeddings enable row level security;
alter table public.dog_match_reviews enable row level security;
alter table public.dog_claim_requests enable row level security;
alter table public.user_blocks enable row level security;

-- Embeddings and review internals are never directly exposed to public clients.
revoke all on public.dog_embeddings from anon, authenticated;
revoke all on public.dog_match_reviews from anon, authenticated;

create policy "claim requests read own" on public.dog_claim_requests
  for select to authenticated using (requester_id = auth.uid());
create policy "claim requests insert own" on public.dog_claim_requests
  for insert to authenticated with check (requester_id = auth.uid() and status = 'pending');
create policy "blocks read own" on public.user_blocks
  for select to authenticated using (blocker_id = auth.uid());
create policy "blocks insert own" on public.user_blocks
  for insert to authenticated with check (blocker_id = auth.uid());
create policy "blocks delete own" on public.user_blocks
  for delete to authenticated using (blocker_id = auth.uid());

-- Candidate matching runs only with service-role privileges inside an Edge Function.
create or replace function public.find_dog_candidates(
  query_embedding extensions.vector(768),
  match_limit integer default 5,
  min_similarity real default 0.72
) returns table(dog_id uuid, similarity real)
language sql stable security definer set search_path = public, extensions as $$
  select e.dog_id,
         (1 - (e.embedding <=> query_embedding))::real as similarity
  from public.dog_embeddings e
  join public.dogs d on d.id = e.dog_id
  where d.visibility = 'public'
    and d.claim_status in ('unclaimed','pending','verified')
    and (1 - (e.embedding <=> query_embedding)) >= min_similarity
  group by e.dog_id
  order by max(1 - (e.embedding <=> query_embedding)) desc
  limit greatest(1, least(match_limit, 10));
$$;
revoke all on function public.find_dog_candidates(extensions.vector,integer,real) from public, anon, authenticated;
grant execute on function public.find_dog_candidates(extensions.vector,integer,real) to service_role;

-- Never expose precise coordinates through public queries. Store a deliberately jittered point
-- or a coarse location label from a trusted server process before public display.
create index if not exists sightings_geog_idx on public.sightings using gist(approximate_geog);
