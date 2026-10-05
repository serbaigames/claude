// Перевод «настенного» времени в часовом поясе IANA в UTC без внешних библиотек.

const formatters = new Map<string, Intl.DateTimeFormat>();

function formatter(tz: string): Intl.DateTimeFormat {
  let f = formatters.get(tz);
  if (!f) {
    f = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
    formatters.set(tz, f);
  }
  return f;
}

export function isValidTimeZone(tz: string): boolean {
  try {
    formatter(tz);
    return true;
  } catch {
    return false;
  }
}

/** Смещение пояса tz относительно UTC в момент utcMs, в миллисекундах. */
export function tzOffsetMs(utcMs: number, tz: string): number {
  const parts: Record<string, number> = {};
  for (const p of formatter(tz).formatToParts(new Date(utcMs))) {
    if (p.type !== "literal") parts[p.type] = Number(p.value);
  }
  const asUtc = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second);
  return asUtc - Math.floor(utcMs / 1000) * 1000;
}

export function zonedToUtc(
  y: number,
  mo: number,
  d: number,
  h: number,
  mi: number,
  s: number,
  tz: string,
): Date {
  const wall = Date.UTC(y, mo - 1, d, h, mi, s);
  if (!isValidTimeZone(tz)) return new Date(wall);
  // Две итерации покрывают переходы на летнее время.
  let guess = wall - tzOffsetMs(wall, tz);
  guess = wall - tzOffsetMs(guess, tz);
  return new Date(guess);
}
