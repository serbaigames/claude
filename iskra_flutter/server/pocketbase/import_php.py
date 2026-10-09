#!/usr/bin/env python3
"""Выгрузка учётных записей со старого PHP-сервера «Искры» для переноса в PocketBase.

    python3 import_php.py iskra.sqlite iskra-export.json
    ./pocketbase iskra-import iskra-export.json

iskra.sqlite — база старого сервера (на хостинге она в папке data/ рядом с api/).
Скрипт только читает её и пишет JSON: имена, хеши паролей, даты регистрации, сохранения и рейтинги.
"""
import json
import sqlite3
import sys


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    db = sqlite3.connect(f"file:{src}?mode=ro", uri=True)
    db.row_factory = sqlite3.Row
    saves = {r["user_id"]: r for r in db.execute("SELECT user_id, data, saved, updated FROM saves")}
    stats = {r["user_id"]: r for r in db.execute("SELECT user_id, matter, cells, kills, updated FROM stats")}
    users = []
    for u in db.execute("SELECT id, login, pass, created FROM users ORDER BY id"):
        item = {"login": u["login"], "pass": u["pass"], "created": u["created"]}
        if (s := saves.get(u["id"])) is not None:
            item["save"] = {"data": s["data"], "saved": s["saved"], "updated": s["updated"]}
        if (s := stats.get(u["id"])) is not None:
            item["stats"] = {"matter": s["matter"], "cells": s["cells"], "kills": s["kills"], "updated": s["updated"]}
        users.append(item)
    with open(dst, "w", encoding="utf-8") as f:
        json.dump({"users": users}, f, ensure_ascii=False)
    print(f"Выгружено учётных записей: {len(users)} (с сохранением: {len(saves)}) → {dst}")


if __name__ == "__main__":
    main()
