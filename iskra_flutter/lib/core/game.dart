// «Искра» — мир шестигранников: клетки, экономика, персонаж, рост тьмы.
// Вся игровая логика без зависимостей от Flutter: её можно гонять в тестах и симуляциях.
// Перенос функций из index.html веб-версии; имена по возможности те же (tick, capture, foeFromCell…).
library;

import 'dart:math' as math;

import 'defs.dart';
import 'fmt.dart';
import 'model.dart';

export 'defs.dart';
export 'fmt.dart';
export 'model.dart';

part 'battle.dart';
part 'meta.dart';
part 'forecast.dart';

class IncomeParts {
  final double base, mines, facSum, fac, minesEff, total;
  const IncomeParts(this.base, this.mines, this.facSum, this.fac, this.minesEff, this.total);
}

class Eff {
  final double v, pen;
  const Eff(this.v, this.pen);
}

/// Клетка под угрозой: игрок решает — защищать или отдать
class DefendRequest {
  final String own, att;
  final bool wasPaused;
  const DefendRequest(this.own, this.att, this.wasPaused);
}

typedef LogFn = void Function(String text, String kind);

class Game {
  Game({math.Random? random}) : rng = random ?? math.Random();

  final math.Random rng;
  late GameState s;
  final List<Cell> own = [];
  final Set<String> vis = {};

  DefendRequest? def;
  Battle? b;
  bool gameOver = false;

  // Состояние мира за последние 2 минуты и кэши прогноза (см. forecast.dart)
  final List<TrendPoint> trendHist = [];
  double _trendAcc = 0;
  ({String key, double at, Forecast v})? _fcCache;
  ({double at, WorldTrend v})? _wtCache;

  /// Текущее время интерфейса, с (для эффектов боя и кэша прогноза)
  double now = 0;

  /// Сообщения в ленту: текст и вид (good / bad / info)
  LogFn? onLog;

  /// Тьма догнала защиту клетки — интерфейс показывает окно «Клетка под ударом!»
  void Function()? onDefend;

  void log(String text, [String kind = 'info']) => onLog?.call(text, kind);

  /// Звуки событий: интерфейс сопоставляет имя с файлом (capture, hit, win…)
  void Function(String id)? onSfx;
  void sfx(String id) => onSfx?.call(id);

  /// Прибавка к накопительной статистике s.st
  void stat(String k, [double v = 1]) => s.st[k] = (s.st[k] ?? 0) + v;
  double stv(String k) => s.st[k] ?? 0;

  static String k(int q, int r) => '$q,$r';
  static double hexDist(int q1, int r1, int q2, int r2) => ((q1 - q2).abs() + (r1 - r2).abs() + (q1 + r1 - q2 - r2).abs()) / 2;

  double rnd(double a, double b) => a + rng.nextDouble() * (b - a);
  double get random => rng.nextDouble();
  int randInt(int max) => rng.nextInt(max);

  Cell? cell(String? key) => key == null ? null : s.cells[key];
  Cell? get sel => s.sel != null && vis.contains(s.sel) ? s.cells[s.sel] : null;

  /* ---------- эры ---------- */
  EraDef get eraNow {
    final e = s.era;
    if (e == null || e.i < 0 || e.i >= Defs.eras.length) newEra(true);
    return Defs.eras[s.era!.i];
  }

  double eraV(String key) {
    final e = s.era;
    if (e == null || e.i < 0 || e.i >= Defs.eras.length) return 1;
    return Defs.eras[e.i].fx[key] ?? 1;
  }

  /// Эры меняются каждые 1–10 минут игрового времени, следующая — случайная (не та же)
  void newEra([bool silent = false]) {
    final prev = s.era?.i ?? -1;
    int i;
    do {
      i = randInt(Defs.eras.length);
    } while (i == prev && Defs.eras.length > 1);
    final dur = 60.0 + randInt(541);
    s.era = EraState(i, dur, dur);
    final e = Defs.eras[i];
    if (!silent) {
      log('Новая эра: «${e.name}» — ${e.desc}.', e.kind == 'bad' ? 'bad' : 'good');
      sfx('era');
    }
  }

