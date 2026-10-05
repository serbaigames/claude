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
    'Латунное сердце: шестерни, заклёпки, топка и пар.',
    Color(0xFFD9A441),
    'iskra_skin_steampunk',
  ),
  Skin.gothic: SkinInfo(
    'Готика',
    'Роза-витраж в каменной оправе с шипами, свет сквозь цветное стекло.',
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

/* ---------- стимпанк: латунное сердце ---------- */

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

void _brassGear(Canvas c, Offset o, double ro, int n, double rot, {bool copper = false}) {
  final g = _gear(o, ro, ro * .84, n, rot);
  final hi = copper ? const Color(0xFFF0A070) : const Color(0xFFF6D88A);
  final lo = copper ? const Color(0xFF7A3418) : const Color(0xFF7A4E1C);
  c.drawPath(
    g,
    Paint()..shader = ui.Gradient.linear(o - Offset(ro, ro), o + Offset(ro, ro), [hi, Color.lerp(hi, lo, .5)!, lo], [0, .5, 1]),
  );
  c.drawPath(
    g,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.8, ro * .035)
      ..color = const Color(0xFF2A1708),
  );
}

void _steampunk(Canvas c, Offset o, double r, double t, double charge, double speed) {
  final rot = t * .35 * speed, fire = .75 + .25 * math.sin(t * 7) * math.sin(t * 3.1) + charge * .5;
  plasmaGlow(c, o, r * (2.8 + charge * 1.2), const Color(0xFFFF8A2A), .2 + .2 * charge);
  // пар из клапанов поднимается вверх
  for (var k = 0; k < _n(7); k++) {
    final u = (t * .22 * speed + k / 7) % 1, side = k.isEven ? -1.0 : 1.0;
    final p = o + Offset(side * r * (.75 + .25 * u) + math.sin(t * 1.3 + k) * r * .15, -r * .55 - u * r * 2);
    _puff(c, p, r * (.2 + u * .55), const Color(0xFFEDE6DA), .45 * (1 - u) * (u < .1 ? u * 10 : 1));
  }
  // малая шестерня сбоку, сцеплена с большой
  final sat = o + _polar(-.7, r * 1.28);
  _brassGear(c, sat, r * .42, 9, -rot * 12 / 9 + .2, copper: true);
  c.drawCircle(sat, r * .1, Paint()..color = const Color(0xFF2A1708));
  // большая шестерня с окном топки
  _brassGear(c, o, r, 14, rot);
  final hole = r * .7;
  c.drawCircle(o, hole, Paint()..color = const Color(0xFF1E1008));
  // огонь в топке
  c.drawCircle(
    o,
    hole * .96,
    Paint()
      ..shader = ui.Gradient.radial(
        o,
        hole,
        [
          Color.lerp(const Color(0xFFFFF4D0), const Color(0xFFFFFFFF), charge)!.withValues(alpha: (fire).clamp(0, 1)),
          const Color(0xFFFFA030).withValues(alpha: (.9 * fire).clamp(0, 1)),
          const Color(0xFFB8300C).withValues(alpha: (.85 * fire).clamp(0, 1)),
          const Color(0xFF3A0E04),
        ],
        [0, .35, .75, 1],
      ),
  );
  for (var k = 0; k < _n(6); k++) {
    final a = k * 1.9 + t * (1.5 + k * .3), d = hole * (.25 + .5 * ((k * 37) % 10) / 10);
    plasmaGlow(c, o + _polar(a, d), r * .14, const Color(0xFFFFD27A), .5 * fire);
  }
  // спицы колеса крутятся вместе с шестернёй
  final spoke = Paint()
    ..strokeWidth = r * .1
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFB8843A);
  final edge = Paint()
    ..strokeWidth = r * .14
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF2A1708);
  for (final p in [edge, spoke]) {
    for (var k = 0; k < 5; k++) {
      final a = rot + k * _tau / 5;
      c.drawLine(o + _polar(a, r * .2), o + _polar(a, hole * .98), p);
    }
  }
  // ободок окна и заклёпки
  c.drawCircle(
    o,
    hole,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .07
      ..color = const Color(0xFF8A5A22),
  );
  for (var k = 0; k < 12; k++) {
    final p = o + _polar(rot + (k + .5) * _tau / 12, r * .77);
    c.drawCircle(p, r * .035, Paint()..color = const Color(0xFF3A220C));
    c.drawCircle(p - Offset(r * .01, r * .01), r * .02, Paint()..color = const Color(0xFFFFE6A8));
  }
  // встречная шестерёнка в центре
  _brassGear(c, o, r * .3, 8, -rot * 1.8, copper: true);
  c.drawCircle(o, r * .1, Paint()..color = const Color(0xFF2A1708));
  c.drawCircle(o, r * .05, Paint()..color = const Color(0xFFFFD27A));
  plasmaGlow(c, o, r * .9, const Color(0xFFFFB050), .25 + .3 * charge);
}

/* ---------- готика: роза-витраж ---------- */

const _glass = [Color(0xFFC21E3A), Color(0xFF2347B8), Color(0xFF7A2FB0), Color(0xFFE0A030)];

/// Стрельчатое окно-лепесток вдоль оси x: от r0 до r1, ширина hw
Path _lancet(double r0, double r1, double hw) => Path()
  ..moveTo(r0, -hw * .35)
  ..lineTo(r1 * .62, -hw)
  ..quadraticBezierTo(r1 * .9, -hw * .9, r1, 0)
  ..quadraticBezierTo(r1 * .9, hw * .9, r1 * .62, hw)
  ..lineTo(r0, hw * .35)
  ..close();

