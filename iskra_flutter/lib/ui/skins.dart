// Стили Искры: как выглядит сама Искра на карте, в бою и в окне Искры.
// «Звёздная плазма» — стиль по умолчанию, остальные покупаются в магазине (меняют только вид, не игру).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'gfx.dart';
import 'plasma_art.dart';

const _tau = math.pi * 2;

enum Skin { plasma, steampunk, gothic, bio, crystal }

class SkinInfo {
  const SkinInfo(this.titleRu, this.aboutRu, this.accent, [this.product]);
  final String titleRu, aboutRu;
  String get title => tx(titleRu);
  String get about => tx(aboutRu);
  final Color accent;

  /// Товар в магазине; null — стиль бесплатный
  final String? product;
}

const skinInfo = {
  Skin.plasma: SkinInfo('Звёздная плазма', 'Звезда с короной и протуберанцами. Стиль по умолчанию.', Color(0xFFFFB050)),
  Skin.steampunk: SkinInfo(
    'Стимпанк',
    'Часовой механизм в стеклянной сфере: шестерни, искры и льющийся металл.',
    Color(0xFFD9A441),
    'iskra_skin_steampunk',
  ),
  Skin.gothic: SkinInfo(
    'Готика',
    'Багровая сфера в кольце скал и пиков, на вершине — собор с горящими окнами.',
    Color(0xFFD23C5A),
    'iskra_skin_gothic',
  ),
  Skin.bio: SkinInfo(
    'Биология',
    'Живая клетка: дышащая мембрана, ядро, митохондрии и реснички.',
    Color(0xFF5EE38A),
    'iskra_skin_bio',
  ),
  Skin.crystal: SkinInfo(
    'Кристалл',
    'Ледяной самоцвет: грани ловят свет и рассыпают радугу.',
    Color(0xFF7CD4FF),
    'iskra_skin_crystal',
  ),
};

class Skins {
  /// Выбранный стиль: его читают все места, где рисуется Искра
  static Skin current = Skin.plasma;

  static Skin parse(String? v) => Skin.values.firstWhere((s) => s.name == v, orElse: () => Skin.plasma);
}

/// Искра в выбранном стиле (или в [skin], если задан — для витрины магазина)
void paintSpark(Canvas c, Offset o, double r, double t, double charge, {double speed = 1, int rays = 44, Skin? skin}) {
  switch (skin ?? Skins.current) {
    case Skin.plasma:
      paintSparkStar(c, o, r, t, charge, speed: speed, rays: rays);
    case Skin.steampunk:
      _steampunk(c, o, r, t, charge, speed);
    case Skin.gothic:
      _gothic(c, o, r, t, charge, speed);
    case Skin.bio:
      _bio(c, o, r, t, charge, speed);
    case Skin.crystal:
      _crystal(c, o, r, t, charge, speed);
  }
}

int _n(int full) => math.max(1, (full * Gfx.density).round());

Offset _polar(double a, double d) => Offset(math.cos(a), math.sin(a)) * d;

/// Мягкое облачко (пар, пепел) обычным, а не сложением цветов смешиванием
void _puff(Canvas c, Offset p, double r, Color col, double a) {
  if (a <= .003 || r <= 0) return;
  if (!Gfx.gradients) {
    c.drawCircle(p, r * .6, Paint()..color = col.withValues(alpha: a * .6));
    return;
  }
  c.drawCircle(p, r, Paint()..shader = ui.Gradient.radial(p, r, [col.withValues(alpha: a), col.withValues(alpha: 0)]));
}

/* ---------- стимпанк: часовой механизм в прозрачной сфере ---------- */

Path _gear(Offset o, double ro, double ri, int n, double rot) {
  final p = Path(), w = _tau / n;
  for (var i = 0; i < n; i++) {
    final a = rot + i * w;
    final pts = [o + _polar(a, ri), o + _polar(a + w * .16, ro), o + _polar(a + w * .42, ro), o + _polar(a + w * .58, ri)];
    for (var j = 0; j < pts.length; j++) {
      i == 0 && j == 0 ? p.moveTo(pts[j].dx, pts[j].dy) : p.lineTo(pts[j].dx, pts[j].dy);
    }
  }
  return p..close();
}

/// Колесо часового механизма: зубчатый обод, спицы и ступица; [dim] — дальний слой, темнее
void _watchGear(Canvas c, Offset o, double ro, int teeth, double rot, {bool copper = false, double dim = 0}) {
  final hi = Color.lerp(copper ? const Color(0xFFF0A070) : const Color(0xFFF6D88A), const Color(0xFF2A160A), dim)!;
  final lo = Color.lerp(copper ? const Color(0xFF7A3418) : const Color(0xFF7A4E1C), const Color(0xFF140A04), dim)!;
  final fill = Paint()
    ..shader = ui.Gradient.linear(o - Offset(ro, ro), o + Offset(ro, ro), [hi, Color.lerp(hi, lo, .5)!, lo], [0, .5, 1]);
  final rim = Path()
    ..fillType = PathFillType.evenOdd
    ..addPath(_gear(o, ro, ro * .86, teeth, rot), Offset.zero)
    ..addOval(Rect.fromCircle(center: o, radius: ro * .68));
  c.drawPath(rim, fill);
  final spokes = teeth > 12 ? 5 : 4;
  final sp = Paint()
    ..strokeWidth = ro * .13
    ..strokeCap = StrokeCap.round
    ..shader = fill.shader;
  for (var k = 0; k < spokes; k++) {
    final a = rot + k * _tau / spokes;
    c.drawLine(o + _polar(a, ro * .16), o + _polar(a, ro * .7), sp);
  }
  c.drawCircle(o, ro * .2, fill);
  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(.6, ro * .03)
    ..color = const Color(0xFF1E0F05).withValues(alpha: 1 - dim * .5);
  c.drawPath(rim, edge);
  c.drawCircle(o, ro * .07, Paint()..color = dim > .3 ? const Color(0xFF4A1010) : const Color(0xFFE0304A));
}