  /* ---------- технологии ---------- */
  bool hasTech(String id) => techRank(id) > 0;
  int techRank(String id) => s.tech[id] ?? 0;

  /// Технология доступна, когда у каждой предыдущей изучен хотя бы 1-й ранг
  bool techOpen(TechDef t) => t.req.every(hasTech);

  /// Цена следующего ранга или null, если изучены все ранги
  int? techNextCost(TechDef t) {
    final r = techRank(t.id);
    return r >= t.ranks ? null : t.rankCost(r);
  }

  /// Множитель технологии: 1 + прибавка × ранг; накладывается поверх всех остальных множителей
  double techMul(String id) {
    final t = Defs.techById[id];
    return t == null ? 1 : 1 + t.per * math.min(techRank(id), t.ranks);
  }

  void researchTech(String id) {
    final t = Defs.techById[id];
    if (t == null || t.soon || !techOpen(t)) return;
    final cost = techNextCost(t);
    if (cost == null || s.pulsars < cost) return;
    s.pulsars -= cost;
    final r = techRank(id) + 1;
    s.tech[id] = r;
    log(t.ranks > 1 ? 'Технология «${t.name}»: ранг $r.' : 'Изучена технология «${t.name}».', 'good');
    sfx('tech');
  }

  /* ---------- агрессивность мира ---------- */
  // Случайна для каждого мира (заново при прыжке), от ×0,70 до ×1,60. Умножает силу сущностей,
  // скорость роста тьмы, а шанс легендарной сущности — на её квадрат.
  double rollAggr() => jsRound((Bal.aggrMin + random * (Bal.aggrMax - Bal.aggrMin)) * 100) / 100;
  double get aggr => s.aggr > 0 ? s.aggr : 1;
  static String aggrName(double a) => a < 0.85
      ? 'спокойный'
      : a < 1.1
      ? 'обычный'
      : a < 1.35
      ? 'агрессивный'
      : 'яростный';
  String get aggrText => '×${Fmt.x(aggr, 2)} — ${aggrName(aggr)}';
  int get speed => s.speed > 0 ? s.speed : 1;

  /* ---------- состояние ---------- */
  ({double m, double e, double f}) _split() {
    var a = random, bb = random;
    if (a > bb) (a, bb) = (bb, a);
    final m = jsRound(a * 100), e = jsRound((bb - a) * 100);
    return (m: m, e: e, f: 100 - m - e);
  }

  static double mult(double p) => math.max(0.15, p / 33.3);

  // Уровень клетки: у своей — по времени владения, у клетки тьмы — по возрасту (1, 2, 4, 8… мин), +10% за уровень
  static double cellAge(Cell c) => c.own ? c.held : c.age;
  static int cellLvl(Cell c) {
    if (c.spark) return 0;
    final h = cellAge(c);
    return h < 60 ? 0 : (math.log(h / 60) / math.ln2).floor() + 1;
  }

  static double nextLvlAt(Cell c) => 60 * math.pow(2, cellLvl(c)).toDouble();
  static double gMul(Cell c) => 1 + 0.1 * cellLvl(c);

  /// «Управление» усиливает материю и энергию клеток (и их защиту — в cellDef)
  double st(Cell c, String key) {
    final v = key == 'm'
        ? c.m
        : key == 'e'
        ? c.e
        : c.f;
    return v * gMul(c) * (key != 'f' && c.own ? ctrlMul : 1);
  }

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  void newGame() {
    s = GameState()..saved = nowMs();
    freshWorld();
    s.aggr = 1; // первый мир всегда обычный; случайная агрессивность — с первого прыжка
  }

  void freshWorld() {
    trendHist.clear();
    s.wk = 0;
    s.we = 0;
    s.worldTime = 0;
    s.aggr = s.nextAggr ?? rollAggr();
    s.nextAggr = rollAggr();
    s.cells = {};
    s.worldStart = nowMs();
    s.worldMax = 1;
    s.matter = 60;
    s.sel = null;
    s.lostOnce = false;
    final sp = _split();
    final spark = Cell(q: 0, r: 0, own: true, spark: true, m: sp.m, e: sp.e, f: sp.f);
    s.cells[spark.key] = spark;
    refresh();
    _ensureNeighbors(0, 0);
    refresh();
  }

