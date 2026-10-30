-- DOGGO community albums: let a dog creator/claimed owner approve or reject contributed photos.
-- Contributors may submit pending photos using the existing photos insert policy.
-- Only the moderation_status column is writable by authenticated clients.
revoke update on public.dog_photos from authenticated;
grant update (moderation_status) on public.dog_photos to authenticated;

drop policy if exists "dog owners moderate photos" on public.dog_photos;
create policy "dog owners moderate photos" on public.dog_photos
for update to authenticated
using (
  exists (
    select 1 from public.dogs d
    where d.id = dog_photos.dog_id
      and (d.created_by = auth.uid() or d.claimed_by = auth.uid())
  )
)
with check (
  moderation_status in ('approved','rejected')
  and exists (
    select 1 from public.dogs d
    where d.id = dog_photos.dog_id
      and (d.created_by = auth.uid() or d.claimed_by = auth.uid())
  )
);

-- Dog creators and claimed owners may see pending submissions on their own profiles.
drop policy if exists "photos read" on public.dog_photos;
create policy "photos read" on public.dog_photos
for select
using (
  contributor_id = auth.uid()
  or (moderation_status = 'approved'
      and exists (select 1 from public.dogs d where d.id = dog_id and d.visibility = 'public'))
  or exists (
      select 1 from public.dogs d
      where d.id = dog_id
        and (d.created_by = auth.uid() or d.claimed_by = auth.uid())
  )
);
