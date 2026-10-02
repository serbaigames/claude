// Портреты в окнах клетки: Искра со спутниками-ядрами и сущность тьмы в стиле «Звёздная плазма».
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/game.dart';
import 'plasma_art.dart';

/// Живой портрет: [PlasmaPortrait.spark] — звезда, вокруг которой по наклонным орбитам кружат ядра искры;
/// [PlasmaPortrait.entity] — чёрная дыра в цвете ранга, с джетами у эпических и легендарных.
class PlasmaPortrait extends StatefulWidget {
  const PlasmaPortrait.spark({super.key, required this.cores, this.speed = 1}) : tier = null;
  const PlasmaPortrait.entity({super.key, required String this.tier}) : cores = 0, speed = 1;

  final String? tier;
  final int cores;
  final double speed;

  @override
  State<PlasmaPortrait> createState() => _PlasmaPortraitState();
}

class _PlasmaPortraitState extends State<PlasmaPortrait> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker;
  ui.Image? _bg;
  Size? _bgSize;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _bg?.dispose();
    super.dispose();
  }

  ui.Image _background(Size size, double dpr) {
    if (_bg == null || _bgSize != size) {
      _bg?.dispose();
      _bgSize = size;
      _bg = buildNebula(size, dpr, seed: widget.tier == null ? 4242 : 777);
    }
    return _bg!;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PortraitPainter(this, _time, mq?.devicePixelRatio ?? 1, mq?.disableAnimations ?? false),
        size: Size.infinite,
      ),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.st, this.time, this.dpr, this.still) : super(repaint: time);
  final _PlasmaPortraitState st;
  final ValueNotifier<double> time;
  final double dpr;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 2 || size.height < 2) return;
    final w = st.widget, t = still ? 4.0 : time.value;
    final rect = Offset.zero & size, o = size.center(Offset.zero);
    canvas.clipRect(rect);
    final bg = st._background(size, dpr);
    final src = Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble());
    canvas.drawImageRect(bg, src, rect, Paint());
    if (w.tier == null) {
      _spark(canvas, size, o, t, w.cores, w.speed);
    } else {
      final tier = Color(Defs.tierColor[w.tier] ?? 0xFFFF8A3D);
      final r =
          size.height *
          .26 *
          switch (w.tier) {
            'low' => .8,
            'rare' => .87,
            'epic' => .94,
            _ => 1.0,
          };
      paintLens(canvas, bg, src, rect, o, r * 1.45, 1.5, math.pi + t * .02);
      if (w.tier == 'epic' || w.tier == 'legend') paintJets(canvas, o, r, t);
      paintBlackHole(canvas, o, r, t, tier);
    }
    canvas.drawRect(
      rect,
      Paint()..shader = ui.Gradient.radial(o, size.longestSide * .62, const [Color(0x00000000), Color(0x99000000)], [.45, 1]),
    );
  }

  void _spark(Canvas c, Size size, Offset o, double t, int cores, double speed) {
    final r = size.height * .21, n = cores.clamp(0, 6);
    // ядра искры: позиция на наклонной орбите и признак «за звездой»
    final sats = <(Offset, bool)>[];
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x2EFFC88C);
    for (var i = 0; i < n; i++) {
      final tilt = (i - (n - 1) / 2) * .32, rx = r * (1.55 + i * .26), ry = rx * .32;
      final a = t * (.7 - i * .08) * speed + i * 2.1, px = math.cos(a) * rx, py = math.sin(a) * ry;
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(tilt);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), orbit);
      c.restore();
      final p = o + Offset(px * math.cos(tilt) - py * math.sin(tilt), px * math.sin(tilt) + py * math.cos(tilt));
      sats.add((p, math.sin(a) < 0));
    }
    void sat(Offset p, bool back) {
      final k = size.height / 220 * (back ? .85 : 1);
      plasmaGlow(c, p, 16 * k, const Color(0xFFFFDCAA), back ? .7 : .8);
      plasmaGlow(c, p, 3.5 * k, const Color(0xFFFFFFFF), 1);
    }

    for (final (p, back) in sats) {
      if (back) sat(p, true);
    }
    paintSparkStar(c, o, r, t, .15 + .1 * math.sin(t * 2), speed: 1.4 * speed);
    for (final (p, back) in sats) {
      if (!back) sat(p, false);
    }
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter old) => true;
}
