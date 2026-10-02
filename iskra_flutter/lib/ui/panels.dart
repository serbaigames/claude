// Вкладки меню: клетка, персонаж, способности, артефакты, технологии и прыжок, эры, аккаунт, рейтинги.
// Тексты и подсказки взяты из веб-версии.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/game.dart';
import '../net/api.dart';
import '../net/cloud_sync.dart';
import 'controller.dart';
import 'map_art.dart';
import 'portraits.dart';
import 'theme.dart';
import 'widgets.dart';

enum MenuTab { cell, char, abil, art, tech, era, acc, top }

const tabTitles = {
  MenuTab.cell: 'Клетка',
  MenuTab.char: 'Характеристики искры',
  MenuTab.abil: 'Способности',
  MenuTab.art: 'Артефакты',
  MenuTab.tech: 'Технологии',
  MenuTab.era: 'Эры',
  MenuTab.acc: 'Аккаунт',
  MenuTab.top: 'Рейтинги',
};

Widget panelFor(MenuTab t, GameController ctl) => switch (t) {
  MenuTab.cell => CellPanel(ctl),
  MenuTab.char => CharPanel(ctl),
  MenuTab.abil => AbilPanel(ctl),
  MenuTab.art => ArtPanel(ctl),
  MenuTab.tech => TechPanel(ctl),
  MenuTab.era => EraPanel(ctl),
  MenuTab.acc => AccountPanel(ctl),
  MenuTab.top => TopPanel(ctl),
};

Widget _wrap(List<Widget> children) => Wrap(spacing: 8, runSpacing: 8, children: children);

/* ---------- клетка ---------- */
class CellPanel extends StatelessWidget {
  const CellPanel(this.ctl, {super.key});
  final GameController ctl;

  @override
  Widget build(BuildContext context) {
    final g = ctl.game, c = g.sel;
    if (c == null) return _overview(g);
    if (c.spark) return _spark(g);
    return c.own ? _own(g, c) : _dark(g, c);
  }

