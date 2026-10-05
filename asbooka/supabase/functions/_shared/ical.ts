// Минимальный разбор и сборка iCalendar (RFC 5545) для событий VEVENT.

import { zonedToUtc } from "./tz.ts";

export interface IcsEvent {
  uid: string;
  summary: string;
  description: string;
  location: string;
  start: Date;
  end: Date;
  allDay: boolean;
  rrule: string | null;
  exdates: Date[];
  recurrenceId: Date | null;
  reminderMinutes: number | null;
}

interface Prop {
  name: string;
  params: Record<string, string>;
  value: string;
}

// Часто встречающиеся пояса Windows (Outlook/Exchange) → IANA.
const WINDOWS_TZ: Record<string, string> = {
  "Russian Standard Time": "Europe/Moscow",
  "Russia Time Zone 3": "Europe/Samara",
  "Ekaterinburg Standard Time": "Asia/Yekaterinburg",
  "N. Central Asia Standard Time": "Asia/Novosibirsk",
  "North Asia Standard Time": "Asia/Krasnoyarsk",
  "North Asia East Standard Time": "Asia/Irkutsk",
  "Yakutsk Standard Time": "Asia/Yakutsk",
  "Vladivostok Standard Time": "Asia/Vladivostok",
  "Kaliningrad Standard Time": "Europe/Kaliningrad",
  "UTC": "UTC",
  "GMT Standard Time": "Europe/London",
  "W. Europe Standard Time": "Europe/Berlin",
  "Central European Standard Time": "Europe/Warsaw",
  "FLE Standard Time": "Europe/Kiev",
  "Belarus Standard Time": "Europe/Minsk",
};

export function normalizeTzid(tzid: string | undefined, fallback: string): string {
  if (!tzid) return fallback;
  const t = tzid.replace(/^"|"$/g, "");
  if (WINDOWS_TZ[t]) return WINDOWS_TZ[t];
  const m = t.match(/([A-Za-z_]+\/[A-Za-z_\-+]+(?:\/[A-Za-z_\-+]+)?)$/);
  return m ? m[1] : (t === "Z" || t === "UTC" ? "UTC" : fallback);
}

function unfold(text: string): string[] {
  return text.replace(/\r\n/g, "\n").replace(/\r/g, "\n").replace(/\n[ \t]/g, "").split("\n")
    .filter((l) => l.length > 0);
}

function splitParams(s: string): string[] {
  const out: string[] = [];
  let cur = "";
  let quoted = false;
  for (const ch of s) {
    if (ch === '"') quoted = !quoted;
    if (ch === ";" && !quoted) {
      out.push(cur);
      cur = "";
    } else {
      cur += ch;
    }
  }
  out.push(cur);
  return out;
}

function parseLine(line: string): Prop | null {
  // Ищем первое двоеточие вне кавычек.
  let quoted = false;
  let idx = -1;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') quoted = !quoted;
    else if (ch === ":" && !quoted) {
      idx = i;
      break;
    }
  }
  if (idx < 0) return null;
  const head = splitParams(line.slice(0, idx));
  const params: Record<string, string> = {};
  for (const p of head.slice(1)) {
    const eq = p.indexOf("=");
    if (eq > 0) params[p.slice(0, eq).toUpperCase()] = p.slice(eq + 1).replace(/^"|"$/g, "");
  }
  return { name: head[0].toUpperCase(), params, value: line.slice(idx + 1) };
}

export function unescapeText(v: string): string {
  return v.replace(/\\([\\;,nN])/g, (_, c) => (c === "n" || c === "N" ? "\n" : c));
}

export function escapeText(v: string): string {
  return v.replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\r?\n/g, "\\n");
}