  /// Подключает загруженное состояние; false — если сохранение повреждено
  bool attach(GameState st) {
    if (!st.cells.values.any((c) => c.spark)) return false;
    s = st;
    for (var i = 0; i < s.abilities.length; i++) {
      final a = s.abilities[i];
      if (a != null && !Defs.abilities.containsKey(a.id)) s.abilities[i] = null;
    }
    s.artifacts.removeWhere((a) => !Defs.arts.containsKey(a.type));
    s.nextAggr ??= rollAggr();
    refresh();
    // Пока игрока нет, мир стоит на паузе и ничего не начисляется — никаких бонусов за отсутствие
    return true;
  }

  // Уровни персонажа слабо усиливают тьму; прыжки — никак
  double _strength() {
    final lv = s.char.values.fold<int>(0, (a, b) => a + b) - 6;
    return lv * 0.3 + own.length * 0.6;
  }

  double get legendChance => Bal.legendChance * aggr * aggr * eraV('leg');

  String rollTier(double d) {
    if (d >= 2 && random < legendChance) return 'legend';
    final r = random;
    return r < 0.05 + math.min(0.1, d * 0.006)
        ? 'epic'
        : r < 0.3
        ? 'rare'
        : 'low';
  }

  Cell _genDark(int q, int r) {
    final d = hexDist(q, r, 0, 0);
    final base = (5 + _strength() * 1.5) * (1 + d * 0.09);
    final tier = rollTier(d);
    final sp = _split();
    return Cell(
      q: q,
      r: r,
      m: sp.m,
      e: sp.e,
      f: sp.f,
      might: base * rnd(0.7, 1.3),
      dev: rnd(Bal.devMin, Bal.devMax),
      growth: rnd(7, 18),
      t: rnd(0, 5),
      tier: tier,
      traits: rollTraits(tier),
      alive: true,
    );
  }

  void _ensureNeighbors(int q, int r) {
    for (final d in Defs.dirs) {
      final key = k(q + d[0], r + d[1]);
      if (!s.cells.containsKey(key)) s.cells[key] = _genDark(q + d[0], r + d[1]);
    }
  }

  void refresh() {
    own.clear();
    vis.clear();
    for (final c in s.cells.values) {
      if (!c.own) continue;
      own.add(c);
      vis.add(c.key);
      for (final d in Defs.dirs) {
        vis.add(k(c.q + d[0], c.r + d[1]));
      }
    }
  }

  Iterable<Cell> neighbors(Cell c) sync* {
    for (final d in Defs.dirs) {
      final n = s.cells[k(c.q + d[0], c.r + d[1])];
      if (n != null) yield n;
    }
  }

  /* ---------- экономика ---------- */
  double get bonusMul => 1 + s.bonus;
  // Ядра искры: множители всех применённых ядер складываются целиком. Без ядер ×1. Навсегда.
  int get coreSum => s.cores.fold(0, (a, b) => a + b);
  int get coreMul => coreSum > 0 ? coreSum : 1;
  double get incBonus => math.pow(bonusMul, Bal.bonusPow).toDouble(); // сила бонуса прыжка в добыче
  double get sparkMatter => own.length * incBonus;
  double get sparkSpeed => 1 + 0.15 * s.rebirths;

  /// (база + шахты × бонус) × (1 + заводы %) × эра
  double income() => incomeParts().total * eraV('inc') * techMul('income');