void _steampunk(Canvas c, Offset o, double r, double t, double charge, double speed) {
  final rot = t * .45 * speed, R = r * .88;
  plasmaGlow(c, o, r * (2.6 + charge * 1.2), const Color(0xFFFF8A2A), .18 + .2 * charge);
  // латунное кольцо вокруг сферы, как у планеты: задняя половина за сферой
  const tilt = -.32;
  final ringRect = Rect.fromCenter(center: Offset.zero, width: r * 2.7, height: r * .62);
  void ring(bool back) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(tilt);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .09
      ..shader = ui.Gradient.linear(
        Offset(-r * 1.35, 0),
        Offset(r * 1.35, 0),
        [const Color(0xFF7A4E1C), const Color(0xFFF6D88A), const Color(0xFF7A4E1C)],
        [0, .45, 1],
      );
    c.drawArc(ringRect, back ? math.pi : 0, math.pi, false, p);
    // деления на кольце бегут по кругу
    for (var k = 0; k < 24; k++) {
      final a = (k / 24 * _tau + rot * .5) % _tau;
      if ((math.sin(a) < 0) != back) continue;
      final q = Offset(math.cos(a) * r * 1.35, math.sin(a) * r * .31);
      c.drawCircle(q, r * .022, Paint()..color = const Color(0xFF2A1708));
    }
    c.restore();
  }

  ring(true);
  c.save();
  c.clipPath(Path()..addOval(Rect.fromCircle(center: o, radius: R)));
  // глубина корпуса
  c.drawCircle(
    o,
    R,
    Paint()
      ..shader = ui.Gradient.radial(
        o - Offset(R * .15, R * .2),
        R * 1.1,
        const [Color(0xFF4A2A14), Color(0xFF22120A), Color(0xFF080403)],
        [0, .6, 1],
      ),
  );
  // дальний слой механизма
  _watchGear(c, o + Offset(-R * .42, -R * .38), R * .4, 16, -rot * .6, dim: .55);
  _watchGear(c, o + Offset(R * .5, R * .3), R * .34, 14, rot * .7, dim: .55);
  _watchGear(c, o + Offset(R * .35, -R * .55), R * .22, 10, -rot * 1.1, copper: true, dim: .55);
  // расплавленный металл льётся сверху в ванну на дне сферы
  final pourX = o.dx - R * .18, pourTop = o.dy - R, poolY = o.dy + R * .6;
  final wob = math.sin(t * 3) * R * .02;
  final stream = Path()
    ..moveTo(pourX - R * .08, pourTop)
    ..quadraticBezierTo(pourX - R * .03 + wob, (pourTop + poolY) / 2, pourX - R * .06, poolY)
    ..lineTo(pourX + R * .06, poolY)
    ..quadraticBezierTo(pourX + R * .04 + wob, (pourTop + poolY) / 2, pourX + R * .08, pourTop)
    ..close();
  c.drawPath(
    stream,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(pourX - R * .05, 0),
        Offset(pourX + R * .05, 0),
        const [Color(0xFFB8300C), Color(0xFFFFE28A), Color(0xFFB8300C)],
        [0, .5, 1],
      ),
  );
  for (var k = 0; k < 5; k++) {
    final u = (t * 1.4 + k / 5) % 1;
    plasmaGlow(c, Offset(pourX + wob * u, pourTop + (poolY - pourTop) * u), R * .07, const Color(0xFFFFD27A), .7);
  }
  final pool = Path()..moveTo(o.dx - R, poolY);
  for (var i = 0; i <= 20; i++) {
    final x = o.dx - R + i / 20 * R * 2;
    pool.lineTo(x, poolY + math.sin(i * .9 + t * 2.5) * R * .025);
  }
  pool
    ..lineTo(o.dx + R, o.dy + R)
    ..lineTo(o.dx - R, o.dy + R)
    ..close();
  c.drawPath(
    pool,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, poolY),
        Offset(0, o.dy + R),
        const [Color(0xFFFFC04A), Color(0xFFD2501A), Color(0xFF5A1206)],
        [0, .35, 1],
      ),
  );
  plasmaGlow(c, Offset(pourX, poolY), R * .5, const Color(0xFFFF8A2A), .45 + .2 * math.sin(t * 4));
  // ближний слой: большое колесо, сцепленное с малым, и баланс
  final big = o + Offset(R * .12, -R * .08), small = big + _polar(2.6, R * .62);
  _watchGear(c, big, R * .52, 18, rot);
  _watchGear(c, small, R * .26, 9, -rot * 2 + .17, copper: true);
  final bal = o + Offset(R * .55, -R * .1), swing = math.sin(t * 5 * speed) * 1.2;
  c.drawCircle(
    bal,
    R * .2,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = R * .035
      ..color = const Color(0xFFE6C070),
  );
  c.drawLine(
    bal + _polar(swing, R * .2),
    bal - _polar(swing, R * .2),
    Paint()
      ..strokeWidth = R * .03
      ..color = const Color(0xFFE6C070),
  );
  // искры в местах зацепления: короткие вспышки
  final hits = [big + _polar(2.6, R * .48), o + Offset(-R * .1, -R * .55), o + Offset(R * .32, R * .22)];
  for (var k = 0; k < hits.length; k++) {
    final ph = (t * (1.1 + k * .23) + k * .37) % 1;
    if (ph > .18) continue;
    final f = 1 - ph / .18, p = hits[k];
    plasmaGlow(c, p, R * .16 * f + 2, const Color(0xFFFFE6A0), .9 * f);
    final line = Paint()
      ..strokeWidth = math.max(.6, R * .015)
      ..blendMode = BlendMode.plus
      ..color = const Color(0xFFFFD27A).withValues(alpha: f);
    for (var j = 0; j < 6; j++) {
      final a = j * 1.05 + k;
      c.drawLine(p + _polar(a, R * .03), p + _polar(a, R * (.06 + .12 * (1 - f))), line);
    }
  }
  c.restore();
  // стекло корпуса: блики и кромка
  c.drawCircle(
    o,
    R,
    Paint()..shader = ui.Gradient.radial(o, R, const [Color(0x00FFFFFF), Color(0x00FFFFFF), Color(0x40CFE8FF)], [0, .78, 1]),
  );
  c.drawArc(
    Rect.fromCircle(center: o, radius: R * .84),
    math.pi * 1.08,
    math.pi * .42,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = R * .07
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x55FFFFFF),
  );
  c.drawOval(
    Rect.fromCenter(center: o + Offset(R * .4, R * .5), width: R * .22, height: R * .1),
    Paint()..color = const Color(0x30FFFFFF),
  );
  c.drawCircle(
    o,
    R,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .08
      ..shader = ui.Gradient.linear(
        o - Offset(R, R),
        o + Offset(R, R),
        const [Color(0xFFF6D88A), Color(0xFFA06A28), Color(0xFF5A3410)],
        [0, .5, 1],
      ),
  );
  for (var k = 0; k < 16; k++) {
    c.drawCircle(o + _polar(k * _tau / 16, R), r * .022, Paint()..color = const Color(0xFFFFE6A8));
  }
  ring(false);
}

