// Сцена боя в стиле «Звёздная плазма»: Искра-звезда против сущности-чёрной дыры.
// Рисуется целиком в CustomPainter: фон туманности (заранее в картинку), гравитационная линза,
// шестигранные барьеры, плазменные заряды и луч, взрыв как в вакууме, блики, bloom, зерно.
// События берутся из Battle.fx (bolt, num, heal, flash, spiral, stun) — логика боя не меняется.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/game.dart';
import 'theme.dart';

const _tau = math.pi * 2;
final _rng = math.Random();
double _r(double a, double b) => a + _rng.nextDouble() * (b - a);
double _ease(double k) => k < .5 ? 2 * k * k : 1 - math.pow(-2 * k + 2, 2) / 2;

class _Seeded {
  _Seeded(this.s);
  int s;
  double call() {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  }
}

void _glow(Canvas cv, Offset c, double r, Color col, double a) {
  if (r <= 0 || a <= 0.003) return;
  cv.drawCircle(
    c,
    r,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(c, r, [col.withValues(alpha: a.clamp(0, 1)), col.withValues(alpha: 0)]),
  );
}

// цвет остывающей плазмы: белый → жёлтый → оранжевый → красный → тёмный
const _heatStops = [0.0, .15, .4, .7, 1.0];
const _heatCols = [Color(0xFFFFFFFF), Color(0xFFFFE296), Color(0xFFFF963C), Color(0xFFD23C1E), Color(0xFF5A1419)];
Color _heat(double f) {
  f = f.clamp(0, 1);
  for (var i = 1; i < _heatStops.length; i++) {
    if (f <= _heatStops[i]) {
      return Color.lerp(_heatCols[i - 1], _heatCols[i], (f - _heatStops[i - 1]) / (_heatStops[i] - _heatStops[i - 1]))!;
    }
  }
  return _heatCols.last;
}

enum _K { dot, streak, ring, smoke, ember, fire, debris }

class _P {
  _P(this.k, this.x, this.y, this.vx, this.vy, this.life, this.size, this.col, {this.g = 0, this.drag = 1, this.grow = 0})
    : max = life,
      rot = _r(0, _tau),
      vr = _r(-6, 6);
  final _K k;
  double x, y, vx, vy, life, size, g, drag, grow, rot, vr;
  final double max;
  final Color col;
}

class _Hit {
  _Hit(this.x, this.y, this.t, [this.k = 1]);
  final double x, y, t, k;
}

class _Flare {
  _Flare(this.x, this.y, this.t, this.a);
  final double x, y, t, a;
}

class _Num {
  _Num(this.text, this.col, this.at, this.t0) : rot = _r(-.12, .12), dx = _r(-24, 24);
  final String text, at;
  final Color col;
  final double t0, rot, dx;
}

/// Выстрел: 0 — плазменный заряд, 1 — луч, 2 — гравитационная линза сущности
class _Shot {
  _Shot(this.kind, this.t0, this.col, {this.big = false});
  final int kind;
  final double t0;
  final Color col;
  final bool big;
  bool hit = false, boom = false;
}

class _Ray {
  _Ray(_Seeded r) : a = r() * _tau, l = .6 + r() * 1.1, w = .025 + r() * .05, ph = r() * 9, cold = r() < .3, dir = r() < .5 ? 1 : -1;
  final double a, l, w, ph;
  final bool cold;
  final int dir;
}

final _rays = (() {
  final r = _Seeded(99);
  return List.generate(44, (_) => _Ray(r));
})();

/// Состояние сцены между кадрами: частицы, попадания, выстрелы
class _SceneFx {
  double t = 0, shake = 0, flash = 0, zoom = 0, charge = 0, ageE = 9, ageS = 9;
  double? lostAt, wonAt;
  bool primed = false;
  final seen = Expando<bool>();
  final parts = <_P>[];
  final eHits = <_Hit>[], sHits = <_Hit>[];
  final flares = <_Flare>[];
  final nums = <_Num>[];
  final pending = <(_Num, double)>[];
  final shots = <_Shot>[];
  final shocks = <_Hit>[];
  double stunUntil = -1;
  ui.Image? bg, grain;
  Size? bgSize;
  final motes = (() {
    final r = _Seeded(5);
    return List.generate(26, (_) => [r(), r(), .4 + r() * 1.4]);
  })();

  void step(double dt) {
    t += dt;
    ageE += dt;
    ageS += dt;
    final k = math.exp(-dt * 9);
    shake *= k;
    flash *= math.exp(-dt * 7);
    zoom *= math.exp(-dt * 4);
    charge *= math.exp(-dt * 5);
    for (var i = parts.length - 1; i >= 0; i--) {
      final p = parts[i];
      p.life -= dt;
      if (p.life <= 0) {
        parts.removeAt(i);
        continue;
      }
      p.vy += p.g * dt;
      final d = math.pow(p.drag, dt * 10).toDouble();
      p.vx *= d;
      p.vy *= d;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.vr * dt;
    }
    eHits.removeWhere((h) => t - h.t > .9);
    sHits.removeWhere((h) => t - h.t > .9);
    flares.removeWhere((f) => t - f.t > .35);
    nums.removeWhere((n) => t - n.t0 > 1.1);
    shocks.removeWhere((s) => t - s.t > 1.1);
    for (final m in motes) {
      m[0] -= dt * .012 * m[2];
      if (m[0] < -.05) m[0] = 1.05;
    }
  }

