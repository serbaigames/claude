// Карта мира: шестигранная сетка с туманом войны, перетаскивание, щипок и колесо для масштаба, касание — выбор клетки.
// Координаты как в веб-версии (toScreen/fromScreen): клетки стоят на сетке GRID = 2 × SIZE.
// Рисунок упрощён: шары с кольцом материи/энергии/силы и числами; полный перенос рисунков веб-версии — следующий шаг.
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/game.dart';
import 'controller.dart';
import 'theme.dart';

const _size = 34.0, _grid = _size * 2;
final _sq3 = math.sqrt(3);

Offset hexToWorld(int q, int r) => Offset(_grid * _sq3 * (q + r / 2), _grid * 1.5 * r);

(int, int) worldToHex(Offset w) {
  final q = (_sq3 / 3 * w.dx - w.dy / 3) / _grid, r = (2 / 3 * w.dy) / _grid;
  final x = q, z = r, y = -x - z;
  var rx = x.roundToDouble(), ry = y.roundToDouble(), rz = z.roundToDouble();
  final dx = (rx - x).abs(), dy = (ry - y).abs(), dz = (rz - z).abs();
  if (dx > dy && dx > dz) {
    rx = -ry - rz;
  } else if (dy <= dz) {
    rz = -rx - ry;
  }
  return (rx.toInt(), rz.toInt());
}

class HexMap extends StatefulWidget {
  const HexMap({super.key, required this.ctl, this.controlsBottom = 0});
  final GameController ctl;

  /// На сколько поднять кнопки масштаба над нижним краем карты (блок выбранной клетки)
  final double controlsBottom;

  @override
  State<HexMap> createState() => _HexMapState();
}

class _HexMapState extends State<HexMap> {
  Offset cam = Offset.zero;
  double zoom = 0.8;
  double _startZoom = 1;
  Offset _startFocal = Offset.zero, _startCam = Offset.zero;
  Size _size = Size.zero;

  Offset _toWorld(Offset p) => (p - _size.center(Offset.zero)) / zoom + cam;

  void _onTapUp(TapUpDetails d) {
    final (q, r) = worldToHex(_toWorld(d.localPosition));
    final key = Game.k(q, r);
    final g = widget.ctl.game;
    widget.ctl.select(g.vis.contains(key) ? key : null);
  }