/** Разбор DATE или DATE-TIME. Даты (all-day) возвращаются как полночь UTC. */
export function parseDateValue(
  value: string,
  params: Record<string, string>,
  defaultTz: string,
): { date: Date; allDay: boolean } | null {
  const v = value.trim();
  const d = v.match(/^(\d{4})(\d{2})(\d{2})$/);
  if (d || params.VALUE === "DATE") {
    const m = d ?? v.match(/^(\d{4})(\d{2})(\d{2})/);
    if (!m) return null;
    return { date: new Date(Date.UTC(+m[1], +m[2] - 1, +m[3])), allDay: true };
  }
  const t = v.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$/);
  if (!t) return null;
  const [y, mo, da, h, mi, s] = [+t[1], +t[2], +t[3], +t[4], +t[5], +t[6]];
  if (t[7] === "Z") return { date: new Date(Date.UTC(y, mo - 1, da, h, mi, s)), allDay: false };
  const tz = normalizeTzid(params.TZID, defaultTz);
  return { date: zonedToUtc(y, mo, da, h, mi, s, tz), allDay: false };
}

/** Длительность ISO 8601 / RFC 5545 в минутах (со знаком). */
export function parseDurationMinutes(v: string): number | null {
  const m = v.trim().match(/^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/);
  if (!m) return null;
  const sign = m[1] === "-" ? -1 : 1;
  const mins = (+(m[2] ?? 0)) * 7 * 1440 + (+(m[3] ?? 0)) * 1440 + (+(m[4] ?? 0)) * 60 + (+(m[5] ?? 0)) +
    Math.floor((+(m[6] ?? 0)) / 60);
  return sign * mins;
}

export function parseCalendar(text: string, defaultTz = "Europe/Moscow"): IcsEvent[] {
  const events: IcsEvent[] = [];
  const stack: string[] = [];
  let props: Prop[] = [];
  let alarmTriggers: Prop[] = [];
  let alarmTrigger: Prop | null = null;

  for (const line of unfold(text)) {
    const p = parseLine(line);
    if (!p) continue;
    if (p.name === "BEGIN") {
      stack.push(p.value.toUpperCase());
      if (p.value.toUpperCase() === "VEVENT") {
        props = [];
        alarmTriggers = [];
      }
      if (p.value.toUpperCase() === "VALARM") alarmTrigger = null;
      continue;
    }
    if (p.name === "END") {
      const kind = stack.pop();
      if (kind === "VALARM" && alarmTrigger) alarmTriggers.push(alarmTrigger);
      if (kind === "VEVENT") {
        const ev = buildEvent(props, alarmTriggers, defaultTz);
        if (ev) events.push(ev);
      }
      continue;
    }
    const top = stack[stack.length - 1];
    if (top === "VEVENT") props.push(p);
    else if (top === "VALARM" && p.name === "TRIGGER") alarmTrigger = p;
  }
  return events;
}

function buildEvent(props: Prop[], triggers: Prop[], defaultTz: string): IcsEvent | null {
  const get = (n: string) => props.find((p) => p.name === n);
  const uid = get("UID")?.value;
  const dtstart = get("DTSTART");
  if (!uid || !dtstart) return null;
  const start = parseDateValue(dtstart.value, dtstart.params, defaultTz);
  if (!start) return null;

  let end: Date;
  const dtend = get("DTEND");
  const duration = get("DURATION");
  const parsedEnd = dtend ? parseDateValue(dtend.value, dtend.params, defaultTz) : null;
  if (parsedEnd) {
    end = parsedEnd.date;
  } else if (duration) {
    end = new Date(start.date.getTime() + (parseDurationMinutes(duration.value) ?? 0) * 60000);
  } else {
    end = new Date(start.date.getTime() + (start.allDay ? 86400000 : 0));
  }
  if (end < start.date) end = start.date;

  const exdates: Date[] = [];
  for (const p of props.filter((p) => p.name === "EXDATE")) {
    for (const part of p.value.split(",")) {
      const d = parseDateValue(part, p.params, defaultTz);
      if (d) exdates.push(d.date);
    }
  }
  const rid = get("RECURRENCE-ID");
  const recurrenceId = rid ? parseDateValue(rid.value, rid.params, defaultTz)?.date ?? null : null;

  let reminderMinutes: number | null = null;
  for (const t of triggers) {
    if (t.params.VALUE === "DATE-TIME") {
      const d = parseDateValue(t.value, t.params, defaultTz);
      if (d) {
        const mins = Math.round((start.date.getTime() - d.date.getTime()) / 60000);
        if (mins >= 0 && (reminderMinutes === null || mins < reminderMinutes)) reminderMinutes = mins;
      }
      continue;
    }
    const dur = parseDurationMinutes(t.value);
    if (dur === null || t.params.RELATED === "END") continue;
    const before = -dur;
    if (before >= 0 && (reminderMinutes === null || before < reminderMinutes)) reminderMinutes = before;
  }

  const text = (n: string) => unescapeText(get(n)?.value ?? "");
  return {
    uid,
    summary: text("SUMMARY"),
    description: text("DESCRIPTION"),
    location: text("LOCATION"),
    start: start.date,
    end,
    allDay: start.allDay,
    rrule: get("RRULE")?.value ?? null,
    exdates,
    recurrenceId,
    reminderMinutes,
  };
}