  Widget _statBars(Game g, Cell c) {
    final own = c.own && !c.spark;
    Widget row(String k, String n, Color col, String what) {
      final v = g.st(c, k), m = Game.mult(v);
      return Tooltip(
        message: '$n: $what ×${Fmt.x(m, 2)}',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(n, style: const TextStyle(color: C.muted)),
              ),
              Expanded(child: Bar(v / 100, color: col)),
              SizedBox(width: 48, child: Text('${v.round()}%', textAlign: TextAlign.right)),
              SizedBox(
                width: 48,
                child: Text(
                  '×${Fmt.x(m, 2)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: C.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        row('m', 'Материя', C.matter, own ? 'выработка шахт' : 'материя клетки'),
        row('e', 'Энергия', C.energy, own ? 'сила заводов' : 'энергия клетки'),
        row('f', 'Сила', C.force, own ? 'прибавка укреплений' : 'сила клетки'),
      ],
    );
  }

  Widget _overview(Game g) {
    final x = g.incomeParts(), thr = g.threatCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Владения', style: h2()),
        const SizedBox(height: 6),
        KV([
          ('Агрессивность мира', g.aggrText),
          ('Клеток', '${g.own.length}'),
          ('Под угрозой', '$thr'),
          ('Шахты, в секунду', Fmt.n1(x.mines * g.bonusMul)),
          ('Заводы, ко всей добыче', '+${Fmt.n1(x.fac)}%'),
          ('База искры, в секунду', Fmt.n1(x.base)),
        ]),
        if (thr > 0)
          const Note('Клетки с красной рамкой может забрать тьма.', kind: 'bad')
        else if (g.own.length == 1 && g.s.lostOnce)
          const Note('Соседей не одолеть? Совершите прыжок — вкладка «Технологии».'),
        const Note('Нажмите на клетку на карте: золотые — ваши, фиолетовые — тьма.'),
      ],
    );
  }

  Widget _portrait(Widget p) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(height: 150, child: p),
  );

  Widget _spark(Game g) {
    final x = g.incomeParts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Искра', style: h2(C.gold)),
        const SizedBox(height: 8),
        _portrait(PlasmaPortrait.spark(cores: g.s.cores.length, speed: g.sparkSpeed)),
        const SizedBox(height: 8),
        KV([
          ('Клетки × бонус', Fmt.n1(g.sparkMatter)),
          ('Ядра искры${g.s.cores.isEmpty ? '' : ' (${g.s.cores.length})'}', '×${g.coreMul}'),
          ('Скорость искры', '×${Fmt.x(g.sparkSpeed, 2)}'),
          ('Добыча базы, в секунду', Fmt.n1(x.base)),
          ('Бонус прыжка', '×${Fmt.x(g.bonusMul, 2)}'),
        ]),
        const Note('Добыча базы = 0,5 × ядро × клетки × бонус × скорость. Искру нельзя потерять.'),
      ],
    );
  }

  Widget _own(Game g, Cell c) {
    final def = g.cellDef(c), th = g.maxAdjMight(c), danger = th >= def * 0.8;
    final lv = Game.cellLvl(c), nx = Game.nextLvlAt(c), from = lv > 0 ? nx / 2 : 0.0;
    final dc = g.defCost(c), gain = g.fortGain(c);
    final cap = Game.cap(c), full = Game.usedCap(c) >= cap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ваша клетка', style: h2(C.gold)),
                  Text(
                    'Уровень $lv (+${lv * 10}%) · до ${lv + 1}-го ${Fmt.clock(nx - c.held)}',
                    style: const TextStyle(color: C.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Bar((c.held - from) / (nx - from), height: 4),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ActBtn(
              'Укрепить +${Fmt.n1(gain)}',
              g.s.matter >= dc ? () => ctl.act((g) => g.fortify(c.key)) : null,
              right: Fmt.n(dc),
              primary: danger,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) => _portrait(
            PlasmaPortrait.cell(
              slots: slotTypes(c.b, cap),
              ring: [c.m, c.e, c.f],
              tagLeft: 'защита ${Fmt.n(def.floor())}',
              tagRight: '${Game.usedCap(c)} / $cap',
              onEmptySlot: full ? null : () => _buildMenu(context, c.key),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _statBars(g, c),
        const SizedBox(height: 8),
        KV([
          ('Защита', '${Fmt.n(def.floor())} · ур. укрепления ${c.defLvl}'),
          ('Сильнейший сосед', th > 0 ? Fmt.n(th.ceil()) : '—'),
          ('Башни', '+${Fmt.n(Game.towerPct(Game.bL(c, 'tower')))}% защиты'),
          ('Ячейки строений', '${Game.usedCap(c)} из $cap · новая через ${Fmt.clock(Game.nextSlotIn(c))}'),
          ('Во владении', Fmt.clock(c.held)),
        ]),
        if (danger) const Note('Сосед почти сравнялся с защитой.', kind: 'bad'),
        const SizedBox(height: 10),
        for (final b in Defs.buildings.values) _bld(g, c, b, full),
      ],
    );
  }

  // Касание пустой ячейки на орбите: что построить
  void _buildMenu(BuildContext context, String key) => showDialog<void>(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: ctl,
      builder: (ctx, _) {
        final g = ctl.game, c = g.s.cells[key];
        return SimpleDialog(
          title: const Text('Построить в ячейке'),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            if (c != null && c.own)
              for (final b in Defs.buildings.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      BuildingIcon(b.id),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ActBtn(
                          '${b.name}${Game.bL(c, b.id) > 0 ? ' (${Game.bL(c, b.id) + 1} ур.)' : ''}',
                          g.s.matter >= g.bldCost(c, b.id) && Game.usedCap(c) < Game.cap(c)
                              ? () {
                                  ctl.act((g) => g.build(key, b.id));
                                  Navigator.pop(ctx);
                                }
                              : null,
                          right: Fmt.n(g.bldCost(c, b.id)),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    ),
  );

  Widget _bld(Game g, Cell c, BuildingDef b, bool full) {
    final l = Game.bL(c, b.id), cost = g.bldCost(c, b.id);
    final now = switch (b.id) {
      'mine' => '+${Fmt.n1(g.mineRate(c, l))}/с',
      'factory' => '+${Fmt.n1(g.factPct(c, l))}%',
      _ => '+${Fmt.n(Game.towerPct(l))}% защиты',
    };
    final next = switch (b.id) {
      'mine' => '+${Fmt.n1(g.mineRate(c, l + 1))} материи/с',
      'factory' => '+${Fmt.n1(g.factPct(c, l + 1))}% в сумму заводов',
      _ => '+${Fmt.n(Game.towerPct(l + 1))}% защиты',
    };
    final syn = l > 1 && b.id != 'tower' ? ' · комплекс +${(l - 1) * 10}%' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          BuildingIcon(b.id),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${b.name}: $l', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(l > 0 ? '$now$syn' : 'не построено', style: const TextStyle(color: C.muted, fontSize: 12)),
              ],
            ),
          ),
          Tooltip(
            message: '${l > 0 ? 'Улучшить' : 'Построить'}: $next',
            child: ActBtn(
              '+',
              !full && g.s.matter >= cost ? () => ctl.act((g) => g.build(c.key, b.id)) : null,
              right: Fmt.n(cost),
            ),
          ),
          if (l > 0) ...[
            const SizedBox(width: 6),
            _Confirm(label: '−', confirm: 'Понизить?', onConfirm: () => ctl.act((g) => g.lower(c.key, b.id))),
          ],
        ],
      ),
    );
  }

  Widget _dark(Game g, Cell c) {
    final t = Defs.tiers[c.tier]!;
    final paused = g.s.paused, rate = g.growRate(c), left = math.max(0, (c.growth - c.t) / rate);
    final grow = KV([
      ('Мощь', Fmt.n(c.might.ceil())),
      ('После шага', '≈${Fmt.n((c.might * (1 + (c.dev - 1) * g.darkF) + 0.2).ceil())}'),
      ('До шага', paused ? 'пауза' : '${left.toStringAsFixed(0)} с'),
      ('Уровень клетки', '${Game.cellLvl(c)} (+${Game.cellLvl(c) * 10}%)'),
    ]);
    if (!c.alive) {
      final cost = c.might.ceil(), lack = g.s.matter < cost;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Свободная клетка', style: h2()),
          const Text('Защитник побеждён. Клетку можно взять за материю, равную мощи.', style: TextStyle(color: C.muted)),
          const SizedBox(height: 6),
          _statBars(g, c),
          const SizedBox(height: 6),
          grow,
          const SizedBox(height: 10),
          ActBtn(
            lack ? 'Нужно ещё ${Fmt.n((cost - g.s.matter).ceil())}' : 'Захватить',
            lack ? null : () => ctl.act((g) => g.capture(c.key)),
            right: Fmt.n(cost),
            primary: true,
          ),
        ],
      );
    }
    final f = g.foeFromCell(c), hit = f.atk / g.defDiv();
    final fc = g.fightForecast(c), lab = GameForecast.forecastLabel(fc.p);
    final art = math.min(100, Defs.artChance[c.tier]! * g.aggr * 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(child: Text(f.name, style: h2())),
            const SizedBox(width: 8),
            tierChip(c.tier, t.name),
            if (f.dist > 1) ...[const SizedBox(width: 6), Text('×${f.dist}', style: const TextStyle(color: C.muted))],
          ],
        ),
        if (c.tier == 'epic') const Text('очень опасна', style: TextStyle(color: C.bad)),
        if (c.tier == 'legend') const Text('смертельно опасна, соседи растут ×2', style: TextStyle(color: C.bad)),
        const SizedBox(height: 8),
        _portrait(PlasmaPortrait.entity(tier: c.tier)),
        const SizedBox(height: 8),
        KV([
          ('Здоровье', Fmt.n(f.maxHp.round())),
          ('Удар по вам', '${Fmt.n(hit.round())} раз в ${Fmt.x(f.cd)} с'),
          ('Награда за победу', '+${Fmt.n((f.matter * 0.5).floor())}'),
          ('Штраф за поражение', '−${Fmt.n((f.pen * 0.5).floor())}'),
          ('Шанс артефакта', '${Fmt.x(art)}%'),
        ]),
        for (final tr in f.traits)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${Defs.traits[tr]!.glyph} ${Defs.traits[tr]!.name}: ${Defs.traits[tr]!.desc}',
              style: const TextStyle(color: C.warn, fontSize: 13),
            ),
          ),
        const SizedBox(height: 8),
        grow,
        const SizedBox(height: 8),
        Note('${lab.label[0].toUpperCase()}${lab.label.substring(1)} · ${g.fcMatter(fc)}', kind: lab.kind),
        const SizedBox(height: 10),
        ActBtn('В бой', () => ctl.act((g) => g.startBattle(g.foeFromCell(c), c.key)), primary: true),
      ],
    );
  }
}

