
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
