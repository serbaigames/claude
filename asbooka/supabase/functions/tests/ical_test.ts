import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildCalendar, fold, parseCalendar, parseDurationMinutes } from "../_shared/ical.ts";
import { zonedToUtc } from "../_shared/tz.ts";

const YANDEX_ICS = [
  "BEGIN:VCALENDAR",
  "PRODID:-//Yandex LLC//Yandex Calendar//EN",
  "VERSION:2.0",
  "BEGIN:VTIMEZONE",
  "TZID:Europe/Moscow",
  "END:VTIMEZONE",
  "BEGIN:VEVENT",
  "DTSTART;TZID=Europe/Moscow:20261006T100000",
  "DTEND;TZID=Europe/Moscow:20261006T113000",
  "SUMMARY:Планёрка\\, отдел",
  "DESCRIPTION:Строка 1\\nСтрока 2",
  "LOCATION:Переговорная",
  "UID:abc@yandex.ru",
  "RRULE:FREQ=WEEKLY;BYDAY=TU,TH",
  "EXDATE;TZID=Europe/Moscow:20261008T100000",
  "BEGIN:VALARM",
  "TRIGGER:-PT15M",
  "ACTION:DISPLAY",
  "END:VALARM",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "DTSTART;TZID=Europe/Moscow:20261013T120000",
  "DTEND;TZID=Europe/Moscow:20261013T130000",
  "RECURRENCE-ID;TZID=Europe/Moscow:20261013T100000",
  "SUMMARY:Планёрка (перенос)",
  "UID:abc@yandex.ru",
  "END:VEVENT",
  "END:VCALENDAR",
].join("\r\n");

Deno.test("разбор события Яндекс Календаря с поясом, повтором и напоминанием", () => {
  const [master, override] = parseCalendar(YANDEX_ICS);
  assertEquals(master.summary, "Планёрка, отдел");
  assertEquals(master.description, "Строка 1\nСтрока 2");
  assertEquals(master.start.toISOString(), "2026-10-06T07:00:00.000Z");
  assertEquals(master.end.toISOString(), "2026-10-06T08:30:00.000Z");
  assertEquals(master.rrule, "FREQ=WEEKLY;BYDAY=TU,TH");
  assertEquals(master.exdates.map((d) => d.toISOString()), ["2026-10-08T07:00:00.000Z"]);
  assertEquals(master.reminderMinutes, 15);
  assertEquals(master.allDay, false);
  assertEquals(override.recurrenceId?.toISOString(), "2026-10-13T07:00:00.000Z");
});

Deno.test("событие на весь день и длительность", () => {
  const [e] = parseCalendar(
    "BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:1\nDTSTART;VALUE=DATE:20261231\nSUMMARY:НГ\nEND:VEVENT\nBEGIN:VEVENT\nUID:2\nDTSTART:20261001T090000Z\nDURATION:PT1H30M\nEND:VEVENT\nEND:VCALENDAR",
  );
  assertEquals(e.allDay, true);
  assertEquals(e.start.toISOString(), "2026-12-31T00:00:00.000Z");
  assertEquals(e.end.toISOString(), "2027-01-01T00:00:00.000Z");
  const [, d] = parseCalendar(
    "BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:1\nDTSTART;VALUE=DATE:20261231\nEND:VEVENT\nBEGIN:VEVENT\nUID:2\nDTSTART:20261001T090000Z\nDURATION:PT1H30M\nEND:VEVENT\nEND:VCALENDAR",
  );
  assertEquals(d.end.toISOString(), "2026-10-01T10:30:00.000Z");
  assertEquals(parseDurationMinutes("-P1D"), -1440);
  assertEquals(parseDurationMinutes("P1W"), 10080);
});

Deno.test("сборка и обратный разбор дают то же событие", () => {
  const [master, override] = parseCalendar(YANDEX_ICS);
  const ics = buildCalendar([override, master]);
  assert(ics.indexOf("RRULE") < ics.indexOf("RECURRENCE-ID"), "основное событие идёт первым");
  const again = parseCalendar(ics);
  assertEquals(again.length, 2);
  assertEquals(again[0].summary, master.summary);
  assertEquals(again[0].start.getTime(), master.start.getTime());
  assertEquals(again[0].exdates[0].getTime(), master.exdates[0].getTime());
  assertEquals(again[0].reminderMinutes, 15);
  assertEquals(again[1].recurrenceId?.getTime(), override.recurrenceId?.getTime());
});

Deno.test("длинные строки переносятся по 75 байт", () => {
  const line = "SUMMARY:" + "Ж".repeat(100);
  const folded = fold(line);
  for (const part of folded.split("\r\n")) assert(new TextEncoder().encode(part).length <= 75);
  assertEquals(folded.replace(/\r\n /g, ""), line);
});

Deno.test("пояса: Москва и переход на летнее время в Берлине", () => {
  assertEquals(zonedToUtc(2026, 1, 15, 12, 0, 0, "Europe/Moscow").toISOString(), "2026-01-15T09:00:00.000Z");
  assertEquals(zonedToUtc(2026, 7, 1, 12, 0, 0, "Europe/Berlin").toISOString(), "2026-07-01T10:00:00.000Z");
  assertEquals(zonedToUtc(2026, 12, 1, 12, 0, 0, "Europe/Berlin").toISOString(), "2026-12-01T11:00:00.000Z");
});
