-- WeighWell cloud storage. Run once in Supabase → SQL Editor.
-- Every record belongs to one user; row-level security makes sure people
-- can only ever read or change their own rows.

create table if not exists public.records (
  user_id    uuid        not null references auth.users (id) on delete cascade,
  kind       text        not null,   -- profile | plan | myfoods | food | workout | checkin
  id         text        not null,   -- record id ('me' for single records, day for check-ins)
  data       jsonb       not null default '{}'::jsonb,
  deleted    boolean     not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, kind, id)
);

create index if not exists records_user_updated on public.records (user_id, updated_at);

alter table public.records enable row level security;

drop policy if exists "own rows: select" on public.records;
drop policy if exists "own rows: insert" on public.records;
drop policy if exists "own rows: update" on public.records;
drop policy if exists "own rows: delete" on public.records;

create policy "own rows: select" on public.records
  for select using (auth.uid() = user_id);
create policy "own rows: insert" on public.records
  for insert with check (auth.uid() = user_id);
create policy "own rows: update" on public.records
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows: delete" on public.records
  for delete using (auth.uid() = user_id);
