// «Искра» — сохраняемое состояние в формате веб-версии (объект S из index.html).
// toJson() даёт тот же JSON, что пишет браузер: его принимает сервер учётных записей (server/pocketbase),
// а сохранение из браузера загружается сюда без преобразований. Неизвестные поля
// сохраняются как есть, чтобы не терять данные более новых версий.

double _d(Object? v, [double def = 0]) => v is num ? v.toDouble() : def;
int _i(Object? v, [int def = 0]) => v is num ? v.round() : def;
bool _b(Object? v) => v == true;

class Cell {
  int q, r;
  bool own, spark, alive;
  double m, e, f; // материя, энергия, сила клетки, %
  double def, defMul;
  int defLvl, inv;
  Map<String, int> b; // уровни строений: mine, factory, tower
  double held, age; // время владения / возраст клетки тьмы, с
  int? lv0; // последний объявленный уровень клетки
  double might, dev, growth, t;
  String tier;
  List<String> traits;
  final Map<String, Object?> extra;

  Cell({
    required this.q,
    required this.r,
    this.own = false,
    this.spark = false,
    this.alive = false,
    this.m = 0,
    this.e = 0,
    this.f = 0,
    this.def = 0,
    this.defMul = 1,
    this.defLvl = 0,
    this.inv = 0,
    Map<String, int>? b,
    this.held = 0,
    this.age = 0,
    this.lv0,
    this.might = 0,
    this.dev = 1,
    this.growth = 10,
    this.t = 0,
    this.tier = 'low',
    List<String>? traits,
    Map<String, Object?>? extra,
  }) : b = b ?? {},
       traits = traits ?? [],
       extra = extra ?? {};

  String get key => '$q,$r';

  static const _known = {
    'q',
    'r',
    'own',
    'spark',
    'alive',
    'm',
    'e',
    'f',
    'def',
    'defMul',
    'defLvl',
    'inv',
    'b',
    'held',
    'age',
    'lv0',
    'might',
    'dev',
    'growth',
    't',
    'tier',
    'traits',
    'bld',
    'bldLvl',
  };

  factory Cell.fromJson(Map<String, dynamic> j) {
    final b = <String, int>{};
    final raw = j['b'];
    if (raw is Map) raw.forEach((k, v) => b['$k'] = _i(v));
    // старые сохранения: одно строение на клетку (bld + bldLvl)
    if (j['bld'] is String && j['bldLvl'] is num && _i(j['bldLvl']) > 0) b[j['bld'] as String] = _i(j['bldLvl']);
    return Cell(
      q: _i(j['q']),
      r: _i(j['r']),
      own: _b(j['own']),
      spark: _b(j['spark']),
      alive: _b(j['alive']),
      m: _d(j['m']),
      e: _d(j['e']),
      f: _d(j['f']),
      def: _d(j['def']),
      defMul: _d(j['defMul'], 1),
      defLvl: _i(j['defLvl']),
      inv: _i(j['inv']),
      b: b,
      held: _d(j['held']),
      age: _d(j['age']),
      lv0: j['lv0'] is num ? _i(j['lv0']) : null,
      might: _d(j['might']),
      dev: _d(j['dev'], 1),
      growth: _d(j['growth'], 10),
      t: _d(j['t']),
      tier: j['tier'] is String ? j['tier'] as String : 'low',
      traits: j['traits'] is List ? [for (final x in j['traits'] as List) '$x'] : null,
      extra: {
        for (final e in j.entries)
          if (!_known.contains(e.key)) e.key: e.value,
      },
    );
  }

  Map<String, dynamic> toJson() {
    final j = <String, dynamic>{...extra, 'q': q, 'r': r, 'own': own};
    if (spark) j['spark'] = true;
    j.addAll({'m': m, 'e': e, 'f': f});
    if (!spark) {
      j.addAll({
        'might': might,
        'dev': dev,
        'growth': growth,
        't': t,
        'tier': tier,
        'traits': traits,
        'alive': alive,
        'held': held,
        'age': age,
      });
      if (lv0 != null) j['lv0'] = lv0;
    }
    j.addAll({'def': def, 'defLvl': defLvl, 'defMul': defMul, 'b': b, 'inv': inv});
    return j;
  }
}

class AbilitySlot {
  String id;
  int lvl;
  int inv; // сколько ОС вложено (половина возвращается при удалении)
  AbilitySlot(this.id, {this.lvl = 1, this.inv = 0});

  factory AbilitySlot.fromJson(Map<String, dynamic> j) => AbilitySlot('${j['id']}', lvl: _i(j['lvl'], 1), inv: _i(j['inv']));
  Map<String, dynamic> toJson() => {'id': id, 'lvl': lvl, 'inv': inv};
}

