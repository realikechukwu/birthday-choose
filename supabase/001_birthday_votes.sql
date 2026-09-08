-- Run once in your existing Supabase project's SQL editor.
-- No Auth configuration, service-role key or extra server is required.
begin;
create extension if not exists pgcrypto;
create table public.birthday_votes (
 id uuid primary key default gen_random_uuid(),
 name text not null check (char_length(name) between 1 and 60),
 name_key text generated always as (lower(regexp_replace(btrim(name), '\s+', ' ', 'g'))) stored unique,
 ranking jsonb not null check (
   jsonb_typeof(ranking) = 'array' and jsonb_array_length(ranking) = 5
   and ranking @> '["cut-and-craft","ivy","maricarmen","pasta-factory","rosas-thai"]'::jsonb
 ),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
-- Kept separate: public rankings never disclose a write credential or hash.
create table public.birthday_vote_owners (
 vote_id uuid primary key references public.birthday_votes(id) on delete cascade,
 token_hash bytea not null
);
alter table public.birthday_votes enable row level security;
alter table public.birthday_vote_owners enable row level security;
revoke all on public.birthday_votes from anon, authenticated;
revoke all on public.birthday_vote_owners from public, anon, authenticated;
grant select (id,name,ranking,created_at,updated_at) on public.birthday_votes to anon, authenticated;
create policy "Public birthday rankings" on public.birthday_votes for select to anon, authenticated using (true);

create function public.submit_birthday_vote(p_name text, p_ranking jsonb, p_token text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
 clean_name text := regexp_replace(btrim(p_name), '\s+', ' ', 'g');
 v_vote_id uuid;
 owner_hash bytea;
begin
 if clean_name is null or char_length(clean_name) not between 1 and 60 or clean_name ~ '[[:cntrl:]]' then
  raise exception 'Invalid name';
 end if;
 if p_token is null or p_token !~ '^[a-f0-9]{64}$' then raise exception 'Invalid browser token'; end if;
 if p_ranking is null or jsonb_typeof(p_ranking) <> 'array' then raise exception 'Invalid ranking'; end if;
 if jsonb_array_length(p_ranking) <> 5 or not (p_ranking @> '["cut-and-craft","ivy","maricarmen","pasta-factory","rosas-thai"]'::jsonb) then
  raise exception 'Rank all five restaurants exactly once';
 end if;
 -- Serialize claims/edits of the same normalized name, including first submissions.
 perform pg_advisory_xact_lock(hashtextextended(lower(clean_name), 0));
 select id into v_vote_id from public.birthday_votes where name_key=lower(clean_name) for update;
 if v_vote_id is null then
  insert into public.birthday_votes(name,ranking) values(clean_name,p_ranking) returning id into v_vote_id;
  insert into public.birthday_vote_owners(vote_id,token_hash) values(v_vote_id,digest(convert_to(p_token,'UTF8'),'sha256'));
 else
  select token_hash into owner_hash from public.birthday_vote_owners where birthday_vote_owners.vote_id=v_vote_id;
  if owner_hash is distinct from digest(convert_to(p_token,'UTF8'),'sha256') then
   raise exception 'This name is already in use on another browser';
  end if;
  update public.birthday_votes set name=clean_name,ranking=p_ranking,updated_at=now() where id=v_vote_id;
 end if;
 return v_vote_id;
end;
$$;
revoke all on function public.submit_birthday_vote(text,jsonb,text) from public;
grant execute on function public.submit_birthday_vote(text,jsonb,text) to anon, authenticated;
commit;
