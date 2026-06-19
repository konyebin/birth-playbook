-- Birth Playbook — Supabase sync setup
-- Paste this whole file into: Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Safe to re-run (idempotent).

-- ---------- tables ----------
create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table if not exists public.room_members (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create table if not exists public.playbook_state (
  room_id uuid not null references public.rooms(id) on delete cascade,
  key text not null,
  value jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (room_id, key)
);

-- ---------- row level security ----------
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.playbook_state enable row level security;

drop policy if exists "members see room" on public.rooms;
create policy "members see room" on public.rooms
  for select to authenticated using (
    id in (select room_id from public.room_members where user_id = auth.uid())
  );

drop policy if exists "see own memberships" on public.room_members;
create policy "see own memberships" on public.room_members
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "members read state" on public.playbook_state;
create policy "members read state" on public.playbook_state
  for select to authenticated using (
    room_id in (select room_id from public.room_members where user_id = auth.uid())
  );

drop policy if exists "members insert state" on public.playbook_state;
create policy "members insert state" on public.playbook_state
  for insert to authenticated with check (
    room_id in (select room_id from public.room_members where user_id = auth.uid())
  );

drop policy if exists "members update state" on public.playbook_state;
create policy "members update state" on public.playbook_state
  for update to authenticated using (
    room_id in (select room_id from public.room_members where user_id = auth.uid())
  ) with check (
    room_id in (select room_id from public.room_members where user_id = auth.uid())
  );

drop policy if exists "members delete state" on public.playbook_state;
create policy "members delete state" on public.playbook_state
  for delete to authenticated using (
    room_id in (select room_id from public.room_members where user_id = auth.uid())
  );

-- ---------- RPCs (validate + bypass RLS via security definer) ----------
create or replace function public.create_room()
returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;
  insert into public.rooms default values returning id into new_id;
  insert into public.room_members (room_id, user_id) values (new_id, auth.uid());
  return new_id;
end; $$;

create or replace function public.join_room(p_room_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;
  if not exists (select 1 from public.rooms where id = p_room_id) then
    raise exception 'room not found';
  end if;
  insert into public.room_members (room_id, user_id)
  values (p_room_id, auth.uid()) on conflict do nothing;
end; $$;

revoke all on function public.create_room() from public;
revoke all on function public.join_room(uuid) from public;
grant execute on function public.create_room() to authenticated;
grant execute on function public.join_room(uuid) to authenticated;

-- ---------- realtime ----------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'playbook_state'
  ) then
    execute 'alter publication supabase_realtime add table public.playbook_state';
  end if;
end $$;