/// Кнопка с подтверждением вторым нажатием (как «Нажмите ещё раз» в веб-версии)
class _Confirm extends StatefulWidget {
  const _Confirm({required this.label, required this.confirm, required this.onConfirm});
  final String label, confirm;
  final VoidCallback onConfirm;
  @override
  State<_Confirm> createState() => _ConfirmState();
}

class _ConfirmState extends State<_Confirm> {
  DateTime? armed;
  @override
  Widget build(BuildContext context) {
    final on = armed != null && DateTime.now().difference(armed!).inMilliseconds < 3500;
    return ActBtn(on ? widget.confirm : widget.label, () {
      if (on) {
        armed = null;
        widget.onConfirm();
      } else {
        setState(() => armed = DateTime.now());
      }
    }, danger: on);
  }
}

/// Переключатель «сколько за раз»: ×1 → ×10 → ×100 → MAX
class _ModeBtn extends StatelessWidget {
  const _ModeBtn(this.mode, this.onChange);
  final BuyMode mode;
  final ValueChanged<BuyMode> onChange;
  @override
  Widget build(BuildContext context) =>
      ActBtn(buyModeLabel(mode), () => onChange(buyModes[(buyModes.indexOf(mode) + 1) % buyModes.length]));
}

/* ---------- персонаж ---------- */
class CharPanel extends StatefulWidget {
  const CharPanel(this.ctl, {super.key});
  final GameController ctl;
  @override
  State<CharPanel> createState() => _CharPanelState();
}