/* ---------- готика: багровая сфера, скалы, пики и собор ---------- */

/// Силуэт собора в единицах u, основание в точке (0, 0), вверх — минус y
Path _cathedral(double u) {
  Rect rr(double x0, double y0, double x1, double y1) => Rect.fromLTRB(x0 * u, y0 * u, x1 * u, y1 * u);
  Path spire(double x, double w, double base, double tip) => Path()
    ..moveTo((x - w) * u, base * u)
    ..lineTo(x * u, tip * u)
    ..lineTo((x + w) * u, base * u)
    ..close();
  final p = Path()
    // неф с крутой крышей
    ..addRect(rr(-2.2, -3, 2.2, .6))
    ..addPath(
      Path()
        ..moveTo(-2.4 * u, -3 * u)
        ..lineTo(0, -4.6 * u)
        ..lineTo(2.4 * u, -3 * u)
        ..close(),
      Offset.zero,
    )
    // две башни и шпили
    ..addRect(rr(-3.5, -5.6, -2.2, .6))
    ..addRect(rr(2.2, -5.6, 3.5, .6))
    ..addPath(spire(-2.85, .75, -5.6, -8.4), Offset.zero)
    ..addPath(spire(2.85, .75, -5.6, -8.4), Offset.zero)
    // центральный шпиль
    ..addRect(rr(-.55, -5.4, .55, -3.4))
    ..addPath(spire(0, .65, -5.4, -10), Offset.zero)
    // пинакли и аркбутаны
    ..addPath(spire(-4.4, .3, -1.6, -3.6), Offset.zero)
    ..addPath(spire(4.4, .3, -1.6, -3.6), Offset.zero)
    ..addRect(rr(-4.6, -1.6, -4.2, .6))
    ..addRect(rr(4.2, -1.6, 4.6, .6));
  for (final x in [-3.6, -1.8, 1.8, 3.6]) {
    p.addPath(spire(x, .14, -2.4, -3.3), Offset.zero);
  }
  return p;
}

/// Стрельчатое окно
Path _arch(double x, double y, double w, double h) => Path()
  ..moveTo(x - w, y)
  ..lineTo(x - w, y - h * .6)
  ..quadraticBezierTo(x - w, y - h, x, y - h * 1.08)
  ..quadraticBezierTo(x + w, y - h, x + w, y - h * .6)
  ..lineTo(x + w, y)
  ..close();