  /// Заводы: сумма процентов всех заводов в мире делится на число ваших клеток и даёт бонус ко всей добыче
  IncomeParts incomeParts() {
    var mines = 0.0, facSum = 0.0;
    for (final c in own) {
      if (c.spark) continue;
      mines += mineRate(c, bL(c, 'mine'));
      facSum += factPct(c, bL(c, 'factory'));
    }
    final fac = own.isNotEmpty ? facSum / own.length : 0.0;
    final base = sparkMatter * 0.5 * coreMul * sparkSpeed;
    return IncomeParts(base, mines, facSum, fac, mines * (1 + fac / 100), (base + mines * incBonus) * (1 + fac / 100));
  }

  /// «Управление»: коэффициент защиты клеток 1 на 1-м уровне, ×1,01 за каждый следующий
  double get ctrlMul => math.pow(1.01, math.max(0, eff('control').v - 1)).toDouble();
  double get ctrlPct => (ctrlMul - 1) * 100;
  double fortPct(Cell c) => 10 * mult(st(c, 'f')) * techMul('fort'); // +10% защиты за уровень укрепления при силе клетки 33%
  double cellDef(Cell c) => c.spark
      ? double.infinity
      : c.def *
            (c.defMul > 0 ? c.defMul : 1) *
            (1 + c.defLvl * fortPct(c) / 100) *
            (1 + towerPct(bL(c, 'tower')) / 100) *
            ctrlMul;

  /// Ячейки: при захвате 3 + (материя+энергия)/40, дальше +2 × √(минут владения)
  static int cap(Cell c) => 3 + jsRound((c.m + c.e) / 40).toInt() + (2 * math.sqrt(c.held / 60)).floor();
  static double nextSlotIn(Cell c) {
    final n = (2 * math.sqrt(c.held / 60)).floor() + 1;
    return math.max(0, math.pow(n / 2, 2) * 60 - c.held);
  }

  static int bL(Cell c, String t) => c.b[t] ?? 0;
  static int usedCap(Cell c) => c.b.values.fold(0, (a, v) => a + v);

  double bldCost(Cell c, String t) {
    final l = bL(c, t);
    if (t == 'tower') return (Bal.towerCost * math.pow(Bal.towerGrow, l) * eraV('def')).ceilToDouble();
    final base = t == 'mine' ? Bal.mineCost * math.pow(Bal.mineGrow, l) : Bal.facCost * math.pow(Bal.facGrow, l);
    return (base * eraV('bld')).ceilToDouble();
  }

  static double towerPct(int l) => l > 0 ? 25 * math.pow(2, l - 1).toDouble() : 0; // 25%, 50%, 100%, 200%…
  // Комплекс: каждое следующее одинаковое строение на клетке +10% ко всем таким строениям (5 шахт → ×1,4)
  static double _syn(int l) => l > 0 ? 1 + 0.1 * (l - 1) : 0;
  double mineRate(Cell c, int l) => l * 1.2 * mult(st(c, 'm')) * _syn(l);
  double factPct(Cell c, int l) => l * 8 * mult(st(c, 'e')) * _syn(l);
  double defCost(Cell c) => (Bal.defCost * math.pow(Bal.defGrow, c.defLvl) * eraV('def')).ceilToDouble();

  void addMatter(double x) {
    s.matter += x;
    if (x > 0) {
      s.earned += x;
      s.we += x;
    }
  }

  // Незахваченные клетки рядом с живой легендарной сущностью растут вдвое быстрее
  bool nearLegend(Cell c) => !c.own && neighbors(c).any((n) => !n.own && n.alive && n.tier == 'legend');
  double growMul(Cell c) => nearLegend(c) ? 2 : 1;
  // Чем больше клеток у игрока, тем быстрее растёт тьма: по ×1,25 при 7 клетках, ×1,5 при 30
  double get darkF => 1 + 0.1 * math.sqrt(math.max(0, own.length - 1));
  // Бонус прыжка замедляет тьму
  double growRate(Cell c) => Bal.growthRate * growMul(c) * aggr * eraV('grow') * darkF / math.sqrt(bonusMul);

  double maxAdjMight(Cell c) {
    var m = 0.0;
    for (final n in neighbors(c)) {
      if (!n.own && n.alive) m = math.max(m, n.might);
    }
    return m;
  }

