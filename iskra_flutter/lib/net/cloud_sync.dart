// Синхронизация прогресса с сервером — та же логика, что accInit / syncAfterLogin / cloudSave в веб-версии:
// сохранение раз в 30 секунд и при сворачивании, выбор версии при конфликте устройств.
import 'dart:convert';

import '../core/game.dart';
import '../l10n/l10n.dart';
import 'api.dart';

/// Простое хранилище строк (SharedPreferences в приложении, словарь в тестах)
abstract class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

class MemoryStore implements KeyValueStore {
  final Map<String, String> data = {};
  @override
  String? getString(String key) => data[key];
  @override
  Future<void> setString(String key, String value) async => data[key] = value;
  @override
  Future<void> remove(String key) async => data.remove(key);
}

/// Что показать игроку при конфликте: два сохранения и откуда они
class SyncConflict {
  final ServerSave server;
  final Map<String, dynamic>? serverData;
  final bool justLoggedIn;
  const SyncConflict(this.server, this.serverData, this.justLoggedIn);
}

enum SyncState { idle, ok, err, conflict }

class CloudSync {
  /// [game] — текущая игра; функция, потому что после загрузки с сервера объект игры меняется
  CloudSync(this.api, this.store, Game Function() game) : _game = game;

  final IskraApi api;
  final KeyValueStore store;
  final Game Function() _game;
  Game get game => _game();

  static const syncKey = 'iskra-sync';

  /// Сервер отвечает — вкладки «Аккаунт» и «Рейтинги» имеют смысл
  bool on = false;
  AccountUser? user;
  int? base;
  SyncState state = SyncState.idle;
  DateTime? at;
  bool busy = false;
  String? _lastData;

  /// Интерфейс спрашивает, какой прогресс оставить; true — взять с сервера
  Future<bool> Function(SyncConflict c)? askConflict;

  /// Интерфейс подменяет игру сохранением с сервера
  void Function(String data)? loadServerData;

  void Function(String text, String kind)? onLog;
  void Function()? onChange;

