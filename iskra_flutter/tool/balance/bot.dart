// Балансный бот «Искры»: играет без интерфейса по заданной стратегии и пишет статистику по мирам.
// Временный код для тестов баланса (ветка claude/project-thread-bp64yq), в игру не входит.
// ignore_for_file: avoid_print
import 'dart:math' as math;

import '../../lib/core/game.dart';

/// Настройки стратегии
class Strat {
  final String name;

  /// Веса параметров: life, defense, power, meditation, speed, control
  final Map<String, double> w;

  /// Можно ли превышать порог штрафа за перекос
  final bool skew;

  /// Доля свободной материи на ОП и ОС за шаг
  final double ptShare;

  /// Доля ОС среди очков
  final double osShare;

  /// Нужный шанс победы для атаки
  final double attackP;

  /// Запас защиты клетки к самой сильной соседке тьмы (1,1 = на 10% выше)
  final double defMargin;

  /// Башни вместо укреплений (true — только башни)
  final bool towers;

  /// Шахт на один завод
  final double mineRatio;

  /// Прыжок: 'stall' — когда рост встал, 'never' — никогда (только при банкротстве)
  final String jump;

  /// Минут без нового рекорда клеток до прыжка
  final double stallMin;

  /// Черепаха: после [turtleAfter] минут мира перестаёт атаковать и копит за башнями
  final double turtleAfter;

  /// Предпочтения способностей (раньше — лучше); null — брать любые
  final List<String>? prefer;
  const Strat(
    this.name, {
    this.w = const {'life': 1, 'defense': 1, 'power': 1, 'meditation': 1, 'speed': 1, 'control': 1},
    this.skew = false,
    this.ptShare = 0.25,
    this.osShare = 0.35,
    this.attackP = 0.8,
    this.defMargin = 1.15,
    this.towers = false,
    this.mineRatio = 2,
    this.jump = 'stall',
    this.stallMin = 15,
    this.turtleAfter = double.infinity,
    this.prefer,
    this.think = 1,
    this.turtleWorld = 1,
    this.buildShare = 0.3,
  });

  /// С какого мира включается черепаха (до него — обычная игра с прыжками)
  final int turtleWorld;

  /// Как часто бот принимает решения, с (1 — опытный игрок, 5+ — неспешный)
  final double think;

  /// Доля материи, которую можно отдать за одно строение
  final double buildShare;
}

/// Итоги одного мира
class WorldRec {
  final int idx;
  final double aggr, bonusBefore, darkMul;
  double dur = 0, firstAt = 0;
  int maxCells = 1, endCells = 1, battles = 0, wins = 0, losses = 0, lost = 0, defWon = 0, defFled = 0;
  String end = '';
  bool turtle = false;
  double gain = 0, earned = 0, matterEnd = 0, maxMatter = 0;
  final Map<int, int> cellsAt = {}; // минута → клеток
  final List<String> eras = [];
  String abil = '', chars = '';
  final List<List<double>> fights = []; // [ударов до победы, ударов до гибели, урон удара, здоровье, здоровье врага, удар врага]
  double t5 = 0, t10 = 0, t15 = 0, t20 = 0; // минута, когда клеток стало 5/10/15/20
  WorldRec(this.idx, this.aggr, this.bonusBefore, this.darkMul);
}

class Bot {
  final Strat st;
  final Game g;
  final List<WorldRec> worlds = [];
  late WorldRec cur;
  double lastRecord = 0; // время мира, когда был последний рекорд клеток
  double lastFc = -100;
  final Map<String, int> abilSeen = {}; // какие способности держал бот (по минутам)
  final Map<String, double> abilDmg = {};

  /// Номера миров, по которым печатать поминутный след
  Set<int> trace = {};

