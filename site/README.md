# Сайт ASB studio

Сайт игровой студии на **Flutter web**.

- Главная (`lib/pages/home_page.dart`): идея студии, карта миров и реализованные проекты (пока «Искра», iskraplay.ru).
- Поддержка (`lib/pages/support_page.dart`, адрес `/#/support`): предложение поддержать разработчика.
- `lib/config.dart`: ссылки на донат, подписку и номер карты. Сейчас там заглушки, впишите свои.

## Запуск

```bash
flutter pub get
flutter run -d chrome
```

## Сборка для публикации

```bash
flutter build web --release --no-web-resources-cdn
```

Готовый сайт появится в `build/web`: загрузите содержимое папки на любой статический хостинг.
Флаг `--no-web-resources-cdn` кладёт движок CanvasKit рядом с сайтом, а шрифт Inter (с кириллицей)
уже лежит в `assets/fonts`, так что сайт не зависит от CDN Google.
