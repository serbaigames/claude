// «Искра» — справочники: ранги, способности, эры, особенности, артефакты, технологии и баланс.
// Перенесено из веб-версии (index.html, sw iskra-v27) без изменения чисел.
// Тексты хранятся по-русски (поля …Ru) и переводятся геттерами name, desc… на текущий язык (см. l10n.dart).
import '../l10n/l10n.dart';

class TierDef {
  final String id, nameRu, foeRu;
  final double mult, cd;
  final int os;
  const TierDef(this.id, this.nameRu, this.mult, this.cd, this.os, this.foeRu);
  String get name => tx(nameRu);
  String get foe => tx(foeRu);
}

class AbilityDef {
  final String id, icon, glyph, nameRu, tier, kind;
  final double cost, base;
  final double cd; // уже с множителем ×1,3, как в веб-версии
  AbilityDef(this.id, this.glyph, this.icon, this.nameRu, this.tier, this.cost, double cd, this.base, this.kind)
    : cd = (cd * 1.3 * 10).round() / 10;
  String get name => tx(nameRu);
}

class EraDef {
  final String id, nameRu, icon, kind, descRu;
  final Map<String, double> fx;
  const EraDef(this.id, this.nameRu, this.icon, this.kind, this.descRu, [this.fx = const {}]);
  String get name => tx(nameRu);
  String get desc => tx(descRu);
}

class TraitDef {
  final String id, nameRu, glyph, descRu;
  const TraitDef(this.id, this.nameRu, this.glyph, this.descRu);
  String get name => tx(nameRu);
  String get desc => tx(descRu);
}

class ArtDef {
  final String id, nameRu, glyph, target;
  final String? stat, wordRu;
  final int color;
  final String shortRu;
  const ArtDef(this.id, this.nameRu, this.glyph, this.target, this.color, this.shortRu, {this.stat, this.wordRu});
  String get name => tx(nameRu);
  String get short => tx(shortRu);

  /// Что усиливает, в родительном падеже: «энергии», «силы», «материи»
  String? get word => wordRu == null ? null : tx(wordRu!);
}

class TechDef {
  final String id, nameRu, icon, descRu;
  final int lvl, cost;
  final List<String> req;
  final bool soon;

  /// Число рангов; каждый следующий ранг втрое дороже (3, 9, 27 пульсаров)
  final int ranks;

  /// Прибавка за ранг к множителю (0,25 → ×1,25 / ×1,5 / ×1,75); 0 — без числового эффекта
  final double per;

  /// Что усиливает, для описания: «развитие ваших клеток», «защита от укреплений»…
  final String whatRu;
  const TechDef(
    this.id,
    this.lvl,
    this.nameRu,
    this.icon,
    this.cost,
    this.req,
    this.descRu, {
    this.soon = false,
    this.ranks = 1,
    this.per = 0,
    this.whatRu = '',
  });
  String get name => tx(nameRu);
  String get desc => tx(descRu);
  String get what => whatRu.isEmpty ? '' : tx(whatRu);

  /// Цена ранга r (с нуля)
  int rankCost(int r) => cost * [1, 3, 9, 27, 81][r];
}

class ParamDef {
  final String id, nameRu, descRu;
  final int color;
  const ParamDef(this.id, this.nameRu, this.descRu, this.color);
  String get name => tx(nameRu);
  String get desc => tx(descRu);
}

class BuildingDef {
  final String id, nameRu, shortRu, glyph;
  const BuildingDef(this.id, this.nameRu, this.shortRu, this.glyph);
  String get name => tx(nameRu);
  String get short => tx(shortRu);
}

/// Коэффициенты баланса (набор C8 из веб-версии)
class Bal {
  // шахта окупается ~2 мин (60 материи за 0,5/с), а не за 25 с — первый мир не превращается в снежный ком
  static const mineCost = 60.0, mineRate = 0.5, mineGrow = 1.7, facCost = 90.0, facGrow = 1.75;
  static const bonusPow = 0.6; // сила бонуса прыжка в добыче: (1 + бонус)^0,6
  static const bonusFightPow = 0.3; // сила бонуса прыжка в бою: здоровье и урон × (1 + бонус)^0,3
  // Враги: здоровье и удар в одном масштабе с искрой — бой ~15 ваших ударов и ~8 ударов врага, а не 40 против 20
  static const foeHp = 1.0, foeAtk = 1.6, foeReward = 1.0, defCost = 8.0, defGrow = 1.35;
  static const devMin = 1.008, devMax = 1.028, towerCost = 12.0, towerGrow = 1.8;
  static const growthRate = 0.5; // тьма растёт вдвое медленнее
  static const aggrMin = 0.7, aggrMax = 1.6; // агрессивность мира
  static const legendChance = 0.01;
  static const earlyMul = 1.6; // сущности сильнее в 1,6 раза во всех мирах
  // Сила тьмы растёт с прыжками: 1 + a × прыжки^p (×1,4 после 10 прыжков, ×2,2 после 30)
  static const atkCost = 5.0; // атака стоит 5 материи × Медитацию
  static const startMatter = 100.0; // материи в начале игры и после каждого прыжка
  static const darkJumpA = 0.04, darkJumpP = 1.0;
  static const dotT = 6.0, mendT = 6.0; // длительность метки и восстановления, с
  static const ptGrow = 1.015; // каждое следующее ОП/ОС дороже на 1,5%
  static const abilitySlots = 4;
}