  void _trace() {
    final front = g.vis.map(g.cell).whereType<Cell>().where((c) => !c.own && c.alive).toList()
      ..sort((a, b) => a.might.compareTo(b.might));
    final thr = g.threatCount;
    final beat = front.where((c) => g.quickFight(c).beat).length;
    final towers = g.own.fold<int>(0, (a, c) => a + Game.bL(c, 'tower'));
    final mines = g.own.fold<int>(0, (a, c) => a + Game.bL(c, 'mine'));
    final facs = g.own.fold<int>(0, (a, c) => a + Game.bL(c, 'factory'));
    print('    t=${(s.worldTime / 60).toStringAsFixed(0)}м клеток ${g.own.length} материя ${s.matter.toStringAsFixed(0)} '
        'доход ${g.income().toStringAsFixed(1)}/с пар ${g.parAvg.toStringAsFixed(1)} ОП ${s.opB} ОС ${s.osB} '
        'фронт ${front.length} мин ${front.isEmpty ? 0 : front.first.might.toStringAsFixed(0)} '
        'макс ${front.isEmpty ? 0 : front.last.might.toStringAsFixed(0)} побед. $beat угроз $thr '
        'ш/з/б $mines/$facs/$towers эра ${g.eraNow.id} ${g.worldTrend().kind}');
  }

  Bot(this.st, int seed) : g = Game(random: math.Random(seed));

  GameState get s => g.s;

  void _newWorld() {
    cur = WorldRec(worlds.length + 1, g.aggr, s.bonus, g.darkMul);
    worlds.add(cur);
    lastRecord = 0;
    lastFc = -100;
    reserve = 0;
  }

  void _endWorld(String why) {
    cur
      ..dur = s.worldTime / 60
      ..end = why
      ..endCells = g.own.length
      ..matterEnd = s.matter
      ..earned = s.we
      ..gain = g.rebirthGain()
      ..abil = s.abilities.map((a) => a == null ? '-' : '${a.id}:${a.lvl}').join(',')
      ..chars = Defs.params.map((p) => s.char[p.id]).join('/');
  }

  /// Играет [hours] часов игрового времени
  void run(double hours) {
    g.newGame();
    s.introSeen = true;
    _newWorld();
    final total = hours * 3600;
    var t = 0.0;
    var acc = 0.0;
    var lastMin = -1;
    while (t < total) {
      final inBattle = g.b != null;
      final dt = inBattle ? 0.1 : 0.25;
      g.now = t;
      if (g.frame(dt)) {
        _endWorld('банкротство');
        g.rebirth();
        _newWorld();
        continue;
      }
      t += dt;
      if (g.def != null) _onDefend();
      if (g.b != null) {
        _battle();
        continue;
      }
      // статистика
      final m = (s.worldTime / 60).floor();
      if (m != lastMin) {
        lastMin = m;
        if (trace.contains(cur.idx)) _trace();
        cur.cellsAt[m] = g.own.length;
        final e = g.eraNow.id;
        if (cur.eras.isEmpty || cur.eras.last != e) cur.eras.add(e);
        for (final a in s.abilities) {
          if (a != null) abilSeen[a.id] = (abilSeen[a.id] ?? 0) + 1;
        }
      }
      final n = g.own.length;
      if (n > cur.maxCells) {
        cur.maxCells = n;
        lastRecord = s.worldTime;
        final mm = s.worldTime / 60;
        if (n >= 5 && cur.t5 == 0) cur.t5 = mm;
        if (n >= 10 && cur.t10 == 0) cur.t10 = mm;
        if (n >= 15 && cur.t15 == 0) cur.t15 = mm;
        if (n >= 20 && cur.t20 == 0) cur.t20 = mm;
      }
      cur.maxMatter = math.max(cur.maxMatter, s.matter);
      acc += dt;
      if (acc < st.think) continue;
      acc = 0;
      s.paused = false;
      _decide();
    }
    _endWorld('конец теста');
  }

  /* ---------- защита ---------- */
  void _onDefend() {
    final d = g.def!;
    final c = g.cell(d.att)!;
    final fc = g.fightForecast(c);
    if (fc.p >= 0.6) {
      g.defendFight();
      cur.battles++;
    } else {
      g.defendFlee();
      cur.defFled++;
      cur.lost++;
    }
  }

