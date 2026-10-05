// «Искра» — мир шестигранников. Flutter-версия браузерной игры.
//
// Сервер учётных записей и рейтингов — PocketBase с правилами из server/pocketbase, один на все платформы.
// Адрес по умолчанию — https://api.iskraplay.ru/, другой задаётся при сборке (пустой — без сервера):
//   flutter run --dart-define=ISKRA_SERVER=http://127.0.0.1:8090/
// Магазин (Android): --dart-define=ISKRA_AD_UNIT=R-M-… — блок видео за награду Яндекса;
// ISKRA_UNLOCK_ALL=true открывает все стили (для проверки).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shop/rustore_billing.dart';
import 'shop/shop.dart';
import 'shop/yandex_ads.dart';
import 'ui/controller.dart';
import 'ui/gfx.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';
import 'l10n/l10n.dart';

const _server = String.fromEnvironment('ISKRA_SERVER', defaultValue: 'https://api.iskraplay.ru/');

Uri? serverUri() => _server.isEmpty ? null : Uri.parse(_server.endsWith('/') ? _server : '$_server/');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final prefs = await SharedPreferences.getInstance();
  // покупки (RuStore) и видео за награду (Яндекс) — только в сборке для Android
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final shop = Shop(
    prefs,
    billing: android ? RuStoreBilling() : null,
    ads: android && adUnitId.isNotEmpty ? YandexRewardedAds() : null,
    unlockAll: const bool.fromEnvironment('ISKRA_UNLOCK_ALL'),
  );
  unawaited(shop.init());
  runApp(
    IskraApp(
      controller: GameController(prefs, server: serverUri(), shop: shop),
    ),
  );
}

class IskraApp extends StatelessWidget {
  const IskraApp({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (_) => tx('Искра'),
    debugShowCheckedModeBanner: false,
    theme: iskraTheme(),
    // первое касание разрешает звук (браузеры не дают играть его раньше)
    builder: (context, child) => Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => controller.sound.unlock(),
      // масштаб интерфейса: ×1 или авто по размеру экрана
      child: ValueListenableBuilder<bool>(
        valueListenable: controller.uiAuto,
        builder: (context, auto, _) => UiScale(auto: auto, child: child!),
      ),
    ),
    home: HomeScreen(ctl: controller),
  );
}
