-- youB — Commercial V1 company onboarding and user/employee linking.
-- Uses the existing memberships, employees, Auth and RLS contracts.
-- This migration is local/testable only until explicitly applied to a hosted environment.

create or replace function public.link_organization_user(
  p_organization_id uuid,
  p_email text,
  p_role text,
  p_employee_id uuid default null
)
returns table(user_id uuid, organization_id uuid, role text, employee_id uuid)
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid;
  v_employee_id uuid := p_employee_id;
  v_employee_auth_user_id uuid;
  v_email text := lower(nullif(btrim(p_email), ''));
  v_match_count integer;
begin
  if auth.uid() is null then
    raise exception 'É necessário estar autenticado para vincular um usuário.' using errcode = '42501';
  end if;
  if p_organization_id is null or not public.has_org_role(p_organization_id, array['admin_youb','diretoria']) then
    raise exception 'O acesso atual não pode administrar vínculos desta organização.' using errcode = '42501';
  end if;
  if v_email is null then
    raise exception 'O e-mail do usuário é obrigatório.' using errcode = '22023';
  end if;
  if p_role not in ('diretoria','rh','gestor','colaborador') then
    raise exception 'O perfil informado não é permitido para a Commercial V1.' using errcode = '22023';
  end if;

  select count(*) into v_match_count
  from auth.users u
  where lower(u.email) = v_email;
  if v_match_count = 0 then
    raise exception 'Nenhum usuário autenticado foi encontrado para este e-mail. O usuário precisa criar a conta antes do vínculo.' using errcode = 'P0002';
  end if;
  if v_match_count > 1 then
    raise exception 'Há mais de uma conta Auth para este e-mail; o vínculo foi bloqueado.' using errcode = '23505';
  end if;
  select u.id into v_user_id from auth.users u where lower(u.email) = v_email limit 1;

  if v_employee_id is null then
    select count(*) into v_match_count
    from public.employees e
    where e.organization_id = p_organization_id
      and lower(nullif(btrim(e.email), '')) = v_email;
    if v_match_count = 0 then
      raise exception 'Nenhum colaborador desta organização foi encontrado para este e-mail.' using errcode = 'P0002';
    end if;
    if v_match_count > 1 then
      raise exception 'Há mais de um colaborador com este e-mail nesta organização; o vínculo foi bloqueado.' using errcode = '23505';
    end if;
    select e.id, e.auth_user_id into v_employee_id, v_employee_auth_user_id
    from public.employees e
    where e.organization_id = p_organization_id
      and lower(nullif(btrim(e.email), '')) = v_email
    limit 1;
  else
    select e.auth_user_id into v_employee_auth_user_id
    from public.employees e
    where e.organization_id = p_organization_id and e.id = v_employee_id;
    if not found then
      raise exception 'O colaborador informado não pertence à organização.' using errcode = '42501';
    end if;
  end if;

  if v_employee_auth_user_id is not null and v_employee_auth_user_id <> v_user_id then
    raise exception 'Este colaborador já está vinculado a outra conta Auth.' using errcode = '23505';
  end if;

  update public.employees as e
  set auth_user_id = v_user_id,
      email = coalesce(nullif(btrim(e.email), ''), v_email)
  where e.organization_id = p_organization_id and e.id = v_employee_id;

  insert into public.memberships(organization_id, user_id, role)
  values (p_organization_id, v_user_id, p_role)
  on conflict on constraint memberships_organization_id_user_id_key
  do update set role = excluded.role;

  return query select v_user_id, p_organization_id, p_role, v_employee_id;
end;
$$;

revoke all on function public.link_organization_user(uuid, text, text, uuid) from public, anon;
grant execute on function public.link_organization_user(uuid, text, text, uuid) to authenticated;
