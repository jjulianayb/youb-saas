-- youB — fundação de acesso por camada
-- Sprint 1: additive only. Não altera memberships/roles legados nem concede acesso
-- automaticamente. Aplicar somente após revisão, testes RLS e plano de bootstrap.

create table if not exists public.platform_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform_role text not null check (platform_role in ('platform_admin', 'platform_support', 'platform_analyst')),
  status text not null default 'active' check (status in ('active', 'suspended', 'revoked')),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, platform_role)
);

create table if not exists public.partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  status text not null default 'active' check (status in ('active', 'suspended', 'closed')),
  created_at timestamptz not null default now()
);

create table if not exists public.partner_memberships (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  partner_role text not null check (partner_role in ('partner_admin', 'partner_operator', 'partner_support')),
  status text not null default 'active' check (status in ('invited', 'active', 'suspended', 'revoked')),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (partner_id, user_id)
);

create table if not exists public.partner_organization_access (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  access_scope text not null check (access_scope in ('provisioning', 'implementation', 'support', 'reporting')),
  status text not null default 'active' check (status in ('active', 'suspended', 'revoked')),
  granted_by uuid references auth.users(id) on delete set null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (partner_id, organization_id, access_scope)
);

create index if not exists idx_platform_memberships_user on public.platform_memberships(user_id);
create index if not exists idx_partner_memberships_user on public.partner_memberships(user_id);
create index if not exists idx_partner_memberships_partner on public.partner_memberships(partner_id);
create index if not exists idx_partner_org_access_org on public.partner_organization_access(organization_id);
create index if not exists idx_partner_org_access_partner on public.partner_organization_access(partner_id);

create or replace function public.is_platform_role(allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.platform_memberships pm
    where pm.user_id = auth.uid()
      and pm.platform_role = any(allowed_roles)
      and pm.status = 'active'
      and (pm.expires_at is null or pm.expires_at > now())
  );
$$;

grant execute on function public.is_platform_role(text[]) to authenticated;

create or replace function public.has_partner_role(target_partner uuid, allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.partner_memberships pm
    join public.partners p on p.id = pm.partner_id
    where pm.partner_id = target_partner
      and pm.user_id = auth.uid()
      and pm.partner_role = any(allowed_roles)
      and pm.status = 'active'
      and p.status = 'active'
      and (pm.expires_at is null or pm.expires_at > now())
  );
$$;

grant execute on function public.has_partner_role(uuid, text[]) to authenticated;

create or replace function public.has_partner_org_access(target_org uuid, allowed_scopes text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.partner_memberships pm
    join public.partners p on p.id = pm.partner_id
    join public.partner_organization_access poa on poa.partner_id = pm.partner_id
    where pm.user_id = auth.uid()
      and pm.status = 'active'
      and p.status = 'active'
      and poa.organization_id = target_org
      and poa.access_scope = any(allowed_scopes)
      and poa.status = 'active'
      and (pm.expires_at is null or pm.expires_at > now())
      and (poa.expires_at is null or poa.expires_at > now())
  );
$$;

grant execute on function public.has_partner_org_access(uuid, text[]) to authenticated;

alter table public.platform_memberships enable row level security;
alter table public.partners enable row level security;
alter table public.partner_memberships enable row level security;
alter table public.partner_organization_access enable row level security;

-- Bootstrap de plataforma deve ser feito por operação segura/service role.
drop policy if exists platform_memberships_select_scoped on public.platform_memberships;
create policy platform_memberships_select_scoped
on public.platform_memberships for select to authenticated
using (user_id = auth.uid() or public.is_platform_role(array['platform_admin']));

drop policy if exists platform_memberships_manage_admin on public.platform_memberships;
create policy platform_memberships_manage_admin
on public.platform_memberships for all to authenticated
using (public.is_platform_role(array['platform_admin']))
with check (public.is_platform_role(array['platform_admin']));

drop policy if exists partners_select_scoped on public.partners;
create policy partners_select_scoped
on public.partners for select to authenticated
using (
  public.is_platform_role(array['platform_admin', 'platform_support', 'platform_analyst'])
  or public.has_partner_role(id, array['partner_admin', 'partner_operator', 'partner_support'])
);

drop policy if exists partners_manage_admin on public.partners;
create policy partners_manage_admin
on public.partners for all to authenticated
using (public.is_platform_role(array['platform_admin']))
with check (public.is_platform_role(array['platform_admin']));

drop policy if exists partner_memberships_select_scoped on public.partner_memberships;
create policy partner_memberships_select_scoped
on public.partner_memberships for select to authenticated
using (
  user_id = auth.uid()
  or public.is_platform_role(array['platform_admin', 'platform_support'])
  or public.has_partner_role(partner_id, array['partner_admin', 'partner_operator', 'partner_support'])
);

drop policy if exists partner_memberships_manage_scoped on public.partner_memberships;
create policy partner_memberships_manage_scoped
on public.partner_memberships for all to authenticated
using (
  public.is_platform_role(array['platform_admin'])
  or public.has_partner_role(partner_id, array['partner_admin'])
)
with check (
  public.is_platform_role(array['platform_admin'])
  or public.has_partner_role(partner_id, array['partner_admin'])
);

drop policy if exists partner_org_access_select_scoped on public.partner_organization_access;
create policy partner_org_access_select_scoped
on public.partner_organization_access for select to authenticated
using (
  status = 'active'
  and (expires_at is null or expires_at > now())
  and (
    public.is_platform_role(array['platform_admin', 'platform_support'])
    or public.has_partner_role(partner_id, array['partner_admin', 'partner_operator', 'partner_support'])
  )
);

drop policy if exists partner_org_access_manage_scoped on public.partner_organization_access;
create policy partner_org_access_manage_scoped
on public.partner_organization_access for all to authenticated
using (
  public.is_platform_role(array['platform_admin'])
  or public.has_partner_role(partner_id, array['partner_admin'])
)
with check (
  public.is_platform_role(array['platform_admin'])
  or public.has_partner_role(partner_id, array['partner_admin'])
);

grant select, insert, update, delete on public.platform_memberships,
  public.partners, public.partner_memberships,
  public.partner_organization_access to authenticated;

comment on table public.platform_memberships is
  'Acesso da camada PLATFORM; não substitui memberships organizacionais.';
comment on table public.partner_organization_access is
  'Grant explícito de um partner para uma organização e finalidade.';
