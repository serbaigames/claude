/// <reference path="../pb_data/types.d.ts" />
// «Искра» — схема базы: игроки, сохранения, рейтинги и счётчик попыток входа.
// Все коллекции закрыты для стандартного API PocketBase (правила null): игра ходит только в /api/iskra/*,
// а смотреть и править данные можно в админке (/_/) под суперпользователем.
migrate((app) => {
  const players = new Collection({
    type: "auth",
    name: "players",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      { name: "login", type: "text", required: true, min: 3, max: 24 },
      // имя в нижнем регистре — по нему ищем при входе, «Искра» и «искра» считаются одним именем
      { name: "lkey", type: "text", required: true, min: 3, max: 24 },
      // дата регистрации в секундах; у перенесённых со старого сервера — исходная
      { name: "since", type: "number", onlyInt: true },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_players_lkey ON players (lkey)"],
    // вход только через /api/iskra/login: там свой счётчик неудачных попыток
    passwordAuth: { enabled: false, identityFields: ["email"] },
    authToken: { duration: 90 * 86400 },
  });
  app.save(players);
  // системные поля появляются при первом сохранении; почта не нужна: учётная запись — это имя и пароль
  players.fields.getByName("email").required = false;
  players.fields.getByName("password").min = 8;
  players.fields.getByName("password").max = 71; // предел bcrypt — 72 байта
  app.save(players);

  const saves = new Collection({
    type: "base",
    name: "saves",
    fields: [
      { name: "player", type: "relation", required: true, collectionId: players.id, cascadeDelete: true, maxSelect: 1 },
      { name: "data", type: "text", required: true, max: 2 * 1024 * 1024 },
      { name: "saved", type: "number", onlyInt: true },
      { name: "updated", type: "number", onlyInt: true },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_saves_player ON saves (player)"],
  });
  app.save(saves);

  // Рейтинги: лучшие показатели игрока за всё время, пересчитываются при каждом сохранении
  const stats = new Collection({
    type: "base",
    name: "stats",
    fields: [
      { name: "player", type: "relation", required: true, collectionId: players.id, cascadeDelete: true, maxSelect: 1 },
      { name: "matter", type: "number" },
      { name: "cells", type: "number", onlyInt: true },
      { name: "kills", type: "number", onlyInt: true },
      { name: "updated", type: "number", onlyInt: true },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_stats_player ON stats (player)",
      "CREATE INDEX idx_stats_matter ON stats (matter DESC)",
      "CREATE INDEX idx_stats_cells ON stats (cells DESC)",
      "CREATE INDEX idx_stats_kills ON stats (kills DESC)",
    ],
  });
  app.save(stats);

  const attempts = new Collection({
    type: "base",
    name: "attempts",
    fields: [
      { name: "k", type: "text", required: true },
      { name: "t", type: "number", onlyInt: true },
    ],
    indexes: ["CREATE INDEX idx_attempts_k ON attempts (k, t)"],
  });
  app.save(attempts);

  // Резервная копия базы каждую ночь, хранятся последние 7 (pb_data/backups)
  const settings = app.settings();
  settings.meta.appName = "Искра";
  settings.backups.cron = "0 3 * * *";
  settings.backups.cronMaxKeep = 7;
  app.save(settings);
}, (app) => {
  for (const name of ["attempts", "stats", "saves", "players"]) {
    try {
      app.delete(app.findCollectionByNameOrId(name));
    } catch (_) {}
  }
});
