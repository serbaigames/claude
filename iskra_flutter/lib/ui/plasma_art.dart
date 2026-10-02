// Общая графика стиля «Звёздная плазма»: звезда-Искра, сущность-чёрная дыра, туманность, линза.
// Используется сценой боя и портретами в окнах Искры и сущности.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const _tau = math.pi * 2;
const _white = Color(0xFFFFFFFF);
const _sparkHalo = Color(0xFFFFA03C);

class Seeded {
  Seeded(this.s);
  int s;
  double call() {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  }
}

void plasmaGlow(Canvas cv, Offset c, double r, Color col, double a) {
  if (r <= 0 || a <= 0.003) return;
  cv.drawCircle(
    c,
    r,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(c, r, [col.withValues(alpha: a.clamp(0, 1)), col.withValues(alpha: 0)]),
  );
}

class _Ray {
  _Ray(Seeded r)
    : a = r() * _tau,
      l = .6 + r() * 1.1,
      w = .025 + r() * .05,
      ph = r() * 9,
      cold = r() < .3,
      dir = r() < .5 ? 1 : -1;
  final double a, l, w, ph;
  final bool cold;
  final int dir;
}

final _rays = (() {
  final r = Seeded(99);
  return List.generate(44, (_) => _Ray(r));
})();

/// Фон туманности размером [size] (логические пиксели), отрисованный один раз в картинку
ui.Image buildNebula(Size size, double dpr, {int seed = 9001}) {
  final W = size.width, H = size.height, k = math.min(2.0, dpr);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..scale(k);
  final r = Seeded(seed);
  c.drawRect(
    Rect.fromLTWH(0, 0, W, H),
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(W * .62, H * .38),
        W * .8,
        const [Color(0xFF120C28), Color(0xFF07051A), Color(0xFF020106)],
        [0, .6, 1],
      ),
  );
  double band(double x) => H * (.18 + .42 * (x / W));
  const neb = [Color(0xFF783CBE), Color(0xFF286EAA), Color(0xFFBE5064), Color(0xFF462882), Color(0xFF1E8CA0)];
  for (var i = 0; i < 70; i++) {
    final x = r() * W, y = band(x) + (r() - .5) * H * .55;
    plasmaGlow(c, Offset(x, y), W * (.03 + r() * .16), neb[(r() * neb.length).floor()], .028 + r() * .045);
  }
  final n = (900 * W * H / (700 * 400)).round();
  for (var i = 0; i < n; i++) {
    final x = r() * W, y = r() < .55 ? band(r() * W) + (r() - .5) * H * .5 : r() * H, br = math.pow(r(), 3).toDouble();
    final col = r() < .3 ? const Color(0xFFBED2FF) : (r() < .2 ? const Color(0xFFFFC8AA) : const Color(0xFFFFF8EB));
    c.drawRect(Rect.fromLTWH(x, y, .6 + br * 1.2, .6 + br * 1.2), Paint()..color = col.withValues(alpha: .12 + br * .85));
  }
  for (var i = 0; i < 28; i++) {
    final x = r() * W, y = band(x) + (r() - .5) * H * .18, rr = W * (.02 + r() * .07);
    c.drawCircle(
      Offset(x, y),
      rr,
      Paint()..shader = ui.Gradient.radial(Offset(x, y), rr, const [Color(0x8C020106), Color(0x00020106)]),
    );
  }
  // яркие звёзды с дифракционными лучами: число и размер от площади кадра
  final spikes = math.max(3, (14 * W * H / (700 * 400)).round()), ls = math.min(1.0, H / 400);
  for (var i = 0; i < spikes; i++) {
    final x = r() * W, y = r() * H, L = (4 + r() * 10) * ls;
    plasmaGlow(c, Offset(x, y), L * .9, const Color(0xFFDCE6FF), .5);
    final p = Paint()
      ..color = const Color(0x8CEBF0FF)
      ..blendMode = BlendMode.plus;
    c.drawRect(Rect.fromLTWH(x - L, y - .4, L * 2, .8), p);
    c.drawRect(Rect.fromLTWH(x - .4, y - L, .8, L * 2), p);
  }
  return rec.endRecording().toImageSync((W * k).ceil(), (H * k).ceil());
}

