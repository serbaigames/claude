/// <reference path="../pb_data/types.d.ts" />
// «Искра» — API учётных записей, сохранений и рейтингов поверх PocketBase.
// Те же запросы и ответы, что у прежнего api/index.php, только вход держится не в cookie,
// а в токене: сервер отдаёт его в поле token, клиент шлёт его в заголовке Authorization.
//
//   GET  /api/iskra/me        кто вошёл и метка его сохранения (+ свежий токен)
//   POST /api/iskra/register  {login, password}
//   POST /api/iskra/login     {login, password}
//   POST /api/iskra/logout
//   GET  /api/iskra/save      сохранение целиком
//   POST /api/iskra/save      {data, saved, base, force} — 409, если на сервере новее с другого устройства
//   GET  /api/iskra/top?by=matter|cells|kills&limit=1..100
//   POST /api/iskra/password  {old, new}
//   POST /api/iskra/delete    {password}

routerAdd("GET", "/api/iskra/me", (e) => {
  const L = require(`${__hooks}/iskra_lib.js`);
  const p = L.player(e);
  if (!p) return e.json(200, { ok: true, user: null, save: null });
  return e.json(200, L.authOut(p, { save: L.saveMeta(p) }));
});

routerAdd("POST", "/api/iskra/register", (e) => {
  const L = require(`${__hooks}/iskra_lib.js`);
  const b = L.body(e);
  const login = String(b.login ?? "").trim();
  const pass = String(b.password ?? "");
  if (!L.validLogin(login))
    return L.fail(e, 422, "Имя: от 3 до 24 символов — буквы, цифры, точка, дефис или подчёркивание.", { field: "login" });
  if ([...pass].length < L.CFG.minPassword)
    return L.fail(e, 422, `Пароль должен быть не короче ${L.CFG.minPassword} символов.`, { field: "password" });
  if (L.utf8Bytes(pass) > L.CFG.maxPasswordBytes) return L.fail(e, 422, "Пароль слишком длинный.", { field: "password" });
  const rk = "reg:" + L.clientKey(e);
  if (L.tooMany(rk, L.CFG.registerPerHour, 3600)) return L.fail(e, 429, "Слишком много регистраций с этого адреса. Попробуйте через час.");
  const lkey = login.toLowerCase();
  try {
    $app.findFirstRecordByData("players", "lkey", lkey);
    return L.fail(e, 409, "Это имя уже занято.", { field: "login" });
  } catch (_) {}
  const p = new Record($app.findCollectionByNameOrId("players"));
  p.set("login", login);
  p.set("lkey", lkey);
  p.set("since", L.now());
  p.setPassword(pass);
  try {
    $app.save(p);
  } catch (err) {
    // одновременная регистрация того же имени упрётся в уникальный индекс
    return L.fail(e, 409, "Это имя уже занято.", { field: "login" });
  }
  L.noteAttempt(rk);
  return e.json(200, L.authOut(p, { save: null }));
});

routerAdd("POST", "/api/iskra/login", (e) => {
  const L = require(`${__hooks}/iskra_lib.js`);
  const b = L.body(e);
  const login = String(b.login ?? "").trim();
  const pass = String(b.password ?? "");
  const k1 = "login:" + L.clientKey(e);
  const k2 = "user:" + $security.sha256(login.toLowerCase());
  if (L.tooMany(k1, L.CFG.loginAttempts, L.CFG.attemptWindow) || L.tooMany(k2, L.CFG.loginAttempts, L.CFG.attemptWindow))
    return L.fail(e, 429, "Слишком много неудачных попыток. Подождите 15 минут.");
  let p = null;
  try {
    p = $app.findFirstRecordByData("players", "lkey", login.toLowerCase());
  } catch (_) {}
  if (!p || !p.validatePassword(pass)) {
    L.noteAttempt(k1);
    L.noteAttempt(k2);
    return L.fail(e, 401, "Неверное имя или пароль.");
  }
  return e.json(200, L.authOut(p, { save: L.saveMeta(p) }));
});

// Токен не хранится на сервере: выход — это забыть его на устройстве
routerAdd("POST", "/api/iskra/logout", (e) => e.json(200, { ok: true }));