void _gothic(Canvas c, Offset o, double r, double t, double charge, double speed) {
  final R = r * .74, sway = math.sin(t * .35 * speed) * .07;
  final flick = .75 + .25 * math.sin(t * 9) * math.sin(t * 5.3) + .3 * charge;
  plasmaGlow(c, o, r * (3.2 + charge), const Color(0xFF6A0A1A), .25);
  plasmaGlow(c, o, r * (2.1 + charge), const Color(0xFFD0203A), .2 + .2 * charge);
  // пепел и угли поднимаются от сферы
  for (var k = 0; k < _n(10); k++) {
    final u = (t * .14 + k / 10) % 1, x = math.sin(k * 2.7 + t * .5) * r * (.6 + .5 * u);
    plasmaGlow(c, o + Offset(x, R * .4 - u * r * 2.4), r * .07, const Color(0xFFFF4A3A), .6 * math.sin(u * math.pi));
  }
  c.save();
  c.translate(o.dx, o.dy);
  c.rotate(sway);
  // скалы-пики вокруг сферы, кроме места под собором
  final rnd = Seeded(77);
  final crag = Path();
  for (var i = 0; i < 15; i++) {
    final a = i * _tau / 15 + (rnd() - .5) * .25;
    final top = (a % _tau - math.pi * 1.5).abs() < .6;
    // скалы — короткие и широкие, через одну — острый высокий пик
    final pike = i.isEven && !top;
    final len = R * (top ? .18 + .1 * rnd() : (pike ? .95 + .45 * rnd() : .35 + .25 * rnd()));
    final w = pike ? .13 + .05 * rnd() : .2 + .1 * rnd();
    final b0 = _polar(a - w, R * .95), b1 = _polar(a + w, R * .95), tip = _polar(a + (rnd() - .5) * .1, R + len);
    final m0 = _polar(a - w * .55, R + len * (.35 + .2 * rnd())), m1 = _polar(a + w * .45, R + len * (.5 + .2 * rnd()));
    crag
      ..moveTo(b0.dx, b0.dy)
      ..lineTo(m0.dx, m0.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(m1.dx, m1.dy)
      ..lineTo(b1.dx, b1.dy)
      ..close();
  }
  c.drawPath(
    crag,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(-R * 1.6, -R * 1.6),
        Offset(R * 1.6, R * 1.6),
        const [Color(0xFF5A2028), Color(0xFF2A0C12), Color(0xFF0E0407)],
        [0, .5, 1],
      ),
  );
  c.drawPath(
    crag,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.7, r * .018)
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFE0304A).withValues(alpha: .55 * flick.clamp(0, 1)),
  );
  // багровая сфера
  final sphere = Rect.fromCircle(center: Offset.zero, radius: R);
  c.drawOval(
    sphere,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(-R * .3, -R * .35),
        R * 1.3,
        const [Color(0xFF9A2230), Color(0xFF4A0C16), Color(0xFF14040A)],
        [0, .55, 1],
      ),
  );
  c.save();
  c.clipPath(Path()..addOval(sphere));
  // раскалённые трещины в коре
  final crack = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(.7, r * .022)
    ..strokeJoin = StrokeJoin.round
    ..blendMode = BlendMode.plus
    ..color = const Color(0xFFFF4A2A).withValues(alpha: (.45 + .35 * math.sin(t * 2)).clamp(0, 1));
  final cr = Seeded(5);
  for (var i = 0; i < 5; i++) {
    var p = _polar(cr() * _tau, R * (.2 + .6 * cr()));
    final path = Path()..moveTo(p.dx, p.dy);
    var a = cr() * _tau;
    for (var j = 0; j < 5; j++) {
      a += (cr() - .5) * 1.4;
      p += _polar(a, R * .16);
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, crack);
  }
  // багровый туман плывёт по сфере
  for (var k = 0; k < 3; k++) {
    final x = ((t * .08 + k * .37) % 1) * R * 3 - R * 1.5;
    _puff(c, Offset(x, R * (-.1 + .3 * k)), R * .55, const Color(0xFFB01A2A), .22);
  }
  c.restore();
  c.drawOval(
    sphere,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.8, r * .03)
      ..color = const Color(0xFFFF4A5A).withValues(alpha: .5),
  );
  // собор на вершине сферы
  final u = R * .115;
  c.save();
  c.translate(0, -R * .86);
  final cath = _cathedral(u);
  c.drawPath(cath, Paint()..color = const Color(0xFF12060A));
  c.drawPath(
    cath,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.6, r * .012)
      ..color = const Color(0xFFE0304A).withValues(alpha: .6),
  );
  final glass = Paint()..color = Color.lerp(const Color(0xFF8A0A18), const Color(0xFFFF7A50), flick.clamp(0, 1))!;
  for (final x in [-2.85, 2.85]) {
    c.drawPath(_arch(x * u, -3 * u, .32 * u, 1.6 * u), glass);
  }
  for (final x in [-1.3, 0.0, 1.3]) {
    c.drawPath(_arch(x * u, -.4 * u, .3 * u, 1.7 * u), glass);
  }
  c.drawCircle(Offset(0, -3.55 * u), .5 * u, glass);
  plasmaGlow(c, Offset(0, -2.5 * u), u * 4, const Color(0xFFFF3A3A), .25 * flick);
  c.restore();
  c.restore();
}

/* ---------- биология: живая клетка ---------- */

double _membrane(double a, double r, double t) => r * (.88 + .05 * math.sin(3 * a + t * 1.3) + .03 * math.sin(5 * a - t * 2.1));

