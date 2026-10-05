// Синхронизация против поддельного CalDAV-сервера в стиле Яндекса.
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { CalDavClient, CalDavError, normalizeHref } from "../_shared/caldav.ts";
import { CalendarRow, EventRow, NewEventRow, syncAccount, SyncStore } from "../_shared/sync.ts";
import { parseCalendar } from "../_shared/ical.ts";

const USER = "ivan@yandex.ru";
const HOME = `/calendars/${encodeURIComponent(USER)}/`;
const CAL = `${HOME}events-1/`;
const K = (name: string) => normalizeHref(CAL + name);

class FakeServer {
  objects = new Map<string, { etag: string; data: string }>();
  ctag = 1;
  private n = 0;
  server: Deno.HttpServer;
  url: string;

  constructor() {
    this.server = Deno.serve({ port: 0, hostname: "127.0.0.1", onListen() {} }, (r) => this.handle(r));
    this.url = `http://127.0.0.1:${(this.server.addr as Deno.NetAddr).port}`;
  }

  add(name: string, data: string) {
    this.objects.set(K(name), { etag: `"e${++this.n}"`, data });
    this.ctag++;
  }

  private ms(body: string) {
    return new Response(
      `<?xml version="1.0"?><D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:CS="http://calendarserver.org/ns/" xmlns:A="http://apple.com/ns/ical/">${body}</D:multistatus>`,
      { status: 207 },
    );
  }

