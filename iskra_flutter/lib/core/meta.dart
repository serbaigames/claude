// «Искра» — прокачка персонажа и способностей, артефакты, прыжок искры.
part of 'game.dart';

/// Сколько покупать за раз: ×1, ×10, ×100 или MAX (0)
typedef BuyMode = int;
const BuyMode buyMax = 0;
const buyModes = <BuyMode>[1, 10, 100, buyMax];
String buyModeLabel(BuyMode m) => m == buyMax ? 'MAX' : '×$m';

extension GameMeta on Game {
  /* ---------- очки параметров и способностей ---------- */
  static double _lvlCost(int lvl, int n, int per) => per * (n * lvl + n * (n - 1) / 2);

  static int _lvlCount(BuyMode mode, int lvl, int per, num budget) {
    if (mode != buyMax) return mode;
    var n = 0;
    var c = 0.0;
    while (n < 100000) {
      final nx = (lvl + n) * per;
      if (c + nx > budget) break;
      c += nx;
      n++;
    }
    return n;
  }

  // Каждое следующее очко дороже предыдущего на 1,5% (счёт за мир, сбрасывается при прыжке вместе с персонажем)
  static double _ptCost(double base, int k, int n) =>
      n <= 0 ? 0 : (base * math.pow(Bal.ptGrow, k) * (math.pow(Bal.ptGrow, n) - 1) / (Bal.ptGrow - 1)).ceilToDouble();
  static int _ptMax(double base, int k, double m) =>
      math.max(0, (math.log(1 + m * (Bal.ptGrow - 1) / (base * math.pow(Bal.ptGrow, k))) / math.log(Bal.ptGrow)).floor());

  ({int n, double cost, double next}) _ptInfo(double base, int k, BuyMode mode) {
    final maxN = _ptMax(base, k, s.matter);
    var n = mode == buyMax ? maxN : mode;
    var cost = _ptCost(base, k, n);
    if (mode != buyMax && cost > s.matter) {
      n = math.min(n, maxN);
      cost = _ptCost(base, k, n);
    }
    return (n: n, cost: cost, next: _ptCost(base, k, 1));
  }

  // Бонус прыжка удешевляет очки (цена ÷ √бонуса), эра может удешевить или удорожить их
  double _ptBase(double base) => base * eraV('pt') / math.sqrt(bonusMul);

  ({int n, double cost, double next}) opBuyInfo(BuyMode mode) => _ptInfo(_ptBase(20), s.opB, mode);
  ({int n, double cost, double next}) osBuyInfo(BuyMode mode) => _ptInfo(_ptBase(10), s.osB, mode);

  ({int n, double cost}) parInfo(String key, BuyMode mode) {
    final lv = s.char[key] ?? 1;
    final n = _lvlCount(mode, lv, 1, s.op);
    return (n: n, cost: _lvlCost(lv, n, 1));
  }

  ({int n, double cost}) abInfo(int i, BuyMode mode) {
    final a = s.abilities[i]!;
    final per = Defs.tiers[Defs.abilities[a.id]!.tier]!.os;
    final n = _lvlCount(mode, a.lvl, per, s.os);
    return (n: n, cost: _lvlCost(a.lvl, n, per));
  }

  void buyOp(BuyMode mode) {
    final x = opBuyInfo(mode);
    if (x.n > 0 && s.matter >= x.cost) {
      s.matter -= x.cost;
      s.op += x.n;
      s.opB += x.n;
      sfx('buy');
    }
  }

  void buyOs(BuyMode mode) {
    final x = osBuyInfo(mode);
    if (x.n > 0 && s.matter >= x.cost) {
      s.matter -= x.cost;
      s.os += x.n;
      s.osB += x.n;
      sfx('buy');
    }
  }

  void parUp(String key, BuyMode mode) {
    final x = parInfo(key, mode);
    if (x.n > 0 && s.op >= x.cost) {
      s.op -= x.cost.toInt();
      s.char[key] = (s.char[key] ?? 1) + x.n;
    }
  }

