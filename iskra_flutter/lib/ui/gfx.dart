// Качество графики: высокое — все эффекты, среднее — 30 кадров и без тяжёлых размытий,
// лёгкий режим — 20 кадров, простые свечения без градиентов, без анимации портретов.
import 'package:flutter/foundation.dart';

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
