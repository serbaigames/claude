// Клиент CalDAV (RFC 4791) для Яндекс Календаря и других серверов.

import { XMLParser } from "npm:fast-xml-parser@4.5.0";

export class CalDavError extends Error {
  constructor(message: string, public status = 0) {
    super(message);
  }
}

export interface RemoteCalendar {
  url: string;
  name: string;
  color: number | null;
  ctag: string | null;
  writable: boolean;
}

export interface RemoteResource {
  href: string;
  etag: string | null;
}

export interface RemoteObject extends RemoteResource {
  data: string;
}

/** Интерфейс, через который работает синхронизация (подменяется в тестах). */
export interface CalDavApi {
  discover(): Promise<RemoteCalendar[]>;
  getCtag(calendarUrl: string): Promise<string | null>;
  listResources(calendarUrl: string): Promise<RemoteResource[]>;
  fetchObjects(calendarUrl: string, hrefs: string[]): Promise<RemoteObject[]>;
  put(href: string, ics: string, etag: string | null): Promise<string | null>;
  remove(href: string, etag: string | null): Promise<void>;
}

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  removeNSPrefix: true,
  parseTagValue: false,
  trimValues: true,
  isArray: (name) => ["response", "propstat", "href", "comp", "privilege"].includes(name),
});

// deno-lint-ignore no-explicit-any
type Xml = any;

function textOf(v: Xml): string | null {
  if (v === undefined || v === null) return null;
  if (typeof v === "string") return v;
  if (typeof v === "object" && "#text" in v) return String(v["#text"]);
  return null;
}

function firstHref(v: Xml): string | null {
  if (!v) return null;
  const h = v.href;
  if (Array.isArray(h)) return textOf(h[0]);
  return textOf(h);
}

