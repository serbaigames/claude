// «Искра» — прогноз боя (120 быстрых прогонов) и оценка состояния мира.
part of 'game.dart';

class Forecast {
  final double p, cap, spent, dur, capCost, need;
  final bool winnable;
  const Forecast(this.p, this.cap, this.spent, this.dur, this.capCost, this.need, this.winnable);
}

class WorldTrend {
  final String kind; // grow / stall / warn / dark
  final String text, info;
  const WorldTrend(this.kind, this.text, this.info);
}

class TrendPoint {
  final double t;
  final int n;
  const TrendPoint(this.t, this.n);
}

extension GameForecast on Game {
  /// Число клеток раз в 5 с за последние 2 минуты игрового времени
  void trendSample(double dt) {
    _trendAcc += dt;
    if (_trendAcc < 5) return;
    _trendAcc = 0;
    final t = s.worldTime;
    trendHist.add(TrendPoint(t, own.length));
    while (trendHist.isNotEmpty && trendHist.first.t < t - 120) {
      trendHist.removeAt(0);
    }
  }

  /// Прогноз боя: 120 быстрых прогонов настоящего боя с текущими параметрами, навыками и запасом материи
  Forecast fightForecast(Cell c) {
    final f = foeFromCell(c);
    final key = [
      c.key,
      c.tier,
      aggr,
      f.traits.join(),
      c.might.round(),
      s.matter.floor(),
      s.char.values.join(),
      s.abilities.map((a) => a == null ? '' : '${a.id}${a.lvl}').join(),
      s.era?.i,
    ].join('|');
    final cached = _fcCache;
    if (cached != null && cached.key == key && now - cached.at < 2) return cached.v;

    final hp0 = maxHp(), dd = defDiv(), pm = powMul(), tc = turnCd(), md = med();
    final atkC = math.max(1, (4 * md).ceil()).toDouble();
    final capCost = c.might.ceilToDouble();
    final ab = [for (final a in s.abilities) a == null ? null : (d: Defs.abilities[a.id]!, v: abVal(a), cost: Game.abCost(a))];
    final tr = f.traits, lch = leechAmt();
    const dt = 0.1;

    ({int wins, int capOk, double spent, double dur}) run(double mat0, int nRuns) {
      var wins = 0, capOk = 0;
      var spent = 0.0, durSum = 0.0;
      for (var n = 0; n < nRuns; n++) {
        var hp = hp0, fh = f.maxHp, m = mat0, cd = 0.0, ft = 0.0, sh = 0.0, im = 0.0, ha = 0.0, t = 0.0, wt = 0.0;
        var dot = 0.0, dotV = 0.0, mend = 0.0, mendV = 0.0, wk = 0.0, rf = 0.0, dsp = 0.0;
        var res = 0, hits = 0;
        final acd = List<double>.filled(ab.length, 0);
        bool has(String k) => dsp <= 0 && tr.contains(k);
        double hit(double d, [bool pc = false]) {
          if (!pc && has('ward') && (wt % 10) >= 8) return 0;
          if (!pc && has('shell') && fh > f.maxHp * 0.5) d *= 0.65;
          fh -= d;
          return d;
        }

        while (t < 600) {
          t += dt;
          cd -= dt;
          ft += dt;
          wt += dt;
          sh -= dt;
          im -= dt;
          ha -= dt;
          wk -= dt;
          rf -= dt;
          dsp -= dt;
          for (var i = 0; i < acd.length; i++) {
            acd[i] -= dt;
          }
          if (dot > 0) {
            dot -= dt;
            fh -= dotV * dt * (has('shell') && fh > f.maxHp * 0.5 ? 0.65 : 1);
          }
          if (mend > 0) {
            mend -= dt;
            hp = math.min(hp0, hp + mendV * dt);
          }
          if (has('regen')) fh = math.min(f.maxHp, fh + f.maxHp * 0.015 * dt);
          if (ft >= (has('rage') && fh < f.maxHp * 0.4 ? f.cd / 1.6 : f.cd)) {
            ft = 0;
            hits++;
            if (im <= 0) {
              var d = f.atk * rnd(.85, 1.15) / dd;
              if (sh > 0) d *= 0.5;
              if (wk > 0) d *= 0.6;
              d = jsRound(d);
              hp -= d;
              if (rf > 0) fh -= jsRound(d * 0.6);
              if (has('leech')) m -= math.min(math.max(0.0, m), lch);
              if (has('stun') && hits % 4 == 0) cd += 1;
            }
          }
          if (hp <= 0) {
            res = -1;
            break;
          }
          var pick = -1;
          final hpp = hp / hp0;
          for (var i = 0; i < ab.length; i++) {
            final a = ab[i];
            if (a == null || acd[i] > 0 || m < a.cost) continue;
            final k = a.d.kind;
            if (k == 'heal' && hpp < 0.5 ||
                k == 'regenme' && hpp < 0.75 && mend <= 0 ||
                (k == 'immune' || k == 'shield' || k == 'reflect' || k == 'weaken') && hpp < 0.8 && ft > f.cd * 0.5 ||
                k == 'stunfoe' && ft > f.cd * 0.6 ||
                k == 'dispel' && tr.isNotEmpty && dsp <= 0 ||
                k == 'dot' && dot <= 0 ||
                k == 'execute' && fh < f.maxHp * 0.3 ||
                const ['dmg', 'drain', 'absorb', 'haste', 'pierce', 'harvest'].contains(k)) {
              pick = i;
              break;
            }
          }
          if (pick >= 0) {
            final a = ab[pick]!, k = a.d.kind;
            m -= a.cost;
            acd[pick] = a.d.cd;
            switch (k) {
              case 'dmg':
                hit(a.v * pm * rnd(.9, 1.1));
              case 'heal':
                hp = math.min(hp0, hp + a.v);
              case 'shield':
                sh = a.v;
              case 'drain':
                final x = hit(a.v * pm);
                hp = math.min(hp0, hp + x * 0.6);
              case 'haste':
                ha = a.v;
              case 'immune':
                im = a.v;
              case 'absorb':
                final x = hit(f.maxHp * a.v);
                hp = math.min(hp0, hp + x * 0.5);
              case 'dot':
                dot = Bal.dotT;
                dotV = a.v * pm;
              case 'stunfoe':
                ft -= a.v;
              case 'regenme':
                mend = Bal.mendT;
                mendV = a.v;
              case 'pierce':
                hit(a.v * pm * rnd(.9, 1.1), true);
              case 'weaken':
                wk = a.v;
              case 'reflect':
                rf = a.v;
              case 'dispel':
                dsp = a.v;
              case 'harvest':
                if (hit(a.v * pm * rnd(.9, 1.1)) > 0) m += a.cost * 2;
              case 'execute':
                hit(a.v * pm * rnd(.9, 1.1) * (fh < f.maxHp * 0.3 ? 3 : 1));
            }
          }
          if (cd <= 0) {
            if (m >= atkC) {
              m -= atkC;
              hit(10 * md * pm * rnd(.9, 1.1));
              cd = tc * (ha > 0 ? 0.5 : 1);
            } else if (pick < 0) {
              res = -1; // материя кончилась
              break;
            }
          }
          if (fh <= 0) {
            res = 1;
            break;
          }
        }
        if (res == 1) {
          wins++;
          spent += mat0 - m;
          durSum += t;
          if (m >= capCost) capOk++;
        }
      }
      return (wins: wins, capOk: capOk, spent: spent, dur: durSum);
    }

    const nRuns = 120;
    final r = run(s.matter, nRuns);
    // сколько материи нужно на победу: если с текущим запасом побед мало — считаем «с неограниченным запасом»
    final ri = r.wins >= nRuns * 0.6 ? r : run(1e12, 40);
    final need = ri.wins > 0 ? ri.spent / ri.wins : 0.0;
    final v = Forecast(
      r.wins / nRuns,
      r.wins > 0 ? r.capOk / r.wins : 0,
      r.wins > 0 ? r.spent / r.wins : 0,
      ri.wins > 0 ? ri.dur / ri.wins : 0,
      capCost,
      need,
      ri.wins > 0,
    );
    _fcCache = (key: key, at: now, v: v);
    return v;
  }