class _CharPanelState extends State<CharPanel> {
  BuyMode opMode = 1, parMode = 1;

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl, g = ctl.game;
    final ob = g.opBuyInfo(opMode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Характеристики искры', style: h2()),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('✦ ${g.s.op} ОП', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
            _ModeBtn(opMode, (m) => setState(() => opMode = m)),
            const SizedBox(width: 6),
            ActBtn(
              'Купить +${ob.n}',
              ob.n > 0 && g.s.matter >= ob.cost ? () => ctl.act((g) => g.buyOp(opMode)) : null,
              right: Fmt.n(ob.cost),
              primary: true,
            ),
          ],
        ),
        Text(
          'Каждое следующее ОП дороже на 1,5%; следующее — ${Fmt.n(ob.next)} материи',
          style: const TextStyle(color: C.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Text('Параметры', style: TextStyle(color: C.muted)),
            ),
            _ModeBtn(parMode, (m) => setState(() => parMode = m)),
          ],
        ),
        for (final p in Defs.params) _param(g, p),
        const SizedBox(height: 6),
        KV([
          ('Здоровье в бою', Fmt.n(g.maxHp().round())),
          ('Делитель урона тьмы', Fmt.x(g.defDiv(), 2)),
          ('Сила атаки', '×${Fmt.x(g.powMul(), 2)}'),
          ('Медитация', '×${Fmt.x(g.med(), 2)}'),
          ('Откат хода', '${Fmt.x(g.turnCd(), 2)} с'),
          ('Управление', '+${Fmt.x(g.ctrlPct, 1)}% к клеткам'),
        ]),
        const Note('Если параметр вдвое выше среднего по остальным, он теряет 10% силы, втрое — 20% и так далее до 60%.'),
      ],
    );
  }

  Widget _param(Game g, ParamDef p) {
    final e = g.eff(p.id), x = g.parInfo(p.id, parMode);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: Color(p.color), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: p.desc,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${p.name} ${g.s.char[p.id]}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (e.pen > 0)
                      TextSpan(
                        text: '  −${(e.pen * 100).round()}%',
                        style: const TextStyle(color: C.bad),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ActBtn(
            '+${x.n}',
            x.n > 0 && g.s.op >= x.cost ? () => widget.ctl.act((g) => g.parUp(p.id, parMode)) : null,
            right: '${Fmt.n(x.cost)} ОП',
          ),
        ],
      ),
    );
  }
}

/* ---------- способности ---------- */
class AbilPanel extends StatefulWidget {
  const AbilPanel(this.ctl, {super.key});
  final GameController ctl;
  @override
  State<AbilPanel> createState() => _AbilPanelState();
}

class _AbilPanelState extends State<AbilPanel> {
  BuyMode osMode = 1, abMode = 1;

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl, g = ctl.game;
    final ob = g.osBuyInfo(osMode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Способности', style: h2()),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('✧ ${g.s.os} ОС', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
            _ModeBtn(osMode, (m) => setState(() => osMode = m)),
            const SizedBox(width: 6),
            ActBtn(
              'Купить +${ob.n}',
              ob.n > 0 && g.s.matter >= ob.cost ? () => ctl.act((g) => g.buyOs(osMode)) : null,
              right: Fmt.n(ob.cost),
              primary: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text('Ячейки', style: TextStyle(color: C.muted)),
            ),
            _ModeBtn(abMode, (m) => setState(() => abMode = m)),
          ],
        ),
        for (var i = 0; i < g.s.abilities.length; i++) _slot(g, i),
        const Note(
          'Новые способности выпадают после побед над сущностями того же ранга. Уровень стоит ОС: низшая 1, редкая 3, эпическая 10 за уровень.',
        ),
      ],
    );
  }

  Widget _slot(Game g, int i) {
    final a = g.s.abilities[i];
    if (a == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('${i + 1}. пусто', style: const TextStyle(color: C.muted)),
      );
    }
    final d = Defs.abilities[a.id]!, x = g.abInfo(i, abMode);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(d.glyph, style: TextStyle(fontSize: 20, color: Color(Defs.tierColor[d.tier]!))),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${d.name}, ур. ${a.lvl}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${g.abDesc(a)} · ${Fmt.n(Game.abCost(a))} материи · откат ${Fmt.x(d.cd)} с',
                  style: const TextStyle(color: C.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          ActBtn(
            '+${x.n}',
            x.n > 0 && g.s.os >= x.cost ? () => widget.ctl.act((g) => g.abUp(i, abMode)) : null,
            right: '${Fmt.n(x.cost)} ОС',
          ),
          const SizedBox(width: 6),
          _Confirm(label: '×', confirm: 'Удалить?', onConfirm: () => widget.ctl.act((g) => g.abDelete(i))),
        ],
      ),
    );
  }
}

/* ---------- артефакты ---------- */
class ArtPanel extends StatelessWidget {
  const ArtPanel(this.ctl, {super.key});
  final GameController ctl;

