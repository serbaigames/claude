// «Искра» — мир шестигранников. Flutter-версия браузерной игры.
//
// Сервер учётных записей и рейтингов — PocketBase с правилами из server/pocketbase, один на все платформы.
// Адрес по умолчанию — https://api.iskraplay.ru/, другой задаётся при сборке (пустой — без сервера):
//   flutter run --dart-define=ISKRA_SERVER=http://127.0.0.1:8090/
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/controller.dart';
import 'ui/gfx.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

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
  runApp(IskraApp(controller: GameController(prefs, server: serverUri())));
}

class IskraApp extends StatelessWidget {
  const IskraApp({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Искра',
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