  bool threatened(Cell c) => !c.spark && maxAdjMight(c) >= cellDef(c) * 0.8;
  int get threatCount => own.where(threatened).length;

  /* ---------- персонаж ---------- */
  /// Перекос: параметр выше среднего по всем шести на 50% теряет 10% силы, на 100% — 25%, на 150% — 50%
  static const penSteps = [(1.5, 0.10), (2.0, 0.25), (2.5, 0.50)];

  /// Среднее значение параметров (по всем шести)
  double get parAvg {
    var sum = 0;
    for (final x in Defs.params) {
      sum += s.char[x.id] ?? 1;
    }
    return sum / Defs.params.length;
  }

  /// Штраф за перекос для значения [v] при среднем [avg]
  static double penFor(double v, double avg) {
    var pen = 0.0;
    for (final (k, p) in penSteps) {
      if (v > avg * k) pen = p;
    }
    return pen;
  }

  Eff eff(String p) {
    final v = s.char[p] ?? 1;
    final pen = penFor(v.toDouble(), parAvg);
    return Eff(v * (1 - pen), pen);
  }

  double maxHp() => 60 + 40 * eff('life').v;
  double defDiv() => 1 + 0.125 * (eff('defense').v - 1);
  double powMul() => (1 + 0.125 * (eff('power').v - 1)) * eraV('pAtk');
  double med() => 1 + 0.5 * (eff('meditation').v - 1);
  double turnCd() => 1.4 / (1 + 0.06 * (eff('speed').v - 1)) * eraV('cd');

  /// Стоимость навыка: база × (низш. 1 / ред. 1,25 / эпич. 1,5) × (1 + 12% за уровень)
  static double abCost(AbilitySlot a) {
    final d = Defs.abilities[a.id]!;
    return math.max(1, jsRound(d.cost * Defs.gradeCost[d.tier]! * (1 + 0.12 * (a.lvl - 1))));
  }

  double abVal(AbilitySlot a) {
    final d = Defs.abilities[a.id]!;
    final l = a.lvl - 1;
    switch (d.kind) {
      case 'dmg' || 'drain' || 'dot' || 'pierce' || 'harvest' || 'execute':
        return d.base * (1 + 0.15 * l) * med(); // урон навыков растёт от Медитации, как и атака
      case 'heal' || 'regenme':
        return maxHp() * d.base / 100 * (1 + 0.15 * l); // лечение — доля здоровья
      case 'absorb':
        return d.base + 0.01 * l;
      default:
        return d.base + 0.2 * l;
    }
  }

  String abDesc(AbilitySlot a) {
    final v = abVal(a), pm = powMul();
    String r(double x) => '${jsRound(x).toInt()}';
    switch (Defs.abilities[a.id]!.kind) {
      case 'dmg':
        return 'Урон ${r(v * pm)}';
      case 'heal':
        return 'Лечит ${r(v)}';
      case 'shield':
        return 'Урон по вам вдвое меньше ${Fmt.x(v)} с';
      case 'drain':
        return 'Урон ${r(v * pm)}, лечит 60% от него';
      case 'haste':
        return 'Сбрасывает откат, ходы вдвое быстрее ${Fmt.x(v)} с';
      case 'immune':
        return 'Неуязвимость ${Fmt.x(v)} с';
      case 'absorb':
        return 'Забирает ${r(v * 100)}% здоровья врага, лечит половину';
      case 'dot':
        return 'Жжёт ${r(v * pm)} урона в секунду ${Bal.dotT.toInt()} с';
      case 'stunfoe':
        return 'Отбрасывает удар врага на ${Fmt.x(v)} с';
      case 'regenme':
        return 'Лечит ${r(v)} в секунду ${Bal.mendT.toInt()} с';
      case 'pierce':
        return 'Урон ${r(v * pm)} сквозь панцирь и завесу';
      case 'weaken':
        return 'Враг бьёт на 40% слабее ${Fmt.x(v)} с';
      case 'harvest':
        return 'Урон ${r(v * pm)}, при попадании возвращает вдвое больше материи, чем стоит';
      case 'reflect':
        return '${Fmt.x(v)} с отражает 60% удара врага обратно';
      case 'execute':
        return 'Урон ${r(v * pm)}, втрое больше по врагу с здоровьем ниже 30%';
      case 'dispel':
        return 'Отключает особенности врага на ${Fmt.x(v)} с';
    }
    return '';
  }

