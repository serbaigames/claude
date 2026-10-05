#!/usr/bin/env bash
# Собирает сайт iskraplay.ru в каталог $1: лендинг в корне, игра в /play/.
# Перед запуском нужна сборка: flutter build web --release --no-web-resources-cdn --base-href /play/
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:?каталог назначения}"
rm -rf "$out"
mkdir -p "$out/play" "$out/fonts"
cp -r build/web/. "$out/play/"
cp landing/index.html landing/landing.css landing/landing.js landing/spark.js landing/donate-qr.png "$out/"
cp assets/fonts/*.ttf "$out/fonts/"
# Раньше игра жила в корне: браузеры с её service worker получат этот, и он сам себя удалит
cp build/web/flutter_service_worker.js "$out/"
python3 tool/landing_data.py "$out/releases.json"
cp server/site.htaccess "$out/.htaccess"
