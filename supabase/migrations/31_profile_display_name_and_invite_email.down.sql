-- 31_profile_display_name_and_invite_email.down.sql — restore the pre-31
-- signup trigger body. The backfill is not reversed: the previous value was
-- the account email address, which is the PII leak this migration removes.

begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id, display_name, locale)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', new.email),
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

commit;
