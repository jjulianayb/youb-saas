-- youB — hardening da fundação de acesso
-- A camada Platform atribui primeiro a relação partner-organização.
-- Bootstrap/promoção de platform_memberships permanecem fora do JWT público.

create table if not exists public.platform_partner_organization_assignments (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  status text not null default 'active' check (status in ('active','revoked')),
  assigned_by uuid references auth.users(id) on delete set null,
  assigned_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (partner_id, organization_id)
);
create index if not exists idx_platform_partner_org_assignment_lookup on public.platform_partner_organization_assignments(partner_id, organization_id, status);
alter table public.platform_partner_organization_assignments enable row level security;
revoke all on public.platform_partner_organization_assignments from authenticated;

create or replace function public.require_platform_partner_org_assignment()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.platform_partner_organization_assignments a where a.partner_id = new.partner_id and a.organization_id = new.organization_id and a.status = 'active') then
    raise exception 'partner organization relation requires an active Platform assignment';
  end if;
  return new;
end;
$$;
revoke execute on function public.require_platform_partner_org_assignment() from public, authenticated;
drop trigger if exists enforce_platform_partner_org_assignment on public.partner_organization_access;
create trigger enforce_platform_partner_org_assignment before insert or update of partner_id, organization_id on public.partner_organization_access for each row execute function public.require_platform_partner_org_assignment();

-- Provisioning, promotion, suspension and revocation are server-side.
drop policy if exists platform_memberships_manage_admin on public.platform_memberships;
revoke insert, update, delete on public.platform_memberships from authenticated;

drop policy if exists platform_partner_org_assignments_select_platform on public.platform_partner_organization_assignments;
create policy platform_partner_org_assignments_select_platform on public.platform_partner_organization_assignments for select to authenticated using (public.is_platform_role(array['platform_admin','platform_support','platform_analyst']));
grant select on public.platform_partner_organization_assignments to authenticated;

comment on table public.platform_partner_organization_assignments is 'Relação previamente atribuída pela camada Platform; escrita somente por operação privilegiada server-side.';
comment on table public.platform_memberships is 'Bootstrap, promoção, suspensão e revogação somente server-side; JWT autenticado não administra esta tabela.';