  void abUp(int i, BuyMode mode) {
    final a = s.abilities[i];
    if (a == null) return;
    final x = abInfo(i, mode);
    if (x.n > 0 && s.os >= x.cost) {
      s.os -= x.cost.toInt();
      a.inv += x.cost.toInt();
      a.lvl += x.n;
    }
  }

  /// Удаление способности: возвращается половина вложенных ОС
  void abDelete(int i) {
    final a = s.abilities[i];
    if (a == null) return;
    s.os += a.inv ~/ 2;
    s.abilities[i] = null;
    log('Способность «${Defs.abilities[a.id]!.name}» удалена.');
  }

  /* ---------- артефакты ---------- */
  bool artValid(Artifact a, Cell? c) {
    final t = Defs.arts[a.type]!.target;
    if (t == 'player') return true;
    if (c == null || !vis.contains(c.key)) return false;
    if (t == 'spark') return c.spark;
    return t == 'own' ? c.own && !c.spark : !c.own;
  }

  String artTitle(Artifact a) {
    final d = Defs.arts[a.type]!;
    if (d.stat != null || a.type == 'bulwark') return '${d.name} +${a.v}%';
    return switch (a.type) {
      'core' => '${d.name} ×${a.v}',
      'bloom' => '${d.name} +${a.v} мин',
      'tome' => '${d.name} +${a.v} ОП',
      'rune' => '${d.name} +${a.v} ОС',
      _ => d.name,
    };
  }

  /// Короткая подпись в ячейке артефакта
  String artBadge(Artifact a) {
    final d = Defs.arts[a.type]!;
    if (d.stat != null || a.type == 'bulwark') return '+${a.v}%';
    return switch (a.type) {
      'core' => '×${a.v}',
      'clot' => '÷2',
      'bloom' => '+${a.v}м',
      'frost' => '½',
      'tome' => '+${a.v}ОП',
      'rune' => '+${a.v}ОС',
      _ => 'эра',
    };
  }

  String artDesc(Artifact a) {
    final d = Defs.arts[a.type]!;
    switch (a.type) {
      case 'bulwark':
        return 'Навсегда усиливает защиту вашей клетки на ${a.v}%.';
      case 'bloom':
        return 'Добавляет вашей клетке ${a.v} мин владения — она быстрее набирает уровни.';
      case 'frost':
        return 'Вдвое замедляет развитие клетки тьмы.';
      case 'tome':
        return 'Даёт ${a.v} очков параметров.';
      case 'rune':
        return 'Даёт ${a.v} очков способностей.';
      case 'glass':
        return 'Завершает текущую эру и начинает новую, случайную.';
      case 'core':
        final after = coreSum + (a.v ?? 0);
        return 'Множитель ×${a.v} прибавляется к множителям прежних ядер: базовая добыча искры навсегда станет '
            '0,5 × $after = ${Fmt.x(0.5 * after)} за клетку (сейчас ×$coreMul). Применяется к искре.';
    }
    return d.stat != null ? 'Добавляет захваченной клетке ${a.v}% ${d.word}.' : 'Вдвое снижает мощь не захваченной клетки.';
  }

  /// Применить артефакт к выбранной клетке (или к игроку)
  void applyArt(int i) {
    if (i < 0 || i >= s.artifacts.length) return;
    final a = s.artifacts[i];
    final c = s.sel == null ? null : s.cells[s.sel];
    if (!artValid(a, c)) return;
    final d = Defs.arts[a.type]!;
    final v = a.v ?? 0;
    stat('arts');
    sfx('art');
    if (d.stat != null) {
      switch (d.stat) {
        case 'm':
          c!.m += v;
        case 'e':
          c!.e += v;
        default:
          c!.f += v;
      }
      log('${d.name}: клетка получила +$v% ${d.word}.', 'good');
    } else if (a.type == 'bulwark') {
      c!.defMul = (c.defMul > 0 ? c.defMul : 1) * (1 + v / 100);
      log('${d.name}: защита клетки +$v%.', 'good');
    } else if (a.type == 'bloom') {
      c!.held += v * 60;
      log('${d.name}: клетка получила $v мин владения.', 'good');
    } else if (a.type == 'frost') {
      c!.dev = 1 + (c.dev - 1) * 0.5;
      log('${d.name}: развитие клетки тьмы замедлено вдвое.', 'good');
    } else if (a.type == 'tome') {
      s.op += v;
      log('${d.name}: +$v ОП.', 'good');
    } else if (a.type == 'rune') {
      s.os += v;
      log('${d.name}: +$v ОС.', 'good');
    } else if (a.type == 'glass') {
      newEra();
    } else if (a.type == 'core') {
      final was = coreMul;
      s.cores.add(v);
      log('${d.name} ×$v: базовая добыча искры навсегда ×$was → ×$coreMul (${Fmt.x(0.5 * coreMul)} за клетку).', 'good');
    } else {
      final was = c!.might.ceil();
      c.might /= 2;
      log('${d.name}: мощь клетки тьмы $was → ${c.might.ceil()}.', 'good');
    }
    s.artifacts.removeAt(i);
  }

