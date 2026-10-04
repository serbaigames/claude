// Проверка клиента на настоящем сервере: PocketBase с правилами из server/pocketbase.
// Нужен исполняемый файл PocketBase: переменная ISKRA_POCKETBASE или pocketbase в PATH; без него тест пропускается.
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
  Process? pb;
  late Directory root;
  late Uri base;
  var skip = false;

  setUpAll(() async {
    final bin = Platform.environment['ISKRA_POCKETBASE'] ?? 'pocketbase';
    try {
      await Process.run(bin, ['--version']);
    } catch (_) {
      skip = true;
      return;
    }
    root = await Directory.systemTemp.createTemp('iskra-server');
    final port = 18000 + math.Random().nextInt(1000);
    pb = await Process.start(bin, [
      'serve',
      '--http',
      '127.0.0.1:$port',
      '--dir',
      '${root.path}/pb_data',
      '--hooksDir',
      'server/pocketbase/pb_hooks',
      '--migrationsDir',
      'server/pocketbase/pb_migrations',
    ]);
    pb!.stdout.drain<void>();
    pb!.stderr.drain<void>();
    base = Uri.parse('http://127.0.0.1:$port/');
    final client = HttpClient();
    for (var i = 0; i < 100; i++) {
      try {
        final r = await (await client.getUrl(base.resolve('api/health'))).close();
        await r.drain<void>();
        if (r.statusCode == 200) break;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    client.close();
  });

  tearDownAll(() async {
    pb?.kill();
    await pb?.exitCode;
    if (!skip) await root.delete(recursive: true);
  });

  test('регистрация, сохранение, рейтинг и вход с другого устройства', () async {
    if (skip) {
      markTestSkipped('нет PocketBase');
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

    // токен переживает перезапуск: новый клиент с сохранённым токеном сразу знает игрока
    final api3 = IskraApi(base, session: api.session);
    expect((await api3.me()).user?.login, 'искра_тест');
    expect(api3.session, isNotNull);

    // смена пароля: это устройство получает новый токен, остальные выходят
    await api.changePassword('пароль-123', 'новый-пароль');
    expect((await api.me()).user, isNotNull);
    expect((await api2.me()).user, isNull);
    expect(api2.session, isNull);
    await expectLater(api2.login('искра_тест', 'пароль-123'), throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)));

    await api.logout();
    expect(api.session, isNull);
    expect((await api.me()).user, isNull);
  });

  test('ошибки приходят с полем формы', () async {
    if (skip) {
      markTestSkipped('нет PocketBase');
      return;
    }
    final api = IskraApi(base);
    await expectLater(api.register('a b', 'пароль-123'), throwsA(isA<ApiError>().having((e) => e.field, 'field', 'login')));
    await expectLater(api.register('искорка', 'short'), throwsA(isA<ApiError>().having((e) => e.field, 'field', 'password')));
    await api.register('искорка', 'пароль-123');
    await expectLater(
      IskraApi(base).register('ИСКОРКА', 'пароль-123'),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 409)),
    );
    await api.deleteAccount('пароль-123');
    expect(api.session, isNull);
    await IskraApi(base).register('ИСКОРКА', 'пароль-123');
  });
}