class Artifact {
  String type;
  int? v;
  Artifact(this.type, [this.v]);

  factory Artifact.fromJson(Map<String, dynamic> j) => Artifact('${j['type']}', j['v'] is num ? _i(j['v']) : null);
  Map<String, dynamic> toJson() => {'type': type, if (v != null) 'v': v};
}

class EraState {
  int i;
  double left, dur;
  EraState(this.i, this.left, this.dur);
  Map<String, dynamic> toJson() => {'i': i, 'left': left, 'dur': dur};
}

class GameState {
  double matter = 100, earned = 0; // = Bal.startMatter
  int op = 0, os = 0, opB = 0, osB = 0; // очки параметров / способностей и сколько их куплено в этом мире
  Map<String, int> char = {
    for (final p in ['life', 'defense', 'power', 'meditation', 'speed', 'control']) p: 1,
  };
  List<AbilitySlot?> abilities = newSlots();
  List<Artifact> artifacts = [];
  int rebirths = 0;
  double bonus = 0;
  Map<String, int> kills = {'low': 0, 'rare': 0, 'epic': 0, 'legend': 0};
  double lastWorld = 0;
  bool introSeen = false;
  int bestCells = 1;
  int saved = 0; // мс с 1970 года
  int pulsars = 1;
  Map<String, int> tech = {};
  List<int> cores = [];
  EraState? era;
  int wk = 0; // побед в этом мире
  double we = 0; // добыто материи в этом мире
  double worldTime = 0;
  double aggr = 1;
  double? nextAggr;
  Map<String, Cell> cells = {};
  int worldStart = 0;
  int worldMax = 1;
  String? sel;
  bool lostOnce = false, paused = false;
  int speed = 1;
  Map<String, Object?> extra = {};

  /// Накопительная статистика (только у Flutter-версии): бои, захваты, урон, время игры…
  Map<String, double> st = {};

  static List<AbilitySlot?> newSlots() => [AbilitySlot('spark_strike'), null, null, null];

  static const _known = {
    'matter',
    'earned',
    'op',
    'os',
    'opB',
    'osB',
    'char',
    'abilities',
    'artifacts',
    'rebirths',
    'bonus',
    'kills',
    'lastWorld',
    'introSeen',
    'bestCells',
    'saved',
    'pulsars',
    'tech',
    'cores',
    'coreMul',
    'era',
    'wk',
    'we',
    'worldTime',
    'aggr',
    'nextAggr',
    'cells',
    'worldStart',
    'worldMax',
    'sel',
    'lostOnce',
    'paused',
    'speed',
    'st',
  };

  /// Проверка как в load() и на сервере: есть клетки, число материи и клетка искры
  static bool looksValid(Object? j) =>
      j is Map &&
      j['cells'] is Map &&
      j['matter'] is num &&
      (j['cells'] as Map).values.any((c) => c is Map && c['spark'] == true);

