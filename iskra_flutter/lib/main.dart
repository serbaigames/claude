// «Искра» — мир шестигранников. Flutter-версия браузерной игры.
//
// Сервер учётных записей — тот же PHP из веб-версии (папка server/). Адрес задаётся при сборке:
//   flutter run --dart-define=ISKRA_SERVER=https://example.com/iskra/
// В веб-сборке, выложенной рядом с папкой api/, адрес не нужен: берётся адрес страницы.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/controller.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

const _server = String.fromEnvironment('ISKRA_SERVER');

Uri? serverUri() {
  if (_server.isNotEmpty) return Uri.parse(_server.endsWith('/') ? _server : '$_server/');
  if (kIsWeb && (Uri.base.scheme == 'https' || Uri.base.scheme == 'http')) {
    return Uri.parse(Uri.base.toString().split('#').first.split('?').first);
  }
  return null;
}

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
    builder: (context, child) =>
        Listener(behavior: HitTestBehavior.translucent, onPointerDown: (_) => controller.sound.unlock(), child: child),
    home: HomeScreen(ctl: controller),
  );
}