  void burst(Offset o, int n, _K k, Color col, double s,
      {required List<double> v, required List<double> life, required List<double> size, double? a, double spread = math.pi, double g = 0, double drag = 1, double grow = 0}) {
    for (var i = 0; i < n; i++) {
      final an = a != null ? a + _r(-spread, spread) : _r(0, _tau), sp = _r(v[0], v[1]) * s;
      parts.add(_P(k, o.dx, o.dy, math.cos(an) * sp, math.sin(an) * sp, _r(life[0], life[1]), _r(size[0], size[1]), col, g: g * s, drag: drag, grow: grow));
    }
  }
}

/// Сцена боя. Анимируется своим тикером, состояние боя берётся из [battle].
class BattleScene extends StatefulWidget {
  const BattleScene(this.battle, {super.key});
  final Battle battle;

  @override
  State<BattleScene> createState() => _BattleSceneState();
}

class _BattleSceneState extends State<BattleScene> with SingleTickerProviderStateMixin {
  final _fx = _SceneFx();
  final _repaint = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      final dt = ((e - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
      _last = e;
      _fx.step(dt);
      _repaint.value++;
    })..start();
  }

  @override
  void didUpdateWidget(BattleScene old) {
    super.didUpdateWidget(old);
    if (!identical(old.battle, widget.battle)) _fx.primed = false;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    _fx.bg?.dispose();
    _fx.grain?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ScenePainter(_fx, widget.battle, _repaint, mq?.devicePixelRatio ?? 1, mq?.disableAnimations ?? false),
        size: Size.infinite,
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.fx, this.b, Listenable repaint, this.dpr, this.reduced) : super(repaint: repaint);
  final _SceneFx fx;
  final Battle b;
  final double dpr;
  final bool reduced;

  late double w, h, s;
  late Offset S, E;
  late Color tier;
  late double rE;

  static const _sparkHalo = Color(0xFFFFA03C);
  static const _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    w = size.width;
    h = size.height;
    if (w < 2 || h < 2) return;
    s = h / 360;
    final t = fx.t;
    tier = Color(Defs.tierColor[b.foe.tier] ?? 0xFFFF8A3D);
    rE = 60 * s * switch (b.foe.tier) { 'low' => .72, 'rare' => .82, 'epic' => .92, _ => 1.0 };
    final dx = math.sin(t * .13) * w * .012, dy = math.cos(t * .11) * h * .01;
    S = Offset(w * .25 + dx * .8, h * .55 + dy * .8);
    E = Offset(w * .72 + dx * .6, h * .47 + dy * .6);
    _events();
    _shots();

    _ensureBg(size);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (!reduced && fx.shake > .2) {
      canvas.translate(_r(-1, 1) * fx.shake, _r(-1, 1) * fx.shake);
      canvas.translate(w / 2, h / 2);
      canvas.rotate(_r(-1, 1) * fx.shake * .0012);
      final z = 1 + fx.zoom * .035;
      canvas.scale(z, z);
      canvas.translate(-w / 2, -h / 2);
    }
    final ox = -w * .04 + dx * .3, oy = -h * .04 + dy * .3;
    final bg = fx.bg!;
    final bgDst = Rect.fromLTWH(ox, oy, w * 1.08, h * 1.08), bgSrc = Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble());
    canvas.drawImageRect(bg, bgSrc, bgDst, Paint()..filterQuality = FilterQuality.low);

    // сущность: линза, джеты, диск, рамка, барьер
    final collapse = fx.wonAt == null ? 1.0 : (1 - (t - fx.wonAt!) / 1.2).clamp(0.0, 1.0);
    final wob = fx.ageE < 1 ? 1 + .06 * math.exp(-fx.ageE * 5) * math.sin(fx.ageE * 40) : 1.0;
    if (collapse > 0) {
      _lens(canvas, bg, bgSrc, bgDst, E, rE * 1.45 * wob * collapse, 1.5, math.pi + t * .02);
      if (b.foe.tier == 'epic' || b.foe.tier == 'legend') _jets(canvas, E, rE * collapse, t);
      _blackHole(canvas, E, rE * wob * collapse, t);
      _reticle(canvas, t);
      _hexShield(canvas, E, rE * 1.5, fx.eHits, t, const Color(0xFFC896FF));
    }
    // ответ сущности: гравитационные линзы в полёте
    for (final sh in fx.shots.where((x) => x.kind == 2)) {
      final k = _ease(((t - sh.t0) / .32).clamp(0, 1)), p = Offset.lerp(E, S, k)! + Offset(0, -math.sin(k * math.pi) * 20 * s);
      final lr = (18 + 10 * math.sin(k * math.pi)) * s;
      _lens(canvas, bg, bgSrc, bgDst, p, lr, 1.7, math.pi);
      canvas.drawCircle(p, lr, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..blendMode = BlendMode.plus
        ..color = Color.lerp(sh.col, const Color(0xFFAA82FF), .5)!.withValues(alpha: .7));
      _glow(canvas, p, lr * 2, const Color(0xFF8C5AFF), .25);
      canvas.drawCircle(p, lr * .55, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xE60A0418));
    }
    // искра
    final lost = fx.lostAt == null ? 1.0 : (1 - (t - fx.lostAt!) / 1.5).clamp(.25, 1.0);
    final rS = 44 * s * (fx.ageS < .4 ? 1 - .08 * math.sin(fx.ageS / .4 * math.pi) : 1) * lost;
    _spark(canvas, S, rS, t, fx.charge);
    _shimmer(canvas, rS, t);
    final shieldUp = b.shield > 0 || b.immune > 0;
    if (shieldUp) {
      canvas.drawCircle(S, 60 * s, Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(S, 60 * s, [const Color(0x0078D2FF), const Color(0x5578D2FF)], [.8, 1]));
    }
    _hexShield(canvas, S, 60 * s, fx.sHits, t, const Color(0xFF78D2FF));
    if (fx.stunUntil > t) {
      for (var i = 0; i < 5; i++) {
        final a = t * 3 + i * _tau / 5;
        _glow(canvas, S + Offset(math.cos(a) * rS * 1.3, -rS * 1.1 + math.sin(a) * rS * .3), 5 * s, const Color(0xFFFFE08A), .9);
      }
    }
    _particles(canvas, false);
    _hot(canvas, t, rS);
    _nums(canvas, t);
    // bloom: горячие элементы ещё раз, размытые и сложенные поверх
    canvas.saveLayer(
      Offset.zero & Size(w, h),
      Paint()
        ..blendMode = BlendMode.plus
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 9 * s, sigmaY: 9 * s, tileMode: TileMode.decal),
    );
    _hot(canvas, t, rS);
    _particles(canvas, true);
    _glow(canvas, S, rS * 1.2, const Color(0xFFFFE6B4), .6);
    canvas.restore();
    canvas.restore();

    _post(canvas, t, dx);
  }

  /* ---------- события боя ---------- */
  void _events() {
    final t = fx.t;
    if (!fx.primed) {
      for (final v in b.fx) {
        fx.seen[v] = true;
      }
      fx.primed = true;
      fx.wonAt = b.over && b.won ? t - 2 : null;
      fx.lostAt = b.over && !b.won ? t - 2 : null;
    }
    if (b.over && b.won && fx.wonAt == null) {
      fx.wonAt = t;
      fx.flash = 1;
      fx.shake = 10 * s;
      fx.burst(E, 70, _K.ember, _white, s, v: [120, 520], life: [.6, 1.6], size: [1, 2.6]);
      fx.burst(E, 12, _K.fire, _white, s, v: [10, 80], life: [.6, 1.4], size: [12, 22], grow: 2.5, drag: .9);
      fx.shocks.add(_Hit(E.dx, E.dy, t));
    }
    if (b.over && !b.won && fx.lostAt == null) fx.lostAt = t;
    for (final v in b.fx) {
      if (fx.seen[v] == true) continue;
      fx.seen[v] = true;
      final col = Color(v.color), atP = v.at == 'p';
      switch (v.kind) {
        case 'bolt':
          if (atP) {
            fx.charge = 1;
            final big = v.color == Defs.tierColor['epic'] || v.color == Defs.tierColor['legend'];
            if (big) {
              fx.shots.add(_Shot(1, t, col, big: true));
            } else if (v.color == Defs.tierColor['low'] || v.color == Defs.tierColor['rare']) {
              for (var i = 0; i < 3; i++) {
                fx.shots.add(_Shot(0, t + i * .09, col));
              }
            } else {
              fx.shots.add(_Shot(0, t, col));
            }
          } else {
            fx.shots.add(_Shot(2, t, col));
          }
        case 'num':
          final heal = v.text?.startsWith('+') ?? false;
          fx.pending.add((_Num(v.text ?? '', col, v.at, 0), t + (heal ? 0 : atP ? .32 : .26)));
        case 'heal':
          fx.burst(S, 26, _K.dot, const Color(0xFF7BE0A8), s, v: [10, 50], life: [.8, 1.4], size: [2, 3.5], a: -math.pi / 2, spread: 1.2, g: -40);
          fx.parts.add(_P(_K.ring, S.dx, S.dy, 0, 0, .7, 48 * s, const Color(0xFF7BE0A8), grow: 40 * s));
        case 'flash':
          final o = atP ? S : E, rr = atP ? 60 * s : rE * 1.5;
          for (var i = 0; i < 4; i++) {
            final a = i * _tau / 4 + _r(0, 1);
            (atP ? fx.sHits : fx.eHits).add(_Hit(o.dx + math.cos(a) * rr, o.dy + math.sin(a) * rr, t, .8));
          }
        case 'spiral':
          final o = atP ? S : E;
          for (var i = 0; i < 24; i++) {
            final a = i / 24 * _tau, d = _r(70, 110) * s, sp = _r(140, 200) * s;
            fx.parts.add(_P(_K.streak, o.dx + math.cos(a) * d, o.dy + math.sin(a) * d, -math.cos(a + .6) * sp, -math.sin(a + .6) * sp, d / sp, 2, const Color(0xFFF2B441)));
          }
        case 'stun':
          fx.stunUntil = t + 1.2;
      }
    }
    for (var i = fx.pending.length - 1; i >= 0; i--) {
      final (n, at) = fx.pending[i];
      if (at > t) continue;
      fx.pending.removeAt(i);
      fx.nums.add(_Num(n.text, n.col, n.at, t));
    }
  }

  Offset get _dir => Offset(E.dx - S.dx, E.dy - S.dy) / (E - S).distance;
  Offset get _hitE => E - _dir * (rE * 1.5);
  Offset get _muzzle => S + _dir * (38 * s);

  void _shots() {
    final t = fx.t;
    final ang = math.atan2(_dir.dy, _dir.dx);
    for (final sh in fx.shots) {
      final age = t - sh.t0;
      if (age < 0) continue;
      switch (sh.kind) {
        case 0 when !sh.hit && age >= .28:
          sh.hit = true;
          final p = _hitE + Offset(_r(-8, 8), _r(-14, 14)) * s;
          fx.eHits.add(_Hit(p.dx, p.dy, t));
          fx.flares.add(_Flare(p.dx, p.dy, t, .8));
          fx.burst(p, 18, _K.ember, _white, s, v: [120, 380], life: [.3, .8], size: [1, 2.2], a: ang + math.pi, spread: 1.2);
          fx.burst(p, 4, _K.fire, _white, s, v: [5, 30], life: [.3, .5], size: [6, 10], grow: 2, drag: .9);
          fx.ageE = 0;
          fx.shake = math.max(fx.shake, 3 * s);
        case 1:
          if (age > .1 && age < .55 && _rng.nextDouble() < .9) {
            fx.burst(_hitE, 3, _K.ember, _white, s, v: [150, 420], life: [.25, .7], size: [1, 2.4], a: ang + math.pi, spread: 1.3);
            if (fx.eHits.isEmpty || t - fx.eHits.last.t > .07) fx.eHits.add(_Hit(_hitE.dx, _hitE.dy, t, .6));
          }
          if (!sh.boom && age >= .22) {
            sh.boom = true;
            final p = _hitE;
            fx.flash = .9;
            fx.shake = 12 * s;
            fx.zoom = 1;
            fx.ageE = 0;
            fx.flares.add(_Flare(p.dx, p.dy, t, 1.4));
            fx.eHits.add(_Hit(p.dx, p.dy, t, 2));
            fx.parts.add(_P(_K.fire, p.dx, p.dy, 0, 0, .9, 30, _white, grow: 3));
            fx.burst(p, 10, _K.fire, _white, s, v: [20, 90], life: [.6, 1.3], size: [10, 20], grow: 2.5, drag: .9);
            fx.burst(p, 60, _K.ember, _white, s, v: [160, 620], life: [.5, 1.4], size: [1, 2.6]);
            fx.burst(p, 12, _K.debris, _white, s, v: [60, 220], life: [1.2, 2.2], size: [3, 7]);
            fx.burst(p, 8, _K.smoke, const Color(0xFF5A4678), s, v: [15, 50], life: [1.2, 2], size: [18, 30], drag: .95);
            fx.shocks.add(_Hit(p.dx, p.dy, t));
          }
        case 2 when !sh.hit && age >= .32:
          sh.hit = true;
          final p = S + _dir * (60 * s);
          fx.sHits.add(_Hit(p.dx, p.dy, t, 1.6));
          fx.burst(p, 22, _K.streak, const Color(0xFF96C8FF), s, v: [100, 320], life: [.25, .6], size: [1, 2], a: ang, spread: 1.3);
          fx.ageS = 0;
          fx.shake = math.max(fx.shake, 6 * s);
          fx.zoom = .5;
      }
    }
    fx.shots.removeWhere((x) => t - x.t0 > .8);
  }

  /* ---------- фон ---------- */
  void _ensureBg(Size size) {
    if (fx.bg != null && fx.bgSize == size) return;
    fx.bg?.dispose();
    fx.bgSize = size;
    final W = size.width * 1.08, H = size.height * 1.08, k = math.min(2.0, dpr);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(k);
    final r = _Seeded(9001);
    c.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()..shader = ui.Gradient.radial(Offset(W * .62, H * .38), W * .8, const [Color(0xFF120C28), Color(0xFF07051A), Color(0xFF020106)], [0, .6, 1]),
    );
    double band(double x) => H * (.18 + .42 * (x / W));
    const neb = [Color(0xFF783CBE), Color(0xFF286EAA), Color(0xFFBE5064), Color(0xFF462882), Color(0xFF1E8CA0)];
    for (var i = 0; i < 70; i++) {
      final x = r() * W, y = band(x) + (r() - .5) * H * .55;
      _glow(c, Offset(x, y), W * (.03 + r() * .16), neb[(r() * neb.length).floor()], .028 + r() * .045);
    }
    final n = (900 * W * H / (700 * 400)).round();
    for (var i = 0; i < n; i++) {
      final x = r() * W, y = r() < .55 ? band(r() * W) + (r() - .5) * H * .5 : r() * H, br = math.pow(r(), 3).toDouble();
      final col = r() < .3 ? const Color(0xFFBED2FF) : (r() < .2 ? const Color(0xFFFFC8AA) : const Color(0xFFFFF8EB));
      c.drawRect(Rect.fromLTWH(x, y, .6 + br * 1.2, .6 + br * 1.2), Paint()..color = col.withValues(alpha: .12 + br * .85));
    }
    for (var i = 0; i < 28; i++) {
      final x = r() * W, y = band(x) + (r() - .5) * H * .18, rr = W * (.02 + r() * .07);
      c.drawCircle(Offset(x, y), rr, Paint()..shader = ui.Gradient.radial(Offset(x, y), rr, const [Color(0x8C020106), Color(0x00020106)]));
    }
    for (var i = 0; i < 14; i++) {
      final x = r() * W, y = r() * H, L = 4 + r() * 10;
      _glow(c, Offset(x, y), L * .9, const Color(0xFFDCE6FF), .5);
      final p = Paint()
        ..color = const Color(0x8CEBF0FF)
        ..blendMode = BlendMode.plus;
      c.drawRect(Rect.fromLTWH(x - L, y - .4, L * 2, .8), p);
      c.drawRect(Rect.fromLTWH(x - .4, y - L, .8, L * 2), p);
    }
    fx.bg = rec.endRecording().toImageSync((W * k).ceil(), (H * k).ceil());
    if (fx.grain == null) {
      final px = Uint8List(128 * 128 * 4);
      for (var i = 0; i < px.length; i += 4) {
        final v = _rng.nextInt(256);
        px[i] = v;
        px[i + 1] = v;
        px[i + 2] = v;
        px[i + 3] = 255;
      }
      ui.decodeImageFromPixels(px, 128, 128, ui.PixelFormat.rgba8888, (img) => fx.grain = img);
    }
  }

  void _lens(Canvas c, ui.Image bg, Rect src, Rect dst, Offset at, double r, double mag, double rot) {
    if (r <= 0) return;
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: at, radius: r)));
    c.translate(at.dx, at.dy);
    c.rotate(rot);
    c.scale(mag);
    c.translate(-at.dx, -at.dy);
    c.drawImageRect(bg, src, dst, Paint());
    c.restore();
    c.drawCircle(at, r, Paint()..shader = ui.Gradient.radial(at, r, const [Color(0x00000000), Color(0x00000000), Color(0x2EC8B4FF)], [0, .85, 1]));
  }

  /* ---------- сущность ---------- */
  void _jets(Canvas c, Offset o, double r, double t) {
    for (final sd in [-1.0, 1.0]) {
      final len = r * 2.6;
      for (var i = 0; i < 3; i++) {
        final l = r * (2.6 + .4 * math.sin(t * 2 + i)), wd = r * (.05 + i * .05), end = o + Offset(sd * l * .18, -sd * l);
        c.drawPath(
          Path()
            ..moveTo(o.dx - wd, o.dy)
            ..lineTo(end.dx - wd * 2.5, end.dy)
            ..lineTo(end.dx + wd * 2.5, end.dy)
            ..lineTo(o.dx + wd, o.dy)
            ..close(),
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.linear(o, end, [const Color(0xFFAA96FF).withValues(alpha: .5 - i * .12), const Color(0x007864FF)]),
        );
      }
      for (var k = 0; k < 5; k++) {
        final u = (t * .8 + k / 5) % 1;
        _glow(c, o + Offset(sd * len * .18 * u, -sd * len * u), r * .12 * (1 - u) + 2, const Color(0xFFBEAAFF), .5 * (1 - u));
      }
    }
  }

  void _blackHole(Canvas c, Offset o, double r, double t) {
    if (r <= 1) return;
    _glow(c, o, r * 2.4, tier, .18);
    c.drawCircle(o, r * .66, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .16
      ..blendMode = BlendMode.plus
      ..color = Color.lerp(tier, _white, .3)!.withValues(alpha: .55));
    void disk(bool back) {
      for (var i = 0; i < 14; i++) {
        final k = i / 13, rad = r * (.68 + k), al = (1 - k) * .75 + .08;
        final col = Color.lerp(const Color(0xFFFFF0DC), tier, math.min(1, k * 1.1))!;
        c.drawArc(
          Rect.fromCenter(center: o, width: rad * 2, height: rad * 2 * .24),
          back ? math.pi : 0,
          math.pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * .09
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.linear(Offset(o.dx - rad, o.dy), Offset(o.dx + rad, o.dy), [col.withValues(alpha: al), col.withValues(alpha: al * .35)]),
        );
      }
      for (var j = 0; j < 26; j++) {
        final rad = r * (.75 + (j * .037) % 1), a = (j * 1.3 + t * (1.6 / (rad / r))) % _tau, sy = math.sin(a);
        if ((sy < 0) != back) continue;
        _glow(c, o + Offset(math.cos(a) * rad, sy * rad * .24), r * .07, const Color(0xFFFFE6BE), .8);
      }
    }

    disk(true);
    c.drawCircle(o, r * .57, Paint()..color = const Color(0xFF000000));
    c.drawCircle(o, r * .585, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * .025)
      ..blendMode = BlendMode.plus
      ..color = const Color(0xF2FFECD2));
    disk(false);
  }

  void _reticle(Canvas c, double t) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = tier.withValues(alpha: .55);
    final B = rE * 1.85 + math.sin(t * 2) * 2, bl = 10 * s;
    for (final (sx, sy) in [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)]) {
      c.drawPath(
        Path()
          ..moveTo(E.dx + sx * B, E.dy + sy * (B - bl))
          ..lineTo(E.dx + sx * B, E.dy + sy * B)
          ..lineTo(E.dx + sx * (B - bl), E.dy + sy * B),
        p,
      );
    }
  }

  /// Шестигранный энергобарьер: вспыхивает у точки попадания и расходится волной
  void _hexShield(Canvas c, Offset o, double rb, List<_Hit> hits, double t, Color col) {
    if (hits.isEmpty) return;
    const maxAge = .9;
    final hs = rb / 7, sq3 = math.sqrt(3);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..blendMode = BlendMode.plus;
    final fill = Paint()..blendMode = BlendMode.plus;
    for (var r = -8; r <= 8; r++) {
      for (var q = -8; q <= 8; q++) {
        final px = hs * sq3 * (q + r / 2), py = hs * 1.5 * r, dc = math.sqrt(px * px + py * py);
        if (dc > rb) continue;
        var a = 0.0;
        for (final hh in hits) {
          final age = (t - hh.t) / maxAge;
          if (age >= 1) continue;
          final d = (Offset(o.dx + px - hh.x, o.dy + py - hh.y)).distance;
          a += (1 - age) * (math.exp(-d / (rb * .28)) + .7 * math.exp(-(d - age * rb * 2.4).abs() / hs)) * hh.k;
        }
        a *= .35 + .65 * math.pow(dc / rb, 2);
        if (a < .04) continue;
        a = math.min(1, a);
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final an = i / 6 * _tau + math.pi / 6, X = o.dx + px + math.cos(an) * hs * .92, Y = o.dy + py + math.sin(an) * hs * .92;
          i == 0 ? path.moveTo(X, Y) : path.lineTo(X, Y);
        }
        path.close();
        c.drawPath(path, stroke..color = col.withValues(alpha: a));
        if (a > .5) c.drawPath(path, fill..color = col.withValues(alpha: (a - .5) * .25));
      }
    }
    var rim = 0.0;
    for (final hh in hits) {
      rim += math.max(0, 1 - (t - hh.t) / maxAge) * hh.k;
    }
    c.drawCircle(o, rb, Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(o, rb, [col.withValues(alpha: 0), col.withValues(alpha: math.min(.28, rim * .14))], [.75, 1]));
  }

  /* ---------- искра ---------- */
  void _spark(Canvas c, Offset o, double r, double t, double charge) {
    _glow(c, o, r * (3 + charge * 1.5), _sparkHalo, .22 + .25 * charge);
    for (final q in _rays) {
      final a = q.a + t * .12 * q.dir, len = r * q.l * (1 + .25 * math.sin(t * 3 + q.ph)) * (1 + charge * .7), wd = r * q.w;
      final tip = o + Offset(math.cos(a), math.sin(a)) * len * 1.6;
      c.drawPath(
        Path()
          ..moveTo(o.dx + math.cos(a + 1.57) * wd, o.dy + math.sin(a + 1.57) * wd)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(o.dx + math.cos(a - 1.57) * wd, o.dy + math.sin(a - 1.57) * wd)
          ..close(),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(o, tip, [
            const Color(0xF2FFFFFF),
            q.cold ? const Color(0x8CAAC8FF) : const Color(0x99FFCD78),
            const Color(0x00FFAA3C),
          ], [0, .35, 1]),
      );
    }
    // протуберанцы
    for (var k = 0; k < 3; k++) {
      final a = k * 2.1 + t * .2, rr = r * .72, hh = r * (.35 + .15 * math.sin(t * 1.7 + k));
      final p0 = o + Offset(math.cos(a - .25), math.sin(a - .25)) * rr, p1 = o + Offset(math.cos(a + .25), math.sin(a + .25)) * rr;
      final cp = o + Offset(math.cos(a), math.sin(a)) * (rr + hh * 2);
      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(cp.dx, cp.dy, p1.dx, p1.dy);
      for (final (lw, al) in [(r * .12, .25), (r * .05, .7)]) {
        c.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lw
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..color = Color.fromRGBO(255, 150 + k * 20, 70, al));
      }
    }
    c.drawCircle(o, r * .75, Paint()
      ..shader = ui.Gradient.radial(o - Offset(r * .2, r * .2), r * .8, const [Color(0xFFFFFFFF), Color(0xFFFFF0C8), Color(0xFFFFBE55), Color(0xFFFF8A2A)], [0, .5, .85, 1]));
    for (var k = 0; k < 8; k++) {
      final a = k * .8 + t * .5, d = r * (.2 + .4 * ((k * 37) % 10) / 10);
      _glow(c, o + Offset(math.cos(a), math.sin(a)) * d, r * .18, const Color(0xFFFFFFE6), .35);
    }
    _glow(c, o, r * .55, _white, .9);
  }

  void _shimmer(Canvas c, double rS, double t) {
    for (var i = 0; i < 3; i++) {
      final path = Path();
      for (var j = 0; j <= 40; j++) {
        final an = j / 40 * _tau, rr = rS * (1.05 + i * .12) + math.sin(an * 7 + t * 5 + i) * 2 * s;
        final p = S + Offset(math.cos(an), math.sin(an)) * rr;
        j == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      c.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFFFC88C).withValues(alpha: .06 + .04 * math.sin(t * 4 + i)));
    }
  }

  /* ---------- оружие, блики ---------- */
  void _anamorph(Canvas c, Offset o, double len, double a, [Color col = const Color(0xFFA0C8FF)]) {
    if (a <= .01 || len <= 0) return;
    final p = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.linear(o - Offset(len, 0), o + Offset(len, 0), [col.withValues(alpha: 0), col.withValues(alpha: math.min(1, a)), col.withValues(alpha: 0)], [0, .5, 1]);
    c.drawRect(Rect.fromCenter(center: o, width: len * 2, height: 2), p);
    c.drawRect(Rect.fromCenter(center: o, width: len * 1.2, height: 10), p..color = const Color(0x59FFFFFF));
  }

  void _hot(Canvas c, double t, double rS) {
    final dir = _dir, m = _muzzle, hit = _hitE;
    for (final sh in fx.shots) {
      final age = t - sh.t0;
      if (age < 0) continue;
      if (sh.kind == 0 && age < .28) {
        final k = age / .28, p = Offset.lerp(m, hit, k)!, L = 90 * s, tail = p - dir * L;
        c.drawLine(tail, p, Paint()
          ..strokeWidth = 5 * s
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(tail, p, [sh.col.withValues(alpha: 0), Color.lerp(sh.col, _white, .4)!.withValues(alpha: .9)]));
        c.drawLine(p - dir * (L * .4), p, Paint()
          ..strokeWidth = 1.6 * s
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..color = const Color(0xF2FFFFF0));
        _glow(c, p, 16 * s, sh.col, .7);
        _glow(c, p, 4 * s, _white, 1);
        if (age < .05) _glow(c, m, 30 * s, const Color(0xFFFFE6C8), .8);
      } else if (sh.kind == 1 && age < .67) {
        final grow = (age / .1).clamp(0.0, 1.0), fade = age > .55 ? 1 - (age - .55) / .12 : 1.0;
        final end = Offset.lerp(m, hit, grow)!, wd = fade * (1 + .15 * math.sin(t * 60));
        final halo = Color.lerp(sh.col, const Color(0xFFFF8A3D), .5)!;
        for (final (lw, col) in [(30.0, halo.withValues(alpha: .10)), (14.0, halo.withValues(alpha: .28)), (6.0, const Color(0xB3FFDCA0)), (2.2, _white)]) {
          c.drawLine(m, end, Paint()
            ..strokeWidth = lw * s * wd
            ..strokeCap = StrokeCap.round
            ..blendMode = BlendMode.plus
            ..color = col);
        }
        for (var i = 0; i < 12; i++) {
          final u = (i / 12 + t * 2.5) % 1;
          if (u > grow) continue;
          _glow(c, Offset.lerp(m, end, u)! + Offset(0, math.sin(u * 30 + t * 40) * 2 * s), 8 * s * wd, const Color(0xFFFFE6BE), .6);
        }
        _glow(c, m, 40 * s * wd, const Color(0xFFFFC88C), .6);
        _anamorph(c, m, 160 * s * wd, .7 * wd, const Color(0xFFFFC896));
        if (grow >= 1) {
          _glow(c, end, 34 * s * wd, const Color(0xFFFFDCAA), .8);
          _anamorph(c, end, 220 * s * wd, .8 * wd);
        }
      }
    }
    for (final f in fx.flares) {
      final a = f.a * (1 - (t - f.t) / .35);
      _anamorph(c, Offset(f.x, f.y), 200 * s * a, a);
      _glow(c, Offset(f.x, f.y), 40 * s * a, const Color(0xFFFFE6C8), a);
    }
    _anamorph(c, S, (120 + fx.charge * 220) * s, .25 + fx.charge * .5, const Color(0xFFFFD2A0));
    // отражения в объективе по линии от искры через центр кадра
    final ga = .5 + fx.charge * .8;
    for (final (k, r, col) in [(.55, 10.0, const Color(0xFF78FFC8)), (.9, 6.0, const Color(0xFFFFA05A)), (1.35, 16.0, const Color(0xFF8296FF)), (1.7, 8.0, const Color(0xFFFF78C8))]) {
      final g = S + (Offset(w / 2, h / 2) - S) * (k * 2), rr = r * s, path = Path();
      for (var i = 0; i < 6; i++) {
        final an = i / 6 * _tau, p = g + Offset(math.cos(an), math.sin(an)) * rr;
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      c.drawPath(path..close(), Paint()
        ..blendMode = BlendMode.plus
        ..color = col.withValues(alpha: math.min(1, ga * .12)));
    }
  }

  void _particles(Canvas c, bool hotOnly) {
    for (final p in fx.parts) {
      if (hotOnly && p.k != _K.fire && p.k != _K.ember) continue;
      final a = p.life / p.max, sz = p.size * s, o = Offset(p.x, p.y);
      switch (p.k) {
        case _K.dot:
          _glow(c, o, sz * (1.5 + a), p.col, a);
        case _K.streak:
          c.drawLine(o, o - Offset(p.vx, p.vy) * .035, Paint()
            ..strokeWidth = sz
            ..strokeCap = StrokeCap.round
            ..blendMode = BlendMode.plus
            ..color = p.col.withValues(alpha: a));
        case _K.ring:
          c.drawCircle(o, sz + (1 - a) * p.grow, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, sz * .05 * a + 1)
            ..blendMode = BlendMode.plus
            ..color = p.col.withValues(alpha: a * a));
        case _K.smoke:
          final rr = sz * (2 - a);
          c.drawCircle(o, rr, Paint()..shader = ui.Gradient.radial(o, rr, [p.col.withValues(alpha: a * .35), p.col.withValues(alpha: 0)]));
        case _K.ember:
          c.drawLine(o, o - Offset(p.vx, p.vy) * .05, Paint()
            ..strokeWidth = sz * (.5 + a * .5)
            ..strokeCap = StrokeCap.round
            ..blendMode = BlendMode.plus
            ..color = _heat(1 - a).withValues(alpha: math.min(1, a * 1.6)));
        case _K.fire:
          final f = 1 - a;
          _glow(c, o, sz * (1 + f * p.grow), _heat(math.min(1, f * 1.3)), a * a * .8);
        case _K.debris:
          c.save();
          c.translate(p.x, p.y);
          c.rotate(p.rot);
          final path = Path()
            ..moveTo(sz, 0)
            ..lineTo(sz * .1, sz * .7)
            ..lineTo(-sz * .8, sz * .2)
            ..lineTo(-sz * .3, -sz * .7)
            ..close();
          c.drawPath(path, Paint()..color = const Color(0xFF120D1C).withValues(alpha: math.min(1, a * 2)));
          c.drawLine(Offset(sz, 0), Offset(sz * .1, sz * .7), Paint()
            ..strokeWidth = 1.2
            ..color = _heat(math.min(1, .35 + (1 - a))).withValues(alpha: a));
          c.restore();
      }
    }
  }

  void _nums(Canvas c, double t) {
    for (final n in fx.nums) {
      final age = t - n.t0, life = 1.1 - age;
      final pop = age < .12 ? .6 + age / .12 * .6 : 1.2 - math.min(.2, (age - .12) * .5);
      final o = n.at == 'p' ? S + Offset(0, -62 * s) : E + Offset(n.dx * s, -rE * 1.2);
      final tp = TextPainter(
        text: TextSpan(
          text: n.text,
          style: TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w700,
            fontSize: 26 * s,
            color: n.col.withValues(alpha: math.min(1, life * 2.5)),
            shadows: [Shadow(color: const Color(0xE6FF8C32).withValues(alpha: math.min(.9, life * 2)), blurRadius: 12 * s)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      c.save();
      c.translate(o.dx, o.dy - age * 38 * s);
      c.rotate(n.rot);
      c.scale(pop);
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
      tp.dispose();
    }
  }

  /* ---------- оптика кадра ---------- */
  void _post(Canvas c, double t, double dx) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    // плоская ударная волна взрыва
    for (final sh in fx.shocks) {
      final k = (t - sh.t) / 1.1, r0 = (20 + k * 320) * s;
      c.save();
      c.translate(sh.x, sh.y);
      c.rotate(-.35);
      c.scale(1, .22);
      c.drawCircle(Offset.zero, r0, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (6 * (1 - k) + 1) * s / .22 * .25
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFFFDCB4).withValues(alpha: (1 - k) * .8));
      c.drawCircle(Offset.zero, r0, Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(Offset.zero, r0, [const Color(0x00FFAA5A), const Color(0xFFFFAA5A).withValues(alpha: (1 - k) * .25)], [.6, 1]));
      c.restore();
    }
    // пыль переднего плана не в фокусе
    for (final m in fx.motes) {
      final p = Offset(m[0] * w + dx * m[2] * 3, m[1] * h);
      _glow(c, p, (m[2] * m[2] * 3 + 1) * s, const Color(0xFFC8BEE6), .08 + .06 / m[2]);
    }
    c.drawRect(rect, Paint()..shader = ui.Gradient.radial(Offset(w / 2, h / 2), w * .72, const [Color(0x00000000), Color(0xCC000000)], [h * .35 / (w * .72), 1]));
    final g = fx.grain;
    if (g != null) {
      final m = Matrix4.translationValues(_r(0, 128), _r(0, 128), 0).storage;
      c.drawRect(rect, Paint()
        ..shader = ImageShader(g, TileMode.repeated, TileMode.repeated, m)
        ..color = const Color(0x0BFFFFFF)
        ..blendMode = BlendMode.overlay);
    }
    if (!reduced && fx.flash > .01) {
      c.drawRect(rect, Paint()
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFFFEBD2).withValues(alpha: fx.flash * .55));
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => true;
}