routerAdd("GET", "/api/iskra/save", (e) => {
  const L = require(`${__hooks}/iskra_lib.js`);
  const p = L.player(e);
  if (!p) return L.fail(e, 401, "Войдите в учётную запись.");
  const s = L.findSave(p);
  return e.json(200, {
    ok: true,
    save: s ? { data: s.getString("data"), saved: s.getInt("saved"), updated: s.getInt("updated") } : null,
  });
});

routerAdd("POST", "/api/iskra/save", (e) => {
  const L = require(`${__hooks}/iskra_lib.js`);
  const p = L.player(e);
  if (!p) return L.fail(e, 401, "Войдите в учётную запись.");
  const b = L.body(e);
  const data = b.data;
  if (typeof data !== "string" || data === "") return L.fail(e, 422, "Нет данных для сохранения.");
  if (L.utf8Bytes(data) > L.CFG.maxSaveBytes) return L.fail(e, 413, "Сохранение слишком большое.");
  let parsed;
  try {
    parsed = JSON.parse(data);
  } catch (_) {}
  const cellsOk = parsed && typeof parsed === "object" && parsed.cells && typeof parsed.cells === "object";
  if (!cellsOk || typeof parsed.matter !== "number" || !isFinite(parsed.matter)) return L.fail(e, 422, "Повреждённое сохранение.");
  const hasSpark = Object.values(parsed.cells).some((c) => c && typeof c === "object" && !!c.spark);
  if (!hasSpark) return L.fail(e, 422, "Повреждённое сохранение.");
  const saved = Math.trunc(Number(b.saved) || 0);
  const base = b.base === null || b.base === undefined ? null : Math.trunc(Number(b.base) || 0);
  let s = L.findSave(p);
  // Если с момента последней синхронизации сервер получил сохранение с другого устройства — не затираем молча
  if (s && !b.force && base !== null && s.getInt("updated") > base)
    return L.fail(e, 409, "На сервере есть более новое сохранение с другого устройства.", {
      save: { saved: s.getInt("saved"), updated: s.getInt("updated") },
    });
  if (!s) {
    s = new Record($app.findCollectionByNameOrId("saves"));
    s.set("player", p.id);
  }
  const updated = Date.now();
  s.set("data", data);
  s.set("saved", saved);
  s.set("updated", updated);
  $app.save(s);
  L.updateStats(p, parsed);
  return e.json(200, { ok: true, save: { saved, updated } });
});

routerAdd("GET", "/api/iskra/top", (e) => {
  const L = require(`${__hooks}/iskra_lib.js`);
  const q = e.requestInfo().query;
  const by = q.by || "matter";
  if (!["matter", "cells", "kills"].includes(by)) return L.fail(e, 422, "Неизвестный рейтинг.");
  // limit: сколько мест отдать (по умолчанию 10, как ждёт веб-версия; приложение просит 100)
  const limit = Math.max(1, Math.min(100, Math.trunc(Number(q.limit)) || 10));
  const rows = arrayOf(new DynamicModel({ login: "", v: 0.0 }));
  $app
    .db()
    .newQuery(
      `SELECT p.login AS login, s.${by} AS v FROM stats s JOIN players p ON p.id = s.player
       WHERE s.${by} > 0 ORDER BY s.${by} DESC, s.updated ASC LIMIT ${limit}`,
    )
    .all(rows);
  const total = new DynamicModel({ n: 0 });
  $app.db().newQuery(`SELECT COUNT(*) AS n FROM stats WHERE ${by} > 0`).one(total);
  let me = null;
  const p = L.player(e);
  if (p) {
    try {
      const st = $app.findFirstRecordByData("stats", "player", p.id);
      const v = st.getFloat(by);
      if (v > 0) {
        const above = new DynamicModel({ n: 0 });
        $app.db().newQuery(`SELECT COUNT(*) AS n FROM stats WHERE ${by} > {:v}`).bind({ v }).one(above);
        me = { login: p.getString("login"), value: v, rank: above.n + 1 };
      }
    } catch (_) {}
  }
  return e.json(200, { ok: true, by, list: rows.map((r) => ({ login: r.login, value: r.v })), me, total: total.n });
});

