// «Искра» — форматирование чисел и времени (по-русски запятая, по-английски точка; «k», «M»), как fmt/fmt1/fmtTime в веб-версии.
import 'dart:math' as math;

import '../l10n/l10n.dart';

class Fmt {
  static String _fixed(double v, int d) => isEn ? v.toStringAsFixed(d) : v.toStringAsFixed(d).replaceAll('.', ',');

  /// Целые числа, а с 10 000 — в тысячах и миллионах
  static String n(num n) {
    final s = n < 0 ? '−' : '';
    final a = n.abs().toDouble();
    if (a >= 1e6) return '$s${_fixed(a / 1e6, 2)}M';
    if (a >= 1e4) return '$s${_fixed(a / 1e3, 1)}k';
    return s + a.floor().toString();
  }

  static String n1(num v) => v >= 100 ? n(v) : _fixed(v.toDouble(), 1);

  static String x(num v, [int d = 1]) => _fixed(v.toDouble(), d);

  static String time(num sec) {
    final t = sec.floor();
    final h = t ~/ 3600, m = t % 3600 ~/ 60, s = t % 60;
    return h > 0
        ? tx('{h} ч {m} мин', {'h': h, 'm': m})
        : m > 0
        ? tx('{m} мин {s} с', {'m': m, 's': s})
        : tx('{s} с', {'s': s});
  }

  static String clock(num sec) {
    final t = math.max(0, sec.floor());
    final h = t ~/ 3600, m = t % 3600 ~/ 60, s = t % 60;
    String p(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${p(m)}:${p(s)}' : '$m:${p(s)}';
  }
}

/// Math.round из JS: половины округляются вверх (в том числе для отрицательных)
double jsRound(double v) => (v + 0.5).floorToDouble();
