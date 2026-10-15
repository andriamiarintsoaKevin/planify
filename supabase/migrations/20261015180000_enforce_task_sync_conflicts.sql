create or replace function app_private.set_task_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.deleted_at is not null and new.deleted_at is null then
    return old;
  end if;

  if new.deleted_at is not null and old.deleted_at is null then
    return new;
  end if;

  if new.updated_at <= old.updated_at then
    return old;
  end if;

  return new;
end;
$$;
