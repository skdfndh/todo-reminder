create table if not exists public.user_snapshots (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.user_snapshots enable row level security;

create policy "用户读取自己的待办快照"
on public.user_snapshots
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "用户创建自己的待办快照"
on public.user_snapshots
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "用户更新自己的待办快照"
on public.user_snapshots
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

grant select, insert, update on table public.user_snapshots to authenticated;
