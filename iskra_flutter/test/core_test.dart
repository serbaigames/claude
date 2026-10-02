import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:iskra/core/game.dart';
import 'package:iskra/core/sim.dart';

// Сохранение в том виде, как его пишет браузерная версия (сокращено до нужных полей)
const webSave = '''
{"matter":120.5,"earned":900,"op":2,"os":3,"opB":4,"osB":1,
 "char":{"life":3,"defense":2,"power":2,"meditation":1,"speed":1,"control":1},
 "abilities":[{"id":"spark_strike","lvl":2,"inv":1},null,{"id":"veil","lvl":1,"inv":0},null],
 "artifacts":[{"type":"energy","v":12},{"type":"glass"}],
 "rebirths":1,"bonus":0.35,"kills":{"low":5,"rare":1,"epic":0,"legend":0},"lastWorld":800,"introSeen":true,
 "bestCells":6,"saved":1759380000000,"pulsars":0,"tech":{"jump":1},"cores":[2],"coreMul":2,
 "era":{"i":3,"left":120,"dur":300},"wk":4,"we":500,"worldTime":640,"aggr":1.2,"nextAggr":0.9,
 "cells":{
  "0,0":{"q":0,"r":0,"own":true,"spark":true,"m":30,"e":40,"f":30,"def":0,"defLvl":0,"b":{},"inv":0},
  "1,0":{"q":1,"r":0,"own":true,"m":20,"e":50,"f":30,"might":9,"dev":1.01,"growth":10,"t":0,"tier":"low","traits":[],"alive":false,
         "def":12,"defLvl":1,"defMul":1,"b":{"mine":2,"factory":1},"inv":0,"held":200,"age":0,"lv0":2},
  "2,0":{"q":2,"r":0,"own":false,"m":10,"e":10,"f":80,"might":14.2,"dev":1.02,"growth":12,"t":3,"tier":"rare","traits":["shell"],"alive":true},
  "0,1":{"q":0,"r":1,"own":false,"m":10,"e":10,"f":80,"might":11,"dev":1.02,"growth":12,"t":3,"tier":"low","traits":[],"alive":true,"bld":"mine","bldLvl":1}
 },
 "worldStart":1759379000000,"worldMax":6,"sel":"1,0","lostOnce":false,"paused":false,"speed":2,"futureField":42}
''';

