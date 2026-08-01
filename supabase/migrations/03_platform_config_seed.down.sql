-- 03_platform_config_seed.down.sql — backout for 03_platform_config_seed.sql
-- (REVIEWED, NOT APPLIED)

begin;

delete from public.platform_config;

commit;
