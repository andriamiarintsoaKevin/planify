create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;

create table public.tasks (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  title text not null,
  notes text not null default '',
  duration_minutes integer,
  priority text not null default 'medium'
    check (priority in ('low', 'medium', 'high')),
  due_date timestamptz,
  status text not null default 'inbox'
    check (status in ('inbox', 'scheduled', 'inProgress', 'done', 'postponed')),
  scheduled_start timestamptz,
  planned_end timestamptz,
  project text not null default '',
  is_locked boolean not null default false,
  is_ai_proposed boolean not null default false,
  is_duration_estimated boolean not null default false,
  reminder_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index tasks_user_id_updated_at_idx
  on public.tasks (user_id, updated_at);

alter table public.tasks enable row level security;

revoke all on table public.tasks from public, anon, authenticated;
grant select, insert, update, delete on table public.tasks to authenticated;

create policy "Users can select their own tasks"
  on public.tasks for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can insert their own tasks"
  on public.tasks for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own tasks"
  on public.tasks for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own tasks"
  on public.tasks for delete to authenticated
  using ((select auth.uid()) = user_id);

create function app_private.set_task_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

create trigger tasks_set_updated_at
  before update on public.tasks
  for each row execute function app_private.set_task_updated_at();