class Defs {
  static const tierOrder = ['low', 'rare', 'epic', 'legend'];

  static const tiers = <String, TierDef>{
    'low': TierDef('low', 'Низшая', 1, 2.3, 1, 'Тлеющий сгусток'),
    'rare': TierDef('rare', 'Редкая', 2.5, 2.0, 3, 'Сумрачный страж'),
    'epic': TierDef('epic', 'Эпическая', 6, 1.7, 10, 'Пожиратель света'),
    'legend': TierDef('legend', 'Легендарная', 18, 1.5, 30, 'Сердце бездны'), // в 3 раза сильнее эпической
  };

  static const tierColor = <String, int>{'low': 0xFFA49DBD, 'rare': 0xFF5FB2E6, 'epic': 0xFFEF6B90, 'legend': 0xFFFF8A3D};

  static const params = <ParamDef>[
    ParamDef('life', 'Жизнь', 'Запас здоровья в бою', 0xFFEF6B90),
    ParamDef('defense', 'Защита', 'Делит урон сущностей тьмы', 0xFF5FB2E6),
    ParamDef('power', 'Мощь', 'Множитель силы атаки', 0xFFFF8A3D),
    ParamDef('meditation', 'Медитация', 'Сколько материи уходит в ход — и насколько он сильнее', 0xFFB98BFF),
    ParamDef('speed', 'Скорость', 'Как быстро откатывается ход', 0xFF7BE0A8),
    ParamDef(
      'control',
      'Управление',
      'Коэффициент защиты, материи и энергии всех ваших клеток: 1 на 1-м уровне, каждый следующий уровень умножает его на 1,01',
      0xFFF2B441,
    ),
  ];

  // Порядок важен: из него берётся случайная способность при выпадении (как Object.keys в JS)
  static final abilityList = <AbilityDef>[
    AbilityDef('spark_strike', '✦', 'spark', 'Искровой удар', 'low', 6, 3, 22, 'dmg'),
    AbilityDef('veil', '◐', 'veil', 'Покров', 'low', 5, 8, 3, 'shield'),
    AbilityDef('feed', '✚', 'regen', 'Подпитка', 'low', 6, 5, 14, 'heal'),
    AbilityDef('discharge', 'ϟ', 'bolt', 'Разряд', 'rare', 12, 5, 60, 'dmg'),
    AbilityDef('vampire', '❦', 'fang', 'Вампиризм', 'rare', 10, 6, 32, 'drain'),
    AbilityDef('haste', '⇶', 'haste', 'Ускорение', 'rare', 8, 10, 3, 'haste'),
    AbilityDef('nova', '✹', 'nova', 'Сверхновая', 'epic', 30, 12, 190, 'dmg'),
    AbilityDef('dark_shield', '⬢', 'shell', 'Щит тьмы', 'epic', 20, 14, 3.5, 'immune'),
    AbilityDef('absorb', '◎', 'absorb', 'Поглощение', 'epic', 25, 12, 0.15, 'absorb'),
    AbilityDef('ember', '☼', 'ember', 'Тлеющая метка', 'low', 5, 7, 7, 'dot'),
    AbilityDef('daze', '⊛', 'daze', 'Ошеломление', 'low', 5, 9, 1.4, 'stunfoe'),
    AbilityDef('mend', '❀', 'mend', 'Восстановление', 'low', 6, 10, 2.5, 'regenme'),
    AbilityDef('lance', '➶', 'lance', 'Пронзающий луч', 'rare', 11, 6, 46, 'pierce'),
    AbilityDef('wither', '⊘', 'wither', 'Ослабление', 'rare', 9, 12, 5, 'weaken'),
    AbilityDef('harvest', '⚘', 'harvest', 'Жатва', 'rare', 10, 8, 34, 'harvest'),
    AbilityDef('mirror', '⧉', 'mirror', 'Зеркало', 'epic', 18, 15, 4.5, 'reflect'),
    AbilityDef('finisher', '☠', 'finisher', 'Добивание', 'epic', 22, 10, 110, 'execute'),
    AbilityDef('dispel', '⊗', 'dispel', 'Рассеивание', 'epic', 16, 16, 6, 'dispel'),
  ];

