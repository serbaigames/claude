// Двусторонняя синхронизация учётной записи CalDAV с таблицами calendars/events.
//
// 1. Календари: список с сервера → upsert в calendars, исчезнувшие удаляются.
// 2. Выгрузка (если включена двусторонняя связь): события с sync_state='dirty'
//    отправляются PUT/DELETE с проверкой ETag. При конфликте побеждает сервер.
// 3. Загрузка: сравнение ETag всех ресурсов, скачивание изменённых,
//    удаление исчезнувших. Если CTag календаря не изменился — пропуск.

import { CalDavApi, CalDavError, normalizeHref, RemoteCalendar } from "./caldav.ts";
import { buildCalendar, IcsEvent, parseCalendar } from "./ical.ts";

export interface AccountRow {
  id: string;
  owner_id: string;
  timezone: string;
  two_way: boolean;
}

export interface CalendarRow {
  id: string;
  remote_url: string | null;
  remote_ctag: string | null;
  is_readonly: boolean;
}

export interface EventRow {
  id: string;
  calendar_id: string;
  owner_id: string;
  title: string;
  description: string;
  location: string;
  starts_at: string;
  ends_at: string;
  all_day: boolean;
  rrule: string | null;
  exdates: string[];
  recurrence_id: string | null;
  reminder_minutes: number | null;
  uid: string;
  remote_href: string | null;
  remote_etag: string | null;
  sync_state: "local" | "synced" | "dirty";
  deleted_at: string | null;
}

export type NewEventRow = Omit<EventRow, "id">;

export interface SyncStore {
  listCalendars(accountId: string): Promise<CalendarRow[]>;
  insertCalendar(accountId: string, ownerId: string, cal: RemoteCalendar, readonly: boolean): Promise<string>;
  updateCalendar(id: string, patch: Partial<CalendarRow> & { name?: string }): Promise<void>;
  deleteCalendar(id: string): Promise<void>;
  listEvents(calendarId: string): Promise<EventRow[]>;
  insertEvents(rows: NewEventRow[]): Promise<void>;
  updateEvent(id: string, patch: Partial<EventRow>): Promise<void>;
  deleteEvents(ids: string[]): Promise<void>;
}

export interface SyncReport {
  calendars: number;
  pushed: number;
  pulled: number;
  deleted: number;
  errors: string[];
}

export function hrefFor(calendarUrl: string, uid: string): string {
  const path = new URL(calendarUrl, "http://x").pathname;
  return normalizeHref((path.endsWith("/") ? path : path + "/") + encodeURIComponent(uid) + ".ics");
}

export function rowToIcs(r: EventRow): IcsEvent {
  return {
    uid: r.uid,
    summary: r.title,
    description: r.description,
    location: r.location,
    start: new Date(r.starts_at),
    end: new Date(r.ends_at),
    allDay: r.all_day,
    rrule: r.rrule,
    exdates: (r.exdates ?? []).map((d) => new Date(d)),
    recurrenceId: r.recurrence_id ? new Date(r.recurrence_id) : null,
    reminderMinutes: r.reminder_minutes,
  };
}

function icsToFields(e: IcsEvent) {
  return {
    title: e.summary,
    description: e.description,
    location: e.location,
    starts_at: e.start.toISOString(),
    ends_at: e.end.toISOString(),
    all_day: e.allDay,
    rrule: e.rrule,
    exdates: e.exdates.map((d) => d.toISOString()),
    recurrence_id: e.recurrenceId ? e.recurrenceId.toISOString() : null,
    reminder_minutes: e.reminderMinutes,
    uid: e.uid,
  };
}

function eventKey(uid: string, recurrenceId: string | Date | null): string {
  return `${uid}|${recurrenceId ? new Date(recurrenceId).getTime() : ""}`;
}

function groupBy<T>(items: T[], key: (t: T) => string | null): Map<string, T[]> {
  const m = new Map<string, T[]>();
  for (const it of items) {
    const k = key(it);
    if (k === null) continue;
    const list = m.get(k);
    if (list) list.push(it);
    else m.set(k, [it]);
  }
  return m;
}

export async function syncAccount(api: CalDavApi, store: SyncStore, account: AccountRow): Promise<SyncReport> {
  const report: SyncReport = { calendars: 0, pushed: 0, pulled: 0, deleted: 0, errors: [] };

  // 1. Календари
  const remoteCals = await api.discover();
  const localCals = await store.listCalendars(account.id);
  const cals: { row: CalendarRow; remote: RemoteCalendar }[] = [];
  for (const rc of remoteCals) {
    const readonly = !account.two_way || !rc.writable;
    const existing = localCals.find((c) => c.remote_url === rc.url);
    if (existing) {
      if (existing.is_readonly !== readonly) await store.updateCalendar(existing.id, { is_readonly: readonly });
      cals.push({ row: { ...existing, is_readonly: readonly }, remote: rc });
    } else {
      const id = await store.insertCalendar(account.id, account.owner_id, rc, readonly);
      cals.push({ row: { id, remote_url: rc.url, remote_ctag: null, is_readonly: readonly }, remote: rc });
    }
  }
  for (const lc of localCals) {
    if (!remoteCals.some((rc) => rc.url === lc.remote_url)) await store.deleteCalendar(lc.id);
  }
  report.calendars = cals.length;

  for (const { row: cal, remote } of cals) {
    try {
      const pushed = cal.is_readonly ? 0 : await pushCalendar(api, store, cal, remote.url, report);
      report.pushed += pushed;
      await pullCalendar(api, store, cal, remote, account, pushed > 0, report);
    } catch (e) {
      if (e instanceof CalDavError && e.status === 401) throw e;
      report.errors.push(`${remote.name}: ${(e as Error).message}`);
    }
  }
  return report;
}

