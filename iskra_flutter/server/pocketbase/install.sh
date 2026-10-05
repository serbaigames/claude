#!/usr/bin/env bash
# Установка (и обновление) сервера учётных записей и рейтингов «Искры» на VPS с Ubuntu или Debian.
#
#   curl -fsSL https://raw.githubusercontent.com/serbaigames/claude/claude/project-thread-ioiybu/iskra_flutter/server/pocketbase/install.sh | sudo bash -s -- api.iskraplay.ru
#
# Что делает:
#   - ставит PocketBase в /opt/iskra-pb и запускает его службой systemd «iskra-pb» от отдельного пользователя,
#     он слушает только 127.0.0.1:8090;
#   - кладёт рядом правила «Искры» (pb_hooks, pb_migrations) из репозитория;
#   - снаружи стоит nginx с сертификатом Let's Encrypt (certbot). В нём только TLS 1.2 и HTTP/2:
#     у части операторов в России соединения TLS 1.3 рвутся по пути (рекомендация хостинга AdminVPS);
#   - база и резервные копии (каждую ночь, последние 7) — в /opt/iskra-pb/pb_data.
# Повторный запуск обновляет PocketBase и правила, данные не трогает.
# Перед запуском у домена должна быть A-запись с IP этого сервера.
set -euo pipefail

DOMAIN="${1:-api.iskraplay.ru}"
PB_VERSION="${PB_VERSION:-0.40.4}"
REF="${ISKRA_REF:-claude/project-thread-ioiybu}"
RAW="https://raw.githubusercontent.com/serbaigames/claude/${REF}/iskra_flutter/server/pocketbase"
DIR=/opt/iskra-pb
PB_ADDR=127.0.0.1:8090

[ "$(id -u)" = 0 ] || { echo "Запустите от root (sudo)."; exit 1; }

case "$(uname -m)" in
  x86_64) ARCH=amd64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *) echo "Неизвестная архитектура $(uname -m)"; exit 1 ;;
esac

echo "== Пакеты"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl unzip ca-certificates python3 nginx certbot >/dev/null

echo "== Пользователь и папки"
id pocketbase >/dev/null 2>&1 || useradd --system --home-dir "$DIR" --shell /usr/sbin/nologin pocketbase
mkdir -p "$DIR/pb_data" "$DIR/pb_hooks" "$DIR/pb_migrations" /var/www/letsencrypt

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

echo "== Служба iskra-pb"
cat >/etc/systemd/system/iskra-pb.service <<EOF
[Unit]
Description=Iskra accounts and leaderboards (PocketBase)
After=network-online.target
Wants=network-online.target

[Service]
User=pocketbase
Group=pocketbase
WorkingDirectory=$DIR
ExecStart=$DIR/pocketbase serve --http $PB_ADDR --dir $DIR/pb_data --hooksDir $DIR/pb_hooks --migrationsDir $DIR/pb_migrations
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

# Общая часть: проксирование в PocketBase
PROXY="
    client_max_body_size 8m;
    location / {
        proxy_pass http://$PB_ADDR;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Connection '';
        proxy_buffering off;
        proxy_read_timeout 360s;
    }"
SITE=/etc/nginx/sites-available/iskra-api
CERT="/etc/letsencrypt/live/$DOMAIN"
rm -f /etc/nginx/sites-enabled/default

write_http_only() {
  cat >"$SITE" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    location /.well-known/acme-challenge/ { root /var/www/letsencrypt; }
$PROXY
}
EOF
}

write_https() {
  cat >"$SITE" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    location /.well-known/acme-challenge/ { root /var/www/letsencrypt; }
    location / { return 301 https://\$host\$request_uri; }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate     $CERT/fullchain.pem;
    ssl_certificate_key $CERT/privkey.pem;
    # Только TLS 1.2: соединения TLS 1.3 в части сетей РФ обрываются по пути
    ssl_protocols TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_session_cache shared:iskra:10m;
$PROXY
}
EOF
}

echo "== nginx и сертификат для $DOMAIN"
if [ ! -f "$CERT/fullchain.pem" ]; then
  write_http_only
  ln -sf "$SITE" /etc/nginx/sites-enabled/iskra-api
  nginx -t -q && systemctl reload nginx
  if ! certbot certonly --webroot -w /var/www/letsencrypt -d "$DOMAIN" \
      --non-interactive --agree-tos --register-unsafely-without-email --quiet; then
    echo
    echo "Не удалось получить сертификат. Проверьте, что A-запись $DOMAIN указывает на IP этого сервера"
    echo "(https://dnschecker.org), подождите и запустите скрипт ещё раз. Пока сервер работает по http."
    exit 1
  fi
fi
write_https
ln -sf "$SITE" /etc/nginx/sites-enabled/iskra-api
nginx -t -q
systemctl reload nginx
# после продления сертификата nginx перечитывает его сам
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
printf '#!/bin/sh\nsystemctl reload nginx\n' >/etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

echo "== Проверка"
ok=""
for _ in $(seq 1 15); do
  if curl -fsS "https://$DOMAIN/api/iskra/me" >/dev/null 2>&1; then ok=1; break; fi
  sleep 2
done
if [ -n "$ok" ]; then
  echo "Сервер отвечает: https://$DOMAIN/api/iskra/me"
else
  echo "Сервер пока не отвечает по https://$DOMAIN — журнал: journalctl -u iskra-pb -n 50; nginx: /var/log/nginx/error.log"
fi

# Учётная запись администратора для панели https://$DOMAIN/_/
if [ ! -f "$DIR/.superuser" ] && [ -r /dev/tty ]; then
  echo
  echo "Создадим вход в панель управления https://$DOMAIN/_/"
  read -r -p "Почта администратора: " SU_EMAIL </dev/tty
  read -r -s -p "Пароль (не короче 10 символов): " SU_PASS </dev/tty
  echo
  # из /root пользователь pocketbase не может прочитать текущую папку — запускаем из своей
  if (cd "$DIR" && runuser -u pocketbase -- "$DIR/pocketbase" superuser upsert "$SU_EMAIL" "$SU_PASS" --dir "$DIR/pb_data"); then
    touch "$DIR/.superuser"
  fi
fi

echo
echo "Готово. Перенос аккаунтов со старого сервера:"
echo "  python3 $DIR/import_php.py iskra.sqlite /tmp/iskra-export.json"
echo "  cd $DIR && sudo -u pocketbase $DIR/pocketbase iskra-import /tmp/iskra-export.json --dir $DIR/pb_data"