  private async handle(req: Request): Promise<Response> {
    if (req.headers.get("Authorization") !== "Basic " + btoa(`${USER}:secret`)) {
      return new Response("", { status: 401 });
    }
    const path = normalizeHref(new URL(req.url).pathname);
    const body = await req.text();
    const ok = (p: string) => `<D:propstat><D:prop>${p}</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>`;
    if (req.method === "PROPFIND" && path === "/") {
      return this.ms(
        `<D:response><D:href>/</D:href>${
          ok(`<D:current-user-principal><D:href>/principals/users/${USER}/</D:href></D:current-user-principal>`)
        }</D:response>`,
      );
    }
    if (req.method === "PROPFIND" && path.startsWith("/principals/")) {
      return this.ms(
        `<D:response><D:href>${path}</D:href>${
          ok(`<C:calendar-home-set><D:href>${HOME}</D:href></C:calendar-home-set>`)
        }</D:response>`,
      );
    }
    if (req.method === "PROPFIND" && path === normalizeHref(HOME)) {
      return this.ms(
        `<D:response><D:href>${HOME}</D:href>${ok(`<D:resourcetype><D:collection/></D:resourcetype>`)}</D:response>` +
          `<D:response><D:href>${CAL}</D:href>${
            ok(
              `<D:resourcetype><D:collection/><C:calendar/></D:resourcetype><D:displayname>Мои события</D:displayname><A:calendar-color>#FF5500FF</A:calendar-color><CS:getctag>${this.ctag}</CS:getctag><C:supported-calendar-component-set><C:comp name="VEVENT"/><C:comp name="VTODO"/></C:supported-calendar-component-set><D:current-user-privilege-set><D:privilege><D:read/></D:privilege><D:privilege><D:write/></D:privilege></D:current-user-privilege-set>`,
            )
          }</D:response>` +
          `<D:response><D:href>${HOME}todos/</D:href>${
            ok(
              `<D:resourcetype><D:collection/><C:calendar/></D:resourcetype><C:supported-calendar-component-set><C:comp name="VTODO"/></C:supported-calendar-component-set>`,
            )
          }</D:response>`,
      );
    }
    if (req.method === "PROPFIND" && path === normalizeHref(CAL)) {
      return this.ms(`<D:response><D:href>${CAL}</D:href>${ok(`<CS:getctag>${this.ctag}</CS:getctag>`)}</D:response>`);
    }
    if (req.method === "REPORT" && body.includes("calendar-query")) {
      let out = `<D:response><D:href>${CAL}</D:href>${ok("")}</D:response>`;
      for (const [href, o] of this.objects) {
        out += `<D:response><D:href>${href}</D:href>${ok(`<D:getetag>${o.etag}</D:getetag>`)}</D:response>`;
      }
      return this.ms(out);
    }
    if (req.method === "REPORT" && body.includes("calendar-multiget")) {
      const hrefs = [...body.matchAll(/<d:href>([^<]+)<\/d:href>/g)].map((m) => normalizeHref(m[1]));
      let out = "";
      for (const h of hrefs) {
        const o = this.objects.get(h);
        if (o) {
          out += `<D:response><D:href>${h}</D:href>${
            ok(
              `<D:getetag>${o.etag}</D:getetag><C:calendar-data>${
                o.data.replace(/&/g, "&amp;").replace(/</g, "&lt;")
              }</C:calendar-data>`,
            )
          }</D:response>`;
        }
      }
      return this.ms(out);
    }
    if (req.method === "PUT") {
      const cur = this.objects.get(path);
      const ifMatch = req.headers.get("If-Match");
      if (req.headers.get("If-None-Match") === "*" && cur) return new Response("", { status: 412 });
      if (ifMatch && cur?.etag !== ifMatch) return new Response("", { status: 412 });
      const etag = `"e${++this.n}"`;
      this.objects.set(path, { etag, data: body });
      this.ctag++;
      return new Response(null, { status: cur ? 204 : 201, headers: { ETag: etag } });
    }
    if (req.method === "DELETE") {
      const cur = this.objects.get(path);
      if (!cur) return new Response("", { status: 404 });
      if (req.headers.get("If-Match") && cur.etag !== req.headers.get("If-Match")) {
        return new Response("", { status: 412 });
      }
      this.objects.delete(path);
      this.ctag++;
      return new Response(null, { status: 204 });
    }
    return new Response("", { status: 405 });
  }
}

class MemoryStore implements SyncStore {
  calendars: (CalendarRow & { name: string; account_id: string })[] = [];
  events: EventRow[] = [];
  private n = 0;
  async listCalendars(accountId: string) {
    return this.calendars.filter((c) => c.account_id === accountId).map((c) => ({ ...c }));
  }
  async insertCalendar(accountId: string, _owner: string, cal: { url: string; name: string }, readonly: boolean) {
    const id = `cal${++this.n}`;
    this.calendars.push({
      id,
      account_id: accountId,
      name: cal.name,
      remote_url: cal.url,
      remote_ctag: null,
      is_readonly: readonly,
    });
    return id;
  }
  async updateCalendar(id: string, patch: Partial<CalendarRow>) {
    Object.assign(this.calendars.find((c) => c.id === id)!, patch);
  }
  async deleteCalendar(id: string) {
    this.calendars = this.calendars.filter((c) => c.id !== id);
    this.events = this.events.filter((e) => e.calendar_id !== id);
  }
  async listEvents(calendarId: string) {
    return this.events.filter((e) => e.calendar_id === calendarId).map((e) => ({ ...e }));
  }
  async insertEvents(rows: NewEventRow[]) {
    for (const r of rows) this.events.push({ ...r, id: `ev${++this.n}` });
  }
  async updateEvent(id: string, patch: Partial<EventRow>) {
    Object.assign(this.events.find((e) => e.id === id)!, patch);
  }
  async deleteEvents(ids: string[]) {
    this.events = this.events.filter((e) => !ids.includes(e.id));
  }
}

const ICS = (uid: string, title: string, day = "06") =>
  `BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:${uid}\r\nDTSTART;TZID=Europe/Moscow:202610${day}T100000\r\nDTEND;TZID=Europe/Moscow:202610${day}T110000\r\nSUMMARY:${title}\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n`;

const account = { id: "acc1", owner_id: "u1", timezone: "Europe/Moscow", two_way: true };

Deno.test("двусторонняя синхронизация: загрузка, правка, создание, удаление, изменения на сервере", async () => {
  const srv = new FakeServer();
  try {
    srv.add("a.ics", ICS("a", "Встреча А"));
    srv.add("b.ics", ICS("b", "Встреча Б", "07"));
    const api = new CalDavClient(srv.url, USER, "secret");
    const store = new MemoryStore();

    // Первая загрузка
    let rep = await syncAccount(api, store, account);
    assertEquals(rep.errors, []);
    assertEquals(store.calendars.length, 1, "календарь только для задач пропущен");
    assertEquals(store.calendars[0].name, "Мои события");
    assertEquals(store.events.map((e) => e.title).sort(), ["Встреча А", "Встреча Б"]);
    assertEquals(store.events.find((e) => e.uid === "a")!.starts_at, "2026-10-06T07:00:00.000Z");

    // Повтор без изменений: CTag не изменился, ничего не скачивается
    rep = await syncAccount(api, store, account);
    assertEquals(rep.pulled, 0);

    // Правка в приложении → PUT с If-Match
    const a = store.events.find((e) => e.uid === "a")!;
    a.title = "Встреча А (изменено)";
    a.sync_state = "dirty";
    // Новое событие из приложения
    store.events.push({
      ...a,
      id: "new1",
      uid: "app-1",
      title: "Из приложения",
      remote_href: null,
      remote_etag: null,
      sync_state: "dirty",
      reminder_minutes: 30,
    });
    // Удаление в приложении
    const b = store.events.find((e) => e.uid === "b")!;
    b.deleted_at = new Date().toISOString();
    b.sync_state = "dirty";

    rep = await syncAccount(api, store, account);
    assertEquals(rep.errors, []);
    assertEquals(rep.pushed, 3);
    assert(parseCalendar(srv.objects.get(K("a.ics"))!.data)[0].summary === "Встреча А (изменено)");
    const created = parseCalendar(srv.objects.get(K("app-1.ics"))!.data)[0];
    assertEquals(created.summary, "Из приложения");
    assertEquals(created.reminderMinutes, 30);
    assert(!srv.objects.has(K("b.ics")), "удалено на сервере");
    assertEquals(store.events.map((e) => e.uid).sort(), ["a", "app-1"]);
    assert(store.events.every((e) => e.sync_state === "synced"));

    // Изменения на сервере: правка и удаление
    srv.objects.set(K("a.ics"), { etag: '"zz"', data: ICS("a", "Перенесли", "09") });
    srv.objects.delete(K("app-1.ics"));
    srv.ctag++;
    rep = await syncAccount(api, store, account);
    assertEquals(store.events.length, 1);
    assertEquals(store.events[0].title, "Перенесли");
    assertEquals(store.events[0].id, a.id, "идентификатор события сохраняется");

    // Конфликт: на сервере новая версия, в приложении тоже правка → побеждает сервер
    srv.objects.set(K("a.ics"), { etag: '"yy"', data: ICS("a", "Серверная версия") });
    srv.ctag++;
    store.events[0].title = "Локальная версия";
    store.events[0].sync_state = "dirty";
    rep = await syncAccount(api, store, account);
    assertEquals(store.events[0].title, "Серверная версия");
    assert(rep.errors[0].startsWith("Конфликт"));
  } finally {
    await srv.server.shutdown();
  }
});

Deno.test("односторонний режим: календарь только для чтения, правки не выгружаются", async () => {
  const srv = new FakeServer();
  try {
    srv.add("a.ics", ICS("a", "А"));
    const api = new CalDavClient(srv.url, USER, "secret");
    const store = new MemoryStore();
    const oneWay = { ...account, two_way: false };
    await syncAccount(api, store, oneWay);
    assert(store.calendars[0].is_readonly);
    store.events[0].sync_state = "dirty";
    store.events[0].title = "X";
    const rep = await syncAccount(api, store, oneWay);
    assertEquals(rep.pushed, 0);
    assertEquals(parseCalendar(srv.objects.get(K("a.ics"))!.data)[0].summary, "А");
  } finally {
    await srv.server.shutdown();
  }
});

Deno.test("неверный пароль приложения", async () => {
  const srv = new FakeServer();
  try {
    await assertRejects(() => new CalDavClient(srv.url, USER, "wrong").discover(), CalDavError);
  } finally {
    await srv.server.shutdown();
  }
});
