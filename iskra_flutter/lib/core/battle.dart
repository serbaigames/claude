// «Искра» — бой с сущностью тьмы: автоматическая атака, навыки, особенности врага, награды.
part of 'game.dart';

class Foe {
  final String name, tier;
  final int dist;
  final double maxHp, atk, cd, matter, pen;
  final List<String> traits;
  double hp, t = 0, wt = 0;
  int hits = 0;

  Foe({
    required this.name,
    required this.tier,
    required this.dist,
    required this.maxHp,
    required this.atk,
    required this.cd,
    required this.matter,
    required this.pen,
    required this.traits,
  }) : hp = maxHp;
}

/// Визуальный эффект на арене: ядро только сообщает, интерфейс рисует
class Vfx {
  final String kind; // bolt, spiral, heal, flash, stun, num
  final String at; // 'p' — искра, 'f' — враг
  final int color;
  final String? text;
  final double t0;
  const Vfx(this.kind, this.at, this.color, this.t0, [this.text]);
}

class BattleChoice {
  final String id, tier;
  final bool dup;
  const BattleChoice(this.id, this.tier, {this.dup = false});
}

class Battle {
  final Foe foe;
  final String cell;
  String? defend;
  double hp, maxHp, cd = 0;
  String? last;
  int combo = 0;
  double shield = 0, immune = 0, haste = 0, dot = 0, dotV = 0, mend = 0, mendV = 0, weak = 0, refl = 0, dispel = 0;
  final List<double> abCd = List.filled(Bal.abilitySlots, 0);
  bool over = false, started = false, noAtk = false, won = false;
  final List<String> log = [];
  BattleChoice? choice;
  String status = 'Осмотрите противника и нажмите «Начать бой». Каждый ход тратит свободную материю.';
  final List<Vfx> fx = [];
  double shP = 0, shF = 0; // до какого времени трясти искру / врага

  Battle(this.foe, this.cell, this.hp) : maxHp = hp;
}

extension GameBattle on Game {
  void startBattle(Foe foe, String cellKey) {
    s.paused = true; // при начале боя мир встаёт на паузу
    if (b != null) return;
    b = Battle(foe, cellKey, maxHp());
  }

  void _vfx(String kind, String at, int color, [String? text]) {
    final bt = b;
    if (bt == null) return;
    bt.fx.add(Vfx(kind, at, color, now, text));
    if (bt.fx.length > 40) bt.fx.removeAt(0);
  }

  void _blog(String t) {
    final bt = b!;
    bt.log.insert(0, t);
    if (bt.log.length > 300) bt.log.removeLast();
  }

  /// Цена и готовность хода: 'attack' или 'ab0'…'ab3'
  ({double cost, bool ready})? actInfo(String act) {
    final bt = b;
    if (act == 'attack') return (cost: math.max(1, (4 * med()).ceil()).toDouble(), ready: true);
    final i = int.parse(act.substring(2));
    final a = s.abilities[i];
    if (a == null || bt == null) return null;
    return (cost: math.max(1, Game.abCost(a).ceil()).toDouble(), ready: bt.abCd[i] <= 0);
  }

  // «Рассеивание» отключает особенности
  bool _has(String tr) {
    final bt = b;
    return bt != null && !(bt.dispel > 0) && bt.foe.traits.contains(tr);
  }

  bool wardOn() => _has('ward') && (b!.foe.wt % 10) >= 8;
  bool traitActive(String tr) => _has(tr);

  double _hitFoe(double d, [bool pierce = false]) {
    final bt = b!;
    if (!pierce && wardOn()) {
      _vfx('flash', 'f', 0xFFB89BFF);
      _vfx('num', 'f', 0xFFB89BFF, 'завеса');
      return 0;
    }
    if (!pierce && _has('shell') && bt.foe.hp > bt.foe.maxHp * 0.5) d *= 0.65;
    d = jsRound(d);
    bt.foe.hp -= d;
    bt.shF = now + 0.25;
    _vfx('num', 'f', 0xFFFFE3A3, '−${d.toInt()}');
    return d;
  }

