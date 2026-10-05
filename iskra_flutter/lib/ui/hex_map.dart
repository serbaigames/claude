// Карта мира: шестигранная сетка с туманом войны, перетаскивание, щипок и колесо для масштаба, касание — выбор клетки.
// Координаты как в веб-версии (toScreen/fromScreen): клетки стоят на сетке GRID = 2 × SIZE.
// Рисунок в стиле «Звёздная плазма»: издали — схема (плазма своей территории, каналы от Искры, стены границ,
// узлы строений и число защиты), при приближении свои клетки плавно становятся звёздами-колониями со спутниками.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/game.dart';
import 'controller.dart';
import 'gfx.dart';
import 'map_art.dart';
import 'plasma_art.dart';
import 'skins.dart';
import 'theme.dart';
import '../l10n/l10n.dart';

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
  ui.Image? _bg;
  Size? _bgSize;
  Color? _bgTint;

  ui.Image _nebula(Size size, double dpr) {
    final tint = fieldLook.tint;
    if (_bg == null || _bgSize != size || _bgTint != tint) {
      _bgTint = tint;
      _bg?.dispose();
      _bgSize = size;
      _bg = buildNebula(size, dpr, seed: 37, tint: tint);
    }
    return _bg!;
  }

  @override
  void dispose() {
    _bg?.dispose();
    super.dispose();
  }

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
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _MapPainter(
                        widget.ctl,
                        () => cam,
                        () => zoom,
                        (s) => _nebula(s, MediaQuery.maybeDevicePixelRatioOf(context) ?? 1),
                      ),
                    ),
                  ),
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
  _MapPainter(this.ctl, this.cam, this.zoom, this.nebula) : super(repaint: ctl.paintTick);
  final GameController ctl;
  final Offset Function() cam;
  final double Function() zoom;
  final ui.Image Function(Size) nebula;

  // размер чёрной дыры от радиуса клетки: на схеме и в звёздном виде
  static const _holeC = {'low': .17, 'rare': .2, 'epic': .23, 'legend': .28};
  static const _holeA = {'low': .26, 'rare': .3, 'epic': .34, 'legend': .4};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final g = ctl.game;
    final z = zoom(), c0 = cam(), center = size.center(Offset.zero);
    final t = g.now, rc = _grid * z, k = rc / 54, fs = rc * .19;
    // 0 — схема, 1 — звёзды-колонии; переход при приближении
    final a = ((z - 1.0) / .4).clamp(0.0, 1.0);
    Offset scr(Cell c) => (hexToWorld(c.q, c.r) - c0) * z + center;
    bool onScreen(Offset p) =>
        p.dx > -rc * 1.3 && p.dy > -rc * 1.3 && p.dx < size.width + rc * 1.3 && p.dy < size.height + rc * 1.3;

    canvas.clipRect(Offset.zero & size);
    final bg = nebula(size);
    canvas.drawImageRect(bg, Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()), Offset.zero & size, Paint());
    _stars(canvas, size, c0, z);
    final look = fieldLook;

    final own = <Cell>[], dark = <Cell>[];
    for (final key in g.vis) {
      final c = g.s.cells[key];
      if (c == null || !onScreen(scr(c))) continue;
      (c.own ? own : dark).add(c);
    }

    // контуры клеток; тьма затемнена
    final darkFill = Paint()..color = const Color(0xD106030E).withValues(alpha: .82 * (1 - .6 * a));
    final darkLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x298C6EC8);
    for (final c in dark) {
      final h = hexPath(scr(c), rc * .97);
      canvas.drawPath(h, darkFill);
      canvas.drawPath(h, darkLine);
    }

    // своя территория: плазма внутри общих границ
    if (own.isNotEmpty) {
      final land = Path();
      for (final c in own) {
        land.addPath(hexPath(scr(c), rc * .97), Offset.zero);
      }
      canvas.save();
      canvas.clipPath(land);
      canvas.drawPath(land, Paint()..color = look.land.withValues(alpha: .09));
      for (final c in own) {
        final p = scr(c);
        // у стилей свой узор в клетке, поэтому сгустков меньше
        for (var i = 0; i < ((Skins.current == Skin.plasma ? 5 : 2) * Gfx.density).ceil(); i++) {
          final u = t * .4 + i * 1.7 + c.q, d = rc * .45 * math.sin(t * .7 + i);
          plasmaGlow(canvas, p + Offset(math.cos(u) * d, math.sin(u * 1.3) * d), rc * .5, look.glow, .08);
        }
        if (!c.spark) paintCellDecor(canvas, p, rc, t, (c.q * 31 + c.r * 17).abs());
      }
      canvas.restore();
    }

    _channels(canvas, g, scr, rc, k, t);
    _walls(canvas, g, own, scr, rc, k, t);

    for (final c in dark) {
      _dark(canvas, g, c, scr(c), rc, fs, k, t, a);
    }

    // содержимое своих клеток: схема и звёзды-колонии, на переходе — наплывом
    final cells = [for (final c in own) (c, scr(c))];
    for (final (c, p) in cells) {
      if (c.spark) paintSpark(canvas, p, rc * (.34 + .06 * a), t, .15, rays: 30);
    }
    paintFieldAmbient(canvas, size, t);
    void layer(double alpha, void Function() draw) {
      if (alpha <= 0) return;
      if (alpha >= 1) return draw();
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      draw();
      canvas.restore();
    }

    layer(1 - a, () {
      for (final (c, p) in cells) {
        if (!c.spark) _scheme(canvas, g, c, p, rc, fs, t);
      }
    });
    layer(a, () {
      for (final (c, p) in cells) {
        if (!c.spark) _colony(canvas, g, c, p, rc, fs, t);
      }
    });

    final sel = g.s.sel == null ? null : g.s.cells[g.s.sel];
    if (sel != null && g.vis.contains(sel.key)) {
      final p = scr(sel), pulse = .5 + .5 * math.sin(t * 3);
      canvas.drawPath(
        hexPath(p, rc * .9),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = C.gold.withValues(alpha: .6 + .4 * pulse),
      );
    }
  }

  void _stars(Canvas canvas, Size size, Offset cam, double z) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.3);
    final rnd = math.Random(7);
    for (var i = 0; i < 70; i++) {
      final x = (rnd.nextDouble() * size.width - cam.dx * 0.05 * z) % size.width;
      final y = (rnd.nextDouble() * size.height - cam.dy * 0.05 * z) % size.height;
      canvas.drawCircle(Offset(x, y), rnd.nextDouble() * 1.1 + 0.3, p);
    }
  }

  // Каналы между своими клетками: импульсы бегут от Искры к окраинам
  void _channels(Canvas canvas, Game g, Offset Function(Cell) scr, double rc, double k, double t) {
    final dist = <String, int>{};
    final queue = <Cell>[for (final c in g.own.where((c) => c.spark)) c];
    for (final c in queue) {
      dist[c.key] = 0;
    }
    for (var i = 0; i < queue.length; i++) {
      final c = queue[i];
      for (final n in g.neighbors(c)) {
        if (n.own && !dist.containsKey(n.key)) {
          dist[n.key] = dist[c.key]! + 1;
          queue.add(n);
        }
      }
    }
    for (final c in g.own) {
      for (final n in g.neighbors(c)) {
        if (!n.own || n.key.compareTo(c.key) < 0) continue;
        // от ближнего к Искре — к дальнему
        final far = (dist[n.key] ?? 99) >= (dist[c.key] ?? 99);
        final p0 = scr(far ? c : n), p1 = scr(far ? n : c);
        paintChannel(canvas, p0, p1, rc, t, c.q * .13);
      }
    }
  }

  // Границы своей территории: стены энергии, у сильной соседней тьмы — красные и пульсируют
  void _walls(Canvas canvas, Game g, List<Cell> own, Offset Function(Cell) scr, double rc, double k, double t) {
    for (final c in own) {
      final p = scr(c), threat = g.threatened(c), def = g.cellDef(c);
      for (final d in Defs.dirs) {
        final n = g.s.cells[Game.k(c.q + d[0], c.r + d[1])];
        if (n != null && n.own) continue;
        final a0 = math.atan2(1.5 * d[1], _sq3 * (d[0] + d[1] / 2)), rr = rc * .97;
        final p0 = p + Offset(math.cos(a0 - math.pi / 6), math.sin(a0 - math.pi / 6)) * rr;
        final p1 = p + Offset(math.cos(a0 + math.pi / 6), math.sin(a0 + math.pi / 6)) * rr;
        final hot = threat && n != null && n.alive && n.might >= def * .8;
        final col = hot
            ? const Color(0xFFEF5A82)
            : n != null
            ? Color.lerp(fieldLook.wall, Colors.white, .15)!
            : fieldLook.wall;
        final al = hot ? .6 + .4 * math.sin(t * 6) : (n != null ? .55 : .25);
        final wall = Paint()
          ..strokeWidth = math.max(1.0, (hot ? 3 : 2) * k)
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..color = col.withValues(alpha: al);
        canvas.drawLine(p0, p1, wall);
        paintWallDecor(canvas, p0, p1, Offset(math.cos(a0), math.sin(a0)), rc, t, n != null);
        if (n != null) {
          canvas.drawLine(
            p0,
            p1,
            wall
              ..strokeWidth = math.max(3.0, (hot ? 10 : 8) * k)
              ..color = col.withValues(alpha: hot ? .2 + .1 * math.sin(t * 6) : .12),
          );
        }
      }
    }
  }

  void _dark(Canvas canvas, Game g, Cell c, Offset p, double rc, double fs, double k, double t, double a) {
    final tier = Color(Defs.tierColor[c.tier] ?? 0xFFA49DBD);
    if (!c.alive) {
      paintDeadDisk(canvas, p, rc * (.26 + .1 * a), t);
    } else {
      final r = rc * (_holeC[c.tier]! + (_holeA[c.tier]! - _holeC[c.tier]!) * a);
      final tt = t + c.q * 1.3 + c.r;
      if (r < 6) {
        plasmaGlow(canvas, p, r * 2.4, tier, .3);
        canvas.drawCircle(p, r * .8, Paint()..color = const Color(0xFF000000));
        canvas.drawCircle(
          p,
          r * .8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, r * .25)
            ..color = Color.lerp(tier, Colors.white, .3)!,
        );
      } else {
        if (c.tier == 'legend' || (c.tier == 'epic' && a > .5)) paintJets(canvas, p, r, tt);
        paintBlackHole(canvas, p, r, tt, tier);
      }
    }
    final mv = c.might.ceil(), m = mv >= 1e5 ? Fmt.n(mv) : '$mv';
    if (!c.alive) {
      paintPill(
        canvas,
        tx('свободна · {m}', {'m': m}),
        p + Offset(0, rc * .62),
        fs,
        fg: const Color(0xFFF6DFA6),
        border: C.gold.withValues(alpha: .7),
      );
    } else {
      paintPill(canvas, m, p + Offset(0, rc * .62), fs, fg: const Color(0xFFF1ECFF), border: tier.withValues(alpha: .8));
    }
    // прогресс до шага роста — тонкая дуга
    final prog = (c.t / c.growth).clamp(0.0, 1.0);
    final rect = Rect.fromCircle(center: p, radius: rc * .72);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 2 * k)
      ..color = C.violet.withValues(alpha: .22);
    canvas.drawArc(rect, math.pi * .65, math.pi * .7, false, arc);
    canvas.drawArc(rect, math.pi * .65, prog * math.pi * .7, false, arc..color = c.alive ? tier : C.gold.withValues(alpha: .8));
    if (g.nearLegend(c)) {
      paintPill(canvas, tx('рост ×2'), p - Offset(0, rc * .62), fs * .9, fg: C.warn, border: C.warn.withValues(alpha: .8));
    }
  }

  // Своя клетка на схеме: свечение, число защиты, узлы строений по кругу и уровень
  void _scheme(Canvas canvas, Game g, Cell c, Offset p, double rc, double fs, double t) {
    final threat = g.threatened(c);
    plasmaGlow(canvas, p, rc * .3, threat ? const Color(0xFFFF6E8C) : Color.lerp(fieldLook.glow, Colors.white, .3)!, .35);
    final dv = g.cellDef(c).floor();
    _text(
      canvas,
      dv >= 1e5 ? Fmt.n(dv) : '$dv',
      p - Offset(0, rc * .02),
      rc * .26,
      threat ? const Color(0xFFFFC2D2) : const Color(0xFFFFF3D6),
    );
    final slots = slotTypes(c.b, Game.cap(c)), n = slots.length;
    final s = math.min(rc * .085, rc * .56 * math.pi / math.max(1, n) * .42);
    for (var i = 0; i < n; i++) {
      final u = -math.pi / 2 + i / n * math.pi * 2 + math.pi / n;
      paintNode(canvas, slots[i], p + Offset(math.cos(u), math.sin(u)) * rc * .56, s, t);
    }
    paintPill(canvas, tx('ур. {n}', {'n': Game.cellLvl(c)}), p + Offset(0, rc * .27), fs * .85, fg: const Color(0xFFD9C9A0));
  }

  // Своя клетка вблизи: звезда-колония, строения кружат вокруг неё спутниками
  void _colony(Canvas canvas, Game g, Cell c, Offset p, double rc, double fs, double t) {
    final threat = g.threatened(c);
    if (threat) {
      final pulse = .5 + .5 * math.sin(t * 5);
      canvas.drawPath(
        hexPath(p, rc * .94),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = C.bad.withValues(alpha: .45 + .5 * pulse),
      );
      plasmaGlow(canvas, p, rc * .9, const Color(0xFFEF5078), .12 + .1 * pulse);
    }
    final r = rc * .2, rx = rc * .52, ry = rx * .36;
    const tilt = -.25;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(tilt);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x33FFC88C),
    );
    canvas.restore();
    final slots = slotTypes(c.b, Game.cap(c)), n = slots.length;
    final sats = <(Offset, bool, String?)>[];
    for (var i = 0; i < n; i++) {
      final u = t * .45 + i / n * math.pi * 2, px = math.cos(u) * rx, py = math.sin(u) * ry;
      sats.add((
        p + Offset(px * math.cos(tilt) - py * math.sin(tilt), px * math.sin(tilt) + py * math.cos(tilt)),
        math.sin(u) < 0,
        slots[i],
      ));
    }
    final ss = (7 / math.max(1, n)).clamp(.75, 1.0);
    for (final (q, back, type) in sats) {
      if (back) paintBuilding(canvas, type, q, rc * .08 * ss, t);
    }
    paintColony(canvas, p, r, t + c.q * 2);
    paintStatRing(canvas, p, r * 1.2, 2, [c.m, c.e, c.f]);
    for (final (q, back, type) in sats) {
      if (!back) paintBuilding(canvas, type, q, rc * .11 * ss, t);
    }
    final dv = g.cellDef(c).floor();
    paintPill(
      canvas,
      tx('{d} · ур. {n}', {'d': dv >= 1e5 ? Fmt.n(dv) : '$dv', 'n': Game.cellLvl(c)}),
      p + Offset(0, rc * .66),
      fs,
      fg: threat ? const Color(0xFFFFC2D2) : const Color(0xFFFFE2A8),
      border: (threat ? C.bad : C.gold).withValues(alpha: .6),
    );
  }

  // Число защиты шрифтом заголовков с тёплым ореолом
  void _text(Canvas canvas, String s, Offset p, double size, Color col) {
    if (size < 6) return;
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: displayFont,
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: col,
          shadows: const [Shadow(color: Color(0xE6FF9628), blurRadius: 10)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
