// Подключение календаря CalDAV (Яндекс Календарь по умолчанию).
// Проверяет логин и пароль приложения, сохраняет пароль зашифрованным
// и сразу выполняет первую синхронизацию.
//
// POST { username, password, server_url?, sync_interval_minutes?, two_way?, timezone? }
// POST { account_id, password }  — сменить пароль приложения

import { adminClient, corsHeaders, env, json, requestUser } from "../_shared/http.ts";
import { CalDavClient, CalDavError } from "../_shared/caldav.ts";
import { encryptSecret } from "../_shared/crypto.ts";
import { FullAccountRow, runAccountSync } from "../_shared/store.ts";
import { isValidTimeZone } from "../_shared/tz.ts";

const YANDEX = "https://caldav.yandex.ru";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const db = adminClient();
  const user = await requestUser(req, db);
  if (!user) return json({ error: "unauthorized" }, 401);

  const body = await req.json().catch(() => ({}));
  const password = String(body.password ?? "").trim();
  if (!password) return json({ error: "Укажите пароль приложения" }, 400);

  // Смена пароля существующей учётной записи
  if (body.account_id) {
    const { data: acc } = await db.from("calendar_accounts").select("*").eq("id", body.account_id)
      .eq("owner_id", user.id).maybeSingle();
    if (!acc) return json({ error: "Учётная запись не найдена" }, 404);
    try {
      await new CalDavClient(acc.server_url, acc.username, password).discover();
    } catch (e) {
      return json({ error: (e as Error).message }, e instanceof CalDavError && e.status === 401 ? 401 : 502);
    }
    await db.from("calendar_account_secrets").upsert({
      account_id: acc.id,
      password_enc: await encryptSecret(password, env("CALDAV_ENCRYPTION_KEY")),
    });
    const report = await runAccountSync(db, acc as FullAccountRow).catch((e) => ({ error: e.message }));
    return json({ account_id: acc.id, report });
  }

  const username = String(body.username ?? "").trim();
  if (!username) return json({ error: "Укажите логин" }, 400);
  let serverUrl = String(body.server_url ?? YANDEX).trim() || YANDEX;
  if (!/^https:\/\//.test(serverUrl)) return json({ error: "Адрес сервера должен начинаться с https://" }, 400);
  serverUrl = serverUrl.replace(/\/+$/, "");
  const interval = Math.min(1440, Math.max(5, Number(body.sync_interval_minutes) || 30));
  const timezone = isValidTimeZone(String(body.timezone ?? "")) ? String(body.timezone) : "Europe/Moscow";

  let calendars;
  try {
    calendars = await new CalDavClient(serverUrl, username, password).discover();
  } catch (e) {
    return json({ error: (e as Error).message }, e instanceof CalDavError && e.status === 401 ? 401 : 502);
  }
  if (!calendars.length) return json({ error: "На сервере не найдено календарей" }, 404);

  const { data: account, error } = await db.from("calendar_accounts").insert({
    owner_id: user.id,
    provider: serverUrl === YANDEX ? "yandex" : "caldav",
    server_url: serverUrl,
    username,
    timezone,
    sync_interval_minutes: interval,
    two_way: body.two_way !== false,
  }).select("*").single();
  if (error) return json({ error: error.message }, 500);

  await db.from("calendar_account_secrets").insert({
    account_id: account.id,
    password_enc: await encryptSecret(password, env("CALDAV_ENCRYPTION_KEY")),
  });

  const report = await runAccountSync(db, account as FullAccountRow).catch((e) => ({ error: e.message }));
  return json({ account_id: account.id, calendars: calendars.length, report });
});