  static final abilities = {for (final a in abilityList) a.id: a};

  static const gradeCost = <String, double>{'low': 1, 'rare': 1.25, 'epic': 1.5};

  static const eras = <EraDef>[
    EraDef('dawn', 'Тихая заря', 'spark', 'good', 'добыча материи +25%', {'inc': 1.25}),
    EraDef('drain', 'Иссякание', 'matter', 'bad', 'добыча материи −25%', {'inc': 0.75}),
    EraDef('tide', 'Прилив тьмы', 'comet', 'bad', 'тьма растёт в 1,5 раза быстрее', {'grow': 1.5}),
    EraDef('torpor', 'Оцепенение тьмы', 'ward', 'good', 'тьма растёт на 40% медленнее', {'grow': 0.6}),
    EraDef('flame', 'Пламя искры', 'rage', 'good', 'ваш урон +30%', {'pAtk': 1.3}),
    EraDef('dim', 'Тусклый свет', 'veil', 'bad', 'ваш урон −20%', {'pAtk': 0.8}),
    EraDef('blood', 'Кровь бездны', 'fang', 'bad', 'удар сущностей +35%', {'foeAtk': 1.35}),
    EraDef('brittle', 'Хрупкая тьма', 'stun', 'good', 'здоровье сущностей −30%', {'foeHp': 0.7}),
    EraDef('stone', 'Каменная тьма', 'shell', 'bad', 'здоровье сущностей +40%', {'foeHp': 1.4}),
    EraDef('lore', 'Эпоха знаний', 'might', 'good', 'ОП и ОС дешевле на 30%', {'pt': 0.7}),
    EraDef('toll', 'Цена знаний', 'leech', 'bad', 'ОП и ОС дороже на 40%', {'pt': 1.4}),
    EraDef('builders', 'Зодчие', 'cells', 'good', 'шахты и заводы дешевле на 30%', {'bld': 0.7}),
    EraDef('scarcity', 'Дефицит', 'erase', 'bad', 'шахты и заводы дороже на 40%', {'bld': 1.4}),
    EraDef('bastions', 'Бастионы', 'shield', 'good', 'укрепление и башни дешевле на 40%', {'def': 0.6}),
    EraDef('spoils', 'Щедрые трофеи', 'core', 'good', 'награда за победу +60%', {'reward': 1.6}),
    EraDef('meager', 'Скупые трофеи', 'clot', 'bad', 'награда за победу −40%', {'reward': 0.6}),
    EraDef('starfall', 'Звездопад', 'nova', 'good', 'артефакты выпадают в 2,5 раза чаще', {'drop': 2.5}),
    EraDef('void', 'Пустота', 'absorb', 'bad', 'артефакты выпадают втрое реже', {'drop': 0.33}),
    EraDef('ancients', 'Пробуждение древних', 'target', 'mixed', 'легендарные появляются втрое чаще, сущности +10% здоровья', {
      'leg': 3,
      'foeHp': 1.1,
    }),
    EraDef('bloom', 'Расцвет', 'regen', 'good', 'ваши клетки набирают уровни вдвое быстрее', {'held': 2}),
    EraDef('swift', 'Быстрые руки', 'haste', 'good', 'ваши ходы в бою на 20% чаще', {'cd': 0.8}),
    EraDef('viscous', 'Вязкое время', 'timer', 'bad', 'ваши ходы в бою на 25% реже', {'cd': 1.25}),
    EraDef('balance', 'Равновесие', 'heart', 'mixed', 'никаких особых эффектов'),
    EraDef('eclipse', 'Затмение', 'bolt', 'mixed', 'тьма +25% к росту, удар сущностей +15%, но награда +30%', {
      'inc': 0.85,
      'grow': 1.25,
      'foeAtk': 1.15,
      'reward': 1.3,
    }),
  ];

  // Особенности сущностей: меняют ход боя
  static const traits = <String, TraitDef>{
    'regen': TraitDef('regen', 'Регенерация', '✚', 'восстанавливает 1,5% здоровья в секунду'),
    'shell': TraitDef('shell', 'Панцирь', '⬢', 'получает на 35% меньше урона, пока здоровье выше половины'),
    'rage': TraitDef('rage', 'Ярость', '♨', 'при здоровье ниже 40% бьёт в 1,6 раза чаще'),
    'ward': TraitDef('ward', 'Завеса', '◌', 'каждые 10 с на 2 с становится неуязвимой'),
    'leech': TraitDef('leech', 'Иссушение', '☍', 'каждый удар отнимает у вас материю'),
    'stun': TraitDef('stun', 'Оглушение', '✴', 'каждый 4-й удар задерживает ваш ход на 1 с'),
  };
  static final traitOrder = traits.keys.toList();