void _gothic(Canvas c, Offset o, double r, double t, double charge, double speed) {
  final rot = t * .07 * speed, beat = .5 + .5 * math.sin(t * 1.4);
  plasmaGlow(c, o, r * (3.2 + charge), const Color(0xFF5A2A8C), .2);
  plasmaGlow(c, o, r * (2.2 + charge), const Color(0xFFB0203C), .22 + .2 * charge);
  // пепел и угольки вокруг
  for (var k = 0; k < _n(8); k++) {
    final u = (t * .12 + k / 8) % 1, a = k * 2.4 + t * .1;
    plasmaGlow(c, o + _polar(a, r * (1.2 + u * 1.3)), r * .08, const Color(0xFFFF5A6A), .55 * math.sin(u * math.pi));
  }
  // венец из шипов
  final thorns = Path();
  const n = 16;
  for (var i = 0; i < n; i++) {
    final a = -rot * 1.5 + i * _tau / n, l = r * (1.28 + .1 * math.sin(t * 2 + i * 1.7) + (i.isEven ? .14 : 0));
    final p0 = o + _polar(a - .13, r * .9), tip = o + _polar(a + .04, l), p1 = o + _polar(a + .13, r * .9);
    thorns
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(o.dx + math.cos(a - .02) * r * 1.1, o.dy + math.sin(a - .02) * r * 1.1, tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..close();
  }
  c.drawPath(thorns, Paint()..color = const Color(0xFF1A0B1E));
  c.drawPath(
    thorns,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.8, r * .02)
      ..color = const Color(0xFF8C2A44).withValues(alpha: .8),
  );
  // каменная оправа
  c.drawCircle(
    o,
    r * .98,
    Paint()..shader = ui.Gradient.radial(o, r, const [Color(0xFF3A3040), Color(0xFF241C2A), Color(0xFF4A3E52)], [.8, .9, 1]),
  );
  // лепестки витража
  final lead = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1, r * .035)
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF0E0810);
  const petals = 8;
  for (var i = 0; i < petals; i++) {
    final a = rot + i * _tau / petals, col = _glass[i % _glass.length];
    final lit = (.55 + .3 * math.sin(t * 1.1 + i * .9) + .25 * charge).clamp(0.0, 1.0);
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(a);
    final p = _lancet(r * .22, r * .88, r * .27);
    c.drawPath(
      p,
      Paint()
        ..shader = ui.Gradient.linear(Offset(r * .2, 0), Offset(r * .9, 0), [
          Color.lerp(col, const Color(0xFFFFF0E0), .45 * lit)!,
          Color.lerp(col, const Color(0xFF000000), .45 - .3 * lit)!,
        ]),
    );
    // средник посередине лепестка
    c.drawLine(Offset(r * .3, 0), Offset(r * .8, 0), lead..strokeWidth = math.max(.8, r * .02));
    c.drawPath(p, lead..strokeWidth = math.max(1, r * .035));
    c.restore();
    // круглое окошко между лепестками
    final q = o + _polar(a + _tau / petals / 2, r * .74), qc = _glass[(i + 2) % _glass.length];
    c.drawCircle(q, r * .09, Paint()..color = Color.lerp(qc, const Color(0xFFFFF0D0), .3 * lit)!);
    c.drawCircle(q, r * .09, lead);
  }
  // свет сквозь стекло
  plasmaGlow(c, o, r * .9, const Color(0xFFFF6A80), .22 + .25 * charge + .08 * beat);
  // рубиновая середина
  c.drawCircle(
    o,
    r * .21,
    Paint()
      ..shader = ui.Gradient.radial(
        o - Offset(r * .05, r * .05),
        r * .22,
        const [Color(0xFFFFE0E6), Color(0xFFE0203C), Color(0xFF50060F)],
        [0, .45, 1],
      ),
  );
  c.drawCircle(o, r * .21, lead);
  plasmaGlow(c, o, r * .35, const Color(0xFFFFB0C0), .35 + .3 * beat);
}

/* ---------- биология: живая клетка ---------- */

double _membrane(double a, double r, double t) => r * (.88 + .05 * math.sin(3 * a + t * 1.3) + .03 * math.sin(5 * a - t * 2.1));

void _bio(Canvas c, Offset o, double r, double t, double charge, double speed) {
  final tt = t * speed, breath = 1 + .04 * math.sin(tt * 1.6) + .05 * charge;
  final rr = r * breath;
  plasmaGlow(c, o, r * (2.7 + charge), const Color(0xFF3CE07A), .2 + .2 * charge);
  // жгутик: длинная волна в одну сторону
  final fa = math.pi * .8 + .3 * math.sin(tt * .4);
  final fl = Path();
  for (var i = 0; i <= 24; i++) {
    final u = i / 24, d = _membrane(fa, rr, tt) + u * r * 1.5, w = math.sin(u * 9 - tt * 6) * r * .14 * u;
    final p = o + _polar(fa, d) + _polar(fa + math.pi / 2, w);
    i == 0 ? fl.moveTo(p.dx, p.dy) : fl.lineTo(p.dx, p.dy);
  }
  c.drawPath(
    fl,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * .05)
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xCCB8FFCF),
  );
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