  static ({String label, String kind}) forecastLabel(double p) => p <= 0
      ? (label: 'победа невозможна', kind: 'bad')
      : p < 0.15
      ? (label: 'почти без шансов', kind: 'bad')
      : p < 0.35
      ? (label: 'маловероятная победа', kind: 'warn')
      : p < 0.6
      ? (label: 'исход неясен', kind: 'warn')
      : p < 0.85
      ? (label: 'вероятная победа', kind: 'ok')
      : p < 0.98
      ? (label: 'уверенная победа', kind: 'good')
      : (label: 'безоговорочная победа', kind: 'good');

  /// Строка о материи: сколько нужно на победу и хватает ли
  String fcMatter(Forecast fc) {
    if (!fc.winnable) return 'даже с любым запасом материи не победить';
    final need = fc.need.ceil(), total = need + fc.capCost;
    if (s.matter < need) return 'нужно ≈${Fmt.n(need)} материи — не хватает ${Fmt.n((need - s.matter).ceil())}';
    if (s.matter < total) return '≈${Fmt.n(need)} на бой, на захват (${Fmt.n(fc.capCost)}) может не хватить';
    return '≈${Fmt.n(need)} материи на бой · ~${fc.dur.round()} с';
  }

  /// Быстрая оценка боя (без прогона): урон в секунду игрока и сущности с учётом особенностей
  ({bool beat, double tKill, double cost}) quickFight(Cell c) {
    final f = foeFromCell(c), tr = f.traits, pm = powMul(), tc = turnCd();
    final atkC = math.max(1, (4 * med()).ceil());
    var dps = 10 * med() * pm / tc, abCostPs = 0.0;
    for (final a in s.abilities) {
      if (a == null) continue;
      final d = Defs.abilities[a.id]!, v = abVal(a), k = d.kind;
      final dm = k == 'dmg' || k == 'drain' || k == 'pierce' || k == 'harvest'
          ? v * pm
          : k == 'execute'
          ? v * pm * 1.4
          : k == 'dot'
          ? v * pm * Bal.dotT
          : k == 'absorb'
          ? f.maxHp * v
          : 0.0;
      if (dm > 0) {
        dps += dm / d.cd;
        abCostPs += Game.abCost(a) / d.cd;
      }
    }
    if (tr.contains('shell')) dps *= 0.82;
    if (tr.contains('ward')) dps *= 0.8;
    if (tr.contains('regen')) dps -= f.maxHp * 0.015;
    final tKill = dps > 0 ? f.maxHp / dps : double.infinity;
    final foeDps = f.atk / defDiv() / f.cd * (tr.contains('rage') ? 1.2 : 1);
    final tDie = maxHp() / math.max(1e-6, foeDps);
    final cost = tKill.isFinite
        ? tKill / tc * atkC + tKill * abCostPs + (tr.contains('leech') ? tKill / f.cd * leechAmt() : 0)
        : double.infinity;
    return (beat: tKill < tDie * 0.8, tKill: tKill, cost: cost + c.might.ceil());
  }