void _bio(Canvas c, Offset o, double r, double t, double charge, double speed) {
  final tt = t * speed, breath = 1 + .04 * math.sin(tt * 1.6) + .05 * charge;
  final rr = r * breath;
  plasmaGlow(c, o, r * (2.7 + charge), const Color(0xFF3CE07A), .2 + .2 * charge);
  // реснички по краю
  final cil = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(.7, r * .022)
    ..strokeCap = StrokeCap.round
    ..color = const Color(0x99B8FFCF);
  final nc = _n(36);
  for (var i = 0; i < nc; i++) {
    final a = i * _tau / nc, b = _membrane(a, rr, tt), sw = .35 * math.sin(tt * 4 + i * .8);
    final p0 = o + _polar(a, b), p1 = o + _polar(a + sw * .12, b + r * .14), p2 = o + _polar(a + sw * .25, b + r * .24);
    c.drawPath(
      Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy),
      cil,
    );
  }
  // мембрана и цитоплазма
  final mem = Path();
  for (var i = 0; i <= 64; i++) {
    final a = i / 64 * _tau, p = o + _polar(a, _membrane(a, rr, tt));
    i == 0 ? mem.moveTo(p.dx, p.dy) : mem.lineTo(p.dx, p.dy);
  }
  mem.close();
  c.drawPath(
    mem,
    Paint()
      ..shader = ui.Gradient.radial(
        o - Offset(r * .2, r * .25),
        r,
        const [Color(0xE07CF0B0), Color(0xD035B884), Color(0xE01A6E58)],
        [0, .6, 1],
      ),
  );
  c.save();
  c.clipPath(mem);
  // рибосомы
  final rib = Paint()..color = const Color(0x99E6FFE0);
  for (var k = 0; k < _n(26); k++) {
    final a = k * 2.39996 + tt * .05, d = r * .8 * math.sqrt(((k * 53) % 26) / 26);
    c.drawCircle(o + _polar(a, d), math.max(.6, r * .018), rib);
  }
  // вакуоли
  for (var k = 0; k < 3; k++) {
    final p = o + _polar(k * 2.1 + tt * .12, r * .52);
    c.drawCircle(p, r * (.13 + .03 * k), Paint()..color = const Color(0x55DFFFF4));
    c.drawCircle(
      p,
      r * (.13 + .03 * k),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.6, r * .015)
        ..color = const Color(0x88FFFFFF),
    );
  }
  // митохондрии с кристами
  for (var k = 0; k < 4; k++) {
    final a = k * 1.57 + .8 + tt * .18, p = o + _polar(a, r * (.58 + .06 * math.sin(tt + k)));
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(a + tt * .3 + k);
    final box = Rect.fromCenter(center: Offset.zero, width: r * .3, height: r * .14);
    c.drawOval(box, Paint()..color = const Color(0xFFF2B44E));
    final zz = Path()..moveTo(-r * .12, 0);
    for (var j = 0; j < 6; j++) {
      zz.lineTo(-r * .12 + (j + .5) * r * .04, (j.isEven ? -1 : 1) * r * .045);
    }
    c.drawPath(
      zz,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.6, r * .015)
        ..color = const Color(0xFF8A4A10),
    );
    c.drawOval(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.6, r * .018)
        ..color = const Color(0xFF8A4A10),
    );
    c.restore();
  }
  c.restore();
  c.drawPath(
    mem,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, r * .06)
      ..color = const Color(0xCCC8FFDA),
  );
  // ядро с ядрышком
  final np = o + Offset(r * .06 * math.sin(tt * .5), -r * .04);
  final nr = r * (.3 + .02 * math.sin(tt * 2.2));
  plasmaGlow(c, np, nr * 1.8, const Color(0xFFC8A0FF), .3 + .25 * charge);
  c.drawCircle(
    np,
    nr,
    Paint()
      ..shader = ui.Gradient.radial(
        np - Offset(nr * .3, nr * .3),
        nr * 1.1,
        const [Color(0xFFD8C0FF), Color(0xFF7A4CD0), Color(0xFF3A2380)],
        [0, .6, 1],
      ),
  );
  c.drawCircle(
    np,
    nr,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.8, r * .03)
      ..color = const Color(0xFFE6D8FF),
  );
  c.drawCircle(np + Offset(nr * .25, nr * .15), nr * .32, Paint()..color = const Color(0xFF2A1660));
  plasmaGlow(c, np + Offset(nr * .25, nr * .15), nr * .5, const Color(0xFFFFFFFF), .25 + .3 * charge);
}

/* ---------- кристалл: ледяной самоцвет ---------- */