  /// Загрузка с теми же исправлениями старых сохранений, что и load() в веб-версии.
  /// [returned] получает ОС, возвращённые за лишние способности (раньше ячеек было больше 4).
  static GameState fromJson(Map<String, dynamic> j, {void Function(String msg)? onNote}) {
    final s = GameState();
    s.extra = {
      for (final e in j.entries)
        if (!_known.contains(e.key)) e.key: e.value,
    };
    s.matter = _d(j['matter'], 60);
    s.earned = _d(j['earned']);
    s.op = _i(j['op']);
    s.os = _i(j['os']);
    s.opB = _i(j['opB']);
    s.osB = _i(j['osB']);
    final ch = j['char'];
    if (ch is Map) {
      for (final k in s.char.keys.toList()) {
        if (ch[k] is num) s.char[k] = _i(ch[k], 1);
      }
      if (ch['control'] == null) s.char['control'] = _i(ch['combo'], 1); // «Комбо» стало «Управлением»
    }
    final abs = j['abilities'];
    if (abs is List) {
      final list = [for (final a in abs) a is Map && a['id'] is String ? AbilitySlot.fromJson(a.cast<String, dynamic>()) : null];
      s.abilities = List<AbilitySlot?>.filled(4, null);
      for (var i = 0; i < 4 && i < list.length; i++) {
        s.abilities[i] = list[i];
      }
      // Ячеек способностей теперь 4: лишние переезжают в пустые ячейки или возвращаются очками
      for (final a in list.skip(4).whereType<AbilitySlot>()) {
        final free = s.abilities.indexOf(null);
        if (free >= 0) {
          s.abilities[free] = a;
        } else {
          s.os += a.inv + (_tierOs[_abTier[a.id]] ?? 1);
          onNote?.call('Ячеек способностей теперь 4: одна способность убрана, очки возвращены.');
        }
      }
    }
    final arts = j['artifacts'];
    if (arts is List) {
      s.artifacts = [
        for (final a in arts)
          if (a is Map) Artifact.fromJson(a.cast<String, dynamic>()),
      ];
    }
    s.rebirths = _i(j['rebirths']);
    s.bonus = _d(j['bonus']);
    final k = j['kills'];
    if (k is Map) {
      for (final t in s.kills.keys.toList()) {
        s.kills[t] = _i(k[t]);
      }
    }
    s.lastWorld = _d(j['lastWorld']);
    s.introSeen = _b(j['introSeen']);
    s.bestCells = _i(j['bestCells'], 1);
    s.saved = _i(j['saved']);
    s.pulsars = j['pulsars'] == null ? 1 : _i(j['pulsars']);
    final tech = j['tech'];
    if (tech is Map) tech.forEach((id, v) => s.tech['$id'] = _i(v, 1));
    final cores = j['cores'];
    if (cores is List) {
      s.cores = [for (final v in cores) _i(v)];
    } else if (_d(j['coreMul']) > 1) {
      s.cores = [_i(j['coreMul'])];
    }
    final era = j['era'];
    if (era is Map && era['i'] is num) s.era = EraState(_i(era['i']), _d(era['left']), _d(era['dur'], 60));
    s.wk = _i(j['wk']);
    s.we = _d(j['we']);
    s.worldStart = _i(j['worldStart']);
    s.worldTime = j['worldTime'] is num
        ? _d(j['worldTime'])
        : ((s.saved - s.worldStart) / 1000).clamp(0, double.infinity).toDouble();
    s.aggr = j['aggr'] is num ? _d(j['aggr']) : 1;
    s.nextAggr = j['nextAggr'] is num ? _d(j['nextAggr']) : null;
    final cells = j['cells'];
    if (cells is Map) {
      cells.forEach((key, c) {
        if (c is Map) {
          final cell = Cell.fromJson(c.cast<String, dynamic>());
          s.cells[cell.key] = cell;
        }
      });
    }
    s.worldMax = _i(j['worldMax'], 1);
    s.sel = j['sel'] is String ? j['sel'] as String : null;
    s.lostOnce = _b(j['lostOnce']);
    s.paused = _b(j['paused']);
    s.speed = _i(j['speed'], 1).clamp(1, 3);
    final st = j['st'];
    if (st is Map) {
      st.forEach((k, v) {
        if (k is String && v is num && v.isFinite) s.st[k] = v.toDouble();
      });
    }
    return s;
  }

  Map<String, dynamic> toJson() => {
    ...extra,
    'matter': matter,
    'earned': earned,
    'op': op,
    'os': os,
    'opB': opB,
    'osB': osB,
    'char': char,
    'abilities': [for (final a in abilities) a?.toJson()],
    'artifacts': [for (final a in artifacts) a.toJson()],
    'rebirths': rebirths,
    'bonus': bonus,
    'kills': kills,
    'lastWorld': lastWorld,
    'introSeen': introSeen,
    'bestCells': bestCells,
    'saved': saved,
    'pulsars': pulsars,
    'tech': tech,
    'cores': cores,
    if (cores.isNotEmpty) 'coreMul': cores.fold<int>(0, (a, b) => a + b),
    if (era != null) 'era': era!.toJson(),
    'wk': wk,
    'we': we,
    'worldTime': worldTime,
    'aggr': aggr,
    if (nextAggr != null) 'nextAggr': nextAggr,
    'cells': {for (final c in cells.values) c.key: c.toJson()},
    'worldStart': worldStart,
    'worldMax': worldMax,
    'sel': sel,
    'lostOnce': lostOnce,
    'paused': paused,
    if (st.isNotEmpty) 'st': st,
    'speed': speed,
  };

  // Для разбора старых сохранений без зависимости от defs.dart
  static const _tierOs = {'low': 1, 'rare': 3, 'epic': 10};
  static const _abTier = {
    'spark_strike': 'low',
    'veil': 'low',
    'feed': 'low',
    'ember': 'low',
    'daze': 'low',
    'mend': 'low',
    'discharge': 'rare',
    'vampire': 'rare',
    'haste': 'rare',
    'lance': 'rare',
    'wither': 'rare',
    'harvest': 'rare',
    'nova': 'epic',
    'dark_shield': 'epic',
    'absorb': 'epic',
    'mirror': 'epic',
    'finisher': 'epic',
    'dispel': 'epic',
  };
}
