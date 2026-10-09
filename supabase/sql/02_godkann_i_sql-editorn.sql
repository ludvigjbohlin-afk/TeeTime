-- Kör den här filen i Supabase: SQL Editor → New query → klistra in → Run.
-- Den lägger till avbokning, ta bort vän, radera konto, direktuppdatering,
-- bevakningskontroll, notisutskick, påminnelser och nattlig städning.

create or replace function public.cancel_booking(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare b bookings%rowtype; cl clubs%rowtype; c courses%rowtype; m record;
begin
  select * into b from bookings where id = p_id;
  if not found then raise exception 'not_found'; end if;
  select * into c from courses where id = b.course_id;
  select * into cl from clubs where id = c.club_id;
  if b.user_id is distinct from auth.uid() then
    if not public.is_club_admin(cl.id) then raise exception 'not_allowed'; end if;
    if b.user_id is not null then
      perform public.notify_user(b.user_id, 'cancelled_by_club', 'Klubben har avbokat din tid',
        cl.name || ' har avbokat ' || public.sv_date(b.play_date) || ' kl ' || to_char(b.tee_time, 'HH24:MI') || ' på ' || c.name || '.',
        jsonb_build_object('club_id', cl.id, 'date', b.play_date));
    end if;
  else
    if (b.play_date + b.tee_time) - make_interval(mins => cl.cancel_cutoff_min) < public.local_now() then raise exception 'too_late_to_cancel'; end if;
  end if;
  if b.proposal_id is not null then
    for m in select user_id from proposal_members where proposal_id = b.proposal_id and response = 'yes' loop
      perform public.notify_user(m.user_id, 'round_cancelled', 'Rundan är avbokad',
        public.sv_date(b.play_date) || ' kl ' || to_char(b.tee_time, 'HH24:MI') || ' på ' || c.name || ' är avbokad.',
        jsonb_build_object('proposal_id', b.proposal_id));
    end loop;
    update proposals set status = 'cancelled' where id = b.proposal_id;
  end if;
  delete from bookings where id = p_id;
end; $$;

create or replace function public.remove_friend(p_user uuid) returns void
language sql security definer set search_path = public as $$
  delete from friendships where (requester = auth.uid() and addressee = p_user) or (requester = p_user and addressee = auth.uid());
$$;

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  delete from auth.users where id = v_uid;
end; $$;

-- Bokningar och stängningar: uppdatera tee-sheet-signal och kolla bevakningar
create or replace function public.trg_booking_changed() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_club uuid; r record;
begin
  for r in select distinct x.course_id, x.play_date from (
      select new.course_id as course_id, new.play_date as play_date where tg_op <> 'DELETE'
      union all select old.course_id, old.play_date where tg_op <> 'INSERT') x loop
    select club_id into v_club from courses where id = r.course_id;
    if v_club is not null then
      perform public.touch_sheet(v_club, r.play_date);
      perform public.check_watches(v_club, r.play_date);
    end if;
  end loop;
  return null;
end; $$;
drop trigger if exists bookings_changed on public.bookings;
create trigger bookings_changed after insert or update or delete on public.bookings for each row execute function public.trg_booking_changed();

create or replace function public.trg_block_changed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    perform public.touch_sheet(old.club_id, old.play_date); perform public.check_watches(old.club_id, old.play_date);
  else
    perform public.touch_sheet(new.club_id, new.play_date); perform public.check_watches(new.club_id, new.play_date);
  end if;
  return null;
end; $$;
drop trigger if exists blocks_changed on public.blocks;
create trigger blocks_changed after insert or delete on public.blocks for each row execute function public.trg_block_changed();

create or replace function public.trg_watch_inserted() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.play_date < (public.local_now())::date then raise exception 'in_past'; end if;
  if (select count(*) from watches where user_id = new.user_id and play_date >= (public.local_now())::date) > 20 then raise exception 'too_many_watches'; end if;
  perform public.check_watches(new.club_id, new.play_date);
  return null;
end; $$;
drop trigger if exists watches_inserted on public.watches;
create trigger watches_inserted after insert on public.watches for each row execute function public.trg_watch_inserted();

-- Ny notis: be edge-funktionen skicka push och mejl
create or replace function public.trg_notification_inserted() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform net.http_post(
    url := 'https://lerviyfefqtnkyppvbqh.supabase.co/functions/v1/send-notification',
    body := jsonb_build_object('id', new.id),
    headers := jsonb_build_object('Content-Type', 'application/json'),
    timeout_milliseconds := 8000);
  return null;
exception when others then
  return null;
end; $$;
drop trigger if exists notifications_inserted on public.notifications;
create trigger notifications_inserted after insert on public.notifications for each row execute function public.trg_notification_inserted();

-- Direktuppdatering
do $$ begin
  alter publication supabase_realtime add table public.notifications, public.sheet_events, public.friendships, public.proposal_members, public.proposals, public.watches;
exception when duplicate_object then null; end $$;

-- Påminnelse kvällen före och nattlig städning
create or replace function public.send_reminders() returns void
language plpgsql security definer set search_path = public as $$
declare r record; v_tomorrow date := (public.local_now())::date + 1;
begin
  for r in
    select b.user_id, b.tee_time, b.code, c.name as course, cl.name as club
      from bookings b join courses c on c.id = b.course_id join clubs cl on cl.id = c.club_id
      join settings s on s.user_id = b.user_id
     where b.play_date = v_tomorrow and s.remind_day_before
  loop
    perform public.notify_user(r.user_id, 'reminder', 'Imorgon kl ' || to_char(r.tee_time, 'HH24:MI') || ': ' || r.course,
      r.club || '. Bokningskod ' || r.code || '. Lycka till!', jsonb_build_object('date', v_tomorrow));
  end loop;
end; $$;

create or replace function public.daily_cleanup() returns void
language sql security definer set search_path = public as $$
  delete from watches where play_date < (public.local_now())::date;
  delete from notifications where created_at < now() - interval '60 days';
  delete from sheet_events where play_date < (public.local_now())::date - 1;
$$;

-- Inga körrättigheter på interna funktioner för appen
revoke execute on function public.price_for(uuid, date, time), public.block_reason(uuid, date, time), public.slot_free(uuid, date, time),
  public.is_valid_tee(uuid, time), public.touch_sheet(uuid, date), public.notify_user(uuid, text, text, text, jsonb),
  public.find_watch_slot(uuid), public.check_watches(uuid, date), public.trg_booking_changed(), public.trg_block_changed(),
  public.trg_watch_inserted(), public.trg_notification_inserted(), public.handle_new_user(), public.new_code(),
  public.send_reminders(), public.daily_cleanup(), public.get_push_config()
  from public, anon, authenticated;
revoke execute on all functions in schema public from anon;
grant execute on function public.get_push_config() to service_role;

select cron.unschedule(jobid) from cron.job where jobname in ('teetime-reminders', 'teetime-cleanup');
select cron.schedule('teetime-reminders', '0 16 * * *', $$select public.send_reminders()$$);
select cron.schedule('teetime-cleanup', '15 2 * * *', $$select public.daily_cleanup()$$);
