create or replace function public.delete_account_data(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() is distinct from 'service_role' or p_user_id is null then
    raise exception 'Unauthorized account deletion request';
  end if;

  delete from public.tasks where user_id = p_user_id;
  delete from public.ai_usage where user_id = p_user_id;
end;
$$;

revoke all on function public.delete_account_data(uuid)
  from public, anon, authenticated;
grant execute on function public.delete_account_data(uuid)
  to service_role;
