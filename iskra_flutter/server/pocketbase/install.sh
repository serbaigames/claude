#!/usr/bin/env bash
# Установка (и обновление) сервера учётных записей и рейтингов «Искры» на VPS с Ubuntu или Debian.
#
#   curl -fsSL https://raw.githubusercontent.com/serbaigames/claude/claude/project-thread-ioiybu/iskra_flutter/server/pocketbase/install.sh | sudo bash -s -- api.iskraplay.ru
#
# Что делает:
#   - ставит PocketBase в /opt/iskra-pb и запускает его службой systemd «iskra-pb» от отдельного пользователя;
#   - кладёт рядом правила «Искры» (pb_hooks, pb_migrations) из репозитория;
#   - PocketBase сам получает сертификат Let's Encrypt для домена и слушает порты 80 и 443;
#   - база и резервные копии (каждую ночь, последние 7) — в /opt/iskra-pb/pb_data.
# Повторный запуск обновляет PocketBase и правила, данные не трогает.
# Перед запуском у домена должна быть A-запись с IP этого сервера.
set -euo pipefail

DOMAIN="${1:-api.iskraplay.ru}"
PB_VERSION="${PB_VERSION:-0.40.4}"
REF="${ISKRA_REF:-claude/project-thread-ioiybu}"
RAW="https://raw.githubusercontent.com/serbaigames/claude/${REF}/iskra_flutter/server/pocketbase"
DIR=/opt/iskra-pb

[ "$(id -u)" = 0 ] || { echo "Запустите от root (sudo)."; exit 1; }

case "$(uname -m)" in
  x86_64) ARCH=amd64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *) echo "Неизвестная архитектура $(uname -m)"; exit 1 ;;
esac

echo "== Пакеты"
apt-get update -qq
apt-get install -y -qq curl unzip ca-certificates python3 >/dev/null

echo "== Пользователь и папки"
id pocketbase >/dev/null 2>&1 || useradd --system --home-dir "$DIR" --shell /usr/sbin/nologin pocketbase
mkdir -p "$DIR/pb_data" "$DIR/pb_hooks" "$DIR/pb_migrations"

echo "== PocketBase $PB_VERSION"
tmp="$(mktemp -d)"
curl -fsSL -o "$tmp/pb.zip" "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_${ARCH}.zip"
unzip -qo "$tmp/pb.zip" pocketbase -d "$tmp"
install -m 755 "$tmp/pocketbase" "$DIR/pocketbase"
rm -rf "$tmp"

echo "== Правила «Искры» из ветки $REF"
curl -fsSL -o "$DIR/pb_hooks/iskra.pb.js" "$RAW/pb_hooks/iskra.pb.js"
curl -fsSL -o "$DIR/pb_hooks/iskra_lib.js" "$RAW/pb_hooks/iskra_lib.js"
curl -fsSL -o "$DIR/pb_migrations/1700000000_iskra.js" "$RAW/pb_migrations/1700000000_iskra.js"
curl -fsSL -o "$DIR/import_php.py" "$RAW/import_php.py"
chown -R pocketbase:pocketbase "$DIR"

echo "== Служба iskra-pb для $DOMAIN"
cat >/etc/systemd/system/iskra-pb.service <<EOF
[Unit]
Description=Iskra accounts and leaderboards (PocketBase)
After=network-online.target
Wants=network-online.target

[Service]
User=pocketbase
Group=pocketbase
WorkingDirectory=$DIR
ExecStart=$DIR/pocketbase serve $DOMAIN --dir $DIR/pb_data --hooksDir $DIR/pb_hooks --migrationsDir $DIR/pb_migrations
AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=always
RestartSec=5
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable iskra-pb >/dev/null 2>&1
systemctl restart iskra-pb

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 80/tcp >/dev/null
  ufw allow 443/tcp >/dev/null
fi

echo "== Проверка"
ok=""
for _ in $(seq 1 30); do
  if curl -fsS "https://$DOMAIN/api/iskra/me" >/dev/null 2>&1; then ok=1; break; fi
  sleep 2
done
if [ -n "$ok" ]; then
  echo "Сервер отвечает: https://$DOMAIN/api/iskra/me"
else
  echo "Сервер пока не отвечает по https://$DOMAIN — проверьте DNS-запись домена и журнал: journalctl -u iskra-pb -n 50"
fi

# Учётная запись администратора для панели https://$DOMAIN/_/
if [ ! -f "$DIR/.superuser" ] && [ -r /dev/tty ]; then
  echo
  echo "Создадим вход в панель управления https://$DOMAIN/_/"
  read -r -p "Почта администратора: " SU_EMAIL </dev/tty
  read -r -s -p "Пароль (не короче 10 символов): " SU_PASS </dev/tty
  echo
  if sudo -u pocketbase "$DIR/pocketbase" superuser upsert "$SU_EMAIL" "$SU_PASS" --dir "$DIR/pb_data"; then
    touch "$DIR/.superuser"
  fi
fi

echo
echo "Готово. Перенос аккаунтов со старого сервера:"
echo "  python3 $DIR/import_php.py iskra.sqlite /tmp/iskra-export.json"
echo "  sudo -u pocketbase $DIR/pocketbase iskra-import /tmp/iskra-export.json --dir $DIR/pb_data --hooksDir $DIR/pb_hooks --migrationsDir $DIR/pb_migrations"