  double _healMe(double h) {
    final bt = b!;
    final before = bt.hp;
    bt.hp = math.min(bt.maxHp, bt.hp + h);
    final x = jsRound(bt.hp - before);
    if (x > 0) {
      _vfx('heal', 'p', 0xFF7BE0A8);
      _vfx('num', 'p', 0xFF7BE0A8, '+${x.toInt()}');
    }
    return x;
  }

  void battleStart() {
    final bt = b;
    if (bt == null || bt.started || bt.over) return;
    bt.started = true;
    bt.status = 'Бой идёт! Каждый ход тратит свободную материю.';
    _vfx('flash', 'p', 0xFFFFF3C4);
  }

  void doAction(String act) {
    final bt = b;
    if (bt == null || bt.over || !bt.started) return;
    if (act == 'attack' && bt.cd > 0) return; // навыки ждут только свой откат
    final info = actInfo(act);
    if (info == null || !info.ready || s.matter < info.cost) return;
    s.matter -= info.cost;
    if (act == 'attack') {
      _vfx('bolt', 'p', 0xFFFFD27A);
      _blog('Атака: ${_hitFoe(10 * med() * powMul() * rnd(.9, 1.1)).toInt()} урона (−${info.cost.toInt()} материи)');
    } else {
      final i = int.parse(act.substring(2));
      final a = s.abilities[i]!, d = Defs.abilities[a.id]!, v = abVal(a);
      bt.abCd[i] = d.cd;
      _vfx(d.kind == 'heal' || d.kind == 'regenme' ? 'heal' : 'bolt', 'p', Defs.tierColor[d.tier]!);
      String n(double x) => '${x.toInt()}';
      switch (d.kind) {
        case 'dmg':
          _blog('${d.name}: ${n(_hitFoe(v * powMul() * rnd(.9, 1.1)))} урона');
        case 'heal':
          _blog('${d.name}: +${n(_healMe(v))} здоровья');
        case 'shield':
          bt.shield = v;
          _blog('${d.name}: урон по вам снижен');
        case 'drain':
          final x = _hitFoe(v * powMul());
          _blog('${d.name}: ${n(x)} урона, +${n(_healMe(x * 0.6))} здоровья');
        case 'haste':
          bt.haste = v;
          _blog('${d.name}: ходы ускорены');
        case 'immune':
          bt.immune = v;
          _blog('${d.name}: вы неуязвимы');
        case 'absorb':
          final x = _hitFoe(bt.foe.maxHp * v);
          _blog('${d.name}: ${n(x)} урона, +${n(_healMe(x * 0.5))} здоровья');
        case 'dot':
          bt.dot = Bal.dotT;
          bt.dotV = v * powMul();
          _blog('${d.name}: враг горит');
        case 'stunfoe':
          bt.foe.t -= v;
          _blog('${d.name}: удар врага отброшен');
        case 'regenme':
          bt.mend = Bal.mendT;
          bt.mendV = v;
          _blog('${d.name}: здоровье восстанавливается');
        case 'pierce':
          _blog('${d.name}: ${n(_hitFoe(v * powMul() * rnd(.9, 1.1), true))} урона');
        case 'weaken':
          bt.weak = v;
          _blog('${d.name}: враг ослаблен');
        case 'harvest':
          final x = _hitFoe(v * powMul() * rnd(.9, 1.1));
          var g = 0.0;
          if (x > 0) {
            g = Game.abCost(a) * 2;
            s.matter += g;
            _vfx('spiral', 'f', 0xFFF2B441);
          }
          _blog('${d.name}: ${n(x)} урона${g > 0 ? ', +${n(g)} материи' : ''}');
        case 'reflect':
          bt.refl = v;
          _blog('${d.name}: удары отражаются');
        case 'execute':
          final low = bt.foe.hp < bt.foe.maxHp * 0.3;
          _blog('${d.name}: ${n(_hitFoe(v * powMul() * rnd(.9, 1.1) * (low ? 3 : 1)))} урона${low ? ' — добивание!' : ''}');
        case 'dispel':
          bt.dispel = v;
          _blog('${d.name}: особенности врага отключены');
      }
    }
    if (bt.last == act) {
      bt.combo++;
    } else {
      bt.combo = 0;
    }
    bt.last = act;
    if (act == 'attack') bt.cd = turnCd() * (bt.haste > 0 ? 0.5 : 1);
    _checkEnd();
  }