void main() {
  test('новая игра: искра и шесть соседей тьмы', () {
    final g = Game(random: math.Random(1))..newGame();
    expect(g.own.length, 1);
    expect(g.s.cells.length, 7);
    expect(g.s.cells['0,0']!.spark, isTrue);
    expect(g.income(), greaterThan(0));
  });

  test('сохранение из браузера загружается и сохраняется обратно в том же формате', () {
    final j = jsonDecode(webSave) as Map<String, dynamic>;
    expect(GameState.looksValid(j), isTrue);
    final g = Game(random: math.Random(2));
    expect(g.attach(GameState.fromJson(j)), isTrue);
    expect(g.own.length, 2);
    expect(g.s.char['life'], 3);
    expect(g.s.abilities[1], isNull);
    expect(g.s.abilities[2]!.id, 'veil');
    expect(g.coreMul, 2);
    expect(g.hasTech('jump'), isTrue);
    expect(Game.bL(g.s.cells['1,0']!, 'mine'), 2);
    expect(Game.bL(g.s.cells['0,1']!, 'mine'), 1, reason: 'старое поле bld/bldLvl');
    expect(g.eraNow.id, 'torpor');

    final out = jsonDecode(jsonEncode(g.s.toJson())) as Map<String, dynamic>;
    expect(GameState.looksValid(out), isTrue, reason: 'сервер проверяет cells, matter и искру');
    expect(out['char'], isA<Map>());
    expect(out['tech'], {'jump': 1});
    expect(out['abilities'][1], isNull);
    expect((out['cells'] as Map).keys, containsAll(['0,0', '1,0', '2,0']));
    expect(out['cells']['1,0']['b'], {'mine': 2, 'factory': 1});
    expect(out['futureField'], 42, reason: 'неизвестные поля не теряются');
    expect(out['kills'], {'low': 5, 'rare': 1, 'epic': 0, 'legend': 0});
    expect(out['earned'], 900);
    expect(out['bestCells'], 6);
  });

  test('бой: победа над слабой сущностью даёт материю и клетку', () {
    final g = Game(random: math.Random(3))..newGame();
    final c = g.vis.map(g.cell).whereType<Cell>().where((c) => !c.own).first;
    c.might = 1;
    c.traits = [];
    g.s.matter = 1000;
    g.startBattle(g.foeFromCell(c), c.key);
    g.battleStart();
    for (var i = 0; i < 2000 && !g.b!.over; i++) {
      g.now += 0.05;
      g.battleTick(0.05);
    }
    expect(g.b!.won, isTrue);
    expect(c.own, isTrue);
    expect(g.s.kills[c.tier], 1);
    g.closeBattle();
    expect(g.b, isNull);
  });

  test('прогноз боя даёт вероятность от 0 до 1', () {
    final g = Game(random: math.Random(4))..newGame();
    final c = g.vis.map(g.cell).whereType<Cell>().firstWhere((c) => !c.own);
    final fc = g.fightForecast(c);
    expect(fc.p, inInclusiveRange(0, 1));
    expect(fc.capCost, c.might.ceil());
  });

  test('прыжок сбрасывает персонажа и оставляет бонус', () {
    final g = Game(random: math.Random(5))..newGame();
    g.s.worldMax = 10;
    g.s.char['life'] = 7;
    g.rebirth();
    expect(g.s.rebirths, 1);
    expect(g.s.bonus, greaterThan(0));
    expect(g.s.char['life'], 1);
    expect(g.own.length, 1);
  });

  test('технологии: порядок изучения, ранги 3/9/27 и множители поверх остальных', () {
    final g = Game(random: math.Random(7))..newGame();
    final grow = Defs.techById['grow']!, fort = Defs.techById['fort']!, inc = Defs.techById['income']!;
    expect([for (var r = 0; r < 3; r++) grow.rankCost(r)], [3, 9, 27]);
    g.s.pulsars = 100;
    // без «Прыжка» второй уровень закрыт
    g.researchTech('grow');
    expect(g.techRank('grow'), 0);
    g.researchTech('jump');
    expect(g.hasTech('jump'), isTrue);
    // третий уровень закрыт, пока не изучен 1-й ранг родителя, и пока не готов
    expect(g.techOpen(Defs.techById['grow-a']!), isFalse);
    final inc0 = g.income();
    g.researchTech('income');
    expect(g.techRank('income'), 1);
    expect(g.s.pulsars, 100 - 1 - 3);
    expect(g.income(), closeTo(inc0 * (1 + inc.per), 1e-9));
    g.researchTech('income');
    g.researchTech('income');
    g.researchTech('income'); // четвёртого ранга нет
    expect(g.techRank('income'), 3);
    expect(g.s.pulsars, 100 - 1 - 3 - 9 - 27);
    expect(g.techOpen(Defs.techById['income-a']!), isTrue);
    g.researchTech('income-a'); // «скоро» — не изучается
    expect(g.techRank('income-a'), 0);

    // укрепление: защита от уровня укрепления растёт на 25% за ранг
    final c = g.s.cells.values.firstWhere((c) => !c.own)
      ..own = true
      ..alive = false
      ..def = 100
      ..defLvl = 2;
    final pct0 = g.fortPct(c);
    g.researchTech('fort');
    expect(g.fortPct(c), closeTo(pct0 * (1 + fort.per), 1e-9));

    // рост: время владения клеткой идёт быстрее
    g.refresh();
    g.researchTech('grow');
    final h0 = c.held;
    g.tick(1);
    expect(c.held - h0, closeTo(g.eraV('held') * (1 + grow.per), 1e-9));

    // технологии сохраняются при прыжке и в сохранении
    g.s.worldMax = 10;
    g.rebirth();
    expect(g.techRank('income'), 3);
    final back = GameState.fromJson(jsonDecode(jsonEncode(g.s.toJson())) as Map<String, dynamic>);
    expect(back.tech, {'jump': 1, 'income': 3, 'fort': 1, 'grow': 1});
  });

  test('штраф за перекос: от превышения среднего на 50% — 10/25/50%', () {
    expect(Game.penFor(15, 10), 0);
    expect(Game.penFor(16, 10), 0.10);
    expect(Game.penFor(21, 10), 0.25);
    expect(Game.penFor(26, 10), 0.50);
    final g = Game(random: math.Random(1))..newGame();
    for (final p in Defs.params) {
      g.s.char[p.id] = 10;
    }
    expect(g.eff('power').pen, 0);
    g.s.char['power'] = 40; // среднее 15, превышение ×2.67
    expect(g.eff('power').pen, 0.50);
    expect(g.eff('power').v, 20);
    expect(g.eff('life').pen, 0);
  });

  test('симуляция: бот играет час без ошибок на нескольких сидах', () {
    for (final seed in [1, 2, 3]) {
      final r = runSim(seed: seed, minutes: 60);
      expect(r.game.s.earned, greaterThan(0));
      expect(r.game.own, isNotEmpty);
    }
  });
}
