# Сервер учётных записей и рейтингов «Искры» (PocketBase)

Один сервер на все сборки: Android, iOS, Windows и веб ходят на `https://api.iskraplay.ru/`.
Это [PocketBase](https://pocketbase.io) — одна программа с базой SQLite и панелью управления,
плюс правила «Искры» в `pb_hooks/` и схема базы в `pb_migrations/`. Снаружи перед ним стоит nginx
с сертификатом Let's Encrypt, только TLS 1.2 и HTTP/2: у части операторов в России соединения TLS 1.3
обрываются по пути (рекомендация хостинга AdminVPS).

## Установка на VPS

1. VPS с Ubuntu 22.04/24.04 или Debian 12: хватит 1 ядра и 1 ГБ памяти.
2. В DNS домена iskraplay.ru — A-запись `api` с IP-адресом VPS. Подождите, пока она заработает
   (`ping api.iskraplay.ru` показывает этот IP).
3. На VPS под root:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/serbaigames/claude/claude/project-thread-ioiybu/iskra_flutter/server/pocketbase/install.sh | sudo bash -s -- api.iskraplay.ru
   ```

   Скрипт поставит PocketBase службой `iskra-pb` (слушает 127.0.0.1:8090), nginx и certbot, получит
   сертификат HTTPS, проверит, что сервер отвечает, и попросит почту и пароль для панели управления
   `https://api.iskraplay.ru/_/`. Если сертификат не получен, значит DNS-запись ещё не разошлась:
   подождите и запустите команду снова.

Повторный запуск той же команды обновляет PocketBase и правила, данные остаются.

## Перенос аккаунтов со старого PHP-сервера

Старая база лежит на хостинге в папке `data/` рядом с `api/` — файл `iskra.sqlite`. Скачайте его через
файловый менеджер хостинга и загрузите на VPS (например, `scp iskra.sqlite root@IP:/root/`). Затем на VPS:

```bash
python3 /opt/iskra-pb/import_php.py /root/iskra.sqlite /tmp/iskra-export.json
cd /opt/iskra-pb && sudo -u pocketbase /opt/iskra-pb/pocketbase iskra-import /tmp/iskra-export.json --dir /opt/iskra-pb/pb_data
```

Переносятся имена, пароли (тот же хеш bcrypt, игрокам ничего вводить заново не нужно), даты регистрации,
сохранения и рейтинги. Имена, которые уже заняты на новом сервере, пропускаются и печатаются в выводе.

## Обслуживание

- Журнал: `journalctl -u iskra-pb -f`; перезапуск: `systemctl restart iskra-pb`.
- nginx: `/etc/nginx/sites-available/iskra-api`; сертификат продлевает certbot сам.
- База: `/opt/iskra-pb/pb_data/data.db`. Резервные копии — каждую ночь в 3:00, последние 7, в `pb_data/backups`
  (их же видно и можно скачать в панели: Settings → Backups).
- Игроки, сохранения и рейтинги — в панели управления, коллекции `players`, `saves`, `stats`.

## API

Те же запросы и ответы, что у прежнего `api/index.php`, по адресам `/api/iskra/…`:
`me`, `register`, `login`, `logout`, `save` (GET и POST), `top`, `password`, `delete`.
Вход держится не в cookie, а в токене: сервер отдаёт его в поле `token`, клиент шлёт его в заголовке
`Authorization`. Токен действует 90 дней и продлевается при каждом запуске игры; смена пароля выводит
остальные устройства. Стандартный API PocketBase для коллекций «Искры» закрыт.

Проверка на своём компьютере: `pocketbase serve --hooksDir pb_hooks --migrationsDir pb_migrations`,
затем `flutter run --dart-define=ISKRA_SERVER=http://127.0.0.1:8090/`. Тест `test/server_test.dart`
запускает PocketBase сам, если найдёт его (`ISKRA_POCKETBASE=/путь/к/pocketbase` или `pocketbase` в PATH).
