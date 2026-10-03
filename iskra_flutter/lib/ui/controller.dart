// Связка ядра игры с Flutter: ход времени, сохранение, облако, лента сообщений.
// Ритм как в веб-версии: кадр мира каждый кадр экрана, панели раз в 0,3 с,
// локальное сохранение раз в 5 с, облачное раз в 30 с и при сворачивании.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/game.dart';
import '../net/api.dart';
import '../net/cloud_sync.dart';
import 'gfx.dart';
import 'sound.dart';

class FeedItem {
  final String text, kind;
  final DateTime at;
  FeedItem(this.text, this.kind) : at = DateTime.now();
}

class PrefsStore implements KeyValueStore {
  PrefsStore(this.prefs);
  final SharedPreferences prefs;
  @override
  String? getString(String key) => prefs.getString(key);
  @override
  Future<void> setString(String key, String value) => prefs.setString(key, value);
  @override
  Future<void> remove(String key) => prefs.remove(key);
}

class GameController extends ChangeNotifier {
  GameController(this.prefs, {Uri? server}) : sound = Sound(prefs) {
    _boot();
    if (server != null) {
      final api = IskraApi(
        server,
        manageCookies: !kIsWeb, // в браузере cookie сеанса держит сам браузер
        session: prefs.getString(_sessionKey),
        onSession: (v) => v == null ? prefs.remove(_sessionKey) : prefs.setString(_sessionKey, v),
      );
      sync = CloudSync(api, PrefsStore(prefs), () => game)
        ..onLog = log
        ..onChange = notifyListeners
        ..loadServerData = _loadData;
    }
  }

  /// Тот же ключ, что у localStorage в браузере: в веб-сборке на том же сайте прогресс общий
  static const saveKey = 'iskra-save-v1';
  static const _sessionKey = 'iskra-session';

  final SharedPreferences prefs;
  final Sound sound;
  late Game game;
  CloudSync? sync;

  /// Перерисовка карты и окна боя — каждый кадр; остальной интерфейс — через notifyListeners
  final frameTick = ValueNotifier<int>(0);

  /// Перерисовка анимаций карты с лимитом кадров по качеству графики
  final paintTick = ValueNotifier<int>(0);
  final _gate = FrameGate();
  static const gfxKey = 'iskra-gfx';

  GfxLevel get gfx => Gfx.level;
  void setGfx(GfxLevel l) {
    Gfx.level = l;
    prefs.setString(gfxKey, l.name);
    paintTick.value++;
    notifyListeners();
  }

  /// Масштаб интерфейса: true — авто по размеру экрана, false — ×1
  final uiAuto = ValueNotifier<bool>(true);
  static const uiKey = 'iskra-ui-scale';
  void setUiAuto(bool v) {
    uiAuto.value = v;
    prefs.setString(uiKey, v ? 'auto' : '1');
    notifyListeners();
  }

  /// Окно новой эры: показывается при смене эры во время игры
  bool showEra = false;
  void _eraChanged() {
    showEra = true;
    notifyListeners();
  }

  void closeEra() {
    showEra = false;
    notifyListeners();
  }

  final List<FeedItem> feed = [];

  bool jumpDefeat = false; // материя ушла в минус — окно прыжка без кнопки «Остаться»
  bool showJump = false;
  bool _noSave = false;
  double _panelT = 0, _saveT = 0, _cloudT = 0;

  void _boot() {
    Gfx.level = Gfx.parse(prefs.getString(gfxKey));
    uiAuto.value = prefs.getString(uiKey) != '1';
    game = _newGameObject();
    final raw = prefs.getString(saveKey);
    if (raw == null || !_attach(raw)) game.newGame();
  }

  Game _newGameObject() => Game()
    ..onLog = log
    ..onDefend = notifyListeners
    ..onSfx = sound.play
    ..onEra = _eraChanged;

  bool _attach(String raw) {
    try {
      final j = jsonDecode(raw);
      if (!GameState.looksValid(j)) return false;
      return game.attach(GameState.fromJson(j as Map<String, dynamic>, onNote: (m) => log(m)));
    } catch (_) {
      return false;
    }
  }

  void _loadData(String data) {
    final g = _newGameObject();
    final old = game;
    game = g;
    if (!_attach(data)) {
      game = old;
      log('Сохранение с сервера повреждено.', 'bad');
      return;
    }
    save();
    log('Загружен прогресс с сервера.', 'info');
    notifyListeners();
  }

  void log(String text, [String kind = 'info']) {
    feed.insert(0, FeedItem(text, kind));
    if (feed.length > 30) feed.removeLast();
    notifyListeners();
  }

  void save() {
    if (_noSave) return;
    game.s.saved = Game.nowMs();
    prefs.setString(saveKey, jsonEncode(game.s.toJson()));
  }

  void tick(double dt) {
    game.now += dt;
    if (game.frame(dt)) {
      jumpDefeat = true;
      showJump = true;
      save();
      notifyListeners();
    }
    sound.setBattle(game.b != null);
    frameTick.value++;
    if (_gate.pass(dt)) paintTick.value++;
    _panelT += dt;
    if (_panelT > 0.3) {
      _panelT = 0;
      notifyListeners();
    }
    _saveT += dt;
    if (_saveT > 5) {
      _saveT = 0;
      save();
    }
    _cloudT += dt;
    if (_cloudT > 30) {
      _cloudT = 0;
      sync?.cloudSave();
    }
  }

  /// Приложение свернули: сохраняем всё сразу
  void onPause() {
    sound.setAppPaused(true);
    save();
    sync?.cloudSave();
  }

  /// Любое действие игрока: применить и сразу перерисовать
  void act(void Function(Game g) f) {
    f(game);
    game.refresh();
    notifyListeners();
  }

  /// Артефакт, который ждёт выбора клетки на карте (номер в s.artifacts)
  int? artPick;

  void startArtPick(int i) {
    artPick = i;
    notifyListeners();
  }

  void cancelArtPick() {
    artPick = null;
    notifyListeners();
  }

  /// Нажатие на клетку карты. Если ждёт артефакт и клетка подходит — артефакт применяется к ней
  void select(String? key) {
    final i = artPick;
    final c = key == null ? null : game.s.cells[key];
    if (i != null && i < game.s.artifacts.length && game.artValid(game.s.artifacts[i], c)) {
      artPick = null;
      act((g) {
        g.s.sel = key;
        g.applyArt(i);
      });
      return;
    }
    if (key != null) sound.play('tap');
    act((g) => g.s.sel = key);
  }

  void setPaused(bool v) => act((g) => g.s.paused = v);

  void setSpeed(int v) => act((g) => g.s.speed = v);

  void openJump() {
    if (!game.hasTech('jump')) {
      log('Прыжок закрыт: изучите технологию «Прыжок» во вкладке «Технологии».', 'info');
      return;
    }
    jumpDefeat = false;
    showJump = true;
    notifyListeners();
  }

  void closeJump() {
    if (jumpDefeat) return;
    showJump = false;
    notifyListeners();
  }

  void doJump() {
    showJump = false;
    jumpDefeat = false;
    act((g) => g.rebirth());
    save();
  }

  /// Начать заново: обнуляется всё, включая технологии и пульсары
  void resetAll() {
    _noSave = true;
    prefs.remove(saveKey);
    game = _newGameObject()..newGame();
    _noSave = false;
    save();
    sync?.cloudSave(force: true);
    notifyListeners();
  }

  @override
  void dispose() {
    frameTick.dispose();
    paintTick.dispose();
    uiAuto.dispose();
    sound.dispose();
    sync?.api.close();
    super.dispose();
  }
}
