// Музыка и звуки. Фоновые мелодии идут по кругу, в бою — своя тема; звуки событий ядра
// приходят через Game.onSfx. Громкость: общая × музыка / эффекты, хранится в настройках.
// Файлы синтезированы скриптом tool/gen_audio.py.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

class Track {
  final String id, nameRu;
  const Track(this.id, this.nameRu);
  String get name => tx(nameRu);
}

const ambientTracks = [
  Track('music_drift', 'Звёздный дрейф'),
  Track('music_nebula', 'Туманность'),
  Track('music_pulsar', 'Пульсар'),
];
const battleTrack = Track('music_battle', 'Схватка');

const sfxIds = [
  'tap', 'open', 'close', 'capture', 'build', 'level', 'tech', 'era', 'alarm', 'lost', 'zap', //
  'cast', 'hurt', 'heal', 'start', 'win', 'lose', 'jump', 'buy', 'art', 'error',
];

class Sound extends ChangeNotifier {
  Sound(this.prefs) {
    master = _vol('master', 0.8);
    music = _vol('music', 0.5);
    effects = _vol('sfx', 0.7);
    battleMusic = prefs.getBool('iskra-vol-battle') ?? true;
  }

  /// Выключено в тестах: там нет платформенных плагинов
  static bool enabled = true;

  final SharedPreferences prefs;
  late double master, music, effects;
  late bool battleMusic;

  double _vol(String k, double def) => (prefs.getDouble('iskra-vol-$k') ?? def).clamp(0.0, 1.0);

  double get musicVol => master * music;
  double get sfxVol => master * effects;

  void setMaster(double v) {
    master = v;
    prefs.setDouble('iskra-vol-master', v);
    _applyMusic();
    notifyListeners();
  }

  void setMusic(double v) {
    music = v;
    prefs.setDouble('iskra-vol-music', v);
    _applyMusic();
    notifyListeners();
  }

  void setEffects(double v) {
    effects = v;
    prefs.setDouble('iskra-vol-sfx', v);
    notifyListeners();
  }

  void setBattleMusic(bool v) {
    battleMusic = v;
    prefs.setBool('iskra-vol-battle', v);
    _pickMusic();
    notifyListeners();
  }

  /* ---------- музыка ---------- */
  AudioPlayer? _mp;
  StreamSubscription<void>? _done;
  bool _started = false, _inBattle = false, _paused = false;
  int _ambient = 0;
  Track? _now;
  Timer? _fade;
  double _fadeMul = 1;

  /// Что играет сейчас (для подписи в настройках)
  Track? get nowPlaying => _now;

  /// Первое касание игрока: браузеры разрешают звук только после него
  void unlock() {
    if (_started || !enabled) return;
    _started = true;
    _ambient = DateTime.now().second % ambientTracks.length;
    _pickMusic();
  }

  /// Бой начался / закончился: смена темы
  void setBattle(bool v) {
    if (v == _inBattle) return;
    _inBattle = v;
    _pickMusic();
  }

  /// Приложение свёрнуто: музыка встаёт
  void setAppPaused(bool v) {
    _paused = v;
    final p = _mp;
    if (p == null) return;
    _safe(() => v || musicVol <= 0 ? p.pause() : p.resume());
  }

  void nextTrack() {
    _ambient = (_ambient + 1) % ambientTracks.length;
    if (!(_inBattle && battleMusic)) _switchTo(ambientTracks[_ambient]);
  }

  void _pickMusic() {
    if (!_started) return;
    _switchTo(_inBattle && battleMusic ? battleTrack : ambientTracks[_ambient]);
  }

  void _switchTo(Track t) {
    if (_now?.id == t.id) return;
    final first = _now == null;
    _now = t;
    notifyListeners();
    if (first) {
      _play(t);
      return;
    }
    // плавно увести прежнюю мелодию и начать новую
    _runFade(1, 0, 0.6, () => _play(t));
  }

  void _play(Track t) {
    final p = _mp ??= _newMusicPlayer();
    _fadeMul = 0;
    _safe(() async {
      await p.stop();
      await p.setReleaseMode(t == battleTrack ? ReleaseMode.loop : ReleaseMode.release);
      await p.setSource(AssetSource('audio/${t.id}.mp3'));
      await p.setVolume(0);
      if (!_paused && musicVol > 0) await p.resume();
    });
    _runFade(0, 1, 1.2, null);
  }

  AudioPlayer _newMusicPlayer() {
    final p = AudioPlayer(playerId: 'iskra-music');
    // фоновая мелодия закончилась — следующая по кругу
    _done = p.onPlayerComplete.listen((_) {
      if (_now == battleTrack) return;
      _ambient = (_ambient + 1) % ambientTracks.length;
      _now = null;
      _pickMusic();
    });
    return p;
  }

  void _runFade(double from, double to, double secs, void Function()? then) {
    _fade?.cancel();
    final steps = (secs * 20).ceil();
    var i = 0;
    _fadeMul = from;
    _fade = Timer.periodic(const Duration(milliseconds: 50), (tm) {
      i++;
      _fadeMul = from + (to - from) * (i / steps).clamp(0, 1);
      _setVol();
      if (i >= steps) {
        tm.cancel();
        then?.call();
      }
    });
  }

  void _setVol() {
    final p = _mp;
    if (p != null) _safe(() => p.setVolume(musicVol * _fadeMul));
  }

  void _applyMusic() {
    final p = _mp;
    if (p == null) {
      if (musicVol > 0) _pickMusic();
      return;
    }
    _setVol();
    // на нуле плеер стоит, чтобы не тратить батарею
    if (musicVol <= 0) {
      _safe(p.pause);
    } else if (!_paused && p.state != PlayerState.playing) {
      _safe(p.resume);
    }
  }

  /* ---------- звуки ---------- */
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  final Map<String, int> _last = {};

  void play(String id) {
    if (!enabled || !_started || sfxVol <= 0) return;
    // один и тот же звук не чаще раза в 70 мс, чтобы залпы не сливались в треск
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_last[id] ?? 0) < 70) return;
    _last[id] = now;
    if (_pool.isEmpty) {
      final low = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      for (var i = 0; i < 6; i++) {
        final p = AudioPlayer(playerId: 'iskra-sfx-$i');
        _safe(() => p.setReleaseMode(ReleaseMode.stop));
        if (low) _safe(() => p.setPlayerMode(PlayerMode.lowLatency));
        _pool.add(p);
      }
    }
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    final v = sfxVol * (id == 'tap' ? 0.6 : 1);
    _safe(() async {
      await p.stop();
      await p.play(AssetSource('audio/sfx_$id.wav'), volume: v);
    });
  }

  void _safe(FutureOr<void> Function() f) {
    try {
      final r = f();
      if (r is Future) r.catchError((Object e) => debugPrint('Звук: $e'));
    } catch (e) {
      debugPrint('Звук: $e');
    }
  }

  @override
  void dispose() {
    _fade?.cancel();
    _done?.cancel();
    _mp?.dispose();
    for (final p in _pool) {
      p.dispose();
    }
    super.dispose();
  }
}