  @override
  Widget build(BuildContext context) {
    final g = ctl.game, c = g.sel;
    final target = c == null
        ? 'ничего'
        : c.spark
        ? 'искра'
        : c.own
        ? 'ваша клетка'
        : c.alive
        ? 'тьма, мощь ${c.might.ceil()}'
        : 'свободная, мощь ${c.might.ceil()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Артефакты', style: h2()),
        const SizedBox(height: 4),
        Text('Выбрано: $target', style: const TextStyle(color: C.muted)),
        const SizedBox(height: 8),
        if (g.s.artifacts.isEmpty) const Text('Пока пусто. Артефакты выпадают после побед.', style: TextStyle(color: C.muted)),
        _wrap([for (var i = 0; i < g.s.artifacts.length; i++) _art(g, i)]),
        const SizedBox(height: 10),
        const Text('Виды', style: TextStyle(color: C.muted)),
        for (final a in Defs.arts.values)
          Text('${a.glyph} ${a.name} — ${a.short}', style: TextStyle(color: Color(a.color), fontSize: 13)),
        const Note('Шанс артефакта за победу: 4% / 12% / 25% / 100% по рангу сущности, умноженный на агрессивность мира и эру.'),
      ],
    );
  }

  Widget _art(Game g, int i) {
    final a = g.s.artifacts[i], d = Defs.arts[a.type]!, ok = g.artValid(a, g.sel);
    return Tooltip(
      message: '${g.artTitle(a)}: ${g.artDesc(a)}${ok ? '' : ' Выберите на карте подходящую клетку.'}',
      child: InkWell(
        onTap: ok ? () => ctl.act((g) => g.applyArt(i)) : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Color(d.color).withValues(alpha: ok ? 0.18 : 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Color(d.color).withValues(alpha: ok ? 0.8 : 0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(d.glyph, style: TextStyle(fontSize: 20, color: Color(d.color))),
              Text(g.artBadge(a), style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------- технологии и прыжок ---------- */
/// Значки технологий
const techIcons = {
  'rebirth': Icons.rocket_launch_outlined,
  'grow': Icons.spa_outlined,
  'fort': Icons.shield_outlined,
  'income': Icons.savings_outlined,
  'unknown': Icons.question_mark,
};

/// Значок пульсара (валюта технологий)
const pulsarIcon = Icons.flare;

class TechPanel extends StatelessWidget {
  const TechPanel(this.ctl, {super.key});
  final GameController ctl;

  @override
  Widget build(BuildContext context) {
    final g = ctl.game;
    final l1 = Defs.tech.where((t) => t.lvl == 1).toList();
    final l2 = Defs.tech.where((t) => t.lvl == 2).toList();
    final l3 = [for (final p in l2) ...Defs.tech.where((t) => t.lvl == 3 && t.req.contains(p.id))];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Технологии', style: h2()),
            const SizedBox(width: 12),
            const Icon(pulsarIcon, size: 18, color: C.gold),
            const SizedBox(width: 4),
            Text(
              '${g.s.pulsars}',
              style: const TextStyle(color: C.gold, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Пульсары изредка выпадают после побед над сущностями. Технология открывается, когда изучен '
          'хотя бы 1-й ранг предыдущей. Технологии и их ранги сохраняются при прыжке.',
          style: TextStyle(color: C.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth, col = w / 3;
            const gap = 22.0;
            Widget level(String label) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(label, style: const TextStyle(color: C.muted, fontSize: 11)),
            );
            return Column(
              children: [
                level('Уровень 1'),
                Center(
                  child: SizedBox(width: col, child: _node(context, g, l1.first)),
                ),
                _Links(
                  height: gap,
                  from: [w / 2],
                  to: [for (var i = 0; i < l2.length; i++) (i + 0.5) * col],
                  lit: [for (final t in l2) g.techOpen(t)],
                ),
                level('Уровень 2'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final t in l2)
                      SizedBox(
                        width: col,
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _node(context, g, t)),
                      ),
                  ],
                ),
                _Links(
                  height: gap,
                  from: [for (var i = 0; i < l2.length; i++) (i + 0.5) * col],
                  to: [for (var j = 0; j < l3.length; j++) (j + 0.5) * w / l3.length],
                  lit: [for (final t in l3) g.techOpen(t)],
                  fanOut: 2,
                ),
                level('Уровень 3'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final t in l3)
                      SizedBox(
                        width: w / l3.length,
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _small(context, g, t)),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Text('Прыжок искры', style: h2()),
        const SizedBox(height: 4),
        Text(g.worldTrend().info, style: const TextStyle(color: C.muted, fontSize: 13)),
        const SizedBox(height: 8),
        ActBtn(
          g.hasTech('jump') ? 'Прыжок…' : 'Нужна технология «Прыжок»',
          g.hasTech('jump') ? ctl.openJump : null,
          right: g.hasTech('jump') ? '+${Fmt.x(g.rebirthGain(), 2)} к бонусу' : null,
          primary: true,
        ),
      ],
    );
  }

  /// Состояние узла: изучено полностью, доступно, закрыто
  Color _tone(Game g, TechDef t) {
    if (t.soon) return C.line;
    if (g.techRank(t.id) >= t.ranks) return C.ok;
    if (g.hasTech(t.id)) return C.gold;
    return g.techOpen(t) ? C.violet : C.line;
  }

  Widget _node(BuildContext context, Game g, TechDef t) {
    final r = g.techRank(t.id), cost = g.techNextCost(t), open = g.techOpen(t), tone = _tone(g, t);
    final can = open && cost != null && g.s.pulsars >= cost;
    return Container(
      key: ValueKey('tech-${t.id}'),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      decoration: BoxDecoration(
        color: C.bg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: open ? 0.8 : 0.5)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 24),
              Expanded(child: Center(child: _badge(t, tone, open, 40))),
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'О технологии «${t.name}»',
                  icon: const Icon(Icons.info_outline, size: 18, color: C.muted),
                  onPressed: () => _info(context, g, t),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: open ? C.ink : C.muted),
          ),
          if (t.ranks > 1) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < t.ranks; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < r ? C.gold : Colors.transparent,
                      border: Border.all(color: i < r ? C.gold : C.muted),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          if (cost == null)
            Text(t.ranks > 1 ? 'все ранги' : 'изучено', style: const TextStyle(color: C.ok, fontSize: 12))
          else if (!open)
            const Text('закрыто', style: TextStyle(color: C.muted, fontSize: 12))
          else
            SizedBox(
              height: 32,
              child: FilledButton(
                onPressed: can ? () => ctl.act((g) => g.researchTech(t.id)) : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: C.goldBg,
                  foregroundColor: C.gold,
                  side: BorderSide(color: can ? C.gold.withValues(alpha: 0.45) : C.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(r == 0 ? 'Изучить' : 'Ранг ${r + 1}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text('$cost', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const Icon(pulsarIcon, size: 13),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Узел третьего уровня: значок и подпись, подробности по нажатию
  Widget _small(BuildContext context, Game g, TechDef t) => InkWell(
    key: ValueKey('tech-${t.id}'),
    borderRadius: BorderRadius.circular(10),
    onTap: () => _info(context, g, t),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _badge(t, _tone(g, t), false, 34),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(t.soon ? 'скоро' : t.name, style: const TextStyle(color: C.muted, fontSize: 11)),
          ),
        ],
      ),
    ),
  );

  Widget _badge(TechDef t, Color tone, bool open, double d) => Container(
    width: d,
    height: d,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: tone.withValues(alpha: 0.15),
      border: Border.all(color: tone.withValues(alpha: 0.8), width: 1.5),
    ),
    child: Icon(techIcons[t.icon] ?? Icons.question_mark, size: d * 0.55, color: t.soon ? C.muted : tone),
  );

  void _info(BuildContext context, Game g, TechDef t) {
    final r = g.techRank(t.id);
    final need = t.req.map((id) => Defs.techById[id]!.name).join(', ');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.panel,
        title: Row(
          children: [
            Icon(techIcons[t.icon] ?? Icons.question_mark, color: C.gold),
            const SizedBox(width: 8),
            Expanded(child: Text(t.name, style: h2())),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.desc),
            if (t.per > 0) ...[
              const SizedBox(height: 10),
              for (var i = 0; i < t.ranks; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'Ранг ${i + 1}: ${t.what} ×${Fmt.x(1 + t.per * (i + 1), 2)} · ${t.rankCost(i)} пульсаров',
                    style: TextStyle(color: i < r ? C.ok : C.muted, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                r == 0 ? 'Пока не изучена.' : 'Сейчас: ранг $r из ${t.ranks}, ${t.what} ×${Fmt.x(g.techMul(t.id), 2)}.',
                style: const TextStyle(color: C.gold),
              ),
            ] else if (!t.soon) ...[
              const SizedBox(height: 8),
              Text(r > 0 ? 'Изучено.' : 'Стоит ${t.cost} пульсар.', style: const TextStyle(color: C.gold)),
            ],
            if (need.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Нужна технология: $need (хотя бы 1-й ранг).', style: const TextStyle(color: C.muted, fontSize: 12)),
            ],
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно'))],
      ),
    );
  }
}

/// Линии дерева между уровнями: от каждого родителя к его детям
class _Links extends StatelessWidget {
  const _Links({required this.height, required this.from, required this.to, required this.lit, this.fanOut});
  final double height;
  final List<double> from, to;
  final List<bool> lit;

  /// Сколько детей у каждого родителя; null — все дети от первого родителя
  final int? fanOut;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _LinksPainter(this)),
  );
}

class _LinksPainter extends CustomPainter {
  _LinksPainter(this.l);
  final _Links l;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    for (var j = 0; j < l.to.length; j++) {
      final x0 = l.from[l.fanOut == null ? 0 : j ~/ l.fanOut!], x1 = l.to[j];
      final p = Paint()
        ..color = l.lit[j] ? C.gold.withValues(alpha: 0.8) : C.line
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      canvas.drawPath(
        Path()
          ..moveTo(x0, 0)
          ..lineTo(x0, h / 2)
          ..lineTo(x1, h / 2)
          ..lineTo(x1, h),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_LinksPainter old) => true;
}

/* ---------- эры ---------- */
/// Картинка эры: своя для каждой из 24 эр (кнопка эры и список эр)
const eraIcons = {
  'dawn': Icons.wb_twilight,
  'drain': Icons.water_drop_outlined,
  'tide': Icons.waves,
  'torpor': Icons.ac_unit,
  'flame': Icons.local_fire_department,
  'dim': Icons.brightness_low,
  'blood': Icons.bloodtype_outlined,
  'brittle': Icons.heart_broken_outlined,
  'stone': Icons.landscape_outlined,
  'lore': Icons.menu_book_outlined,
  'toll': Icons.paid_outlined,
  'builders': Icons.construction,
  'scarcity': Icons.remove_shopping_cart_outlined,
  'bastions': Icons.fort,
  'spoils': Icons.card_giftcard,
  'meager': Icons.money_off,
  'starfall': Icons.auto_awesome,
  'void': Icons.blur_on,
  'ancients': Icons.visibility_outlined,
  'bloom': Icons.local_florist_outlined,
  'swift': Icons.bolt,
  'viscous': Icons.hourglass_bottom,
  'balance': Icons.balance,
  'eclipse': Icons.brightness_3_outlined,
};

class EraPanel extends StatelessWidget {
  const EraPanel(this.ctl, {super.key});
  final GameController ctl;

  @override
  Widget build(BuildContext context) {
    final g = ctl.game, e = g.eraNow, cur = g.s.era!.i;
    final l = g.s.era!.left.ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(eraIcons[e.id], color: C.kind(e.kind), size: 24),
            const SizedBox(width: 8),
            Flexible(child: Text(e.name, style: h2(C.kind(e.kind)))),
          ],
        ),
        Text('${e.desc} · осталось ${l ~/ 60}:${(l % 60).toString().padLeft(2, '0')} из ${(g.s.era!.dur / 60).round()} мин'),
        const SizedBox(height: 10),
        for (var i = 0; i < Defs.eras.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: 8),
                  child: Icon(eraIcons[Defs.eras[i].id], size: 18, color: C.kind(Defs.eras[i].kind)),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: Defs.eras[i].name,
                          style: TextStyle(fontWeight: FontWeight.w700, color: C.kind(Defs.eras[i].kind)),
                        ),
                        if (i == cur)
                          const TextSpan(
                            text: ' · сейчас',
                            style: TextStyle(color: C.gold),
                          ),
                        TextSpan(
                          text: ' — ${Defs.eras[i].desc}',
                          style: const TextStyle(color: C.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Note(
          'Эра длится от 1 до 10 минут игрового времени (на паузе не идёт). Зелёные помогают вам, красные — тьме, жёлтые — смешанные.',
        ),
      ],
    );
  }
}