  void battleTick(double dt) {
    final bt = b;
    if (bt == null || bt.over || !bt.started) return;
    final f = bt.foe;
    bt.cd = math.max(0, bt.cd - dt);
    for (var i = 0; i < bt.abCd.length; i++) {
      bt.abCd[i] = math.max(0, bt.abCd[i] - dt);
    }
    bt.shield = math.max(0, bt.shield - dt);
    bt.immune = math.max(0, bt.immune - dt);
    bt.haste = math.max(0, bt.haste - dt);
    bt.weak = math.max(0, bt.weak - dt);
    bt.refl = math.max(0, bt.refl - dt);
    bt.dispel = math.max(0, bt.dispel - dt);
    if (bt.dot > 0) {
      bt.dot -= dt;
      var x = bt.dotV * dt;
      if (_has('shell') && f.hp > f.maxHp * 0.5) x *= 0.65;
      f.hp -= x;
    }
    if (bt.mend > 0) {
      bt.mend -= dt;
      bt.hp = math.min(bt.maxHp, bt.hp + bt.mendV * dt);
    }
    f.t += dt;
    f.wt += dt;
    if (_has('regen') && f.hp > 0) f.hp = math.min(f.maxHp, f.hp + f.maxHp * 0.015 * dt);
    final fcd = _has('rage') && f.hp < f.maxHp * 0.4 ? f.cd / 1.6 : f.cd;
    if (f.t >= fcd) {
      f.t = 0;
      f.hits++;
      var d = f.atk * rnd(.85, 1.15) / defDiv();
      _vfx('bolt', 'f', Defs.tierColor[f.tier] ?? 0xFFEF6B90);
      if (bt.immune > 0) {
        _blog('${f.name} бьёт, но вы неуязвимы');
        _vfx('num', 'p', 0xFFFFD27A, '0');
      } else {
        if (bt.shield > 0) d *= 0.5;
        if (bt.weak > 0) d *= 0.6;
        d = jsRound(d);
        bt.hp -= d;
        if (bt.refl > 0 && d > 0) {
          final r = jsRound(d * 0.6);
          f.hp -= r;
          _vfx('num', 'f', 0xFFDFE8FF, '−${r.toInt()}');
          _blog('Зеркало: ${r.toInt()} урона обратно');
        }
        _blog('${f.name} наносит ${d.toInt()} урона');
        bt.shP = now + 0.3;
        _vfx('num', 'p', 0xFFFF8AA8, '−${d.toInt()}');
        if (_has('leech')) {
          final l = math.min(math.max(0.0, s.matter), leechAmt());
          s.matter -= l;
          if (l > 0) {
            _blog('Иссушение: −${l.toInt()} материи');
            _vfx('spiral', 'p', 0xFFF2B441);
          }
        }
        if (_has('stun') && f.hits % 4 == 0) {
          bt.cd += 1;
          _blog('Оглушение: ваш ход задержан');
          _vfx('stun', 'p', 0xFFFFE08A);
        }
      }
    }
    _checkEnd();
    // атака — автоматически, как только готов ход и хватает материи
    if (!bt.over && bt.cd <= 0) {
      final ai = actInfo('attack')!;
      if (s.matter >= ai.cost) {
        doAction('attack');
      } else if (!bt.noAtk) {
        bt.noAtk = true;
        _blog('Не хватает материи на атаку');
      }
    }
  }

  void _checkEnd() {
    final bt = b!;
    if (bt.over) return;
    if (bt.foe.hp <= 0) {
      _finish(true);
    } else if (bt.hp <= 0) {
      _finish(false);
    }
  }