/** #RRGGBB или #RRGGBBAA → ARGB-число как во Flutter. */
export function parseColor(v: string | null): number | null {
  if (!v) return null;
  const m = v.trim().match(/^#?([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$/);
  if (!m) return null;
  return 0xff000000 + parseInt(m[1], 16);
}

/**
 * Каноническая форма пути ресурса: серверы по-разному экранируют символы
 * (например, @ и %40), поэтому сравниваем пути после нормализации.
 */
export function normalizeHref(href: string): string {
  const path = new URL(href, "http://x").pathname;
  return path.replace(/%([0-9a-fA-F]{2})/g, (m, hex) => {
    const ch = String.fromCharCode(parseInt(hex, 16));
    return /[A-Za-z0-9\-._~!$&'()*+,;=:@]/.test(ch) ? ch : m.toUpperCase();
  });
}

function basicAuth(user: string, pass: string): string {
  const bytes = new TextEncoder().encode(`${user}:${pass}`);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return "Basic " + btoa(bin);
}

export class CalDavClient implements CalDavApi {
  private auth: string;

  constructor(private baseUrl: string, private username: string, password: string) {
    this.auth = basicAuth(username, password);
  }

  private resolve(href: string): string {
    return new URL(href, this.baseUrl).toString();
  }

  private async request(
    method: string,
    url: string,
    body: string | null,
    headers: Record<string, string> = {},
  ): Promise<Response> {
    const res = await fetch(this.resolve(url), {
      method,
      body,
      headers: {
        Authorization: this.auth,
        ...(body ? { "Content-Type": "application/xml; charset=utf-8" } : {}),
        ...headers,
      },
    });
    if (res.status === 401 || res.status === 403) {
      await res.body?.cancel();
      throw new CalDavError("Неверный логин или пароль приложения", res.status);
    }
    return res;
  }

  private async multistatus(method: string, url: string, body: string, depth: "0" | "1"): Promise<Xml[]> {
    const res = await this.request(method, url, body, { Depth: depth });
    const text = await res.text();
    if (res.status !== 207) throw new CalDavError(`${method} ${url}: HTTP ${res.status}`, res.status);
    const doc = parser.parse(text);
    return doc?.multistatus?.response ?? [];
  }

  private static okProp(resp: Xml): Xml {
    const stats: Xml[] = resp.propstat ?? [];
    const ok = stats.find((s) => String(s.status ?? "").includes(" 200")) ?? stats[0];
    return ok?.prop ?? {};
  }

  async discover(): Promise<RemoteCalendar[]> {
    let principal: string | null = null;
    for (const start of [this.baseUrl, "/.well-known/caldav"]) {
      try {
        const r = await this.multistatus(
          "PROPFIND",
          start,
          `<?xml version="1.0" encoding="utf-8"?><d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>`,
          "0",
        );
        for (const resp of r) {
          principal = firstHref(CalDavClient.okProp(resp)["current-user-principal"]);
          if (principal) break;
        }
        if (principal) break;
      } catch (e) {
        if (e instanceof CalDavError && e.status === 401) throw e;
      }
    }

    let home: string | null = null;
    if (principal) {
      const r = await this.multistatus(
        "PROPFIND",
        principal,
        `<?xml version="1.0" encoding="utf-8"?><d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><c:calendar-home-set/></d:prop></d:propfind>`,
        "0",
      );
      for (const resp of r) {
        home = firstHref(CalDavClient.okProp(resp)["calendar-home-set"]);
        if (home) break;
      }
    }
    // Яндекс: /calendars/<логин>/
    home ??= `/calendars/${encodeURIComponent(this.username)}/`;

    const r = await this.multistatus(
      "PROPFIND",
      home,
      `<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/" xmlns:ic="http://apple.com/ns/ical/">
  <d:prop>
    <d:resourcetype/><d:displayname/><ic:calendar-color/><cs:getctag/>
    <c:supported-calendar-component-set/><d:current-user-privilege-set/>
  </d:prop>
</d:propfind>`,
      "1",
    );

    const calendars: RemoteCalendar[] = [];
    for (const resp of r) {
      const href = textOf(resp.href?.[0]);
      const prop = CalDavClient.okProp(resp);
      const rt = prop.resourcetype ?? {};
      if (!href || typeof rt !== "object" || !("calendar" in rt)) continue;
      const comps: Xml[] = prop["supported-calendar-component-set"]?.comp ?? [];
      if (comps.length && !comps.some((c) => c["@_name"] === "VEVENT")) continue;
      const privs: Xml[] = prop["current-user-privilege-set"]?.privilege ?? [];
      const writable = privs.length === 0 ||
        privs.some((p) => p && typeof p === "object" && ("write" in p || "write-content" in p || "all" in p));
      calendars.push({
        url: href,
        name: textOf(prop.displayname) || decodeURIComponent(href.split("/").filter(Boolean).pop() ?? "Календарь"),
        color: parseColor(textOf(prop["calendar-color"])),
        ctag: textOf(prop.getctag),
        writable,
      });
    }
    return calendars;
  }

  async getCtag(calendarUrl: string): Promise<string | null> {
    const r = await this.multistatus(
      "PROPFIND",
      calendarUrl,
      `<?xml version="1.0" encoding="utf-8"?><d:propfind xmlns:d="DAV:" xmlns:cs="http://calendarserver.org/ns/"><d:prop><cs:getctag/></d:prop></d:propfind>`,
      "0",
    );
    return r.length ? textOf(CalDavClient.okProp(r[0]).getctag) : null;
  }

  async listResources(calendarUrl: string): Promise<RemoteResource[]> {
    const r = await this.multistatus(
      "REPORT",
      calendarUrl,
      `<?xml version="1.0" encoding="utf-8"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:getetag/></d:prop>
  <c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT"/></c:comp-filter></c:filter>
</c:calendar-query>`,
      "1",
    );
    const own = normalizeHref(this.resolve(calendarUrl));
    const out: RemoteResource[] = [];
    for (const resp of r) {
      const href = textOf(resp.href?.[0]);
      if (!href || normalizeHref(this.resolve(href)) === own) continue;
      out.push({ href: normalizeHref(this.resolve(href)), etag: textOf(CalDavClient.okProp(resp).getetag) });
    }
    return out;
  }

  async fetchObjects(calendarUrl: string, hrefs: string[]): Promise<RemoteObject[]> {
    const out: RemoteObject[] = [];
    for (let i = 0; i < hrefs.length; i += 50) {
      const chunk = hrefs.slice(i, i + 50);
      const hrefXml = chunk.map((h) => `<d:href>${h.replace(/&/g, "&amp;").replace(/</g, "&lt;")}</d:href>`).join("");
      const r = await this.multistatus(
        "REPORT",
        calendarUrl,
        `<?xml version="1.0" encoding="utf-8"?>
<c:calendar-multiget xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:getetag/><c:calendar-data/></d:prop>${hrefXml}
</c:calendar-multiget>`,
        "1",
      );
      for (const resp of r) {
        const href = textOf(resp.href?.[0]);
        const prop = CalDavClient.okProp(resp);
        const data = textOf(prop["calendar-data"]);
        if (href && data) {
          out.push({ href: normalizeHref(this.resolve(href)), etag: textOf(prop.getetag), data });
        }
      }
    }
    return out;
  }

  async put(href: string, ics: string, etag: string | null): Promise<string | null> {
    const res = await this.request("PUT", href, ics, {
      "Content-Type": "text/calendar; charset=utf-8",
      ...(etag ? { "If-Match": etag } : { "If-None-Match": "*" }),
    });
    await res.body?.cancel();
    if (res.status === 412) throw new CalDavError("Событие изменено на сервере", 412);
    if (res.status >= 300) throw new CalDavError(`PUT ${href}: HTTP ${res.status}`, res.status);
    return res.headers.get("ETag");
  }

  async remove(href: string, etag: string | null): Promise<void> {
    const res = await this.request("DELETE", href, null, etag ? { "If-Match": etag } : {});
    await res.body?.cancel();
    if (res.status === 404 || res.status === 410) return;
    if (res.status === 412) throw new CalDavError("Событие изменено на сервере", 412);
    if (res.status >= 300) throw new CalDavError(`DELETE ${href}: HTTP ${res.status}`, res.status);
  }
}
