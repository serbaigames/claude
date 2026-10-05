// Синхронизация CalDAV.
// - Из pg_cron (заголовок x-cron-secret): все учётные записи, у которых подошёл
//   срок по sync_interval_minutes.
// - Из приложения (JWT пользователя): учётные записи пользователя сразу,
//   либо одна, если передан account_id.

import { adminClient, corsHeaders, json, requestUser } from "../_shared/http.ts";
import { FullAccountRow, runAccountSync } from "../_shared/store.ts";
import { timingSafeEqual } from "../_shared/crypto.ts";

const COLUMNS = "id,owner_id,server_url,username,timezone,two_way,sync_interval_minutes,last_synced_at";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const db = adminClient();
  const body = await req.json().catch(() => ({}));
  const cronSecret = Deno.env.get("CRON_SECRET");
  const given = req.headers.get("x-cron-secret");
  let accounts: FullAccountRow[];

  if (cronSecret && given && timingSafeEqual(given, cronSecret)) {
    const { data, error } = await db.from("calendar_accounts").select(COLUMNS);
    if (error) return json({ error: error.message }, 500);
    const now = Date.now();
    accounts = (data as FullAccountRow[]).filter((a) =>
      !a.last_synced_at ||
      new Date(a.last_synced_at).getTime() + a.sync_interval_minutes * 60000 <= now + 60000
    );
  } else {
    const user = await requestUser(req, db);
    if (!user) return json({ error: "unauthorized" }, 401);
    let q = db.from("calendar_accounts").select(COLUMNS).eq("owner_id", user.id);
    if (body.account_id) q = q.eq("id", body.account_id);
    const { data, error } = await q;
    if (error) return json({ error: error.message }, 500);
    accounts = data as FullAccountRow[];
  }

  const results: Record<string, unknown> = {};
  for (const account of accounts) {
    try {
      results[account.id] = await runAccountSync(db, account);
    } catch (e) {
      results[account.id] = { error: (e as Error).message };
    }
  }
  return json({ synced: accounts.length, results });
});
