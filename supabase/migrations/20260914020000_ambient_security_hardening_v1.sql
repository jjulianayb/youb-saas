-- youB — Ambient Intelligence Foundation V1 security hardening
-- Minimal subject/audience contract. No ACL engine, provider integration or hosted activation.

alter table public.ambient_observations
  add column if not exists subject_type text not null default 'organization',
  add column if not exists subject_ref text,
  add column if not exists subject_owner_user_id uuid references auth.users(id) on delete set null,
  add column if not exists visibility_scope text not null default 'organizational',
  add column if not exists authorized_roles text[] not null default array['admin_youb','rh']::text[],
  add column if not exists authorized_user_ids uuid[] not null default '{}'::uuid[];
update public.ambient_observations set subject_ref = organization_id::text where subject_ref is null or btrim(subject_ref) = '';
alter table public.ambient_observations alter column subject_ref set not null;
alter table public.ambient_observations add constraint ambient_observations_subject_type_check check (subject_type in ('organization','area','team','employee','position','user','personal'));
alter table public.ambient_observations add constraint ambient_observations_visibility_scope_check check (visibility_scope in ('personal','subject','organizational'));
alter table public.ambient_observations add constraint ambient_observations_authorized_roles_check check (authorized_roles <@ array['admin_youb','rh','diretoria','gestor','colaborador','platform_admin']::text[]);
alter table public.ambient_observations add constraint ambient_observations_personal_subject_check check (visibility_scope <> 'personal' or subject_owner_user_id is not null);
create index if not exists ambient_observations_subject_visibility on public.ambient_observations(organization_id, subject_type, subject_ref, visibility_scope);

alter table public.ambient_attention_items
  add column if not exists visibility_scope text not null default 'personal',
  add column if not exists authorized_roles text[] not null default '{}'::text[],
  add column if not exists authorized_user_ids uuid[] not null default '{}'::uuid[];
alter table public.ambient_attention_items add constraint ambient_attention_visibility_scope_check check (visibility_scope in ('personal','organizational'));
alter table public.ambient_attention_items add constraint ambient_attention_authorized_roles_check check (authorized_roles <@ array['admin_youb','rh','diretoria','gestor','colaborador','platform_admin']::text[]);

alter table public.ambient_attention_briefs
  add column if not exists visibility_scope text not null default 'personal',
  add column if not exists authorized_roles text[] not null default '{}'::text[],
  add column if not exists authorized_user_ids uuid[] not null default '{}'::uuid[];
alter table public.ambient_attention_briefs add constraint ambient_briefs_visibility_scope_check check (visibility_scope in ('personal','organizational'));
alter table public.ambient_attention_briefs add constraint ambient_briefs_authorized_roles_check check (authorized_roles <@ array['admin_youb','rh','diretoria','gestor','colaborador','platform_admin']::text[]);

create or replace function public.ambient_visibility_allows(
  target_org uuid,
  target_scope text,
  target_roles text[],
  target_users uuid[],
  target_owner uuid
) returns boolean language sql stable security definer set search_path = public as $$
  select
    auth.uid() = target_owner
    or auth.uid() = any(coalesce(target_users, '{}'::uuid[]))
    or (
      target_scope <> 'personal'
      and public.has_org_role(target_org, coalesce(target_roles, '{}'::text[]))
    );
$$;
revoke all on function public.ambient_visibility_allows(uuid,text,text[],uuid[],uuid) from public;
grant execute on function public.ambient_visibility_allows(uuid,text,text[],uuid[],uuid) to authenticated;

-- Observation visibility is explicit. Diretoria is not a blanket reader of standard/restricted records.
drop policy if exists ambient_observations_select on public.ambient_observations;
create policy ambient_observations_select on public.ambient_observations
  for select to authenticated using (
    public.ambient_visibility_allows(organization_id, visibility_scope, authorized_roles, authorized_user_ids, subject_owner_user_id)
  );

drop policy if exists ambient_observations_insert on public.ambient_observations;
create policy ambient_observations_insert on public.ambient_observations
  for insert to authenticated with check (
    created_by_user_id = auth.uid()
    and (
      (
        epistemic_kind in ('human_declared','human_confirmed','human_corrected')
        and actor_user_id = auth.uid()
      )
      or (
        epistemic_kind in ('system_record','machine_observed','machine_inferred')
        and actor_user_id is null
        and source_registry_id is not null
      )
    )
    and exists (
      select 1 from public.ambient_source_registry source
      where source.organization_id = ambient_observations.organization_id
        and source.id = ambient_observations.source_registry_id
        and source.status = 'available'
    )
    and (
      public.intelligence_is_admin(organization_id)
      or public.has_org_role(organization_id, array['diretoria','gestor','colaborador'])
    )
  );