void _crystal(Canvas c, Offset o, double r, double t, double charge, double speed) {
  final rot = t * .12 * speed, light = t * .7;
  plasmaGlow(c, o, r * (3 + charge * 1.5), const Color(0xFF5AB4FF), .2 + .22 * charge);
  // радужные лучи преломления
  final nr = _n(12);
  for (var i = 0; i < nr; i++) {
    final a = rot * .5 + i * _tau / nr + .2 * math.sin(t * .8 + i),
        len = r * (1.5 + .5 * math.sin(t * 1.7 + i * 2.3) + charge * .6);
    final col = HSVColor.fromAHSV(1, (i * 360 / nr + t * 20) % 360, .55, 1).toColor();
    final tip = o + _polar(a, len), wd = r * .06;
    c.drawPath(
      Path()
        ..moveTo(o.dx + math.cos(a + 1.57) * wd, o.dy + math.sin(a + 1.57) * wd)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(o.dx + math.cos(a - 1.57) * wd, o.dy + math.sin(a - 1.57) * wd)
        ..close(),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(o, tip, [col.withValues(alpha: .8), col.withValues(alpha: 0)]),
    );
  }
  // осколки на орбите
  final orbit = <(Offset, bool)>[];
  for (var k = 0; k < 6; k++) {
    final a = -t * .4 * speed + k * _tau / 6, p = o + Offset(math.cos(a) * r * 1.45, math.sin(a) * r * .5);
    orbit.add((p, math.sin(a) < 0));
  }
  void shard(Offset p, bool back) {
    final s = r * (back ? .1 : .14);
    final d = Path()
      ..moveTo(p.dx, p.dy - s * 1.4)
      ..lineTo(p.dx + s * .7, p.dy)
      ..lineTo(p.dx, p.dy + s * 1.4)
      ..lineTo(p.dx - s * .7, p.dy)
      ..close();
    c.drawPath(d, Paint()..color = (back ? const Color(0xFF7FB8E0) : const Color(0xFFD8F4FF)));
    c.drawPath(
      d,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = const Color(0xFFFFFFFF),
    );
  }

  for (final (p, back) in orbit) {
    if (back) shard(p, true);
  }
  // самоцвет: шестигранник, внешние и внутренние грани освещены вращающимся светом
  final outer = [for (var i = 0; i < 6; i++) o + _polar(rot + i * _tau / 6 - math.pi / 2, r * .95)];
  final inner = [for (var i = 0; i < 6; i++) o + _polar(rot + i * _tau / 6 - math.pi / 2 + _tau / 12, r * .5)];
  Color shade(double faceA, double k) {
    final b = (.5 + .5 * math.cos(faceA - light)) * k;
    return Color.lerp(const Color(0xFF123A6A), const Color(0xFFCDEFFF), b.clamp(0, 1))!;
  }

  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(.8, r * .022)
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xCCFFFFFF);
  for (var i = 0; i < 6; i++) {
    final a0 = outer[i], a1 = outer[(i + 1) % 6], b0 = inner[(i + 5) % 6], b1 = inner[i];
    final fa = rot + (i + .5) * _tau / 6 - math.pi / 2;
    // внешний пояс: два треугольника на сторону
    final f1 = Path()
      ..moveTo(a0.dx, a0.dy)
      ..lineTo(a1.dx, a1.dy)
      ..lineTo(b1.dx, b1.dy)
      ..close();
    final f2 = Path()
      ..moveTo(a0.dx, a0.dy)
      ..lineTo(b1.dx, b1.dy)
      ..lineTo(b0.dx, b0.dy)
      ..close();
    c.drawPath(f1, Paint()..color = shade(fa, .95));
    c.drawPath(f2, Paint()..color = shade(fa - .5, .8));
    c.drawPath(f1, edge);
    c.drawPath(f2, edge);
  }
  for (var i = 0; i < 6; i++) {
    final f = Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(inner[i].dx, inner[i].dy)
      ..lineTo(inner[(i + 1) % 6].dx, inner[(i + 1) % 6].dy)
      ..close();
    c.drawPath(f, Paint()..color = shade(rot + i * _tau / 6 + math.pi, 1.1).withValues(alpha: .92));
    c.drawPath(f, edge);
  }
  plasmaGlow(c, o, r * .55, const Color(0xFFCFF4FF), .2 + .3 * charge);
  // блик на вершине, ближайшей к свету
  var best = 0;
  for (var i = 1; i < 6; i++) {
    if (math.cos(rot + i * _tau / 6 - math.pi / 2 - light) > math.cos(rot + best * _tau / 6 - math.pi / 2 - light)) best = i;
  }
  final g = outer[best], gl = r * (.35 + .15 * math.sin(t * 5));
  final glint = Paint()
    ..blendMode = BlendMode.plus
    ..color = const Color(0xCCFFFFFF);
  c.drawRect(Rect.fromCenter(center: g, width: gl * 2, height: math.max(1, r * .03)), glint);
  c.drawRect(Rect.fromCenter(center: g, width: math.max(1, r * .03), height: gl * 2), glint);
  plasmaGlow(c, g, gl * .6, const Color(0xFFFFFFFF), .6);
  for (final (p, back) in orbit) {
    if (!back) shard(p, false);
  }
}

/* ---------- поле: свои клетки, каналы, границы и частицы в цвет стиля ---------- */

class FieldLook {
  const FieldLook(this.land, this.glow, this.channel, this.pulse, this.wall, [this.tint]);

  /// Заливка своей территории, сгустки в ней, каналы и бегущие по ним импульсы, граница
  final Color land, glow, channel, pulse, wall;

  /// Оттенок фона карты (null — без оттенка)
  final Color? tint;
}

const fieldLooks = {
  Skin.plasma: FieldLook(Color(0xFFF2B441), Color(0xFFF2AA3C), Color(0x59FFC86E), Color(0xFFFFE6AA), Color(0xFFF2B441)),
  Skin.steampunk: FieldLook(
    Color(0xFFC98A3A),
    Color(0xFFE08A30),
    Color(0xFF8A5424),
    Color(0xFFFFB040),
    Color(0xFFD9A441),
    Color(0x668A5A2A),
  ),
  Skin.gothic: FieldLook(
    Color(0xFFB01A2A),
    Color(0xFFD0203A),
    Color(0x50FF3A4A),
    Color(0xFFFF7A5A),
    Color(0xFFE0304A),
    Color(0x808A0A1A),
  ),
  Skin.bio: FieldLook(
    Color(0xFF3CD07A),
    Color(0xFF3CE07A),
    Color(0x704CE08A),
    Color(0xFFB8FFCF),
    Color(0xFF5EE38A),
    Color(0x661A7A5A),
  ),
  Skin.crystal: FieldLook(
    Color(0xFF7CD4FF),
    Color(0xFF5AB4FF),
    Color(0x70A8E4FF),
    Color(0xFFFFFFFF),
    Color(0xFF9ADCFF),
    Color(0x662A5A9A),
  ),
};

