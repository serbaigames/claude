// Графика поля и окна своей клетки в стиле «Звёздная плазма»: строения (узлы и спутники), кольцо долей, мёртвый диск.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'plasma_art.dart';
import 'theme.dart';

const _tau = math.pi * 2;

/// Цвета строений: шахта — золото, завод — голубой, башня — розовый
const bldColor = {'mine': C.matter, 'factory': C.energy, 'tower': C.force};

/// Подписи строений на орбите окна клетки
const bldLabel = {'mine': 'шахта', 'factory': 'завод', 'tower': 'башня'};

Path hexPath(Offset c, double rad) {
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final a = math.pi / 6 + i * math.pi / 3;
    final p = c + Offset(math.cos(a), math.sin(a)) * rad;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// Строения клетки по ячейкам: каждое повышение уровня занимает ячейку, остальные ячейки пустые (null)
List<String?> slotTypes(Map<String, int> b, int cap) => [
  for (final t in const ['mine', 'factory', 'tower'])
    for (var i = 0; i < (b[t] ?? 0); i++) t,
  for (var i = b.values.fold(0, (a, v) => a + v); i < cap; i++) null,
];

/// Узел строения на схеме поля: ромб — шахта, кольцо — завод, треугольник — башня, тусклое кольцо — пусто
void paintNode(Canvas c, String? type, Offset p, double s, double t, {double a = 1}) {
  if (type == null) {
    c.drawCircle(
      p,
      s * .8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = C.gold.withValues(alpha: .35 * a),
    );
    return;
  }
  final col = bldColor[type]!;
  plasmaGlow(c, p, s * 2.6, col, (.55 + .15 * math.sin(t * 3 + p.dx)) * a);
  final fill = Paint()..color = col.withValues(alpha: a);
  final rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0xFFFFF6E0).withValues(alpha: a);
  switch (type) {
    case 'mine':
      final path = Path()
        ..moveTo(p.dx, p.dy - s * 1.1)
        ..lineTo(p.dx + s * .8, p.dy)
        ..lineTo(p.dx, p.dy + s * 1.1)
        ..lineTo(p.dx - s * .8, p.dy)
        ..close();
      c.drawPath(path, fill);
      c.drawPath(path, rim);
    case 'factory':
      c.drawCircle(
        p,
        s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .45
          ..color = col.withValues(alpha: a),
      );
      c.drawCircle(p, s * .35, Paint()..color = const Color(0xFFE6F6FF).withValues(alpha: a));
    default:
      final path = Path()
        ..moveTo(p.dx, p.dy - s * 1.1)
        ..lineTo(p.dx + s, p.dy + s * .75)
        ..lineTo(p.dx - s, p.dy + s * .75)
        ..close();
      c.drawPath(path, fill);
      c.drawPath(path, rim);
  }
}

/// Строение-спутник: шахта — вращающийся астероид, завод — кольцевая станция, башня — кристалл со щитом,
/// пустая ячейка — пунктирный круг
void paintBuilding(Canvas c, String? type, Offset p, double s, double t, {double a = 1}) {
  if (type == null) {
    _dashedCircle(
      c,
      p,
      s * .9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = C.gold.withValues(alpha: .45 * a),
      2.5,
    );
    return;
  }
  final col = bldColor[type]!;
  c.save();
  c.translate(p.dx, p.dy);
  switch (type) {
    case 'mine':
      plasmaGlow(c, Offset.zero, s * 2.2, col, .45 * a);
      c.rotate(t * .6);
      final rock = Path()
        ..moveTo(s, 0)
        ..lineTo(s * .4, s * .8)
        ..lineTo(-s * .6, s * .7)
        ..lineTo(-s, -.1 * s)
        ..lineTo(-s * .3, -s * .9)
        ..lineTo(s * .6, -s * .7)
        ..close();
      c.drawPath(rock, Paint()..color = const Color(0xFF5B4530).withValues(alpha: a));
      c.drawPath(
        rock,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, s * .18)
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xF2FFD278).withValues(alpha: .95 * a),
      );
      c.drawCircle(Offset(-s * .2, -s * .15), s * .22, Paint()..color = const Color(0xE6FFDC8C).withValues(alpha: .9 * a));
    case 'factory':
      plasmaGlow(c, Offset.zero, s * 2.2, col, .45 * a);
      const tilt = -.3;
      c.save();
      c.rotate(tilt);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 2.3, height: s * .9),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, s * .22)
          ..blendMode = BlendMode.plus
          ..color = const Color(0xFF8CD2FF).withValues(alpha: .95 * a),
      );
      c.restore();
      plasmaGlow(c, Offset.zero, s * .6, const Color(0xFFDCF0FF), a);
      for (var i = 0; i < 3; i++) {
        final u = t * 1.5 + i * _tau / 3, px = math.cos(u) * s * 1.15, py = math.sin(u) * s * .45;
        final q = Offset(px * math.cos(tilt) - py * math.sin(tilt), px * math.sin(tilt) + py * math.cos(tilt));
        plasmaGlow(c, q, s * .3, const Color(0xFFC8EBFF), .9 * a);
      }
    default:
      plasmaGlow(c, Offset.zero, s * 2.2, col, .4 * a);
      c.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: s * 1.4),
        -2.2,
        1.3,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, s * .16)
          ..blendMode = BlendMode.plus
          ..color = const Color(0xFFFF8CB4).withValues(alpha: .75 * a),
      );
      c.drawPath(
        Path()
          ..moveTo(0, -s)
          ..lineTo(s * .7, 0)
          ..lineTo(0, s)
          ..lineTo(-s * .7, 0)
          ..close(),
        Paint()..color = const Color(0xFFFFD1E0).withValues(alpha: a),
      );
      final wing = Paint()..color = col.withValues(alpha: a);
      c.drawRect(Rect.fromLTWH(-s * 1.3, -s * .18, s * .55, s * .36), wing);
      c.drawRect(Rect.fromLTWH(s * .75, -s * .18, s * .55, s * .36), wing);
  }
  c.restore();
}