-- Reviews can only be made by a user already authorized to see the observation.
drop policy if exists ambient_observation_reviews_select on public.ambient_observation_reviews;
create policy ambient_observation_reviews_select on public.ambient_observation_reviews
  for select to authenticated using (
    public.ambient_visibility_allows(
      organization_id,
      (select visibility_scope from public.ambient_observations where organization_id = ambient_observation_reviews.organization_id and id = ambient_observation_reviews.observation_id),
      (select authorized_roles from public.ambient_observations where organization_id = ambient_observation_reviews.organization_id and id = ambient_observation_reviews.observation_id),
      (select authorized_user_ids from public.ambient_observations where organization_id = ambient_observation_reviews.organization_id and id = ambient_observation_reviews.observation_id),
      (select subject_owner_user_id from public.ambient_observations where organization_id = ambient_observation_reviews.organization_id and id = ambient_observation_reviews.observation_id)
    )
  );
drop policy if exists ambient_observation_reviews_insert on public.ambient_observation_reviews;
create policy ambient_observation_reviews_insert on public.ambient_observation_reviews
  for insert to authenticated with check (
    reviewer_user_id = auth.uid()
    and public.ambient_visibility_allows(
      organization_id,
      (select visibility_scope from public.ambient_observations where organization_id = ambient_observation_reviews.organization_id and id = ambient_observation_reviews.observation_id),
      (select authorized_roles from public.ambient_observations where organization_id = ambient_observation_reviews.organization_id and id = ambient_observation_reviews.observation_id),
      (select authorized_user_ids from public.ambient_observations where organization_id = ambient_observation_reviews.organization_id and id = ambient_observation_reviews.observation_id),
      (select subject_owner_user_id from public.ambient_observations where organization_id = ambient_observation_reviews.organization_id and id = ambient_observation_reviews.observation_id)
    )
  );

-- Personal attention and briefs are owner-only unless an organizational audience is explicitly declared.
drop policy if exists ambient_attention_select on public.ambient_attention_items;
create policy ambient_attention_select on public.ambient_attention_items for select to authenticated using (public.ambient_visibility_allows(organization_id, visibility_scope, authorized_roles, authorized_user_ids, owner_user_id));
drop policy if exists ambient_attention_insert on public.ambient_attention_items;
create policy ambient_attention_insert on public.ambient_attention_items for insert to authenticated with check (
  created_by_user_id = auth.uid()
  and (owner_user_id = auth.uid() or public.intelligence_is_admin(organization_id) or public.has_org_role(organization_id, array['diretoria']))
  and (source_observation_id is null or exists (select 1 from public.ambient_observations o where o.organization_id = ambient_attention_items.organization_id and o.id = ambient_attention_items.source_observation_id and public.ambient_visibility_allows(o.organization_id, o.visibility_scope, o.authorized_roles, o.authorized_user_ids, o.subject_owner_user_id)))
);
drop policy if exists ambient_attention_update on public.ambient_attention_items;
create policy ambient_attention_update on public.ambient_attention_items for update to authenticated using (public.ambient_visibility_allows(organization_id, visibility_scope, authorized_roles, authorized_user_ids, owner_user_id)) with check (owner_user_id = auth.uid() or public.intelligence_is_admin(organization_id) or public.has_org_role(organization_id, array['diretoria']));

drop policy if exists ambient_briefs_select on public.ambient_attention_briefs;
create policy ambient_briefs_select on public.ambient_attention_briefs for select to authenticated using (public.ambient_visibility_allows(organization_id, visibility_scope, authorized_roles, authorized_user_ids, owner_user_id));
drop policy if exists ambient_briefs_insert on public.ambient_attention_briefs;
create policy ambient_briefs_insert on public.ambient_attention_briefs for insert to authenticated with check (created_by_user_id = auth.uid() and (owner_user_id = auth.uid() or public.intelligence_is_admin(organization_id) or public.has_org_role(organization_id, array['diretoria'])));

comment on column public.ambient_observations.subject_type is 'Explicit subject entity type. Descriptive identifiers never replace RLS.';
comment on column public.ambient_observations.subject_ref is 'Tenant-scoped subject reference; visibility decisions never trust this value alone.';
comment on column public.ambient_observations.visibility_scope is 'Explicit personal, subject or organizational visibility contract.';
comment on column public.ambient_observations.authorized_roles is 'Audience roles explicitly declared for this observation; diretoria is never implicit.';
comment on function public.ambient_visibility_allows(uuid,text,text[],uuid[],uuid) is 'Least-privilege visibility helper. Personal records require owner/user authorization; role membership alone is not enough for personal scope.';