routerAdd("POST", "/api/iskra/password", (e) => {
  const L = require(`${__hooks}/iskra_lib.js`);
  const p = L.player(e);
  if (!p) return L.fail(e, 401, "Войдите в учётную запись.");
  const b = L.body(e);
  if (!p.validatePassword(String(b.old ?? ""))) return L.fail(e, 401, "Текущий пароль указан неверно.", { field: "old" });
  const pass = String(b.new ?? "");
  if ([...pass].length < L.CFG.minPassword)
    return L.fail(e, 422, `Новый пароль должен быть не короче ${L.CFG.minPassword} символов.`, { field: "new" });
  if (L.utf8Bytes(pass) > L.CFG.maxPasswordBytes) return L.fail(e, 422, "Пароль слишком длинный.", { field: "new" });
  p.setPassword(pass);
  // новый ключ токенов: остальные устройства выйдут, это получит свежий токен
  p.refreshTokenKey();
  $app.save(p);
  return e.json(200, L.authOut(p));
});

routerAdd("POST", "/api/iskra/delete", (e) => {
  const L = require(`${__hooks}/iskra_lib.js`);
  const p = L.player(e);
  if (!p) return L.fail(e, 401, "Войдите в учётную запись.");
  const b = L.body(e);
  if (!p.validatePassword(String(b.password ?? ""))) return L.fail(e, 401, "Пароль указан неверно.", { field: "password" });
  $app.delete(p); // сохранение и рейтинг удалятся каскадно
  return e.json(200, { ok: true });
});

// Уборка старых попыток входа
cronAdd("iskra-attempts-cleanup", "17 * * * *", () => {
  $app.db().newQuery("DELETE FROM attempts WHERE t < {:t}").bind({ t: Math.floor(Date.now() / 1000) - 86400 }).execute();
});

// Перенос учётных записей со старого PHP-сервера: ./pocketbase iskra-import iskra-export.json
// (файл готовит import_php.py из базы iskra.sqlite). Пароли переносятся как есть — тем же хешем bcrypt.
$app.rootCmd.addCommand(
  new Command({
    use: "iskra-import [file.json]",
    short: "Перенести учётные записи, сохранения и рейтинги со старого PHP-сервера",
    run: (cmd, args) => {
      if (args.length !== 1) throw new Error("Укажите файл: iskra-import iskra-export.json");
      const src = JSON.parse(toString($os.readFile(args[0])));
      const players = $app.findCollectionByNameOrId("players");
      const savesCol = $app.findCollectionByNameOrId("saves");
      const statsCol = $app.findCollectionByNameOrId("stats");
      let added = 0;
      let skipped = 0;
      $app.runInTransaction((tx) => {
        for (const u of src.users) {
          const lkey = String(u.login).toLowerCase();
          try {
            tx.findFirstRecordByData("players", "lkey", lkey);
            skipped++;
            console.log(`пропущен: ${u.login} — такое имя уже есть`);
            continue;
          } catch (_) {}
          const p = new Record(players);
          p.set("login", u.login);
          p.set("lkey", lkey);
          p.set("since", u.created);
          p.setRandomPassword();
          tx.save(p);
          // хеш пароля PHP (bcrypt) кладём напрямую, чтобы старый пароль подошёл
          tx.db().newQuery("UPDATE players SET password = {:h} WHERE id = {:id}").bind({ h: u.pass, id: p.id }).execute();
          if (u.save) {
            const s = new Record(savesCol);
            s.set("player", p.id);
            s.set("data", u.save.data);
            s.set("saved", u.save.saved);
            s.set("updated", u.save.updated);
            tx.save(s);
          }
          if (u.stats) {
            const st = new Record(statsCol);
            st.set("player", p.id);
            st.set("matter", u.stats.matter);
            st.set("cells", u.stats.cells);
            st.set("kills", u.stats.kills);
            st.set("updated", u.stats.updated);
            tx.save(st);
          }
          added++;
        }
      });
      console.log(`Перенесено учётных записей: ${added}, пропущено: ${skipped}`);
    },
  }),
);
