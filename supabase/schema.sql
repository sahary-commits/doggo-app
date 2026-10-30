-- DOGGO initial Supabase schema sketch.
-- Includes baseline RLS. Review, test with anon/authenticated roles, and add retention rules before production.
create extension if not exists pgcrypto;
create extension if not exists postgis;
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text,
  country_code char(2),
  preferred_language text default 'en',
  created_at timestamptz not null default now()
);
create table if not exists public.dogs (
  id uuid primary key default gen_random_uuid(),
  display_name text not null default 'Unknown dog',
  breed_label text,
  description text,
  country_code char(2),
  city text,
  created_by uuid references public.profiles(id) on delete set null,
  claimed_by uuid references public.profiles(id) on delete set null,
  claim_status text not null default 'unclaimed' check (claim_status in ('unclaimed','pending','verified')),
  visibility text not null default 'public' check (visibility in ('public','private','hidden')),
  created_at timestamptz not null default now()
);
create table if not exists public.dog_photos (
  id uuid primary key default gen_random_uuid(),
  dog_id uuid not null references public.dogs(id) on delete cascade,
  contributor_id uuid references public.profiles(id) on delete set null,
  storage_path text not null,
  caption text,
  moderation_status text not null default 'pending' check (moderation_status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);
create table if not exists public.sightings (
  id uuid primary key default gen_random_uuid(),
  dog_id uuid not null references public.dogs(id) on delete cascade,
  reporter_id uuid references public.profiles(id) on delete set null,
  approximate_geog geography(point, 4326),
  location_label text,
  observed_at timestamptz not null default now(),
  visibility text not null default 'approximate' check (visibility in ('private','approximate','public')),
  created_at timestamptz not null default now()
);
create table if not exists public.dog_follows (
  user_id uuid not null references public.profiles(id) on delete cascade,
  dog_id uuid not null references public.dogs(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id,dog_id)
);
create table if not exists public.photo_reactions (
  user_id uuid not null references public.profiles(id) on delete cascade,
  photo_id uuid not null references public.dog_photos(id) on delete cascade,
  reaction text not null default 'like',
  created_at timestamptz not null default now(),
  primary key(user_id,photo_id)
);
create index if not exists dogs_country_city_idx on public.dogs(country_code,city);
create index if not exists photos_dog_created_idx on public.dog_photos(dog_id,created_at desc);
create index if not exists sightings_dog_observed_idx on public.sightings(dog_id,observed_at desc);

-- ===== Reviews/moderation helper =====
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  photo_id uuid references public.dog_photos(id) on delete cascade,
  dog_id uuid references public.dogs(id) on delete cascade,
  reason text not null,
  created_at timestamptz not null default now()
);

-- ===== Auto-create a profile on signup =====
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, display_name) values (new.id, split_part(new.email,'@',1))
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ===== Row Level Security =====
alter table public.profiles enable row level security;
alter table public.dogs enable row level security;
alter table public.dog_photos enable row level security;
alter table public.sightings enable row level security;
alter table public.dog_follows enable row level security;
alter table public.photo_reactions enable row level security;
alter table public.reports enable row level security;

-- profiles: readable by everyone, editable by owner
create policy "profiles read" on public.profiles for select using (true);
create policy "profiles update own" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- dogs: public dogs visible; owners/creators see their own; anyone signed in can add
create policy "dogs read" on public.dogs for select
  using (visibility = 'public' or created_by = auth.uid() or claimed_by = auth.uid());
create policy "dogs insert" on public.dogs for insert to authenticated
  with check (created_by = auth.uid());
create policy "dogs update owner" on public.dogs for update to authenticated
  using (created_by = auth.uid() or claimed_by = auth.uid())
  with check (created_by = auth.uid() or claimed_by = auth.uid());

-- photos: only approved photos on public dogs are public; contributors see their own
create policy "photos read" on public.dog_photos for select
  using (
    contributor_id = auth.uid()
    or (moderation_status = 'approved'
        and exists (select 1 from public.dogs d where d.id = dog_id and d.visibility = 'public'))
  );
create policy "photos insert" on public.dog_photos for insert to authenticated
  with check (contributor_id = auth.uid() and moderation_status = 'pending');
create policy "photos delete own" on public.dog_photos for delete to authenticated
  using (contributor_id = auth.uid());

-- sightings: only approximate/public ones on public dogs are visible; reporter sees own
create policy "sightings read" on public.sightings for select
  using (
    reporter_id = auth.uid()
    or (visibility in ('approximate','public')
        and exists (select 1 from public.dogs d where d.id = dog_id and d.visibility = 'public'))
  );
create policy "sightings insert" on public.sightings for insert to authenticated
  with check (reporter_id = auth.uid());

-- follows and reactions: private to the user, except reactions are counted via a view/function
create policy "follows own" on public.dog_follows for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "reactions read" on public.photo_reactions for select using (true);
create policy "reactions write own" on public.photo_reactions for insert to authenticated
  with check (user_id = auth.uid());
create policy "reactions update own" on public.photo_reactions for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "reactions delete own" on public.photo_reactions for delete to authenticated
  using (user_id = auth.uid());

-- reports: write-only for users (moderators read via service role)
create policy "reports insert" on public.reports for insert to authenticated
  with check (reporter_id = auth.uid());

-- ===== Storage: private-by-default bucket, uploads under <user id>/ =====
insert into storage.buckets (id, name, public) values ('dog-photos','dog-photos', false)
on conflict (id) do nothing;
create policy "dog photos upload own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'dog-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "dog photos read" on storage.objects for select to authenticated
  using (bucket_id = 'dog-photos');
create policy "dog photos delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'dog-photos' and (storage.foldername(name))[1] = auth.uid()::text);
