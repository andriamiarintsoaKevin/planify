create table public.ai_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  jour date not null,
  nombre_appels integer not null default 0 check (nombre_appels >= 0),
  primary key (user_id, jour)
);

alter table public.ai_usage enable row level security;

revoke all on table public.ai_usage from public, anon, authenticated;
grant select on table public.ai_usage to authenticated;

create policy "Users can view their own AI usage"
  on public.ai_usage for select to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.consume_ai_usage(
  p_user_id uuid,
  p_daily_limit integer
)
returns table (allowed boolean, nombre_appels integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_jour date := (pg_catalog.now() at time zone 'UTC')::date;
  v_nombre_appels integer;
begin
  if auth.role() is distinct from 'service_role'
     or p_user_id is null
     or p_daily_limit < 1 then
    raise exception 'Unauthorized quota request';
  end if;

  insert into public.ai_usage as usage (user_id, jour, nombre_appels)
  values (p_user_id, v_jour, 1)
  on conflict (user_id, jour) do update
    set nombre_appels = usage.nombre_appels + 1
    where usage.nombre_appels < p_daily_limit
  returning usage.nombre_appels into v_nombre_appels;

  if v_nombre_appels is null then
    select usage.nombre_appels into v_nombre_appels
      from public.ai_usage as usage
      where usage.user_id = p_user_id and usage.jour = v_jour;
    return query select false, v_nombre_appels;
  else
    return query select true, v_nombre_appels;
  end if;
end;
$$;

revoke all on function public.consume_ai_usage(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.consume_ai_usage(uuid, integer)
  to service_role;
