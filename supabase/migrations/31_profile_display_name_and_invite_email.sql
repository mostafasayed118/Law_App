-- 31_profile_display_name_and_invite_email.sql — stop email-as-display-name
-- and require a confirmed address to redeem an invitation.
--
-- Audit 2026-10-28 (H2): the signup trigger fell back to `new.email`, and
-- Google OAuth sends `name`/`full_name` but not `display_name`. Every OAuth
-- profile therefore became its email address, which `send_message` copies
-- into `messages.author_display_name` and the opposing party can read.
--
-- Also backfills existing rows whose display_name equals their account email.
-- The fallback order is display_name -> full_name -> name -> 'Member'; an
-- email address is never used.
--
-- Rollback: 31_profile_display_name_and_invite_email.down.sql restores the
-- previous trigger body. The backfill is a data correction and is not
-- reversed (the previous value was the email address).

begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id, display_name, locale)
  values (
    new.id,
    left(
      coalesce(
        nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
        nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
        nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
        'Member'
      ),
      120
    ),
    coalesce(new.raw_user_meta_data ->> 'locale', 'en')
  );
  perform public.write_audit(
    'system:profile_created', 'allowed',
    p_resource_type => 'profile', p_resource_id => new.id,
    p_redacted_summary => 'profile row created from signup trigger',
    p_actor => null
  );
  return new;
end;
$$;

-- Backfill only rows that copied the account email; never touch a
-- user-chosen display name.
update public.profiles p
   set display_name = left(
         coalesce(
           nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''),
           nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
           nullif(trim(u.raw_user_meta_data ->> 'display_name'), ''),
           'Member'
         ),
         120
       ),
       updated_at = now()
  from auth.users u
 where u.id = p.user_id
   and lower(trim(p.display_name)) = lower(trim(u.email));

commit;