async function pushCalendar(
  api: CalDavApi,
  store: SyncStore,
  cal: CalendarRow,
  calUrl: string,
  report: SyncReport,
): Promise<number> {
  const rows = await store.listEvents(cal.id);
  const dirty = rows.filter((r) => r.sync_state === "dirty");
  if (!dirty.length) return 0;

  const hrefOf = (r: EventRow) => r.remote_href ?? hrefFor(calUrl, r.uid);
  const byHref = groupBy(rows, hrefOf);
  const hrefs = [...new Set(dirty.map(hrefOf))];
  let count = 0;

  for (const href of hrefs) {
    const group = byHref.get(href) ?? [];
    const alive = group.filter((r) => !r.deleted_at);
    const etag = group.find((r) => r.remote_etag)?.remote_etag ?? null;
    const isNew = group.every((r) => !r.remote_href);
    const master = alive.find((r) => !r.recurrence_id);
    try {
      if (!master) {
        if (!isNew) await api.remove(href, etag);
        await store.deleteEvents(group.map((r) => r.id));
      } else {
        const newEtag = await api.put(href, buildCalendar(alive.map(rowToIcs)), isNew ? null : etag);
        const gone = group.filter((r) => r.deleted_at).map((r) => r.id);
        if (gone.length) await store.deleteEvents(gone);
        for (const r of alive) {
          await store.updateEvent(r.id, { remote_href: href, remote_etag: newEtag, sync_state: "synced" });
        }
      }
      count++;
    } catch (e) {
      if (e instanceof CalDavError && e.status === 412) {
        // Конфликт: оставляем версию сервера, загрузка ниже её подтянет.
        for (const r of group) {
          await store.updateEvent(r.id, { remote_etag: null, sync_state: "synced", deleted_at: null });
        }
        report.errors.push(`Конфликт «${master?.title ?? href}»: оставлена версия сервера`);
      } else if (e instanceof CalDavError && e.status === 401) {
        throw e;
      } else {
        report.errors.push(`Не удалось выгрузить «${master?.title ?? href}»: ${(e as Error).message}`);
      }
    }
  }
  return count;
}

async function pullCalendar(
  api: CalDavApi,
  store: SyncStore,
  cal: CalendarRow,
  remote: RemoteCalendar,
  account: AccountRow,
  force: boolean,
  report: SyncReport,
): Promise<void> {
  const ctag = remote.ctag ?? await api.getCtag(remote.url);
  if (!force && ctag && ctag === cal.remote_ctag) return;

  const resources = await api.listResources(remote.url);
  const rows = await store.listEvents(cal.id);
  const byHref = groupBy(rows, (r) => r.remote_href);
  const dirtyHrefs = new Set(rows.filter((r) => r.sync_state === "dirty").map((r) => r.remote_href));
  const remoteHrefs = new Set(resources.map((r) => r.href));

  // Удалённые на сервере
  const toDelete: string[] = [];
  for (const [href, group] of byHref) {
    if (!remoteHrefs.has(href) && !dirtyHrefs.has(href)) toDelete.push(...group.map((r) => r.id));
  }
  if (toDelete.length) {
    await store.deleteEvents(toDelete);
    report.deleted += toDelete.length;
  }
  const deletedIds = new Set(toDelete);

  // Изменённые и новые
  const changed = resources.filter((res) => {
    if (dirtyHrefs.has(res.href)) return false;
    const group = byHref.get(res.href);
    return !group || res.etag === null || group.some((r) => r.remote_etag !== res.etag);
  });
  if (changed.length) {
    const objects = await api.fetchObjects(remote.url, changed.map((c) => c.href));
    const live = rows.filter((r) => !deletedIds.has(r.id));
    const byKey = new Map(live.map((r) => [eventKey(r.uid, r.recurrence_id), r]));

    for (const obj of objects) {
      const parsed = parseCalendar(obj.data, account.timezone);
      const keep = new Set<string>();
      const inserts: NewEventRow[] = [];
      for (const ev of parsed) {
        const key = eventKey(ev.uid, ev.recurrenceId);
        const existing = byKey.get(key);
        if (existing && existing.sync_state === "dirty") {
          keep.add(existing.id);
          continue;
        }
        const fields = {
          ...icsToFields(ev),
          remote_href: obj.href,
          remote_etag: obj.etag,
          sync_state: "synced" as const,
        };
        if (existing) {
          keep.add(existing.id);
          await store.updateEvent(existing.id, { ...fields, deleted_at: null });
        } else {
          inserts.push({ ...fields, calendar_id: cal.id, owner_id: account.owner_id, deleted_at: null });
        }
        report.pulled++;
      }
      if (inserts.length) await store.insertEvents(inserts);
      const stale = (byHref.get(obj.href) ?? []).filter((r) => !keep.has(r.id) && !deletedIds.has(r.id));
      if (stale.length) await store.deleteEvents(stale.map((r) => r.id));
    }
  }

  if (ctag !== cal.remote_ctag) await store.updateCalendar(cal.id, { remote_ctag: ctag });
}
