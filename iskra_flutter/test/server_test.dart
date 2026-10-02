// Проверка клиента на настоящем сервере веб-версии (server/api/index.php).
// Нужен PHP 8 с pdo_sqlite в PATH; без него тест пропускается.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:iskra/core/game.dart';
import 'package:iskra/net/api.dart';
import 'package:iskra/net/cloud_sync.dart';

void main() {
  Process? php;
  late Directory root;
  late Uri base;
  var skip = false;

  setUpAll(() async {
    try {
      final v = await Process.run('php', ['-m']);
      skip = !(v.stdout as String).contains('pdo_sqlite');
    } catch (_) {
      skip = true;
    }
    if (skip) return;
    root = await Directory.systemTemp.createTemp('iskra-server');
    for (final f in ['api/index.php', 'api/config.php']) {
      final dst = File('${root.path}/$f');
      await dst.parent.create(recursive: true);
      await File('server/$f').copy(dst.path);
    }
    final port = 18000 + math.Random().nextInt(1000);
    php = await Process.start('php', ['-S', '127.0.0.1:$port', '-t', root.path]);
    base = Uri.parse('http://127.0.0.1:$port/');
    for (var i = 0; i < 50; i++) {
      try {
        final s = await Socket.connect('127.0.0.1', port);
        s.destroy();
        break;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  tearDownAll(() async {
    php?.kill();
    if (!skip) await root.delete(recursive: true);
  });

  test('регистрация, сохранение, рейтинг и вход с другого устройства', () async {
    if (skip) {
      markTestSkipped('нет PHP с pdo_sqlite');
      return;
    }
    final api = IskraApi(base);
    expect((await api.me()).user, isNull);

    // устройство 1: играет и регистрируется
    final g1 = Game(random: math.Random(7))..newGame();
    g1.s.earned = 1234;
    g1.s.bestCells = 5;
    g1.s.kills['rare'] = 2;
    final sync1 = CloudSync(api, MemoryStore(), () => g1);
    await sync1.init();
    expect(sync1.on, isTrue);
    await sync1.register('искра_тест', 'пароль-123');
    expect(api.session, isNotNull);
    expect(sync1.state, SyncState.ok);

    final top = await api.top('matter');
    expect(top.list.single.login, 'искра_тест');
    expect(top.list.single.value, 1234);
    expect((await api.top('kills')).list.single.value, 6, reason: 'редкая = 3 очка');

    // устройство 2: новая игра, вход — сохранение подтягивается с сервера без вопросов
    final api2 = IskraApi(base);
    final g2 = Game(random: math.Random(8))..newGame();
    final sync2 = CloudSync(api2, MemoryStore(), () => g2);
    String? loaded;
    sync2.loadServerData = (d) => loaded = d;
    await sync2.init();
    await sync2.login('Искра_ТЕСТ', 'пароль-123');
    expect(loaded, isNotNull);
    final st = GameState.fromJson(jsonDecode(loaded!) as Map<String, dynamic>);
    expect(st.earned, 1234);
    expect(g2.attach(st), isTrue);

    // устройство 2 сохраняет новее, устройство 1 получает конфликт и выбирает сервер
    g2.s.earned = 5000;
    await sync2.cloudSave(force: true);
    var asked = false;
    sync1.askConflict = (c) async {
      asked = true;
      expect(c.serverData!['earned'], 5000);
      return true;
    };
    String? fromServer;
    sync1.loadServerData = (d) => fromServer = d;
    g1.s.earned = 1300;
    await sync1.cloudSave();
    expect(asked, isTrue);
    expect(jsonDecode(fromServer!)['earned'], 5000);

    await sync2.logout();
    expect(api2.session, isNull);
    expect((await api2.me()).user, isNull);
  });
}
