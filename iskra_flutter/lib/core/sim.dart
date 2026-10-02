// Бот играет в «Искру» без интерфейса: атакует самых слабых соседей, строит шахты и заводы,
// укрепляет клетки под угрозой, качает параметры и прыгает, когда рост встаёт.
// Нужен для проверки ядра (тесты, tool/sim.dart), в игре не используется.
import 'dart:math' as math;

import 'game.dart';

class SimResult {
  final Game game;
  final int battles, wins, defends, logs;
  SimResult(this.game, this.battles, this.wins, this.defends, this.logs);

  @override
  String toString() {
    final s = game.s, k = s.kills;
    final abs = s.abilities.map((a) => a == null ? '-' : '${a.id}:${a.lvl}').join(',');
    return 'matter ${Fmt.n(s.matter)}, earned ${Fmt.n(s.earned)}, cells ${game.own.length}, best ${s.bestCells}, '
        'rebirths ${s.rebirths}, bonus ${s.bonus}, battles $battles, wins $wins, defends $defends, '
        'kills ${k['low']}/${k['rare']}/${k['epic']}/${k['legend']}, arts ${s.artifacts.length}, cores ${s.cores.length}, '
        'pulsars ${s.pulsars}, tech ${s.tech}, logs $logs\n  char ${s.char.values.join('/')}, abilities $abs, era ${game.eraNow.name}, '
        'trend ${game.worldTrend().text}';
  }
}

SimResult runSim({int seed = 1, double minutes = 60, bool rich = false}) {
  final g = Game(random: math.Random(seed));
  var logs = 0, defends = 0, battles = 0, wins = 0;
  g.onLog = (_, _) => logs++;
  g.onDefend = () => defends++;
  g.newGame();
  g.s.introSeen = true;
  g.s.tech['jump'] = 1;
  const dt = 0.1;
  var t = 0.0;
  var frames = 0;
  while (t < minutes * 60) {
    g.now = t;
    g.frame(dt);
    t += dt;
    frames++;
    if (g.gameOver) {
      g.rebirth();
      continue;
    }
    final d = g.def;
    if (d != null) {
      final fc = g.fightForecast(g.cell(d.att)!);
      if (fc.p > 0.5) {
        g.defendFight();
        battles++;
      } else {
        g.defendFlee();
      }
    }
    final bt = g.b;
    if (bt != null) {
      if (!bt.started) g.battleStart();
      for (var i = 0; i < 4; i++) {
        g.doAction('ab$i');
      }
      if (bt.over) {
        if (bt.won) wins++;
        final ch = bt.choice;
        if (ch != null) g.resolveChoice(ch.dup ? 'up' : '0');
        g.closeBattle();
        g.s.paused = false;
      }
      continue;
    }
    if (rich && frames % 600 == 0) {
      g.s.matter += 1e5 * (1 + t / 600);
      g.s.pulsars += 5;
    }
    if (frames % 10 != 0) continue;
    g.s.paused = false;
    // технологии: самый дешёвый доступный ранг
    final techs = Defs.tech.where((t) => !t.soon && g.techOpen(t) && g.techNextCost(t) != null).toList()
      ..sort((a, b) => g.techNextCost(a)!.compareTo(g.techNextCost(b)!));
    if (techs.isNotEmpty) g.researchTech(techs.first.id);
    // покупки
    for (final c in g.own.toList()) {
      if (c.spark) continue;
      if (g.threatened(c)) g.fortify(c.key);
      if (Game.usedCap(c) < Game.cap(c)) g.build(c.key, Game.bL(c, 'mine') <= Game.bL(c, 'factory') ? 'mine' : 'factory');
    }
    if (g.opBuyInfo(10).cost < g.s.matter * 0.3) g.buyOp(10);
    for (final p in Defs.params) {
      g.parUp(p.id, buyMax);
    }
    if (g.osBuyInfo(1).cost < g.s.matter * 0.1) g.buyOs(1);
    for (var i = 0; i < 4; i++) {
      g.abUp(i, buyMax);
    }
    for (var i = g.s.artifacts.length - 1; i >= 0; i--) {
      final tgt = Defs.arts[g.s.artifacts[i].type]!.target;
      final Cell? cell = switch (tgt) {
        'spark' => g.own.firstWhere((c) => c.spark),
        'own' => g.own.where((c) => !c.spark).firstOrNull,
        'dark' => g.vis.map(g.cell).whereType<Cell>().where((c) => !c.own).firstOrNull,
        _ => null,
      };
      if (cell != null) g.s.sel = cell.key;
      g.applyArt(i);
    }
    // захват свободных и атака самых слабых
    final front = g.vis.map(g.cell).whereType<Cell>().where((c) => !c.own).toList()..sort((a, b) => a.might.compareTo(b.might));
    final free = front.where((c) => !c.alive && g.s.matter >= c.might.ceil()).firstOrNull;
    if (free != null) {
      g.capture(free.key);
      continue;
    }
    final target = front.where((c) => c.alive).firstOrNull;
    if (target != null && frames % 50 == 0) {
      final fc = g.fightForecast(target);
      if (fc.p >= 0.85 && g.s.matter >= fc.need + fc.capCost) {
        g.s.sel = target.key;
        g.startBattle(g.foeFromCell(target), target.key);
        battles++;
      }
    }
    if (frames % 600 == 0 && g.worldTrend().kind == 'dark' && g.own.length > 3) g.rebirth();
  }
  return SimResult(g, battles, wins, defends, logs);
}
