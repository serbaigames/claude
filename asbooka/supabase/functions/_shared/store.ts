// Реализация SyncStore поверх Supabase (сервисный ключ, без RLS).

import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { CalDavClient } from "./caldav.ts";
import { decryptSecret } from "./crypto.ts";
import { env } from "./http.ts";
import { AccountRow, CalendarRow, EventRow, NewEventRow, syncAccount, SyncReport, SyncStore } from "./sync.ts";

const EVENT_COLUMNS =
  "id,calendar_id,owner_id,title,description,location,starts_at,ends_at,all_day,rrule,exdates,recurrence_id,reminder_minutes,uid,remote_href,remote_etag,sync_state,deleted_at";

function check<T>(res: { data: T; error: { message: string } | null }): T {
  if (res.error) throw new Error(res.error.message);
  return res.data;
}

export class SupabaseSyncStore implements SyncStore {
  constructor(private db: SupabaseClient) {}

  async listCalendars(accountId: string): Promise<CalendarRow[]> {
    return check(
      await this.db.from("calendars").select("id,remote_url,remote_ctag,is_readonly").eq("account_id", accountId),
    ) as CalendarRow[];
  }

  async insertCalendar(
    accountId: string,
    ownerId: string,
    cal: { url: string; name: string; color: number | null },
    readonly: boolean,
  ) {
    const row = check(
      await this.db.from("calendars").insert({
        account_id: accountId,
        owner_id: ownerId,
        name: cal.name,
        remote_url: cal.url,
        is_readonly: readonly,
        ...(cal.color ? { color: cal.color } : {}),
      }).select("id").single(),
    ) as { id: string };
    return row.id;
  }

  async updateCalendar(id: string, patch: Record<string, unknown>) {
    check(await this.db.from("calendars").update(patch).eq("id", id));
  }

  async deleteCalendar(id: string) {
    check(await this.db.from("calendars").delete().eq("id", id));
  }

  async listEvents(calendarId: string): Promise<EventRow[]> {
    const out: EventRow[] = [];
    for (let from = 0;; from += 1000) {
      const page = check(
        await this.db.from("events").select(EVENT_COLUMNS).eq("calendar_id", calendarId).order("id").range(
          from,
          from + 999,
        ),
      ) as EventRow[];
      out.push(...page);
      if (page.length < 1000) return out;
    }
  }

  async insertEvents(rows: NewEventRow[]) {
    for (let i = 0; i < rows.length; i += 500) {
      check(await this.db.from("events").insert(rows.slice(i, i + 500)));
    }
  }

  async updateEvent(id: string, patch: Partial<EventRow>) {
    check(await this.db.from("events").update(patch).eq("id", id));
  }

  async deleteEvents(ids: string[]) {
    for (let i = 0; i < ids.length; i += 200) {
      check(await this.db.from("events").delete().in("id", ids.slice(i, i + 200)));
    }
  }
}

export interface FullAccountRow extends AccountRow {
  server_url: string;
  username: string;
  sync_interval_minutes: number;
  last_synced_at: string | null;
}

export async function loadPassword(db: SupabaseClient, accountId: string): Promise<string> {
  const row = check(
    await db.from("calendar_account_secrets").select("password_enc").eq("account_id", accountId).single(),
  ) as { password_enc: string };
  return decryptSecret(row.password_enc, env("CALDAV_ENCRYPTION_KEY"));
}

/** Синхронизирует учётную запись и записывает итог в calendar_accounts. */
export async function runAccountSync(db: SupabaseClient, account: FullAccountRow): Promise<SyncReport> {
  try {
    const password = await loadPassword(db, account.id);
    const api = new CalDavClient(account.server_url, account.username, password);
    const report = await syncAccount(api, new SupabaseSyncStore(db), account);
    await db.from("calendar_accounts").update({
      last_synced_at: new Date().toISOString(),
      last_error: report.errors.length ? report.errors.slice(0, 5).join("\n") : null,
    }).eq("id", account.id);
    return report;
  } catch (e) {
    await db.from("calendar_accounts").update({
      last_synced_at: new Date().toISOString(),
      last_error: (e as Error).message,
    }).eq("id", account.id);
    throw e;
  }
}