  /* ---------- бой ---------- */
  void _battle() {
    final bt = g.b!;
    if (!bt.started) g.battleStart();
    if (!bt.over) {
      final f = bt.foe;
      final hpp = bt.hp / bt.maxHp;
      for (var i = 0; i < s.abilities.length; i++) {
        final a = s.abilities[i];
        if (a == null || bt.abCd[i] > 0) continue;
        final k = Defs.abilities[a.id]!.kind;
        final use =
            k == 'heal' && hpp < 0.5 ||
            k == 'regenme' && hpp < 0.75 && bt.mend <= 0 ||
            (k == 'immune' || k == 'shield' || k == 'reflect' || k == 'weaken') && hpp < 0.8 && f.t > f.cd * 0.5 ||
            k == 'stunfoe' && f.t > f.cd * 0.6 ||
            k == 'dispel' && f.traits.isNotEmpty && bt.dispel <= 0 ||
            k == 'dot' && bt.dot <= 0 ||
            k == 'execute' && f.hp < f.maxHp * 0.3 ||
            const ['dmg', 'drain', 'absorb', 'haste', 'pierce', 'harvest'].contains(k);
        if (use) {
          final hp0 = f.hp;
          g.doAction('ab$i');
          abilDmg[a.id] = (abilDmg[a.id] ?? 0) + math.max(0, hp0 - f.hp);
          if (bt.over) break;
        }
      }
    }
    if (bt.over) {
      if (bt.won) {
        cur.wins++;
        if (bt.defend != null) cur.defWon++;
      } else {
        cur.losses++;
        if (bt.defend != null) cur.lost++;
      }
      final ch = bt.choice;
      if (ch != null) g.resolveChoice(_choice(ch));
      g.closeBattle();
      s.paused = false;
    }
  }

  int _rank(String id) {
    final p = st.prefer;
    if (p == null) return 0;
    final i = p.indexOf(id);
    return i < 0 ? 99 : i;
  }

  String _choice(BattleChoice ch) {
    if (ch.dup) return 'up';
    if (st.prefer == null) {
      // без предпочтений: заменить способность низшего ранга, если новая выше
      final tr = Defs.tierOrder.indexOf(ch.tier == 'legend' ? 'epic' : ch.tier);
      var wi = -1, wt = 99;
      for (var i = 0; i < s.abilities.length; i++) {
        final t = Defs.tierOrder.indexOf(Defs.abilities[s.abilities[i]!.id]!.tier);
        if (t < wt) {
          wt = t;
          wi = i;
        }
      }
      return wi >= 0 && tr > wt ? '$wi' : 'skip';
    }
    final nr = _rank(ch.id);
    var wi = -1, wr = -1;
    for (var i = 0; i < s.abilities.length; i++) {
      final r = _rank(s.abilities[i]!.id);
      if (r > wr) {
        wr = r;
        wi = i;
      }
    }
    return nr < wr ? '$wi' : 'skip';
  }

  /* ---------- решения раз в секунду ---------- */
  void _decide() {
    final wt = s.worldTime;
    // технологии
    final techs = Defs.tech.where((t) => !t.soon && g.techOpen(t) && g.techNextCost(t) != null).toList()
      ..sort((a, b) => g.techNextCost(a)!.compareTo(g.techNextCost(b)!));
    if (techs.isNotEmpty) g.researchTech(techs.first.id);

    _artifacts();
    _defend();

    // прыжок
    if (_wantJump()) return;

    final turtle = wt / 60 >= st.turtleAfter && cur.idx >= st.turtleWorld;
    // захват свободных клеток
    final front = g.vis.map(g.cell).whereType<Cell>().where((c) => !c.own).toList();
    if (turtle) cur.turtle = true;
    if (!turtle) {
      final free = front.where((c) => !c.alive).toList()..sort((a, b) => a.might.compareTo(b.might));
      for (final c in free) {
        if (s.matter >= c.might.ceil() * 1.05) {
          g.capture(c.key);
          if (cur.firstAt == 0) cur.firstAt = wt / 60;
        }
      }
      // атака
      if (_attack(front)) return;
    }
    _build(turtle);
    _points(turtle);
  }