  /// Лучший артефакт данного вида (для быстрых кнопок)
  int bestArt(String type) {
    var bi = -1, bv = -1;
    for (var i = 0; i < s.artifacts.length; i++) {
      final a = s.artifacts[i];
      if (a.type == type && (a.v ?? 0) > bv) {
        bv = a.v ?? 0;
        bi = i;
      }
    }
    return bi;
  }

  int _rollCore() {
    final q = random;
    return q < 0.5
        ? 2
        : q < 0.8
        ? 3
        : q < 0.95
        ? 4
        : 5;
  }

  int _r(int a, int b) => a + randInt(b - a + 1);

  /// Награды после победы: пульсар, ядро искры, артефакт
  String artDrop(String tier) {
    var msg = '';
    if (random < Defs.pulsarChance[tier]! * eraV('drop')) {
      s.pulsars++;
      msg += ' Выпал пульсар!';
    }
    // ядро: гарантировано за легендарную, 5% за эпическую
    if (tier == 'legend' || (tier == 'epic' && random < 0.05 * aggr)) {
      final a = Artifact('core', _rollCore());
      s.artifacts.add(a);
      msg += ' Выпало «${artTitle(a)}»!';
    }
    if (random >= Defs.artChance[tier]! * aggr * eraV('drop')) return msg;
    final w = Defs.artWeights(tier);
    var r = random * w.values.fold<double>(0, (x, y) => x + y);
    var type = 'energy';
    for (final e in w.entries) {
      r -= e.value;
      if (r < 0) {
        type = e.key;
        break;
      }
    }
    final a = Artifact(type);
    if (Defs.arts[type]!.stat != null) a.v = 5 + randInt(46);
    if (type == 'core') a.v = _rollCore();
    if (type == 'bulwark') a.v = _r(10, 40);
    if (type == 'bloom') a.v = _r(1, 8);
    if (type == 'tome' || type == 'rune') a.v = _r(5, 25);
    s.artifacts.add(a);
    return '$msg Выпал артефакт: «${artTitle(a)}»!';
  }

  /* ---------- прыжок искры ---------- */
  // Прибавка к бонусу: 0,02 × рекорд клеток^1,5 × агрессивность^2,5 — длинный мир выгоднее серии быстрых сбросов
  double rebirthGain() => jsRound(0.02 * math.pow(s.worldMax, 1.5) * math.pow(aggr, 2.5) * 100) / 100;

  void rebirth() {
    s.lastWorld = s.worldTime;
    s.bonus = jsRound((s.bonus + rebirthGain()) * 100) / 100;
    s.rebirths++;
    // Персонаж, очки и способности начинаются заново; остаются бонус, скорость искры, ядро и артефакты
    for (final p in Defs.params) {
      s.char[p.id] = 1;
    }
    s.op = 0;
    s.os = 0;
    s.opB = 0;
    s.osB = 0;
    s.abilities = GameState.newSlots();
    b = null;
    def = null;
    gameOver = false;
    freshWorld();
    sfx('jump');
    log('Искра совершила прыжок в новую область вселенной. Агрессивность: $aggrText.', 'good');
  }
}
