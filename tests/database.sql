-- Run with psql -v ON_ERROR_STOP=1 against a disposable database after 001 and 002.
-- All test writes are rolled back; never resets production data.
begin;
set local role anon;
do $$
declare
 ranking jsonb := '["cut-and-craft","ivy","maricarmen","pasta-factory","rosas-thai","etci-mehmet"]';
 reversed jsonb := '["etci-mehmet","rosas-thai","pasta-factory","maricarmen","ivy","cut-and-craft"]';
 first_id uuid;
 next_id uuid;
begin
 first_id := public.submit_birthday_vote('Six choice validation test', ranking, repeat('a',64));
 next_id := public.submit_birthday_vote('  Six choice validation test  ', reversed, repeat('a',64));
 if first_id <> next_id then raise exception 'Own vote update created a duplicate'; end if;
 if not exists (select 1 from public.birthday_votes where id=first_id and birthday_votes.ranking=reversed) then raise exception 'Public read or own update failed'; end if;
 begin
  perform public.submit_birthday_vote('Six choice validation test', ranking, repeat('b',64));
  raise exception 'Ownership protection failed';
 exception when raise_exception then
  if sqlerrm not like '%name is already%' then raise; end if;
 end;
 begin
  perform public.submit_birthday_vote('Invalid five', ranking - 5, repeat('a',64));
  raise exception 'Five-choice validation failed';
 exception when raise_exception then
  if sqlerrm <> 'Rank all six restaurants exactly once' then raise; end if;
 end;
 begin
  perform public.submit_birthday_vote('Duplicate', jsonb_set(ranking,'{5}','"ivy"'), repeat('a',64));
  raise exception 'Duplicate validation failed';
 exception when raise_exception then
  if sqlerrm <> 'Rank all six restaurants exactly once' then raise; end if;
 end;
 begin
  perform public.submit_birthday_vote('Unknown', jsonb_set(ranking,'{5}','"unknown"'), repeat('a',64));
  raise exception 'Unknown validation failed';
 exception when raise_exception then
  if sqlerrm <> 'Rank all six restaurants exactly once' then raise; end if;
 end;
 begin
  perform token_hash from public.birthday_vote_owners;
  raise exception 'Owner credentials were exposed';
 exception when insufficient_privilege then null;
 end;
 begin
  update public.birthday_votes set name='Unauthorized' where id=first_id;
  raise exception 'Direct writes were allowed';
 exception when insufficient_privilege then null;
 end;
end $$;
rollback;