  bool _wantJump() {
    if (!g.hasTech('jump')) return false;
    if (st.jump == 'never' && cur.idx >= st.turtleWorld) return false;
    final wt = s.worldTime / 60;
    if (wt < 5) return false;
    final n = g.own.length;
    final stall = wt - lastRecord / 60 >= st.stallMin;
    final crash = n <= cur.maxCells * 0.6 && cur.maxCells >= 4;
    if (!stall && !crash) return false;
    final tr = g.worldTrend().kind;
    if (stall && tr == 'grow' && !crash && wt - lastRecord / 60 < st.stallMin * 2) return false;
    _endWorld(crash ? 'потери клеток' : 'рост встал');
    g.rebirth();
    _newWorld();
    return true;
  }

  /// Сколько материи держать на следующий бой (0 — копить не на что)
  double reserve = 0;

  bool _attack(List<Cell> front) {
    final wt = s.worldTime;
    if (wt - lastFc < 4) return false;
    lastFc = wt;
    Cell? best;
    var bestCost = double.infinity;
    for (final c in front) {
      if (!c.alive) continue;
      final q = g.quickFight(c);
      final cost = q.beat ? q.cost : q.cost * 100 + c.might * 1e6;
      if (cost < bestCost) {
        bestCost = cost;
        best = c;
      }
    }
    reserve = 0;
    if (best == null) return false;
    // прогноз с неограниченной материей: можно ли победить вообще и сколько это стоит
    final m0 = s.matter;
    s.matter = 1e12;
    final fi = g.fightForecast(best);
    s.matter = m0;
    if (fi.p < st.attackP) return false;
    reserve = fi.spent * 1.15 + fi.capCost;
    if (s.matter < reserve) return false;
    final fc = g.fightForecast(best);
    if (fc.p >= st.attackP) {
      s.sel = best.key;
      final foe = g.foeFromCell(best);
      final hit = 10 * g.med() * g.powMul(), fh = foe.atk / g.defDiv();
      cur.fights.add([foe.maxHp / hit, g.maxHp() / fh, hit, g.maxHp(), foe.maxHp, fh]);
      g.startBattle(foe, best.key);
      cur.battles++;
      reserve = 0;
      return true;
    }
    return false;
  }

  /// Держит защиту клеток выше соседей тьмы с запасом
  void _defend() {
    for (var pass = 0; pass < 40; pass++) {
      Cell? worst;
      var ratio = double.infinity;
      for (final c in g.own) {
        if (c.spark) continue;
        final m = g.maxAdjMight(c);
        if (m <= 0) continue;
        final r = g.cellDef(c) / m;
        if (r < ratio) {
          ratio = r;
          worst = c;
        }
      }
      if (worst == null || ratio >= (cur.idx >= st.turtleWorld ? st.defMargin : 1.15)) return;
      // что выгоднее: укрепление или башня (прирост защиты на единицу материи)
      final d0 = g.cellDef(worst);
      final fCost = g.defCost(worst);
      final fGain = g.fortGain(worst);
      final canTower = Game.usedCap(worst) < Game.cap(worst);
      final tCost = g.bldCost(worst, 'tower');
      final tl = Game.bL(worst, 'tower');
      final tGain = d0 * ((1 + Game.towerPct(tl + 1) / 100) / (1 + Game.towerPct(tl) / 100) - 1);
      final useTower = canTower && ((st.towers && cur.idx >= st.turtleWorld) || tGain / tCost > fGain / fCost);
      final cost = useTower ? tCost : fCost;
      if (s.matter < cost) {
        // клетку не удержать: если тьма уже почти дошла и денег нет — ничего не поделать
        return;
      }
      if (useTower) {
        g.build(worst.key, 'tower');
      } else {
        g.fortify(worst.key);
      }
    }
  }

