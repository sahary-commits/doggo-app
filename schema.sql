-- DOGGO initial Supabase schema sketch.
-- Review, add RLS policies, indexes, retention rules and storage policies before production.
create extension if not exists pgcrypto;
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