  Map<String, dynamic>? _readSync() {
    try {
      final raw = store.getString(syncKey);
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSync(Map<String, dynamic> patch) async {
    final m = _readSync() ?? {};
    m['login'] = user?.login;
    m.addAll(patch);
    await store.setString(syncKey, jsonEncode(m));
  }

  Future<void> _setBase(int updated) async {
    base = updated;
    await _writeSync({'base': updated});
  }

  Future<void> _clearSync() async {
    base = null;
    _lastData = null;
    await store.remove(syncKey);
  }

  String get statusText {
    if (busy) return tx('сохраняем…');
    return switch (state) {
      SyncState.ok => tx('сохранено в {t}', {'t': _hhmm(at!)}),
      SyncState.err => tx('нет связи — повторим'),
      SyncState.conflict => tx('есть другая версия'),
      SyncState.idle => tx('синхронизация включена'),
    };
  }

  static String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool get _isFreshGame => game.s.rebirths == 0 && game.s.earned < 50 && game.own.length <= 1;

  void _changed() => onChange?.call();

  /// Первый запрос при запуске: есть ли сервер и кто вошёл
  Future<void> init() async {
    try {
      final r = await api.me();
      on = true;
      user = r.user;
      _changed();
      if (r.user != null) await _syncAfterLogin(r.save, false);
    } on ApiError {
      on = false;
    }
    _changed();
  }

  String _data() {
    game.s.saved = Game.nowMs();
    return jsonEncode(game.s.toJson());
  }

  Future<void> cloudSave({bool force = false, bool manual = false}) async {
    if (!on || user == null || busy) return;
    final data = _data();
    if (!force && !manual && data == _lastData) return;
    busy = true;
    _changed();
    try {
      await _writeSync({
        'sent': game.s.saved,
      }); // если приложение закроется раньше ответа, при следующем входе узнаем своё сохранение
      final m = await api.save(data, saved: game.s.saved, base: base, force: force);
      await _setBase(m.updated);
      _lastData = data;
      state = SyncState.ok;
      at = DateTime.now();
      if (manual) onLog?.call(tx('Прогресс сохранён на сервере.'), 'info');
    } on ApiError catch (e) {
      if (e.status == 409) {
        state = SyncState.conflict;
        busy = false;
        await _openConflict(false);
      } else if (e.status == 401) {
        user = null;
        state = SyncState.idle;
        await _clearSync();
        onLog?.call(tx('Сеанс истёк — войдите снова, чтобы сохранять прогресс на сервере.'), 'bad');
      } else {
        state = SyncState.err;
        if (manual) onLog?.call(tx('Не удалось сохранить: {err}', {'err': e.message}), 'bad');
      }
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> _loadServerSave(ServerSave sv) async {
    await _setBase(sv.updated);
    _lastData = sv.data;
    loadServerData?.call(sv.data);
  }

  Future<void> _syncAfterLogin(SaveMeta? meta, bool justLoggedIn) async {
    final mark = _readSync();
    final sameUser = mark != null && user != null && mark['login'] == user!.login;
    base = sameUser ? (mark['base'] as num?)?.toInt() : null;
    if (meta == null) return cloudSave(force: true); // на сервере пусто — отправляем своё
    if (base != null && meta.updated == base) return cloudSave(); // это устройство и сервер синхронны
    if (sameUser && mark['sent'] != null && meta.saved == mark['sent']) {
      // на сервере наше же последнее сохранение
      await _setBase(meta.updated);
      return cloudSave();
    }
    if (_isFreshGame) {
      // здесь нечего терять — берём с сервера
      final sv = await api.loadSave();
      if (sv != null) await _loadServerSave(sv);
      return;
    }
    await _openConflict(justLoggedIn);
  }

  Future<void> _openConflict(bool justLoggedIn) async {
    ServerSave? sv;
    try {
      sv = await api.loadSave();
    } on ApiError {
      state = SyncState.err;
      return;
    }
    if (sv == null) return cloudSave(force: true);
    Map<String, dynamic>? d;
    try {
      d = jsonDecode(sv.data) as Map<String, dynamic>;
    } catch (_) {
      return cloudSave(force: true);
    }
    final ask = askConflict;
    if (ask == null) return;
    final useServer = await ask(SyncConflict(sv, d, justLoggedIn));
    if (useServer) {
      await _loadServerSave(sv);
    } else {
      await cloudSave(force: true);
    }
    _changed();
  }

  Future<void> register(String login, String password) async {
    user = await api.register(login, password);
    await _clearSync();
    await cloudSave(force: true); // текущий прогресс сразу сохраняется на сервере
  }

  Future<void> login(String login, String password) async {
    final r = await api.login(login, password);
    user = r.user;
    _changed();
    await _syncAfterLogin(r.save, true);
  }

  Future<void> logout() async {
    await cloudSave();
    try {
      await api.logout();
    } on ApiError {
      // сеанс всё равно забываем
    }
    user = null;
    state = SyncState.idle;
    await _clearSync();
    _changed();
  }

  Future<void> deleteAccount(String password) async {
    await api.deleteAccount(password);
    user = null;
    state = SyncState.idle;
    await _clearSync();
    _changed();
  }

  /// Краткое описание сохранения для окна выбора
  static String saveSummary(Map<String, dynamic> d) {
    final cells = d['cells'];
    final own = cells is Map ? cells.values.where((c) => c is Map && c['own'] == true).length : 0;
    final word = plural(own, 'клетка', 'клетки', 'клеток', en1: 'cell', enMany: 'cells');
    return tx('{n} {word}, заработано {earned} материи, прыжков: {jumps}', {
      'n': own,
      'word': word,
      'earned': Fmt.n((d['earned'] as num?) ?? 0),
      'jumps': d['rebirths'] ?? 0,
    });
  }
}
