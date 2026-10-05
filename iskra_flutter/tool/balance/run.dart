// Прогон стратегий: dart run tool/balance/run.dart [часы] [сиды] [стратегии через запятую]
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'bot.dart';

const dmgPref = [
  'nova', 'finisher', 'absorb', 'discharge', 'lance', 'vampire', 'harvest', 'spark_strike', 'ember', //
  'dark_shield', 'mirror', 'dispel', 'wither', 'haste', 'feed', 'mend', 'veil', 'daze',
];
const tankPref = [
  'absorb', 'vampire', 'dark_shield', 'mirror', 'nova', 'wither', 'feed', 'mend', 'veil', //
  'finisher', 'discharge', 'lance', 'harvest', 'spark_strike', 'ember', 'dispel', 'haste', 'daze',
];

final strats = <Strat>[
  const Strat('balanced'),
  const Strat(
    'fighter',
    w: {'life': 1, 'defense': 1, 'power': 1.5, 'meditation': 1.5, 'speed': 1.5, 'control': 0.5},
    ptShare: 0.45,
    attackP: 0.7,
    prefer: dmgPref,
  ),
  const Strat(
    'economist',
    w: {'life': 1, 'defense': 1, 'power': 1, 'meditation': 1, 'speed': 1, 'control': 1.5},
    ptShare: 0.1,
    attackP: 0.95,
    mineRatio: 1.5,
  ),
  const Strat('tank', w: {'life': 1.5, 'defense': 1.5, 'power': 1, 'meditation': 1, 'speed': 0.7, 'control': 1}, prefer: tankPref),
  const Strat('skew', w: {'life': 0.2, 'defense': 0.2, 'power': 5, 'meditation': 0.2, 'speed': 0.2, 'control': 0.2}, skew: true),
  const Strat('turtle', towers: true, defMargin: 1.6, jump: 'never', turtleAfter: 20),
  const Strat('turtleJump', towers: true, defMargin: 1.6, turtleAfter: 20, stallMin: 40),
  const Strat('noJump', jump: 'never'),
  const Strat('turtleLate', towers: true, defMargin: 1.6, jump: 'never', turtleAfter: 10, turtleWorld: 8),
  const Strat('fastJump', stallMin: 6),
  const Strat('casual', think: 6, attackP: 0.9, buildShare: 0.2, ptShare: 0.2),
];

void main(List<String> args) {
  final hours = args.isNotEmpty ? double.parse(args[0]) : 15.0;
  final seeds = args.length > 1 ? int.parse(args[1]) : 3;
  final only = args.length > 2 && args[2].isNotEmpty ? args[2].split(',').toSet() : null;
  final out = <Map<String, Object?>>[];
  for (final st in strats) {
    if (only != null && !only.contains(st.name)) continue;
    for (var seed = 1; seed <= seeds; seed++) {
      final sw = Stopwatch()..start();
      final bot = Bot(st, seed * 7919 + st.name.hashCode % 1000);
      bot.trace = {for (final x in (Platform.environment['TRACE'] ?? '').split(',')) if (x.isNotEmpty) int.parse(x)};
      bot.run(hours);
      final s = bot.g.s;
      print('=== ${st.name} seed $seed: ${bot.worlds.length} миров, бонус ${s.bonus}, прыжков ${s.rebirths}, '
          'ядра ${s.cores}, тех ${s.tech}, пульсары ${s.pulsars}, ${sw.elapsedMilliseconds} мс');
      for (final w in bot.worlds) {
        print('  мир ${w.idx}: агр ${w.aggr} бонус ${w.bonusBefore} тьма×${w.darkMul.toStringAsFixed(2)} '
            '${w.dur.toStringAsFixed(1)} мин, макс ${w.maxCells}, конец ${w.endCells}, '
            '5/10/15/20 к. на ${w.t5.toStringAsFixed(0)}/${w.t10.toStringAsFixed(0)}/${w.t15.toStringAsFixed(0)}/${w.t20.toStringAsFixed(0)} мин, '
            'бои ${w.battles} (поб ${w.wins}, пор ${w.losses}), потеряно ${w.lost}, +бонус ${w.gain}, '
            '${_fs(w.fights)} '
            'макс материи ${w.maxMatter.toStringAsFixed(0)}, ${w.end} | ${w.chars} | ${w.abil}');
      }
      out.add({
        'strat': st.name,
        'seed': seed,
        'bonus': s.bonus,
        'jumps': s.rebirths,
        'cores': s.cores,
        'abilSeen': bot.abilSeen,
        'abilDmg': bot.abilDmg,
        'worlds': [
          for (final w in bot.worlds)
            {
              'i': w.idx,
              'aggr': w.aggr,
              'bonus': w.bonusBefore,
              'darkMul': w.darkMul,
              'dur': w.dur,
              'max': w.maxCells,
              'endCells': w.endCells,
              't5': w.t5,
              't10': w.t10,
              't15': w.t15,
              't20': w.t20,
              'battles': w.battles,
              'wins': w.wins,
              'losses': w.losses,
              'lost': w.lost,
              'gain': w.gain,
              'end': w.end,
              'maxMatter': w.maxMatter,
              'eras': w.eras,
              'chars': w.chars,
              'abil': w.abil,
              'cellsAt': w.cellsAt.map((k, v) => MapEntry('$k', v)),
            },
        ],
      });
    }
  }
  final f = File(args.length > 3 ? args[3] : 'balance_out.json');
  f.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
}

String _fs(List<List<double>> f) {
  if (f.isEmpty) return 'боёв нет';
  double med(int i) {
    final v = f.map((x) => x[i]).toList()..sort();
    return v[v.length ~/ 2];
  }
  String r(double x) => x.toStringAsFixed(x < 10 ? 1 : 0);
  return 'ударов до победы ${r(med(0))} / до гибели ${r(med(1))} (удар ${r(med(2))}, хп ${r(med(3))}, враг ${r(med(4))}/${r(med(5))})';
}