  void _build(bool turtle) {
    // шахты и заводы: самое дешёвое строение, если цена не больше половины материи
    for (var pass = 0; pass < 10; pass++) {
      Cell? bc;
      String? bt;
      var bcost = double.infinity;
      for (final c in g.own) {
        if (c.spark || Game.usedCap(c) >= Game.cap(c)) continue;
        // черепаха оставляет одну ячейку под башню
        if (turtle && Game.usedCap(c) >= Game.cap(c) - 1) continue;
        final m = Game.bL(c, 'mine'), f = Game.bL(c, 'factory');
        final t = m < (f + 1) * st.mineRatio ? 'mine' : 'factory';
        final cost = g.bldCost(c, t);
        if (cost < bcost) {
          bcost = cost;
          bc = c;
          bt = t;
        }
      }
      if (bc == null || bcost > s.matter * st.buildShare) return;
      g.build(bc.key, bt!);
    }
  }

  void _points(bool turtle) {
    if (turtle) return;
    var budget = math.max(0.0, s.matter - reserve) * st.ptShare;
    for (var i = 0; i < 200; i++) {
      final wantOs = s.osB < (s.opB + s.osB + 1) * st.osShare && s.abilities.any((a) => a != null);
      final info = wantOs ? g.osBuyInfo(1) : g.opBuyInfo(1);
      if (info.cost > budget || info.cost > s.matter) break;
      budget -= info.cost;
      wantOs ? g.buyOs(1) : g.buyOp(1);
    }
    // параметры по весам
    for (var i = 0; i < 500; i++) {
      String? best;
      var bs = double.infinity;
      final avg = g.parAvg;
      for (final p in Defs.params) {
        final lv = s.char[p.id] ?? 1;
        final w = st.w[p.id] ?? 1;
        if (w <= 0) continue;
        if (!st.skew && lv + 1 > avg * 1.5 + 1e-9 && (lv + 1) > 2) {
          // не переходить порог штрафа (среднее растёт вместе с ним — проверим после покупки)
          final na = (avg * 6 + 1) / 6;
          if (lv + 1 > na * 1.5) continue;
        }
        final score = lv / w;
        if (score < bs) {
          bs = score;
          best = p.id;
        }
      }
      if (best == null) break;
      final before = s.op;
      g.parUp(best, 1);
      if (s.op == before) break;
    }
    // способности: самую слабую по уровню
    for (var i = 0; i < 200; i++) {
      var bi = -1, bl = 1 << 30;
      for (var j = 0; j < s.abilities.length; j++) {
        final a = s.abilities[j];
        if (a != null && a.lvl < bl) {
          bl = a.lvl;
          bi = j;
        }
      }
      if (bi < 0) break;
      final before = s.os;
      g.abUp(bi, 1);
      if (s.os == before) break;
    }
  }

  /* ---------- артефакты ---------- */
  void _artifacts() {
    for (var i = s.artifacts.length - 1; i >= 0; i--) {
      final a = s.artifacts[i];
      final d = Defs.arts[a.type]!;
      Cell? c;
      final own = g.own.where((c) => !c.spark).toList();
      switch (a.type) {
        case 'core':
          c = g.own.firstWhere((c) => c.spark);
        case 'energy' || 'force' || 'matter' || 'bloom':
          if (own.isEmpty) continue;
          own.sort((x, y) => Game.usedCap(y).compareTo(Game.usedCap(x)));
          c = own.first;
        case 'bulwark':
          if (own.isEmpty) continue;
          own.sort((x, y) => (g.cellDef(x) / math.max(1, g.maxAdjMight(x))).compareTo(g.cellDef(y) / math.max(1, g.maxAdjMight(y))));
          c = own.first;
        case 'clot' || 'frost':
          final dark = g.vis.map(g.cell).whereType<Cell>().where((c) => !c.own && c.alive).toList()
            ..sort((x, y) => y.might.compareTo(x.might));
          if (dark.isEmpty) continue;
          c = dark.first;
        case 'glass':
          if (g.eraNow.kind != 'bad') continue;
      }
      if (d.target != 'player') {
        if (c == null) continue;
        s.sel = c.key;
      }
      g.applyArt(i);
    }
  }
}