  void _zoomAt(Offset focal, double z) {
    final w = _toWorld(focal);
    setState(() {
      zoom = z.clamp(0.3, 2.2);
      cam = w - (focal - _size.center(Offset.zero)) / zoom;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _size = box.biggest;
        return Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) _zoomAt(e.localPosition, zoom * math.pow(0.999, e.scrollDelta.dy));
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _onTapUp,
            onScaleStart: (d) {
              _startZoom = zoom;
              _startFocal = d.localFocalPoint;
              _startCam = cam;
            },
            onScaleUpdate: (d) {
              setState(() {
                zoom = (_startZoom * d.scale).clamp(0.3, 2.2);
                // точка под пальцами остаётся на месте
                final w0 = (_startFocal - _size.center(Offset.zero)) / _startZoom + _startCam;
                cam = w0 - (d.localFocalPoint - _size.center(Offset.zero)) / zoom;
              });
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(child: CustomPaint(painter: _MapPainter(widget.ctl, () => cam, () => zoom))),
                ),
                Positioned(
                  right: 8,
                  bottom: 8 + widget.controlsBottom,
                  child: Column(
                    children: [
                      _zoomBtn(Icons.add, () => _zoomAt(_size.center(Offset.zero), zoom * 1.25)),
                      _zoomBtn(Icons.remove, () => _zoomAt(_size.center(Offset.zero), zoom / 1.25)),
                      _zoomBtn(
                        Icons.my_location,
                        () => setState(() {
                          cam = Offset.zero;
                          zoom = 0.8;
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback f) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: SizedBox(
      width: 40,
      height: 40,
      child: FilledButton(
        onPressed: f,
        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
        child: Icon(icon, size: 20),
      ),
    ),
  );
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.ctl, this.cam, this.zoom) : super(repaint: ctl.frameTick);
  final GameController ctl;
  final Offset Function() cam;
  final double Function() zoom;

  static const _tierFill = {
    'low': Color(0xFF4A3F6E),
    'rare': Color(0xFF244A6A),
    'epic': Color(0xFF6A2443),
    'legend': Color(0xFF7A3A10),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final g = ctl.game;
    final z = zoom(), c0 = cam(), center = size.center(Offset.zero);
    final t = g.now;
    Offset scr(Cell c) => (hexToWorld(c.q, c.r) - c0) * z + center;

    canvas.drawRect(Offset.zero & size, Paint()..color = C.bg);
    _stars(canvas, size, c0, z);

    final r = _size * 0.95 * z;
    final hex = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = C.line.withValues(alpha: 0.7);
    // контур видимых клеток и связи своих
    for (final key in g.vis) {
      final c = g.s.cells[key];
      if (c == null) continue;
      canvas.drawPath(_hexPath(scr(c), _grid * 0.98 * z), hex);
    }
    final pulse = 0.5 + 0.5 * math.sin(t * 3);
    for (final key in g.vis) {
      final c = g.s.cells[key];
      if (c == null) continue;
      final p = scr(c);
      if (p.dx < -r * 3 || p.dy < -r * 3 || p.dx > size.width + r * 3 || p.dy > size.height + r * 3) continue;
      _cell(canvas, g, c, p, r, z, pulse);
      if (g.s.sel == key) {
        canvas.drawCircle(
          p,
          r * 1.35,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = C.gold.withValues(alpha: 0.6 + 0.4 * pulse),
        );
      }
    }
  }

  void _stars(Canvas canvas, Size size, Offset cam, double z) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.35);
    final rnd = math.Random(7);
    for (var i = 0; i < 90; i++) {
      final x = (rnd.nextDouble() * size.width - cam.dx * 0.05 * z) % size.width;
      final y = (rnd.nextDouble() * size.height - cam.dy * 0.05 * z) % size.height;
      canvas.drawCircle(Offset(x, y), rnd.nextDouble() * 1.2 + 0.3, p);
    }
  }

  Path _star(Offset c, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final p = c + Offset(math.cos(a), math.sin(a)) * (i.isEven ? outer : inner);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  Path _hexPath(Offset c, double rad) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final p = c + Offset(math.cos(a), math.sin(a)) * rad;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  void _cell(Canvas canvas, Game g, Cell c, Offset p, double r, double z, double pulse) {
    if (c.own) {
      final threat = g.threatened(c);
      if (threat) {
        canvas.drawCircle(
          p,
          r * 1.08,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * z
            ..color = C.bad.withValues(alpha: 0.45 + 0.55 * pulse),
        );
      }
      _orb(canvas, p, r, c.spark ? const Color(0xFFFFE08A) : C.gold, c.spark ? 0.5 : 0.25);
      _ring(canvas, c, p, r * 0.8, math.max(2, 3 * z));
      if (c.spark) {
        canvas.drawPath(_star(p, r * 0.42, r * 0.14), Paint()..color = const Color(0xFF6B3A00));
      } else {
        final dv = g.cellDef(c).floor();
        _text(
          canvas,
          dv >= 1e5 ? Fmt.n(dv) : '$dv',
          p,
          13 * z,
          threat ? const Color(0xFF9B1840) : const Color(0xFF23163F),
          bold: true,
        );
        _pill(canvas, 'ур. ${Game.cellLvl(c)} · ${Fmt.clock(c.held)}', p + Offset(0, r * 1.5), 9.5 * z);
        _slots(canvas, c, p, r, z);
      }
      return;
    }
    // тьма
    if (!c.alive) {
      _orb(canvas, p, r * 0.7, const Color(0xFF6B5A3A), 0);
    } else {
      final col = Color(Defs.tierColor[c.tier]!);
      _orb(canvas, p, r * (c.tier == 'legend' ? 1.1 : 0.95), _tierFill[c.tier]!, 0.15, rim: col);
    }
    _ring(canvas, c, p, r * (c.alive ? 0.62 : 0.5), math.max(2, 2.6 * z));
    final mv = c.might.ceil();
    _text(
      canvas,
      mv >= 1e5 ? Fmt.n(mv) : '$mv',
      p,
      (c.alive ? 13 : 12) * z,
      c.alive ? const Color(0xFFF1ECFF) : const Color(0xFFF6DFA6),
      bold: true,
      outline: true,
    );
    if (!c.alive) _text(canvas, 'свободна', p + Offset(0, r * 0.32), 8.5 * z, const Color(0xFFF6DFA6));
    // прогресс до шага роста — тонкая дуга
    final prog = (c.t / c.growth).clamp(0.0, 1.0);
    final rect = Rect.fromCircle(center: p, radius: r * 1.12);
    canvas.drawArc(
      rect,
      math.pi * 0.65,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * z
        ..color = C.violet.withValues(alpha: 0.25),
    );
    canvas.drawArc(
      rect,
      math.pi * 0.65,
      prog * math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * z
        ..color = c.alive ? Color(Defs.tierColor[c.tier]!) : C.gold.withValues(alpha: 0.8),
    );
    if (g.nearLegend(c)) _pill(canvas, 'рост ×2', p - Offset(0, r * 1.25), 9 * z, color: C.warn);
  }

  void _orb(Canvas canvas, Offset p, double r, Color col, double glow, {Color? rim}) {
    if (glow > 0) {
      canvas.drawCircle(
        p,
        r * 1.5,
        Paint()
          ..shader = RadialGradient(
            colors: [
              col.withValues(alpha: glow),
              col.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: p, radius: r * 1.5)),
      );
    }
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [Color.lerp(col, Colors.white, 0.35)!, col, Color.lerp(col, Colors.black, 0.45)!],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
    if (rim != null) {
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = rim.withValues(alpha: 0.8),
      );
    }
  }

  // Кольцо долей материи, энергии и силы клетки (statRing)
  void _ring(Canvas canvas, Cell c, Offset p, double rr, double w) {
    final v = [c.m, c.e, c.f], tot = v[0] + v[1] + v[2];
    if (tot <= 0) return;
    const cols = [C.matter, C.energy, C.force], gap = 0.07;
    canvas.drawCircle(
      p,
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w + 2
        ..color = const Color(0xBF06040E),
    );
    var a = -math.pi / 2;
    final rect = Rect.fromCircle(center: p, radius: rr);
    for (var i = 0; i < 3; i++) {
      final sp = v[i] / tot * math.pi * 2;
      if (sp > gap * 1.5) {
        canvas.drawArc(
          rect,
          a + gap / 2,
          sp - gap,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w
            ..color = cols[i],
        );
      }
      a += sp;
    }
  }

  // Ячейки строений вокруг своей клетки: занятые — цветом строения
  void _slots(Canvas canvas, Cell c, Offset p, double r, double z) {
    final cap = Game.cap(c);
    final cols = <Color>[
      for (var i = 0; i < Game.bL(c, 'mine'); i++) C.matter,
      for (var i = 0; i < Game.bL(c, 'factory'); i++) C.energy,
      for (var i = 0; i < Game.bL(c, 'tower'); i++) const Color(0xFF9FD3FF),
    ];
    final n = math.max(cap, cols.length);
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      final q = p + Offset(math.cos(a), math.sin(a)) * r * 1.12;
      final filled = i < cols.length;
      canvas.drawCircle(q, 3.2 * z, Paint()..color = filled ? cols[i] : const Color(0x33FFFFFF));
    }
  }

  void _text(Canvas canvas, String s, Offset p, double size, Color col, {bool bold = false, bool outline = false}) {
    if (size < 5) return;
    TextPainter tp(Paint? fg) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: bodyFont,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: fg == null ? col : null,
          foreground: fg,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (outline) {
      final o = tp(
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.27
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xE6080514),
      );
      o.paint(canvas, p - Offset(o.width / 2, o.height / 2));
    }
    final t = tp(null);
    t.paint(canvas, p - Offset(t.width / 2, t.height / 2));
  }

  void _pill(Canvas canvas, String s, Offset p, double size, {Color color = const Color(0xFFFFD27A)}) {
    if (size < 6) return;
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: bodyFont, fontSize: size, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: p, width: tp.width + size, height: tp.height + size * 0.3),
      Radius.circular(size),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xCC140E28));
    tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
