-- Фоновая синхронизация CalDAV: раз в 5 минут pg_cron вызывает функцию
-- caldav-sync, а она уже сама выбирает учётные записи, у которых подошёл
-- срок по их интервалу (sync_interval_minutes).
--
-- Перед применением положите в Vault два секрета (SQL Editor):
--   select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
--   select vault.create_secret('<случайная строка>', 'cron_secret');
-- и ту же строку задайте функциям: supabase secrets set CRON_SECRET=<строка>

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'asbooka-caldav-sync',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/caldav-sync',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{"mode":"cron"}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);
