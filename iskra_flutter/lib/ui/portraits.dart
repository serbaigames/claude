// Портреты в окнах клетки в стиле «Звёздная плазма»: Искра со спутниками-ядрами, сущность тьмы
// и своя клетка — звезда, вокруг которой по орбите кружат строения и пустые ячейки.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/game.dart';
import 'gfx.dart';
import 'map_art.dart';
import 'plasma_art.dart';
import 'skins.dart';
import 'theme.dart';

/// Живой портрет: [PlasmaPortrait.spark] — Искра в своём стиле ([skin]), вокруг которой по наклонным орбитам кружат ядра искры;
/// [PlasmaPortrait.entity] — чёрная дыра в цвете ранга, с джетами у эпических и легендарных;
/// [PlasmaPortrait.cell] — своя клетка: строения-спутники по ячейкам ([slots], null — пустая ячейка),
/// кольцо долей [ring] вокруг звезды, плашки [tagLeft] и [tagRight] сверху. Касание пустой ячейки — [onEmptySlot].
class PlasmaPortrait extends StatefulWidget {
  const PlasmaPortrait.spark({super.key, required this.cores, this.speed = 1, this.skin})
    : tier = null,
      slots = null,
      ring = const [],
      tagLeft = null,
      tagRight = null,
      onEmptySlot = null;
  const PlasmaPortrait.entity({super.key, required String this.tier})
    : cores = 0,
      skin = null,
      speed = 1,
      slots = null,
      ring = const [],
      tagLeft = null,
      tagRight = null,
      onEmptySlot = null;
  const PlasmaPortrait.cell({
    super.key,
    required List<String?> this.slots,
    required this.ring,
    this.tagLeft,
    this.tagRight,
    this.onEmptySlot,
  }) : tier = null,
       skin = null,
       cores = 0,
       speed = 1;

  final String? tier;
  final int cores;
  final double speed;

  /// Стиль Искры для витрины магазина; null — выбранный игроком
  final Skin? skin;
  final List<String?>? slots;
  final List<double> ring;
  final String? tagLeft, tagRight;
  final VoidCallback? onEmptySlot;

  @override
  State<PlasmaPortrait> createState() => _PlasmaPortraitState();
}

class _PlasmaPortraitState extends State<PlasmaPortrait> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker;
  ui.Image? _bg;
  Size? _bgSize;

  /// Где спутники клетки были в последнем кадре: для касания пустой ячейки
  final _sats = <(Offset, double, String?)>[];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      final t = e.inMicroseconds / 1e6;
      if (Gfx.still || t - _time.value + 1e-4 < 1 / Gfx.fps) return; // лимит кадров по качеству графики
      _time.value = t;
    })..start();
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
      _bg = buildNebula(
        size,
        dpr,
        seed: widget.tier != null
            ? 777
            : widget.slots != null
            ? 61
            : 4242,
      );
    }
    return _bg!;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    final paint = RepaintBoundary(
      child: CustomPaint(
        painter: _PortraitPainter(this, _time, mq?.devicePixelRatio ?? 1, (mq?.disableAnimations ?? false) || Gfx.still),
        size: Size.infinite,
      ),
    );
    final onEmpty = widget.onEmptySlot;
    if (onEmpty == null) return paint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        for (final (p, r, type) in _sats) {
          if (type == null && (p - d.localPosition).distance <= r) return onEmpty();
        }
      },
      child: paint,
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
    if (w.slots != null) {
      _cell(canvas, size, t, w.slots!);
    } else if (w.tier == null) {
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
    paintSpark(c, o, r, t, .15 + .1 * math.sin(t * 2), speed: 1.4 * speed, skin: st.widget.skin);
    for (final (p, back) in sats) {
      if (!back) sat(p, false);
    }
  }

  // Своя клетка: звезда с кольцом долей, строения на наклонной орбите, пустые ячейки — пунктир с «+»
  void _cell(Canvas c, Size size, double t, List<String?> slots) {
    final h = size.height,
        o = Offset(size.width / 2, h * .5),
        r = h * .17,
        rx = math.min(h * .62, size.width * .4),
        ry = rx * .34;
    const tilt = -.18;
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(tilt);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x40FFC88C),
    );
    c.restore();
    final n = slots.length, ks = (7 / math.max(1, n)).clamp(.7, 1.0);
    st._sats.clear();
    final sats = <(Offset, bool, String?)>[];
    for (var i = 0; i < n; i++) {
      final a = t * .35 + i / n * math.pi * 2, px = math.cos(a) * rx, py = math.sin(a) * ry;
      final p = o + Offset(px * math.cos(tilt) - py * math.sin(tilt), px * math.sin(tilt) + py * math.cos(tilt));
      sats.add((p, math.sin(a) < 0, slots[i]));
      st._sats.add((p, h * .12 * ks, slots[i]));
    }
    void draw(Offset p, bool back, String? type) {
      final k = h * (back ? .045 : .06) * ks;
      type == null ? paintEmptySlot(c, p, k, t) : paintBuilding(c, type, p, k, t);
      if (!back && n <= 6) {
        final tp = TextPainter(
          text: TextSpan(
            text: type == null ? 'свободно' : bldLabel[type],
            style: TextStyle(
              fontFamily: bodyFont,
              fontSize: h * .06,
              fontWeight: FontWeight.w700,
              color: const Color(0xD9F0E6FF),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, p + Offset(-tp.width / 2, k * 1.9));
      }
    }

    for (final (p, back, type) in sats) {
      if (back) draw(p, true, type);
    }
    paintSparkStar(c, o, r, t, .1, rays: 30);
    paintStatRing(c, o, r * 1.15, 3, st.widget.ring);
    for (final (p, back, type) in sats) {
      if (!back) draw(p, false, type);
    }
    final fs = h * .065;
    if (st.widget.tagLeft case final s?) {
      paintPill(c, s, Offset(fs * 1.2, h * .12), fs, border: C.gold.withValues(alpha: .6), alignLeft: true);
    }
    if (st.widget.tagRight case final s?) {
      paintPill(c, s, Offset(size.width - fs * 1.2, h * .12), fs, border: C.gold.withValues(alpha: .6), alignRight: true);
    }
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter old) => true;
}