FieldLook get fieldLook => fieldLooks[Skins.current]!;

/// Оттенок фона карты под стиль
void paintFieldTint(Canvas c, Rect area) {
  final tint = fieldLook.tint;
  if (tint == null) return;
  c.drawRect(
    area,
    Paint()
      ..color = tint
      ..blendMode = BlendMode.color,
  );
}

/// Узор внутри своей клетки (вызывается под обрезкой по территории)
void paintCellDecor(Canvas c, Offset p, double rc, double t, int seed) {
  switch (Skins.current) {
    case Skin.plasma:
      return;
    case Skin.steampunk:
      // большая тусклая шестерня под клеткой и пар из клапана
      final o = p + _polar(seed * 1.7, rc * .3);
      final g = _gear(o, rc * .62, rc * .54, 14, (seed.isEven ? 1 : -1) * t * .15 + seed);
      c.drawPath(
        g,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, rc * .03)
          ..color = const Color(0x40E6B060),
      );
      c.drawCircle(
        o,
        rc * .36,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, rc * .02)
          ..color = const Color(0x30E6B060),
      );
      if (seed % 3 == 0) {
        final u = (t * .25 + seed * .13) % 1;
        _puff(c, p + Offset(rc * .3, -rc * .1 - u * rc * .8), rc * (.12 + .25 * u), const Color(0xFFEDE6DA), .25 * (1 - u));
      }
    case Skin.gothic:
      // раскалённые трещины в камне и багровая дымка
      final r = Seeded(seed * 31 + 7);
      final crack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, rc * .025)
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFFF3A2A).withValues(alpha: .25 + .2 * math.sin(t * 1.5 + seed));
      for (var i = 0; i < 2; i++) {
        var q = p + _polar(r() * _tau, rc * .5 * r());
        var a = r() * _tau;
        final path = Path()..moveTo(q.dx, q.dy);
        for (var j = 0; j < 4; j++) {
          a += (r() - .5) * 1.5;
          q += _polar(a, rc * .18);
          path.lineTo(q.dx, q.dy);
        }
        c.drawPath(path, crack);
      }
      _puff(c, p + Offset(math.sin(t * .3 + seed) * rc * .3, 0), rc * .6, const Color(0xFF8A0A1A), .18);
    case Skin.bio:
      // ткань: соседние клетки-пузырьки с ядрышками
      final r = Seeded(seed * 17 + 3);
      for (var i = 0; i < 4; i++) {
        final q = p + _polar(r() * _tau + t * .05, rc * (.25 + .4 * r())),
            rr = rc * (.16 + .1 * r()) * (1 + .06 * math.sin(t * 2 + i));
        c.drawCircle(
          q,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, rc * .02)
            ..color = const Color(0x407CF0B0),
        );
        c.drawCircle(q + Offset(rr * .2, -rr * .1), rr * .25, Paint()..color = const Color(0x30B8A0FF));
      }
    case Skin.crystal:
      // грани: лучи к вершинам и внутренний шестиугольник, по граням бежит блик
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.8, rc * .015)
        ..color = const Color(0x40CFEFFF);
      final inner = Path();
      for (var i = 0; i < 6; i++) {
        final a = math.pi / 6 + i * math.pi / 3, v = p + _polar(a, rc * .95), w = p + _polar(a, rc * .45);
        c.drawLine(w, v, line);
        i == 0 ? inner.moveTo(w.dx, w.dy) : inner.lineTo(w.dx, w.dy);
      }
      c.drawPath(inner..close(), line);
      final k = ((t * .3 + seed * .17) % 1.6);
      if (k < 1) {
        final a = math.pi / 6 + (seed % 6) * math.pi / 3;
        plasmaGlow(c, p + _polar(a, rc * (.45 + .5 * k)), rc * .12, const Color(0xFFFFFFFF), .5 * math.sin(k * math.pi));
      }
  }
}

/// Канал между своими клетками: от ближней к Искре клетки [p0] к дальней [p1]
void paintChannel(Canvas c, Offset p0, Offset p1, double rc, double t, double phase) {
  final look = fieldLook;
  switch (Skins.current) {
    case Skin.steampunk:
      // медная труба, по ней течёт расплавленный металл
      c.drawLine(
        p0,
        p1,
        Paint()
          ..strokeWidth = rc * .1
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF5A3418),
      );
      c.drawLine(
        p0,
        p1,
        Paint()
          ..strokeWidth = rc * .04
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFB8743A),
      );
      for (final u in [.2, .5, .8]) {
        final q = Offset.lerp(p0, p1, u)!, n = (p1 - p0).direction + math.pi / 2;
        c.drawLine(
          q + _polar(n, rc * .07),
          q - _polar(n, rc * .07),
          Paint()
            ..strokeWidth = rc * .03
            ..color = const Color(0xFFD9A441),
        );
      }
    case Skin.bio:
      // сосуд: волнистая жилка
      final path = Path()..moveTo(p0.dx, p0.dy);
      final d = p1 - p0, n = _polar(d.direction + math.pi / 2, 1);
      for (var i = 1; i <= 12; i++) {
        final u = i / 12;
        final q = p0 + d * u + n * math.sin(u * math.pi * 2 + t * 2 + phase * 9) * rc * .05 * math.sin(u * math.pi);
        path.lineTo(q.dx, q.dy);
      }
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rc * .07
          ..strokeCap = StrokeCap.round
          ..color = look.channel,
      );
    default:
      c.drawLine(
        p0,
        p1,
        Paint()
          ..strokeWidth = rc * .06
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..color = look.channel,
      );
  }
  for (var j = 0; j < 2; j++) {
    final u = (t * .6 + j * .5 + phase) % 1;
    plasmaGlow(c, Offset.lerp(p0, p1, u)!, rc * .1, look.pulse, .9);
  }
}