  static const arts = <String, ArtDef>{
    'energy': ArtDef('energy', 'Кристалл энергии', '◆', 'own', 0xFF5FB2E6, '+5–50% энергии клетке', stat: 'e', wordRu: 'энергии'),
    'force': ArtDef('force', 'Осколок силы', '▲', 'own', 0xFFEF6B90, '+5–50% силы клетке', stat: 'f', wordRu: 'силы'),
    'matter': ArtDef('matter', 'Зерно материи', '●', 'own', 0xFFF2B441, '+5–50% материи клетке', stat: 'm', wordRu: 'материи'),
    'clot': ArtDef('clot', 'Сгусток материи', '✺', 'dark', 0xFFA88BE0, 'мощь клетки тьмы ÷2'),
    'core': ArtDef('core', 'Ядро искры', '✷', 'spark', 0xFFFF8A3D, 'база искры ×2–5, навсегда'),
    'bulwark': ArtDef('bulwark', 'Осколок бастиона', '⛨', 'own', 0xFF9FD3FF, 'защита клетки +10–40%'),
    'bloom': ArtDef('bloom', 'Семя роста', '❁', 'own', 0xFF7BE0A8, '+1–8 мин владения клетке'),
    'frost': ArtDef('frost', 'Иней тьмы', '❄', 'dark', 0xFFC7D6FF, 'развитие тьмы ×½'),
    'tome': ArtDef('tome', 'Свиток силы', '✎', 'player', 0xFFFFD27A, '+5–25 ОП'),
    'rune': ArtDef('rune', 'Руна навыков', '᛭', 'player', 0xFFD89BFF, '+5–25 ОС'),
    'glass': ArtDef('glass', 'Песочные часы', '⌛', 'player', 0xFFFFE8B0, 'сменить эру'),
  };

  static const artChance = <String, double>{'low': 0.04, 'rare': 0.12, 'epic': 0.25, 'legend': 1}; // чаще прежнего в 2,5–4 раза
  static const pulsarChance = <String, double>{'low': 0.005, 'rare': 0.015, 'epic': 0.04, 'legend': 0.25};
  // Ядро выпадает вдвое реже остальных видов (за легендарную сущность — втрое чаще)
  static Map<String, double> artWeights(String tier) => {
    'energy': 1,
    'force': 1,
    'matter': 1,
    'clot': 0.8,
    'core': tier == 'legend' ? 1.5 : 0.35,
    'bulwark': 0.8,
    'bloom': 0.8,
    'frost': 0.6,
    'tome': 0.7,
    'rune': 0.7,
    'glass': 0.4,
  };

  /// Технологии: дерево развития, изучается за пульсары; сохраняется при прыжке
  static final tech = <TechDef>[
    TechDef(
      'jump',
      1,
      'Прыжок',
      'rebirth',
      1,
      [],
      'Открывает прыжок искры в новую область вселенной с бонусами от текущего воплощения.',
    ),
    // второй уровень: открывается после «Прыжка», 3 ранга по 3 / 9 / 27 пульсаров
    TechDef(
      'grow',
      2,
      'Рост',
      'grow',
      3,
      ['jump'],
      'Ускоряет развитие ваших клеток: уровни, новые ячейки строений и всё, что зависит от времени владения.',
      ranks: 3,
      per: 0.25,
      whatRu: 'скорость развития клеток',
    ),
    TechDef(
      'fort',
      2,
      'Укрепление',
      'fort',
      3,
      ['jump'],
      'Каждый уровень укрепления клетки даёт больше защиты.',
      ranks: 3,
      per: 0.25,
      whatRu: 'защита от укреплений',
    ),
    TechDef(
      'income',
      2,
      'Доход',
      'income',
      3,
      ['jump'],
      'Увеличивает приток материи: множитель ко всей добыче, поверх заводов, эры и бонуса прыжка.',
      ranks: 3,
      per: 0.15,
      whatRu: 'вся добыча материи',
    ),
    // третий уровень: по две ветки от каждой технологии второго уровня, пока неизвестны
    for (final p in ['grow', 'fort', 'income'])
      for (final x in ['a', 'b'])
        TechDef('$p-$x', 3, 'Неизвестная технология', 'unknown', 0, [p], 'Откроется в следующих версиях.', soon: true),
  ];
  static final techById = {for (final t in tech) t.id: t};

  static const buildings = <String, BuildingDef>{
    'mine': BuildingDef('mine', 'Шахта', 'шахта', '⛏'),
    'factory': BuildingDef('factory', 'Завод', 'завод', '⚙'),
    'tower': BuildingDef('tower', 'Защитная башня', 'башня', '♜'),
  };

  // Шестиугольная сетка (осевые координаты)
  static const dirs = <List<int>>[
    [1, 0],
    [1, -1],
    [0, -1],
    [-1, 0],
    [-1, 1],
    [0, 1],
  ];
}
