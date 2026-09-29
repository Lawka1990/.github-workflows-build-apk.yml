
create extension if not exists "uuid-ossp";

create table if not exists public.app_profiles (
  id bigserial primary key,
  user_id uuid unique,
  email text unique,
  role text not null default 'user',
  created_at timestamptz not null default now()
);

create table if not exists public.nest_sites (
  id uuid primary key,
  name text not null,
  type text not null default 'Budka lęgowa',
  latitude double precision not null,
  longitude double precision not null,
  place_description text not null default '',
  technical_status text not null default 'Dobry',
  repair_needed boolean not null default false,
  damage_description text not null default '',
  notes text not null default '',
  report_status text not null default 'Zgłoszona',
  delete_requested boolean not null default false,
  delete_reason text not null default '',
  hidden_from_users boolean not null default false,
  deleted boolean not null default false,
  owner_id text not null default '',
  owner_email text not null default '',
  photo_urls jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inspections (
  id uuid primary key,
  nest_site_id uuid not null references public.nest_sites(id) on delete cascade,
  date timestamptz not null,
  inspector text not null default '',
  cleaned boolean not null default false,
  cleaned_by text not null default '',
  condition text not null default 'Dobry',
  birds_present boolean not null default false,
  bird_species text not null default '',
  eggs_count integer not null default 0,
  chicks_count integer not null default 0,
  adults_count integer not null default 0,
  notes text not null default '',
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.nest_sites add column if not exists delete_requested boolean not null default false;
alter table public.nest_sites add column if not exists delete_reason text not null default '';
alter table public.nest_sites add column if not exists hidden_from_users boolean not null default false;
alter table public.nest_sites add column if not exists owner_id text not null default '';
alter table public.nest_sites add column if not exists owner_email text not null default '';
alter table public.nest_sites add column if not exists notes text not null default '';
alter table public.nest_sites add column if not exists photo_urls jsonb not null default '[]'::jsonb;

alter table public.app_profiles enable row level security;
alter table public.nest_sites enable row level security;
alter table public.inspections enable row level security;

drop policy if exists "profiles all anon authenticated" on public.app_profiles;
drop policy if exists "nest sites all anon authenticated" on public.nest_sites;
drop policy if exists "inspections all anon authenticated" on public.inspections;

create policy "profiles all anon authenticated"
on public.app_profiles for all
to anon, authenticated
using (true)
with check (true);

create policy "nest sites all anon authenticated"
on public.nest_sites for all
to anon, authenticated
using (true)
with check (true);

create policy "inspections all anon authenticated"
on public.inspections for all
to anon, authenticated
using (true)
with check (true);

create index if not exists nest_sites_owner_idx on public.nest_sites(owner_id);
create index if not exists nest_sites_updated_idx on public.nest_sites(updated_at desc);
create index if not exists inspections_site_idx on public.inspections(nest_site_id);

-- v0.6.1: niezależne obserwacje ptaków i tabela gatunków wrażliwych.
create table if not exists public.bird_observations (
  id uuid primary key,
  species text not null,
  latitude double precision not null,
  longitude double precision not null,
  observed_at timestamptz not null default now(),
  count integer not null default 1,
  place_description text not null default '',
  behaviour text not null default '',
  notes text not null default '',
  sensitive boolean not null default false,
  hidden_from_users boolean not null default false,
  deleted boolean not null default false,
  owner_id text not null default '',
  owner_email text not null default '',
  photo_urls jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.bird_sensitive_species (
  id bigserial primary key,
  species text not null unique,
  latin_name text not null default '',
  hide_exact_location boolean not null default true,
  blur_radius_m integer not null default 1000,
  notes text not null default '',
  created_at timestamptz not null default now()
);

alter table public.bird_observations add column if not exists count integer not null default 1;
alter table public.bird_observations add column if not exists place_description text not null default '';
alter table public.bird_observations add column if not exists behaviour text not null default '';
alter table public.bird_observations add column if not exists notes text not null default '';
alter table public.bird_observations add column if not exists sensitive boolean not null default false;
alter table public.bird_observations add column if not exists hidden_from_users boolean not null default false;
alter table public.bird_observations add column if not exists deleted boolean not null default false;
alter table public.bird_observations add column if not exists owner_id text not null default '';
alter table public.bird_observations add column if not exists owner_email text not null default '';
alter table public.bird_observations add column if not exists photo_urls jsonb not null default '[]'::jsonb;

alter table public.bird_observations enable row level security;
alter table public.bird_sensitive_species enable row level security;

drop policy if exists "bird observations all anon authenticated" on public.bird_observations;
drop policy if exists "bird sensitive species read anon authenticated" on public.bird_sensitive_species;
drop policy if exists "bird sensitive species write authenticated" on public.bird_sensitive_species;

create policy "bird observations all anon authenticated"
on public.bird_observations for all
to anon, authenticated
using (true)
with check (true);

create policy "bird sensitive species read anon authenticated"
on public.bird_sensitive_species for select
to anon, authenticated
using (true);

create policy "bird sensitive species write authenticated"
on public.bird_sensitive_species for all
to authenticated
using (true)
with check (true);

insert into public.bird_sensitive_species (species, latin_name, hide_exact_location, blur_radius_m, notes)
values
  ('Orlik krzykliwy', 'Clanga pomarina', true, 3000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Bielik', 'Haliaeetus albicilla', true, 2000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Bocian czarny', 'Ciconia nigra', true, 3000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Kania ruda', 'Milvus milvus', true, 2000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Kania czarna', 'Milvus migrans', true, 2000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Sokół wędrowny', 'Falco peregrinus', true, 2000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Płomykówka', 'Tyto alba', true, 1000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Sóweczka', 'Glaucidium passerinum', true, 1000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Włochatka', 'Aegolius funereus', true, 1000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Lelek', 'Caprimulgus europaeus', true, 1000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Zimorodek', 'Alcedo atthis', true, 500, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Żołna', 'Merops apiaster', true, 1000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Dudek', 'Upupa epops', true, 1000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Derkacz', 'Crex crex', true, 1000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Rycyk', 'Limosa limosa', true, 1000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Krwawodziób', 'Tringa totanus', true, 1000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.'),
  ('Turkawka', 'Streptopelia turtur', true, 1000, 'Automatycznie oznaczany jako gatunek rzadki / wrażliwy.')
on conflict (species) do update set
  latin_name = excluded.latin_name,
  hide_exact_location = excluded.hide_exact_location,
  blur_radius_m = excluded.blur_radius_m,
  notes = excluded.notes;

create index if not exists bird_observations_observed_idx on public.bird_observations(observed_at desc);
create index if not exists bird_observations_species_idx on public.bird_observations(species);
create index if not exists bird_observations_owner_idx on public.bird_observations(owner_id);

-- v0.6.3: import obserwacji z Clanga.
alter table public.bird_observations add column if not exists source text not null default 'Ptasia Mapa';
alter table public.bird_observations add column if not exists external_id text not null default '';
alter table public.bird_observations add column if not exists external_url text not null default '';

create unique index if not exists bird_observations_source_external_uidx
on public.bird_observations(source, external_id)
where external_id <> '';

create index if not exists bird_observations_source_idx on public.bird_observations(source);


-- Security and observations hardening, 2026-09-29.
-- Backward-compatible with the currently released Ptasie Budki/Obserwacje clients.

create table if not exists public.bird_observations (
  id uuid primary key,
  species text not null,
  latitude double precision not null,
  longitude double precision not null,
  observed_at timestamptz not null default now(),
  count integer not null default 1 check (count > 0),
  place_description text not null default '',
  behaviour text not null default '',
  notes text not null default '',
  sensitive boolean not null default false,
  hidden_from_users boolean not null default false,
  deleted boolean not null default false,
  owner_id text not null default '',
  owner_email text not null default '',
  photo_urls jsonb not null default '[]'::jsonb,
  source text not null default 'Ptasia Mapa',
  external_id text not null default '',
  external_url text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.bird_sensitive_species (
  id bigserial primary key,
  species text not null unique,
  latin_name text not null default '',
  hide_exact_location boolean not null default true,
  blur_radius_m integer not null default 1000 check (blur_radius_m >= 0),
  notes text not null default '',
  created_at timestamptz not null default now()
);

alter table public.inspections add column if not exists owner_id text not null default '';
alter table public.inspections add column if not exists owner_email text not null default '';

alter table public.app_profiles enable row level security;
alter table public.nest_sites enable row level security;
alter table public.inspections enable row level security;
alter table public.bird_observations enable row level security;
alter table public.bird_sensitive_species enable row level security;

create schema if not exists app_private;
revoke all on schema app_private from public;
revoke all on schema app_private from anon;
grant usage on schema app_private to authenticated;

create or replace function app_private.is_super_admin_identity()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select lower(coalesce((select auth.jwt()) ->> 'email', '')) = 'bartoszlawicki@gmail.com'
$$;

revoke all on function app_private.is_super_admin_identity() from public;
revoke all on function app_private.is_super_admin_identity() from anon;
grant execute on function app_private.is_super_admin_identity() to authenticated;

create or replace function app_private.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app_private.is_super_admin_identity()
      or exists (
        select 1
        from public.app_profiles p
        where p.user_id = (select auth.uid())
          and p.role in ('admin', 'super_admin')
      )
$$;

revoke all on function app_private.is_app_admin() from public;
revoke all on function app_private.is_app_admin() from anon;
grant execute on function app_private.is_app_admin() to authenticated;

-- The client calls this after login. Existing admin roles are never downgraded.
create or replace function public.claim_app_profile()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_email text := lower(trim(coalesce((select auth.jwt()) ->> 'email', '')));
  v_role text;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if v_email = '' then
    raise exception 'Authenticated account has no email';
  end if;

  insert into public.app_profiles(user_id, email, role)
  values (
    v_uid,
    v_email,
    case when app_private.is_super_admin_identity() then 'super_admin' else 'user' end
  )
  on conflict (user_id) do update
    set email = excluded.email,
        role = case
          when public.app_profiles.role in ('admin', 'super_admin') then public.app_profiles.role
          else excluded.role
        end;

  select role into v_role
  from public.app_profiles
  where user_id = v_uid;

  return coalesce(v_role, 'user');
end
$$;

revoke all on function public.claim_app_profile() from public;
revoke all on function public.claim_app_profile() from anon;
grant execute on function public.claim_app_profile() to authenticated;

-- Only the trusted super-admin identity can grant/revoke administrator roles.
create or replace function public.set_app_role(p_email text, p_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_role text := lower(trim(coalesce(p_role, '')));
begin
  if not app_private.is_super_admin_identity() then
    raise exception 'Only super administrator can change roles';
  end if;
  if v_role not in ('user', 'admin') then
    raise exception 'Unsupported role';
  end if;
  if v_email = '' then
    raise exception 'Email is required';
  end if;

  update public.app_profiles
  set role = v_role
  where lower(email) = v_email;

  if not found then
    raise exception 'User must sign in once before a role can be assigned';
  end if;
end
$$;

revoke all on function public.set_app_role(text, text) from public;
revoke all on function public.set_app_role(text, text) from anon;
grant execute on function public.set_app_role(text, text) to authenticated;

-- Keep released clients compatible: they still upsert app_profiles directly.
-- A normal user cannot promote themselves and an existing admin is not downgraded on login.
create or replace function app_private.guard_profile_role()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
     and not app_private.is_super_admin_identity()
     and old.user_id = (select auth.uid()) then
    new.role := old.role;
  end if;
  return new;
end
$$;

drop trigger if exists trg_guard_profile_role on public.app_profiles;
create trigger trg_guard_profile_role
before update on public.app_profiles
for each row execute function app_private.guard_profile_role();

-- Released clients do not send inspection ownership yet; fill it server-side.
create or replace function app_private.fill_inspection_owner()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(new.owner_id, '') = '' and (select auth.uid()) is not null then
    new.owner_id := (select auth.uid())::text;
    new.owner_email := lower(coalesce((select auth.jwt()) ->> 'email', ''));
  end if;
  return new;
end
$$;

drop trigger if exists trg_fill_inspection_owner on public.inspections;
create trigger trg_fill_inspection_owner
before insert on public.inspections
for each row execute function app_private.fill_inspection_owner();

-- Sensitive sightings are private by default even when an older client sends hidden=false.
create or replace function app_private.enforce_sensitive_observation_privacy()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.sensitive and not app_private.is_app_admin() then
    new.hidden_from_users := true;
  end if;
  return new;
end
$$;

drop trigger if exists trg_sensitive_observation_privacy on public.bird_observations;
create trigger trg_sensitive_observation_privacy
before insert or update on public.bird_observations
for each row execute function app_private.enforce_sensitive_observation_privacy();

-- Remove old permissive policies.
drop policy if exists "profiles all anon authenticated" on public.app_profiles;

drop policy if exists "nest sites all anon authenticated" on public.nest_sites;
drop policy if exists "public insert nest sites" on public.nest_sites;
drop policy if exists "public read nest sites" on public.nest_sites;
drop policy if exists "public update nest sites" on public.nest_sites;

drop policy if exists "inspections all anon authenticated" on public.inspections;
drop policy if exists "public insert inspections" on public.inspections;
drop policy if exists "public read inspections" on public.inspections;
drop policy if exists "public update inspections" on public.inspections;

drop policy if exists "bird observations all anon authenticated" on public.bird_observations;
drop policy if exists "bird sensitive species read anon authenticated" on public.bird_sensitive_species;
drop policy if exists "bird sensitive species write authenticated" on public.bird_sensitive_species;

-- Explicit privileges: guests are read-only.
revoke all on public.app_profiles from anon, authenticated;
grant select, insert, update on public.app_profiles to authenticated;
grant usage, select on sequence public.app_profiles_id_seq to authenticated;

revoke all on public.nest_sites from anon, authenticated;
grant select on public.nest_sites to anon, authenticated;
grant insert, update on public.nest_sites to authenticated;

revoke all on public.inspections from anon, authenticated;
grant select on public.inspections to anon, authenticated;
grant insert, update on public.inspections to authenticated;

revoke all on public.bird_observations from anon, authenticated;
grant select on public.bird_observations to anon, authenticated;
grant insert, update on public.bird_observations to authenticated;

revoke all on public.bird_sensitive_species from anon, authenticated;
grant select on public.bird_sensitive_species to anon, authenticated;
grant insert, update on public.bird_sensitive_species to authenticated;
grant usage, select on sequence public.bird_sensitive_species_id_seq to authenticated;

-- Profiles.
create policy "profiles select own or admin"
on public.app_profiles for select
to authenticated
using (
  user_id = (select auth.uid())
  or app_private.is_app_admin()
);

create policy "profiles insert own safe role"
on public.app_profiles for insert
to authenticated
with check (
  (
    user_id = (select auth.uid())
    and lower(email) = lower(coalesce((select auth.jwt()) ->> 'email', ''))
    and role = 'user'
  )
  or app_private.is_super_admin_identity()
);

create policy "profiles update own or superadmin"
on public.app_profiles for update
to authenticated
using (
  user_id = (select auth.uid())
  or app_private.is_super_admin_identity()
)
with check (
  (
    user_id = (select auth.uid())
    and lower(email) = lower(coalesce((select auth.jwt()) ->> 'email', ''))
  )
  or app_private.is_super_admin_identity()
);

-- Nest sites: public map is readable, only owners/admins can modify.
create policy "nest sites public read"
on public.nest_sites for select
to anon
using (not deleted and not hidden_from_users);

create policy "nest sites authenticated read"
on public.nest_sites for select
to authenticated
using (
  (not deleted and not hidden_from_users)
  or owner_id = (select auth.uid())::text
  or app_private.is_app_admin()
);

create policy "nest sites authenticated insert"
on public.nest_sites for insert
to authenticated
with check (
  owner_id = (select auth.uid())::text
  or app_private.is_app_admin()
);

create policy "nest sites owner update"
on public.nest_sites for update
to authenticated
using (
  owner_id = (select auth.uid())::text
  or app_private.is_app_admin()
)
with check (
  owner_id = (select auth.uid())::text
  or app_private.is_app_admin()
);

-- Inspections: guests can read only controls of public visible sites.
create policy "inspections public read"
on public.inspections for select
to anon
using (
  not deleted
  and exists (
    select 1 from public.nest_sites s
    where s.id = nest_site_id
      and not s.deleted
      and not s.hidden_from_users
  )
);

create policy "inspections authenticated read"
on public.inspections for select
to authenticated
using (
  owner_id = (select auth.uid())::text
  or app_private.is_app_admin()
  or exists (
    select 1 from public.nest_sites s
    where s.id = nest_site_id
      and (
        (not s.deleted and not s.hidden_from_users)
        or s.owner_id = (select auth.uid())::text
      )
  )
);

create policy "inspections authenticated insert"
on public.inspections for insert
to authenticated
with check (
  owner_id = (select auth.uid())::text
  and exists (
    select 1 from public.nest_sites s
    where s.id = nest_site_id
      and not s.deleted
      and (
        not s.hidden_from_users
        or s.owner_id = (select auth.uid())::text
        or app_private.is_app_admin()
      )
  )
);

create policy "inspections owner update"
on public.inspections for update
to authenticated
using (
  owner_id = (select auth.uid())::text
  or app_private.is_app_admin()
)
with check (
  owner_id = (select auth.uid())::text
  or app_private.is_app_admin()
);

-- Bird observations: exact data of hidden/sensitive sightings is visible only to owner/admin.
create policy "bird observations public read"
on public.bird_observations for select
to anon
using (not deleted and not hidden_from_users);

create policy "bird observations authenticated read"
on public.bird_observations for select
to authenticated
using (
  (not deleted and not hidden_from_users)
  or owner_id = (select auth.uid())::text
  or app_private.is_app_admin()
);

create policy "bird observations authenticated insert"
on public.bird_observations for insert
to authenticated
with check (
  (
    owner_id = (select auth.uid())::text
    and (not sensitive or hidden_from_users)
  )
  or app_private.is_app_admin()
);

create policy "bird observations owner update"
on public.bird_observations for update
to authenticated
using (
  owner_id = (select auth.uid())::text
  or app_private.is_app_admin()
)
with check (
  (
    owner_id = (select auth.uid())::text
    and (not sensitive or hidden_from_users)
  )
  or app_private.is_app_admin()
);

create policy "sensitive species public read"
on public.bird_sensitive_species for select
to anon, authenticated
using (true);

create policy "sensitive species admin insert"
on public.bird_sensitive_species for insert
to authenticated
with check (app_private.is_app_admin());

create policy "sensitive species admin update"
on public.bird_sensitive_species for update
to authenticated
using (app_private.is_app_admin())
with check (app_private.is_app_admin());

create index if not exists inspections_owner_idx on public.inspections(owner_id);
create index if not exists bird_observations_observed_idx on public.bird_observations(observed_at desc);
create index if not exists bird_observations_species_idx on public.bird_observations(species);
create index if not exists bird_observations_owner_idx on public.bird_observations(owner_id);
create unique index if not exists bird_observations_source_external_uidx
  on public.bird_observations(source, external_id)
  where external_id <> '';

-- Keep only one index for nest_sites.updated_at.
drop index if exists public.nest_sites_updated_idx;

insert into public.bird_sensitive_species(species, latin_name, hide_exact_location, blur_radius_m, notes)
values
  ('Orlik krzykliwy', 'Clanga pomarina', true, 3000, 'Lokalizacja chroniona publicznie.'),
  ('Bielik', 'Haliaeetus albicilla', true, 2000, 'Lokalizacja chroniona publicznie.'),
  ('Bocian czarny', 'Ciconia nigra', true, 3000, 'Lokalizacja chroniona publicznie.'),
  ('Kania ruda', 'Milvus milvus', true, 2000, 'Lokalizacja chroniona publicznie.'),
  ('Kania czarna', 'Milvus migrans', true, 2000, 'Lokalizacja chroniona publicznie.'),
  ('Sokół wędrowny', 'Falco peregrinus', true, 2000, 'Lokalizacja chroniona publicznie.')
on conflict (species) do update set
  latin_name = excluded.latin_name,
  hide_exact_location = excluded.hide_exact_location,
  blur_radius_m = excluded.blur_radius_m,
  notes = excluded.notes;