/// Гравитационная линза: фон, увеличенный и повёрнутый внутри круга
void paintLens(Canvas c, ui.Image bg, Rect src, Rect dst, Offset at, double r, double mag, double rot) {
  if (r <= 0) return;
  c.save();
  c.clipPath(Path()..addOval(Rect.fromCircle(center: at, radius: r)));
  c.translate(at.dx, at.dy);
  c.rotate(rot);
  c.scale(mag);
  c.translate(-at.dx, -at.dy);
  c.drawImageRect(bg, src, dst, Paint());
  c.restore();
  c.drawCircle(
    at,
    r,
    Paint()..shader = ui.Gradient.radial(at, r, const [Color(0x00000000), Color(0x00000000), Color(0x2EC8B4FF)], [0, .85, 1]),
  );
}

void paintJets(Canvas c, Offset o, double r, double t) {
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
          ..shader = ui.Gradient.linear(o, end, [
            const Color(0xFFAA96FF).withValues(alpha: .5 - i * .12),
            const Color(0x007864FF),
          ]),
      );
    }
    for (var k = 0; k < 5; k++) {
      final u = (t * .8 + k / 5) % 1;
      plasmaGlow(c, o + Offset(sd * len * .18 * u, -sd * len * u), r * .12 * (1 - u) + 2, const Color(0xFFBEAAFF), .5 * (1 - u));
    }
  }
}

/// Сущность: чёрная дыра с аккреционным диском в цвете ранга
void paintBlackHole(Canvas c, Offset o, double r, double t, Color tier) {
  if (r <= 1) return;
  plasmaGlow(c, o, r * 2.4, tier, .18);
  c.drawCircle(
    o,
    r * .66,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .16
      ..blendMode = BlendMode.plus
      ..color = Color.lerp(tier, _white, .3)!.withValues(alpha: .55),
  );
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
          ..shader = ui.Gradient.linear(Offset(o.dx - rad, o.dy), Offset(o.dx + rad, o.dy), [
            col.withValues(alpha: al),
            col.withValues(alpha: al * .35),
          ]),
      );
    }
    for (var j = 0; j < 26; j++) {
      final rad = r * (.75 + (j * .037) % 1), a = (j * 1.3 + t * (1.6 / (rad / r))) % _tau, sy = math.sin(a);
      if ((sy < 0) != back) continue;
      plasmaGlow(c, o + Offset(math.cos(a) * rad, sy * rad * .24), r * .07, const Color(0xFFFFE6BE), .8);
    }
  }

  disk(true);
  c.drawCircle(o, r * .57, Paint()..color = const Color(0xFF000000));
  c.drawCircle(
    o,
    r * .585,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * .025)
      ..blendMode = BlendMode.plus
      ..color = const Color(0xF2FFECD2),
  );
  disk(false);
}

/// Искра: звезда с короной, протуберанцами и горячим ядром
void paintSparkStar(Canvas c, Offset o, double r, double t, double charge, {double speed = 1}) {
  plasmaGlow(c, o, r * (3 + charge * 1.5), _sparkHalo, .22 + .25 * charge);
  for (final q in _rays) {
    final a = q.a + t * .12 * q.dir * speed, len = r * q.l * (1 + .25 * math.sin(t * 3 + q.ph)) * (1 + charge * .7), wd = r * q.w;
    final tip = o + Offset(math.cos(a), math.sin(a)) * len * 1.6;
    c.drawPath(
      Path()
        ..moveTo(o.dx + math.cos(a + 1.57) * wd, o.dy + math.sin(a + 1.57) * wd)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(o.dx + math.cos(a - 1.57) * wd, o.dy + math.sin(a - 1.57) * wd)
        ..close(),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(
          o,
          tip,
          [const Color(0xF2FFFFFF), q.cold ? const Color(0x8CAAC8FF) : const Color(0x99FFCD78), const Color(0x00FFAA3C)],
          [0, .35, 1],
        ),
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
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lw
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..color = Color.fromRGBO(255, 150 + k * 20, 70, al),
      );
    }
  }
  c.drawCircle(
    o,
    r * .75,
    Paint()
      ..shader = ui.Gradient.radial(
        o - Offset(r * .2, r * .2),
        r * .8,
        const [Color(0xFFFFFFFF), Color(0xFFFFF0C8), Color(0xFFFFBE55), Color(0xFFFF8A2A)],
        [0, .5, .85, 1],
      ),
  );
  for (var k = 0; k < 8; k++) {
    final a = k * .8 + t * .5, d = r * (.2 + .4 * ((k * 37) % 10) / 10);
    plasmaGlow(c, o + Offset(math.cos(a), math.sin(a)) * d, r * .18, const Color(0xFFFFFFE6), .35);
  }
  plasmaGlow(c, o, r * .55, _white, .9);
}