  /* ---------- ход мира ---------- */
  void tick(double dt) {
    if (s.paused) return;
    addMatter(income() * dt);
    final era = s.era;
    if (era != null) {
      era.left -= dt;
      if (era.left <= 0) newEra();
    }
    trendSample(dt);
    for (final c in own) {
      if (c.spark) continue;
      c.held += dt * eraV('held') * techMul('grow');
      final l = cellLvl(c);
      if (c.lv0 == null) {
        c.lv0 = l;
      } else if (l > c.lv0!) {
        c.lv0 = l;
        if (c.key == s.sel || own.length < 12) {
          log('Клетка достигла уровня $l: +10% к её силе.', 'good');
          sfx('level');
        }
      }
    }
    for (final key in vis.toList()) {
      final c = s.cells[key];
      if (c == null || c.own) continue;
      c.t += dt * growRate(c);
      c.age += dt * eraV('held');
      if (c.t >= c.growth) {
        c.t -= c.growth;
        c.might = c.might * (1 + (c.dev - 1) * darkF) + 0.2;
        if (c.alive) _threaten(c);
      }
    }
  }

  /// Главный кадр (frame в веб-версии): время мира, бой, проверка банкротства.
  /// true — материя ушла в минус и прыжок неизбежен (интерфейс показывает окно прыжка).
  bool frame(double dt) {
    dt = math.min(0.25, dt);
    refresh();
    if (!gameOver && s.matter < 0 && b == null) {
      gameOver = true;
      return true;
    }
    if (!gameOver) {
      final wd = dt * speed;
      tick(wd);
      battleTick(dt);
      if (!s.paused) {
        s.worldTime += wd;
        stat('play', wd);
        if (s.worldTime > stv('longWorld')) s.st['longWorld'] = s.worldTime;
      }
    }
    return false;
  }

  void loseCell(Cell n, Cell c) {
    n
      ..own = false
      ..might = c.might + 1
      ..dev = rnd(Bal.devMin, Bal.devMax)
      ..growth = rnd(7, 18)
      ..t = 0
      ..tier = rollTier(hexDist(n.q, n.r, 0, 0))
      ..alive = true
      ..b = {}
      ..inv = 0
      ..def = 0
      ..defLvl = 0
      ..defMul = 1
      ..held = 0
      ..age = 0
      ..lv0 = null;
    n.traits = rollTraits(n.tier);
    s.lostOnce = true;
    log('Тьма захватила клетку. Её мощь теперь ${n.might.ceil()}.', 'bad');
    stat('lost');
    sfx('lost');
    refresh();
  }

  // Тьма догнала защиту клетки: не забираем сразу, а спрашиваем игрока
  void _threaten(Cell c) {
    if (def != null || b != null || !c.alive) return; // одна угроза за раз; во время боя проверим позже
    for (final n in neighbors(c)) {
      if (n.own && !n.spark && c.might >= cellDef(n)) {
        def = DefendRequest(n.key, c.key, s.paused);
        s.paused = true;
        s.sel = n.key;
        onDefend?.call();
        sfx('alarm');
        return;
      }
    }
  }

  /// Окно защиты ещё актуально? (клетка могла уже уйти)
  bool defendValid() {
    final d = def;
    if (d == null) return false;
    final n = s.cells[d.own], c = s.cells[d.att];
    if (n == null || c == null || !n.own) {
      def = null;
      return false;
    }
    return true;
  }

  /// «Бежать»: клетка переходит к тьме
  void defendFlee() {
    final d = def;
    def = null;
    if (d == null) return;
    final n = s.cells[d.own], c = s.cells[d.att];
    if (n != null && c != null && n.own) loseCell(n, c);
    s.paused = d.wasPaused;
  }