/// Украшение внешней границы: [out] — единичный вектор наружу, [enemy] — за границей есть клетка тьмы
void paintWallDecor(Canvas c, Offset p0, Offset p1, Offset out, double rc, double t, bool enemy) {
  if (!enemy) return;
  switch (Skins.current) {
    case Skin.plasma:
      return;
    case Skin.steampunk:
      // заклёпки по шву
      for (final u in [.25, .5, .75]) {
        final q = Offset.lerp(p0, p1, u)!;
        c.drawCircle(q, rc * .03, Paint()..color = const Color(0xFFE6C070));
        c.drawCircle(q, rc * .015, Paint()..color = const Color(0xFF5A3418));
      }
    case Skin.gothic:
      // ряд острых пиков наружу
      final spikes = Path();
      for (final u in [.2, .5, .8]) {
        final q = Offset.lerp(p0, p1, u)!, along = (p1 - p0) / (p1 - p0).distance;
        final h = rc * (u == .5 ? .2 : .13);
        spikes
          ..moveTo(q.dx - along.dx * rc * .05, q.dy - along.dy * rc * .05)
          ..lineTo(q.dx + out.dx * h, q.dy + out.dy * h)
          ..lineTo(q.dx + along.dx * rc * .05, q.dy + along.dy * rc * .05)
          ..close();
      }
      c.drawPath(spikes, Paint()..color = const Color(0xFF2A0C12));
      c.drawPath(
        spikes,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFE0304A).withValues(alpha: .7),
      );
    case Skin.bio:
      // реснички шевелятся наружу
      final cil = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.8, rc * .015)
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x99B8FFCF);
      for (var i = 1; i < 6; i++) {
        final q = Offset.lerp(p0, p1, i / 6)!, sw = math.sin(t * 4 + i + q.dx * .05) * rc * .04;
        final along = (p1 - p0) / (p1 - p0).distance;
        c.drawPath(
          Path()
            ..moveTo(q.dx, q.dy)
            ..quadraticBezierTo(
              q.dx + out.dx * rc * .06 + along.dx * sw,
              q.dy + out.dy * rc * .06 + along.dy * sw,
              q.dx + out.dx * rc * .11 + along.dx * sw * 2,
              q.dy + out.dy * rc * .11 + along.dy * sw * 2,
            ),
          cil,
        );
      }
    case Skin.crystal:
      // ледяные осколки
      for (final u in [.33, .66]) {
        final q = Offset.lerp(p0, p1, u)!, along = (p1 - p0) / (p1 - p0).distance, h = rc * .14;
        final d = Path()
          ..moveTo(q.dx - along.dx * rc * .04, q.dy - along.dy * rc * .04)
          ..lineTo(q.dx + out.dx * h, q.dy + out.dy * h)
          ..lineTo(q.dx + along.dx * rc * .04, q.dy + along.dy * rc * .04)
          ..close();
        c.drawPath(d, Paint()..color = const Color(0xCCD8F4FF));
      }
  }
}

/// Частицы поверх карты: угли, пепел, споры, снежинки
void paintFieldAmbient(Canvas c, Size size, double t) {
  final skin = Skins.current;
  if (skin == Skin.plasma) return;
  final n = _n(26), r = Seeded(4242);
  for (var i = 0; i < n; i++) {
    final x0 = r() * size.width, y0 = r() * size.height, sp = .5 + r(), ph = r() * _tau;
    switch (skin) {
      case Skin.steampunk || Skin.gothic:
        // угли поднимаются
        final y = (y0 - t * 18 * sp) % size.height, x = x0 + math.sin(t * .8 + ph) * 12;
        final col = skin == Skin.gothic ? const Color(0xFFFF4A3A) : const Color(0xFFFFB050);
        plasmaGlow(c, Offset(x, y), 3 + 3 * sp, col, .35 + .3 * math.sin(t * 3 + ph));
      case Skin.bio:
        // споры плавают
        final p = Offset(
          (x0 + math.sin(t * .2 * sp + ph) * 30) % size.width,
          (y0 + math.cos(t * .17 * sp + ph) * 24) % size.height,
        );
        c.drawCircle(p, 1.5 + 1.5 * sp, Paint()..color = const Color(0x66B8FFCF));
      case Skin.crystal:
        // снежинки опускаются и мерцают
        final y = (y0 + t * 10 * sp) % size.height, x = x0 + math.sin(t * .6 + ph) * 10;
        plasmaGlow(c, Offset(x, y), 2.5 + 2 * sp, const Color(0xFFDFF4FF), .3 + .4 * math.max(0, math.sin(t * 2 + ph)));
      case Skin.plasma:
        return;
    }
  }
}

/// Звезда-колония своей клетки вблизи — в стиле Искры, но скромнее
void paintColony(Canvas c, Offset p, double r, double t) {
  if (Skins.current == Skin.plasma) {
    paintSparkStar(c, p, r, t, .1, rays: 18, flares: false);
  } else {
    paintSpark(c, p, r * .85, t, 0, speed: .6);
  }
}
