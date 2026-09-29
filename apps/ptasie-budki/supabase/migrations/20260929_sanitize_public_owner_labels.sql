-- Never store account e-mail addresses in publicly readable map records.
-- owner_id remains the authorization key; owner_email is retained as a legacy
-- display-label column for compatibility with already released clients.

create or replace function app_private.sanitize_public_owner_label()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if lower(trim(coalesce(new.owner_email, ''))) = 'clanga.com' then
    new.owner_email := 'Clanga.com';
  elsif (select auth.uid()) is not null then
    new.owner_email := case
      when app_private.is_app_admin() then 'Administrator'
      else 'Użytkownik'
    end;
  elsif position('@' in coalesce(new.owner_email, '')) > 0 then
    new.owner_email := 'Gość';
  end if;
  return new;
end
$$;

drop trigger if exists trg_sanitize_nest_site_owner_label on public.nest_sites;
create trigger trg_sanitize_nest_site_owner_label
before insert or update on public.nest_sites
for each row execute function app_private.sanitize_public_owner_label();

drop trigger if exists trg_sanitize_inspection_owner_label on public.inspections;
create trigger trg_sanitize_inspection_owner_label
before insert or update on public.inspections
for each row execute function app_private.sanitize_public_owner_label();

drop trigger if exists trg_sanitize_bird_observation_owner_label on public.bird_observations;
create trigger trg_sanitize_bird_observation_owner_label
before insert or update on public.bird_observations
for each row execute function app_private.sanitize_public_owner_label();

update public.nest_sites
set owner_email = case
  when lower(trim(owner_email)) = 'clanga.com' then 'Clanga.com'
  else 'Użytkownik'
end
where position('@' in owner_email) > 0;

update public.inspections
set owner_email = 'Użytkownik'
where position('@' in owner_email) > 0;

update public.bird_observations
set owner_email = case
  when lower(trim(owner_email)) = 'clanga.com' then 'Clanga.com'
  else 'Użytkownik'
end
where position('@' in owner_email) > 0;