  /// Состояние мира: может ли игрок побеждать соседей, успевает ли добыча за ростом тьмы, есть ли угрозы и потери
  WorldTrend worldTrend() {
    final cached = _wtCache;
    if (cached != null && now - cached.at < 2) return cached.v;
    final inc = math.max(1e-6, income());
    final front = [for (final key in vis) s.cells[key]].whereType<Cell>().where((c) => !c.own).toList();
    var beat = 0;
    var best = double.infinity;
    final rates = <double>[];
    for (final c in front) {
      if (!c.alive) {
        best = math.min(best, math.max(0, (c.might.ceil() - s.matter) / inc));
        beat++;
        continue;
      }
      final q = quickFight(c);
      if (q.beat) {
        beat++;
        best = math.min(best, math.max(0, (q.cost - s.matter) / inc) + q.tKill);
      }
      rates.add(growRate(c) / c.growth * math.log(1 + (c.dev - 1) * darkF));
    }
    rates.sort();
    final r = rates.isNotEmpty ? rates[rates.length >> 1] : 0.0;
    final td = r > 0 ? math.ln2 / r : double.infinity; // время удвоения мощи тьмы, с
    final h = trendHist;
    final lost = h.isNotEmpty && own.length < h.first.n;
    final thr = threatCount;
    final heavy = thr >= math.max(2, own.length * 0.25);
    String m(double x) => x.isFinite ? (x < 90 ? '${x.round()} с' : '${(x / 60).round()} мин') : '—';
    final info =
        'Можно победить соседей: $beat из ${front.length}. Ближайшая победа и захват: '
        '${best.isFinite ? (best < 1 ? 'сейчас' : 'через ${m(best)}') : 'нет'}. Мощь тьмы удваивается за ${m(td)}. '
        'Клеток под угрозой: $thr.';
    String kind, tx;
    if (beat == 0) {
      if (lost || heavy) {
        kind = 'dark';
        tx = '▼ тьма поглощает мир';
      } else {
        kind = 'warn';
        tx = '■ соседи сильнее — нужно усилиться';
      }
    } else if (lost && best > td * 0.5) {
      kind = 'dark';
      tx = '▼ тьма наступает быстрее добычи';
    } else if (best <= td * 0.25 && !heavy) {
      kind = 'grow';
      tx = '▲ мир растёт';
    } else if (best <= td) {
      kind = 'stall';
      tx = heavy ? '■ рост замедляется, тьма давит' : '■ рост замедляется';
    } else {
      kind = 'warn';
      tx = '▼ тьма развивается быстрее добычи';
    }
    final v = WorldTrend(kind, tx, info);
    _wtCache = (at: now, v: v);
    return v;
  }
}