  void _finish(bool win, [bool fled = false]) {
    final bt = b!;
    bt.over = true;
    bt.won = win;
    final f = bt.foe;
    String msg;
    if (win) {
      final gain = (f.matter * 0.5).floorToDouble();
      addMatter(gain);
      s.kills[f.tier] = (s.kills[f.tier] ?? 0) + 1;
      s.wk++;
      final c = s.cells[bt.cell];
      var capMsg = '';
      if (c != null && !c.own) {
        c.alive = false;
        final cost = c.might.ceil();
        if (s.matter >= cost) {
          capture(bt.cell);
          capMsg = ' Клетка захвачена за $cost материи.';
        } else {
          capMsg = ' На захват не хватило материи: нужно $cost.';
        }
      }
      msg = 'Победа! +${gain.toInt()} материи. ${_drop(f.tier)}${artDrop(f.tier)}$capMsg';
      log(msg, 'good');
    } else {
      final p = (f.pen * 0.5).floor();
      msg = (fled ? 'Вы отступили. ' : 'Поражение. ') + _payPenalty(p);
      log(msg, 'bad');
    }
    if (bt.defend != null) {
      final n = s.cells[bt.defend], c = s.cells[bt.cell];
      if (win) {
        msg += ' Клетка удержана.';
        log('Клетка удержана!', 'good');
      } else if (n != null && n.own && c != null) {
        loseCell(n, c);
        msg += ' Клетка потеряна.';
      }
    }
    bt.status = msg;
  }

  /// Выпадение способности ранга сущности (за легендарную — эпической)
  String _drop(String tier) {
    final pool = Defs.abilityList.where((a) => a.tier == (tier == 'legend' ? 'epic' : tier)).toList();
    final id = pool[randInt(pool.length)].id;
    final owned = s.abilities.any((a) => a?.id == id);
    final free = s.abilities.indexOf(null);
    final name = Defs.abilities[id]!.name;
    if (!owned && free >= 0) {
      s.abilities[free] = AbilitySlot(id);
      return 'Новая способность: «$name».';
    }
    if (!owned) {
      b!.choice = BattleChoice(id, tier);
      return 'Выпала способность «$name» — выберите для неё ячейку.';
    }
    b!.choice = BattleChoice(id, tier, dup: true);
    return 'Выпала «$name», она у вас уже есть — повысить её уровень или взять ОС?';
  }

  /// Выбор после выпадения: 'skip' — взять ОС, 'up' — повысить уровень, '0'…'3' — заменить ячейку
  void resolveChoice(String v) {
    final bt = b;
    final ch = bt?.choice;
    if (bt == null || ch == null) return;
    bt.choice = null;
    final name = Defs.abilities[ch.id]!.name;
    final os = Defs.tiers[ch.tier]!.os;
    String msg;
    if (v == 'skip') {
      s.os += os;
      msg = 'Способность не взята: +$os ОС.';
    } else if (v == 'up') {
      final a = s.abilities.firstWhere((x) => x?.id == ch.id, orElse: () => null);
      if (a == null) return;
      a.lvl++;
      msg = '«$name» повышена до ур. ${a.lvl}.';
    } else {
      final i = int.parse(v);
      final old = s.abilities[i]!;
      final ref = old.inv ~/ 2;
      s.os += ref;
      s.abilities[i] = AbilitySlot(ch.id);
      msg = '«$name» заняла место «${Defs.abilities[old.id]!.name}»${ref > 0 ? ', вернулось $ref ОС' : ''}.';
    }
    bt.status += ' $msg';
    log(msg, 'info');
  }

  String _payPenalty(int p) {
    var rest = p.toDouble();
    final parts = <String>[];
    final fromM = math.min(math.max(s.matter, 0.0), rest);
    s.matter -= fromM;
    rest -= fromM;
    if (fromM > 0) parts.add('${fromM.floor()} материи');
    if (rest > 0 && s.os > 0) {
      final use = math.min((rest / 5).ceil(), s.os);
      s.os -= use;
      rest -= use * 5;
      parts.add('$use ОС');
    }
    if (rest > 0) {
      s.matter -= rest;
      parts.add('не хватило ${rest.ceil()} материи');
    }
    return 'Штраф $p: ${parts.isEmpty ? 'нечего отдавать' : parts.join(', ')}.';
  }

  /// «Отступить» / «Закрыть»: до старта — отказ без штрафа, во время боя — штраф, после — закрыть окно
  void closeBattle() {
    final bt = b;
    if (bt == null) return;
    if (!bt.started && !bt.over) {
      b = null;
      return;
    }
    if (!bt.over) {
      _finish(false, true);
    } else {
      if (bt.choice != null) resolveChoice('skip');
      b = null;
    }
  }
}
