-- ONE TIME: apply to the existing database, never rerun 001 against it.
-- The reset and validation change are atomic. Existing RLS/grants stay in place.
begin;
lock table public.birthday_votes, public.birthday_vote_owners in access exclusive mode;
TRUNCATE TABLE
  public.birthday_vote_owners,
  public.birthday_votes
RESTART IDENTITY
CASCADE;
alter table public.birthday_votes drop constraint birthday_votes_ranking_check;
alter table public.birthday_votes add constraint birthday_votes_ranking_check check (
 jsonb_typeof(ranking) = 'array' and jsonb_array_length(ranking) = 6
 and ranking @> '["cut-and-craft","ivy","maricarmen","pasta-factory","rosas-thai","etci-mehmet"]'::jsonb
);
create or replace function public.submit_birthday_vote(p_name text, p_ranking jsonb, p_token text)
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
 if jsonb_array_length(p_ranking) <> 6 or not (p_ranking @> '["cut-and-craft","ivy","maricarmen","pasta-factory","rosas-thai","etci-mehmet"]'::jsonb) then
  raise exception 'Rank all six restaurants exactly once';
 end if;
 -- Serialize claims/edits of the same normalized name, including first submissions.
 perform pg_advisory_xact_lock(hashtextextended(lower(clean_name), 0));
 select id into v_vote_id from public.birthday_votes where name_key=lower(clean_name) for update;
 if v_vote_id is null then
  insert into public.birthday_votes(name,ranking) values(clean_name,p_ranking) returning id into v_vote_id;
  insert into public.birthday_vote_owners(vote_id,token_hash) values(v_vote_id,extensions.digest(convert_to(p_token,'UTF8'),'sha256'::text));
 else
  select token_hash into owner_hash from public.birthday_vote_owners where birthday_vote_owners.vote_id=v_vote_id;
  if owner_hash is distinct from extensions.digest(convert_to(p_token,'UTF8'),'sha256'::text) then
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
