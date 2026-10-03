// Качество графики: высокое — все эффекты, среднее — 30 кадров и без тяжёлых размытий,
// лёгкий режим — 20 кадров, простые свечения без градиентов, без анимации портретов.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum GfxLevel { high, medium, low }

const gfxNames = {GfxLevel.high: 'Высокое', GfxLevel.medium: 'Среднее', GfxLevel.low: 'Лёгкий режим'};
const gfxInfo = {
  GfxLevel.high: 'Все эффекты, 60 кадров в секунду.',
  GfxLevel.medium: '30 кадров, без размытий и сияния в бою. Меньше нагрев и расход батареи.',
  GfxLevel.low: '20 кадров, простые свечения, неподвижные портреты, пониженная чёткость в браузере. Для слабых устройств.',
};

class Gfx {
  static GfxLevel level = GfxLevel.high;

  /// По умолчанию в мобильном браузере — среднее: полный набор эффектов там тяжёл
  static GfxLevel get auto =>
      kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)
      ? GfxLevel.medium
      : GfxLevel.high;

  static GfxLevel parse(String? v) => GfxLevel.values.firstWhere((l) => l.name == v, orElse: () => auto);

  static int get fps => switch (level) {
    GfxLevel.high => 60,
    GfxLevel.medium => 30,
    GfxLevel.low => 20,
  };
  static bool get backdrop => level == GfxLevel.high; // размытие под верхними строками
  static bool get bloom => level == GfxLevel.high; // сияние в бою (размытый слой)
  static bool get gradients => level != GfxLevel.low; // мягкие свечения градиентом
  static bool get still => level == GfxLevel.low; // портреты без анимации
  static double get density => switch (level) {
    GfxLevel.high => 1,
    GfxLevel.medium => .6,
    GfxLevel.low => .35,
  }; // доля частиц и мелких эффектов
}

/// Пропускает кадры сверх лимита качества: true — пора рисовать
class FrameGate {
  double _acc = 1;
  bool pass(double dt) {
    _acc += dt;
    if (_acc + 1e-4 < 1 / Gfx.fps) return false;
    _acc = 0;
    return true;
  }
}

/// Масштаб интерфейса: «1» — как есть, «авто» — крупнее на больших экранах.
/// Подбирается по логическому размеру окна: телефон остаётся ×1, ноутбук ~×1,2, 2K-монитор ~×1,7
double autoUiScale(Size s) => (math.min(s.width / 480, s.height / 820)).clamp(1.0, 2.0).toDouble();

/// Рисует [child] в окне, уменьшенном в [scale] раз, и растягивает на весь экран:
/// все кнопки, значки и шрифты крупнее, касания пересчитываются автоматически
class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.auto, required this.child});
  final bool auto;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final k = auto ? autoUiScale(mq.size) : 1.0;
    if (k == 1.0) return child;
    return MediaQuery(
      data: mq.copyWith(
        size: mq.size / k,
        devicePixelRatio: mq.devicePixelRatio * k,
        padding: mq.padding / k,
        viewPadding: mq.viewPadding / k,
        viewInsets: mq.viewInsets / k,
      ),
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(width: mq.size.width / k, height: mq.size.height / k, child: child),
      ),
    );
  }
}
