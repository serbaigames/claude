// Сила способностей и связок: какую максимальную мощь клетки тьмы (p ≥ 0,8) бьёт искра
// с одной способностью / парой / четвёркой против одной атаки. Прогноз боя — штатный fightForecast.
// dart run tool/balance/abtest.dart
// ignore_for_file: avoid_print
import 'dart:math' as math;

import '../../lib/core/game.dart';

late Game g;
var tick = 0.0;

double maxMight(List<String> abs, int par, int lvl, {List<String> traits = const [], String tier = 'low'}) {
  for (final p in Defs.params) {
    g.s.char[p.id] = par;
  }
  g.s.abilities = [for (var i = 0; i < 4; i++) i < abs.length ? (AbilitySlot(abs[i])..lvl = lvl) : null];
  var lo = 1.0, hi = 20000.0;
  for (var it = 0; it < 16; it++) {
    final mid = math.sqrt(lo * hi);
    final c = Cell(q: 1, r: 0, might: mid, tier: tier, traits: [...traits], alive: true);
    g.now = tick += 10;
    final fc = g.fightForecast(c);
    if (fc.p >= 0.8) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// Материя на победу над клеткой мощи [might]
double costAt(List<String> abs, int par, int lvl, double might) {
  for (final p in Defs.params) {
    g.s.char[p.id] = par;
  }
  g.s.abilities = [for (var i = 0; i < 4; i++) i < abs.length ? (AbilitySlot(abs[i])..lvl = lvl) : null];
  final c = Cell(q: 1, r: 0, might: might, tier: 'low', traits: [], alive: true);
  g.now = tick += 10;
  final fc = g.fightForecast(c);
  return fc.p >= 0.5 ? fc.spent : double.infinity;
}

void main() {
  g = Game(random: math.Random(5));
  g.newGame();
  g.s.matter = 1e12;
  g.s.era = EraState(Defs.eras.indexWhere((e) => e.id == 'balance'), 1e9, 1e9);
  final ids = Defs.abilityList.map((a) => a.id).toList();
  for (final (par, lvl) in [(3, 3), (10, 10), (25, 30)]) {
    final base = maxMight([], par, lvl);
    final cb = costAt([], par, lvl, base * 0.6);
    print('\n## Параметры $par, уровень способностей $lvl: одна атака бьёт мощь ${base.toStringAsFixed(1)}, '
        'бой с мощью ×0,6 стоит ${cb.toStringAsFixed(0)}');
    final single = <String, double>{};
    for (final id in ids) {
      single[id] = maxMight([id], par, lvl) / base;
    }
    final sorted = single.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    print('Одна способность (во сколько раз сильнее противника бьёт / цена боя относительно атаки):');
    for (final e in sorted) {
      final c = costAt([e.key], par, lvl, base * 0.6);
      print('  ${Defs.abilities[e.key]!.name.padRight(16)} ${Defs.abilities[e.key]!.tier.padRight(5)} '
          '×${e.value.toStringAsFixed(2)}  цена ×${(c / cb).toStringAsFixed(2)}');
    }
    // пары из всех
    final pairs = <(String, String), double>{};
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        pairs[(ids[i], ids[j])] = maxMight([ids[i], ids[j]], par, lvl) / base;
      }
    }
    final ps = pairs.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    print('Лучшие пары (синергия = пара / (одна × другая)):');
    for (final e in ps.take(10)) {
      final syn = e.value / (single[e.key.$1]! * single[e.key.$2]!);
      print('  ${Defs.abilities[e.key.$1]!.name} + ${Defs.abilities[e.key.$2]!.name}: ×${e.value.toStringAsFixed(2)} синергия ${syn.toStringAsFixed(2)}');
    }
    // четвёрки из 9 лучших одиночных
    final top = sorted.take(9).map((e) => e.key).toList();
    final quads = <List<String>, double>{};
    for (var a = 0; a < top.length; a++) {
      for (var b = a + 1; b < top.length; b++) {
        for (var c = b + 1; c < top.length; c++) {
          for (var d = c + 1; d < top.length; d++) {
            final q = [top[a], top[b], top[c], top[d]];
            quads[q] = maxMight(q, par, lvl) / base;
          }
        }
      }
    }
    final qs = quads.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    print('Лучшие четвёрки:');
    for (final e in qs.take(5)) {
      print('  ${e.key.map((x) => Defs.abilities[x]!.name).join(' + ')}: ×${e.value.toStringAsFixed(2)}');
    }
    // худшая четвёрка из низших
    final lows = ids.where((x) => Defs.abilities[x]!.tier == 'low').toList();
    print('Четыре низших (${lows.take(4).join(',')}): ×${(maxMight(lows.take(4).toList(), par, lvl) / base).toStringAsFixed(2)}');
  }
}
