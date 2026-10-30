-- DOGGO trainer accounts and explicit dog ownership attribution.
-- Safe to run once after the existing DOGGO schema and community album migration.

alter table public.profiles
  add column if not exists account_type text not null default 'owner';

alter table public.profiles
  drop constraint if exists profiles_account_type_check;
alter table public.profiles
  add constraint profiles_account_type_check
  check (account_type in ('owner','trainer'));

-- A trainer creates a public dog profile without claiming ownership.
-- An owner-created profile is attributed to that signed-in owner immediately.
-- Existing rows are intentionally left unchanged.

create index if not exists dogs_claimed_by_idx on public.dogs(claimed_by);
create index if not exists dogs_created_by_idx on public.dogs(created_by);

comment on column public.profiles.account_type is
  'Self-selected DOGGO account mode: owner or trainer. Trainer status is not independently verified.';
comment on column public.dogs.created_by is
  'DOGGO user who created the profile; for trainer-created dogs this is the managing trainer until an owner claims the profile.';
comment on column public.dogs.claimed_by is
  'Verified/claiming owner account. Null means no owner has claimed the profile yet.';
