// Общие функции API «Искры». Обработчики PocketBase выполняются каждый в своём окружении,
// поэтому каждый подключает этот файл сам: const L = require(`${__hooks}/iskra_lib.js`)

const CFG = {
  minPassword: 8,
  maxPasswordBytes: 71, // предел bcrypt: 35 русских букв или 71 латинская
  maxSaveBytes: 2 * 1024 * 1024,
  loginAttempts: 10, // неудачных попыток входа…
  attemptWindow: 15 * 60, // …за столько секунд, потом пауза
  registerPerHour: 5, // новых учётных записей с одного IP в час
};

// Имя: 3–24 символа — буквы любого алфавита, цифры, точка, дефис, подчёркивание.
// В движке JS PocketBase нет \p{L}, поэтому буква — это символ, у которого есть строчная и заглавная форма.
function validLogin(s) {
  const chars = [...s];
  if (chars.length < 3 || chars.length > 24) return false;
  return chars.every((c) => /[0-9_.\-]/.test(c) || c.toLowerCase() !== c.toUpperCase());
}

function now() {
  return Math.floor(Date.now() / 1000);
}

// Размер строки в байтах UTF-8 (так считал и PHP-сервер)
function utf8Bytes(s) {
  let n = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c < 0x80) n += 1;
    else if (c < 0x800) n += 2;
    else if (c >= 0xd800 && c < 0xdc00) {
      n += 4; // суррогатная пара — один символ из 4 байт
      i++;
    } else n += 3;
  }
  return n;
}

function fail(e, code, msg, extra) {
  return e.json(code, Object.assign({ error: msg }, extra || {}));
}

function body(e) {
  const b = e.requestInfo().body;
  return b && typeof b === "object" ? b : {};
}

// Игрок по токену из заголовка Authorization (PocketBase проверяет подпись и срок сам)
function player(e) {
  const a = e.auth;
  return a && a.collection().name === "players" ? a : null;
}

function userOut(p) {
  return { login: p.getString("login"), created: p.getInt("since") };
}

function clientKey(e) {
  return $security.sha256("ip:" + e.realIP());
}

function tooMany(k, limit, window) {
  const r = new DynamicModel({ n: 0 });
  $app.db().newQuery("SELECT COUNT(*) AS n FROM attempts WHERE k = {:k} AND t > {:t}").bind({ k, t: now() - window }).one(r);
  return r.n >= limit;
}

function noteAttempt(k) {
  const rec = new Record($app.findCollectionByNameOrId("attempts"));
  rec.set("k", k);
  rec.set("t", now());
  $app.save(rec);
}

function findSave(p) {
  try {
    return $app.findFirstRecordByData("saves", "player", p.id);
  } catch (_) {
    return null;
  }
}

function saveMeta(p) {
  const s = findSave(p);
  return s ? { saved: s.getInt("saved"), updated: s.getInt("updated") } : null;
}

// Очки за сущности: низшая 1, редкая 3, эпическая 10, легендарная 500
function killPoints(k) {
  if (!k || typeof k !== "object") return 0;
  const w = { low: 1, rare: 3, epic: 10, legend: 500 };
  let p = 0;
  for (const t in w) p += Math.max(0, Math.trunc(Number(k[t]) || 0)) * w[t];
  return p;
}

// Рейтинг хранит максимум: показатели не уменьшаются, даже если игрок загрузил старое сохранение
function updateStats(p, d) {
  const matter = Math.max(0, Number(d.earned) || 0);
  const cells = Math.max(0, Math.trunc(Number(d.bestCells) || 0));
  const kills = killPoints(d.kills);
  let s;
  try {
    s = $app.findFirstRecordByData("stats", "player", p.id);
  } catch (_) {
    s = new Record($app.findCollectionByNameOrId("stats"));
    s.set("player", p.id);
  }
  s.set("matter", Math.max(s.getFloat("matter"), matter));
  s.set("cells", Math.max(s.getInt("cells"), cells));
  s.set("kills", Math.max(s.getInt("kills"), kills));
  s.set("updated", now());
  $app.save(s);
}

function authOut(p, extra) {
  return Object.assign({ ok: true, token: p.newAuthToken(), user: userOut(p) }, extra || {});
}

module.exports = { CFG, utf8Bytes, validLogin, now, fail, body, player, userOut, clientKey, tooMany, noteAttempt, findSave, saveMeta, updateStats, authOut };