/* ---------- аккаунт и статистика ---------- */
class AccountPanel extends StatefulWidget {
  const AccountPanel(this.ctl, {super.key});
  final GameController ctl;
  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  final login = TextEditingController(), pass = TextEditingController(), pass2 = TextEditingController();
  String? err;
  bool busy = false;
  String mode = 'login'; // login / register / password / delete

  @override
  void dispose() {
    login.dispose();
    pass.dispose();
    pass2.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await f();
      pass.clear();
      pass2.clear();
    } on ApiError catch (e) {
      err = e.message;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl, g = ctl.game, sync = ctl.sync, k = g.s.kills;
    final stats = KV([
      ('Материя за всё время', Fmt.n(g.s.earned)),
      ('Рекорд клеток', '${g.s.bestCells}'),
      ('Прыжков', '${g.s.rebirths}'),
      ('Побеждено: низшие / редкие / эпические / легендарные', '${k['low']} / ${k['rare']} / ${k['epic']} / ${k['legend']}'),
      ('Время в этом мире', Fmt.time(g.s.worldTime)),
    ]);
    final List<Widget> acc;
    if (sync == null || !sync.on) {
      acc = [
        const Text(
          'Сервер учётных записей недоступен: прогресс хранится только на этом устройстве.',
          style: TextStyle(color: C.muted),
        ),
      ];
    } else if (sync.user == null) {
      acc = [
        Row(
          children: [
            ChoiceChip(label: const Text('Вход'), selected: mode == 'login', onSelected: (_) => setState(() => mode = 'login')),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Регистрация'),
              selected: mode == 'register',
              onSelected: (_) => setState(() => mode = 'register'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: login,
          decoration: const InputDecoration(labelText: 'Имя'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: pass,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Пароль'),
        ),
        if (mode == 'register')
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Почта не нужна, поэтому забытый пароль восстановить нельзя.',
              style: TextStyle(color: C.warn, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        ActBtn(
          mode == 'login' ? 'Войти' : 'Создать',
          busy
              ? null
              : () => _run(
                  () => mode == 'login' ? sync.login(login.text.trim(), pass.text) : sync.register(login.text.trim(), pass.text),
                ),
          primary: true,
        ),
      ];
    } else {
      acc = [
        Text('👤 ${sync.user!.login}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        Text(
          sync.statusText,
          style: TextStyle(color: sync.state == SyncState.err || sync.state == SyncState.conflict ? C.bad : C.muted),
        ),
        const SizedBox(height: 8),
        _wrap([
          ActBtn('Сохранить', sync.busy ? null : () => sync.cloudSave(manual: true), primary: true),
          ActBtn('Выйти', busy ? null : () => _run(sync.logout)),
          ActBtn('Сменить пароль', () => setState(() => mode = 'password')),
          ActBtn('Удалить учётную запись', () => setState(() => mode = 'delete'), danger: true),
        ]),
        if (mode == 'password') ...[
          const SizedBox(height: 8),
          TextField(
            controller: pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Текущий пароль'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: pass2,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Новый пароль'),
          ),
          const SizedBox(height: 8),
          ActBtn(
            'Сменить (остальные устройства выйдут)',
            busy ? null : () => _run(() => sync.api.changePassword(pass.text, pass2.text)),
          ),
        ],
        if (mode == 'delete') ...[
          const SizedBox(height: 8),
          TextField(
            controller: pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Пароль для подтверждения'),
          ),
          const SizedBox(height: 8),
          ActBtn('Удалить навсегда', busy ? null : () => _run(() => sync.deleteAccount(pass.text)), danger: true),
        ],
      ];
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Учётная запись', style: h2()),
        const SizedBox(height: 6),
        ...acc,
        if (err != null) Note(err!, kind: 'bad'),
        const SizedBox(height: 14),
        Text('Статистика', style: h2()),
        const SizedBox(height: 6),
        stats,
        const SizedBox(height: 14),
        _Confirm(label: 'Начать заново', confirm: 'Стереть прогресс на устройстве?', onConfirm: ctl.resetAll),
      ],
    );
  }
}

/* ---------- рейтинги ---------- */
class TopPanel extends StatefulWidget {
  const TopPanel(this.ctl, {super.key});
  final GameController ctl;
  @override
  State<TopPanel> createState() => _TopPanelState();
}

class _TopPanelState extends State<TopPanel> {
  static const tops = {
    'matter': 'Материя за всё время',
    'cells': 'Больше всего клеток одновременно',
    'kills': 'Очки за сущности',
  };
  String by = 'matter';
  TopTable? table;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sync = widget.ctl.sync;
    if (sync == null || !sync.on) return;
    try {
      final t = await sync.api.top(by);
      if (mounted) setState(() => table = t);
    } on ApiError catch (e) {
      if (mounted) setState(() => err = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = widget.ctl.sync;
    if (sync == null || !sync.on) {
      return const Text('Рейтинги появляются, когда работает сервер учётных записей.', style: TextStyle(color: C.muted));
    }
    final t = table;
    String v(double x) => by == 'matter' ? Fmt.n(x) : Fmt.n(x.round());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Рейтинги', style: h2()),
        const SizedBox(height: 6),
        _wrap([
          for (final e in tops.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: by == e.key,
              onSelected: (_) {
                setState(() {
                  by = e.key;
                  table = null;
                });
                _load();
              },
            ),
        ]),
        if (by == 'kills')
          const Text('низшая 1, редкая 3, эпическая 10, легендарная 500', style: TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 8),
        if (err != null) Note(err!, kind: 'bad'),
        if (t == null && err == null) const LinearProgressIndicator(),
        if (t != null) ...[
          for (var i = 0; i < t.list.length; i++)
            Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text('${i + 1}.', style: const TextStyle(color: C.muted)),
                ),
                Expanded(
                  child: Text(t.list[i].login, style: TextStyle(color: t.list[i].login == sync.user?.login ? C.gold : C.ink)),
                ),
                Text(v(t.list[i].value), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          if (t.me != null && !t.list.any((e) => e.login == t.me!.login))
            Text('Вы: ${t.me!.rank}-е место из ${t.total}, ${v(t.me!.value)}', style: const TextStyle(color: C.gold)),
          if (t.list.isEmpty) const Text('Пока никого нет.', style: TextStyle(color: C.muted)),
        ],
        const Note('Показатели обновляются при каждом сохранении на сервере и хранятся как максимум.'),
      ],
    );
  }
}