void _dashedCircle(Canvas c, Offset o, double r, Paint p, double dash, [double phase = 0]) =>
    _dashedOval(c, Rect.fromCircle(center: o, radius: r), p, math.max(4, (_tau * r / (dash * 2)).floor()), phase);

void _dashedOval(Canvas c, Rect oval, Paint p, int n, double phase) {
  final step = _tau / n;
  for (var i = 0; i < n; i++) {
    c.drawArc(oval, i * step + phase, step * .58, false, p);
  }
}

/// Пустая ячейка на орбите окна клетки: пульсирующий пунктир и «+»
void paintEmptySlot(Canvas c, Offset p, double k, double t) {
  final pulse = .5 + .5 * math.sin(t * 3);
  _dashedCircle(
    c,
    p,
    k * 1.3,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = C.gold.withValues(alpha: .5 + .4 * pulse),
    3,
    t * .5,
  );
  final plus = Paint()
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFFFD98A);
  c.drawLine(p - Offset(k * .6, 0), p + Offset(k * .6, 0), plus);
  c.drawLine(p - Offset(0, k * .6), p + Offset(0, k * .6), plus);
}

/// Кольцо долей материи, энергии и силы клетки
void paintStatRing(Canvas c, Offset o, double rr, double w, List<double> v, {double a = 1}) {
  final tot = v.fold(0.0, (s, x) => s + x);
  if (tot <= 0 || a <= 0) return;
  const cols = [C.matter, C.energy, C.force], gap = .08;
  final rect = Rect.fromCircle(center: o, radius: rr);
  c.drawCircle(
    o,
    rr,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w + 2
      ..color = const Color(0xB306040E).withValues(alpha: .7 * a),
  );
  var st = -math.pi / 2;
  for (var i = 0; i < 3; i++) {
    final sp = v[i] / tot * _tau;
    if (sp > gap * 1.5) {
      c.drawArc(
        rect,
        st + gap / 2,
        sp - gap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = cols[i].withValues(alpha: a),
      );
    }
    st += sp;
  }
}

/// Свободная клетка: остывший диск обломков с пунктирной границей захвата
void paintDeadDisk(Canvas c, Offset o, double r, double t) {
  for (var i = 0; i < 5; i++) {
    final rad = r * (.6 + i * .18);
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(-.2);
    _dashedOval(
      c,
      Rect.fromCenter(center: Offset.zero, width: rad * 2, height: rad * .6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .1
        ..color = const Color(0x6E96826E),
      8,
      t * .25 * (i.isOdd ? 1 : -1),
    );
    c.restore();
  }
  c.drawCircle(o, r * .38, Paint()..color = const Color(0xFF0A0710));
  _dashedCircle(
    c,
    o,
    r * .95,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = C.gold.withValues(alpha: .75),
    4,
    t * .3,
  );
  final rr = Seeded(3), dust = Paint()..color = const Color(0xB3B4A082);
  for (var i = 0; i < 9; i++) {
    final a = rr() * _tau + t * .2, d = r * (.5 + rr() * .6);
    c.drawRect(Rect.fromLTWH(o.dx + math.cos(a) * d, o.dy + math.sin(a) * d * .35, 2, 2), dust);
  }
}

/// Плашка с текстом: по центру [p], или левым/правым краем в [p] ([alignLeft], [alignRight])
void paintPill(
  Canvas c,
  String s,
  Offset p,
  double fs, {
  Color fg = const Color(0xFFFFE2A8),
  Color? border,
  double a = 1,
  bool alignLeft = false,
  bool alignRight = false,
}) {
  if (fs < 6 || a <= 0) return;
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontFamily: bodyFont,
        fontSize: fs,
        fontWeight: FontWeight.w700,
        color: fg.withValues(alpha: a),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final h = fs * 1.45, w = tp.width + fs * .9;
  if (alignLeft) p += Offset(w / 2, 0);
  if (alignRight) p -= Offset(w / 2, 0);
  final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: w, height: h), Radius.circular(h / 2));
  c.drawRRect(rect, Paint()..color = const Color(0xD10A0616).withValues(alpha: .82 * a));
  if (border != null) {
    c.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border.withValues(alpha: border.a * a),
    );
  }
  tp.paint(c, p - Offset(tp.width / 2, tp.height / 2));
}

/// Значок строения для списков: тот же спутник, что на карте и орбите окна клетки
class BuildingIcon extends StatelessWidget {
  const BuildingIcon(this.type, {super.key, this.size = 28});
  final String type;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _BuildingIconPainter(type)),
  );
}

class _BuildingIconPainter extends CustomPainter {
  _BuildingIconPainter(this.type);
  final String type;

  @override
  void paint(Canvas canvas, Size size) => paintBuilding(canvas, type, size.center(Offset.zero), size.shortestSide * .3, 1.2);

  @override
  bool shouldRepaint(covariant _BuildingIconPainter old) => old.type != type;
}