  /// «Защитить»: бой с напавшей сущностью
  void defendFight() {
    final d = def;
    def = null;
    if (d == null) return;
    final c = s.cells[d.att];
    if (c == null) return;
    s.sel = d.att;
    startBattle(foeFromCell(c), d.att);
    b!.defend = d.own;
  }

  /* ---------- действия с клетками ---------- */
  // Сложность кратна удалённости от искры: соседи искры ×1, через клетку ×2…
  static int foeDist(Cell c) => math.max(1, hexDist(c.q, c.r, 0, 0).toInt());

  /// Особенности: низшая — иногда одна, редкая — одна, эпическая — одна-две, легендарная — две
  List<String> rollTraits(String tier) {
    List<String> pick(int n) {
      final out = <String>[];
      while (out.length < n) {
        final key = Defs.traitOrder[randInt(Defs.traitOrder.length)];
        if (!out.contains(key)) out.add(key);
      }
      return out;
    }

    if (tier == 'low') {
      return random < 0.35
          ? [
              const ['regen', 'shell', 'leech'][randInt(3)],
            ]
          : [];
    }
    if (tier == 'rare') return pick(1);
    if (tier == 'epic') return pick(random < 0.5 ? 2 : 1);
    return pick(2);
  }

  double leechAmt() => (3 * med()).ceilToDouble();

  Foe foeFromCell(Cell c) {
    final t = Defs.tiers[c.tier]!;
    final dm = foeDist(c);
    final base = c.might * t.mult * aggr * Bal.earlyMul;
    return Foe(
      name: t.foe,
      tier: c.tier,
      dist: dm,
      maxHp: base * 8 * dm * Bal.foeHp * eraV('foeHp'),
      atk: (base * 0.55 * dm + 2) * Bal.foeAtk * eraV('foeAtk'),
      cd: t.cd,
      matter: base * 10 * dm * Bal.foeReward * eraV('reward'),
      pen: base * 10,
      traits: c.traits,
    );
  }

  bool capture(String key) {
    final c = s.cells[key];
    if (c == null || c.own || c.alive) return false;
    final cost = c.might.ceilToDouble();
    if (s.matter < cost) return false;
    s.matter -= cost;
    c
      ..own = true
      ..def = 0
      ..defLvl = 0
      ..defMul = 1
      ..b = {}
      ..inv = 0
      ..held = 0
      ..age = 0
      ..lv0 = null; // базовые очки m/e/f остаются
    refresh();
    _ensureNeighbors(c.q, c.r);
    refresh();
    c.def = math.max(cost, maxAdjMight(c)).ceilToDouble() + 1;
    s.worldMax = math.max(s.worldMax, own.length);
    s.bestCells = math.max(s.bestCells, own.length);
    log('Клетка захвачена. Защита ${Fmt.n(c.def)}.', 'good');
    stat('captured');
    sfx('capture');
    return true;
  }

  void build(String key, String t) {
    final c = s.cells[key];
    if (c == null || !c.own || c.spark || !Defs.buildings.containsKey(t)) return;
    if (usedCap(c) >= cap(c)) return;
    final cost = bldCost(c, t);
    if (s.matter < cost) return;
    s.matter -= cost;
    c.b[t] = bL(c, t) + 1;
    stat('built');
    sfx('build');
  }

  void lower(String key, String t) {
    final c = s.cells[key];
    if (c == null || !c.own || bL(c, t) == 0) return;
    c.b[t] = bL(c, t) - 1;
    if (c.b[t] == 0) c.b.remove(t);
  }

  void fortify(String key) {
    final c = s.cells[key];
    if (c == null || !c.own || c.spark) return;
    final cost = defCost(c);
    if (s.matter < cost) return;
    s.matter -= cost;
    c.defLvl++;
    stat('fort');
    sfx('build');
  }

  /// Прибавка за укрепление: столько защиты даст следующий уровень
  double fortGain(Cell c) => c.def * fortPct(c) / 100 * (1 + towerPct(bL(c, 'tower')) / 100) * ctrlMul;
}