// --- Сборка ---------------------------------------------------------------

function pad(n: number, w = 2): string {
  return String(n).padStart(w, "0");
}

export function formatUtc(d: Date): string {
  return `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}T${pad(d.getUTCHours())}${
    pad(d.getUTCMinutes())
  }${pad(d.getUTCSeconds())}Z`;
}

export function formatDate(d: Date): string {
  return `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}`;
}

/** Перенос длинных строк по 75 байт (RFC 5545, 3.1). */
export function fold(line: string): string {
  const enc = new TextEncoder();
  if (enc.encode(line).length <= 75) return line;
  const out: string[] = [];
  let cur = "";
  let bytes = 0;
  for (const ch of line) {
    const b = enc.encode(ch).length;
    const limit = out.length === 0 ? 75 : 74;
    if (bytes + b > limit) {
      out.push(cur);
      cur = "";
      bytes = 0;
    }
    cur += ch;
    bytes += b;
  }
  out.push(cur);
  return out.join("\r\n ");
}

function dateProp(name: string, d: Date, allDay: boolean): string {
  return allDay ? `${name};VALUE=DATE:${formatDate(d)}` : `${name}:${formatUtc(d)}`;
}

export function buildCalendar(events: IcsEvent[], now = new Date()): string {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//ASBooka//Organizer//RU",
    "CALSCALE:GREGORIAN",
  ];
  // Сначала основное событие, затем изменённые экземпляры.
  const sorted = [...events].sort((a, b) => (a.recurrenceId ? 1 : 0) - (b.recurrenceId ? 1 : 0));
  for (const e of sorted) {
    lines.push("BEGIN:VEVENT");
    lines.push(`UID:${e.uid}`);
    lines.push(`DTSTAMP:${formatUtc(now)}`);
    lines.push(dateProp("DTSTART", e.start, e.allDay));
    lines.push(dateProp("DTEND", e.end, e.allDay));
    if (e.recurrenceId) lines.push(dateProp("RECURRENCE-ID", e.recurrenceId, e.allDay));
    lines.push(`SUMMARY:${escapeText(e.summary)}`);
    if (e.description) lines.push(`DESCRIPTION:${escapeText(e.description)}`);
    if (e.location) lines.push(`LOCATION:${escapeText(e.location)}`);
    if (e.rrule && !e.recurrenceId) lines.push(`RRULE:${e.rrule}`);
    if (e.exdates.length && !e.recurrenceId) {
      lines.push(
        e.allDay
          ? `EXDATE;VALUE=DATE:${e.exdates.map(formatDate).join(",")}`
          : `EXDATE:${e.exdates.map(formatUtc).join(",")}`,
      );
    }
    if (e.reminderMinutes !== null && e.reminderMinutes >= 0) {
      lines.push("BEGIN:VALARM");
      lines.push("ACTION:DISPLAY");
      lines.push(`DESCRIPTION:${escapeText(e.summary || "Напоминание")}`);
      lines.push(`TRIGGER:${e.reminderMinutes === 0 ? "PT0S" : `-PT${e.reminderMinutes}M`}`);
      lines.push("END:VALARM");
    }
    lines.push("END:VEVENT");
  }
  lines.push("END:VCALENDAR");
  return lines.map(fold).join("\r\n") + "\r\n";
}
