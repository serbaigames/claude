// Вкладки меню: клетка, персонаж, способности, артефакты, технологии и прыжок, эры, аккаунт, рейтинги.
// Тексты и подсказки взяты из веб-версии.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/game.dart';
import '../l10n/l10n.dart';
import '../net/api.dart';
import '../net/cloud_sync.dart';
import '../shop/shop.dart';
import 'controller.dart';
import 'icons.dart';
import 'map_art.dart';
import 'portraits.dart';
import 'settings.dart';
import 'theme.dart';
import 'widgets.dart';

enum MenuTab { cell, char, abil, art, tech, era, acc, top, world }

Map<MenuTab, String> get tabTitles => {
  MenuTab.cell: tx('Клетка'),
  MenuTab.char: tx('Параметры искры'),
  MenuTab.abil: tx('Способности'),
  MenuTab.art: tx('Артефакты'),
  MenuTab.tech: tx('Технологии'),
  MenuTab.era: tx('Эры'),
  MenuTab.acc: tx('Настройки'),
  MenuTab.top: tx('Рейтинги'),
  MenuTab.world: tx('Искра и мир'),
};

Widget panelFor(MenuTab t, GameController ctl) => switch (t) {
  MenuTab.cell => CellPanel(ctl),
  MenuTab.char => CharPanel(ctl),
  MenuTab.abil => AbilPanel(ctl),
  MenuTab.art => ArtPanel(ctl),
  MenuTab.tech => TechPanel(ctl),
  MenuTab.era => EraPanel(ctl),
  MenuTab.acc => SettingsPanel(ctl),
  MenuTab.top => TopPanel(ctl),
  MenuTab.world => WorldPanel(ctl.game),
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
    if (c.spark) return _spark(g, ctl);
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
        row('m', tx('Материя'), C.matter, own ? tx('выработка шахт') : tx('материя клетки')),
        row('e', tx('Энергия'), C.energy, own ? tx('сила заводов') : tx('энергия клетки')),
        row('f', tx('Сила'), C.force, own ? tx('прибавка укреплений') : tx('сила клетки')),
      ],
    );
  }

  Widget _overview(Game g) {
    final x = g.incomeParts(), thr = g.threatCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tx('Владения'), style: h2()),
        const SizedBox(height: 6),
        KV([
          (tx('Агрессивность мира'), g.aggrText),
          (tx('Клеток'), '${g.own.length}'),
          (tx('Под угрозой'), '$thr'),
          (tx('Шахты, в секунду'), Fmt.n1(x.mines * g.bonusMul)),
          (tx('Заводы, ко всей добыче'), '+${Fmt.n1(x.fac)}%'),
          (tx('База искры, в секунду'), Fmt.n1(x.base)),
        ]),
        if (thr > 0)
          Note(tx('Клетки с красной рамкой может забрать тьма.'), kind: 'bad')
        else if (g.own.length == 1 && g.s.lostOnce)
          Note(tx('Соседей не одолеть? Совершите прыжок — кнопка в правом верхнем углу.')),
        Note(tx('Нажмите на клетку на карте: золотые — ваши, фиолетовые — тьма.')),
      ],
    );
  }

  Widget _portrait(Widget p) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(height: 150, child: p),
  );

  Widget _spark(Game g, GameController ctl) {
    final x = g.incomeParts(), shop = ctl.shop, left = shop.boostLeft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tx('Искра'), style: h2(C.gold)),
        const SizedBox(height: 8),
        _portrait(PlasmaPortrait.spark(cores: g.s.cores.length, speed: g.sparkSpeed)),
        const SizedBox(height: 8),
        KV([
          (tx('Клетки × бонус'), Fmt.n1(g.sparkMatter)),
          (tx('Ядра искры') + (g.s.cores.isEmpty ? '' : ' (${g.s.cores.length})'), '×${g.coreMul}'),
          (tx('Скорость искры'), '×${Fmt.x(g.sparkSpeed, 2)}'),
          (tx('Добыча базы, в секунду'), Fmt.n1(x.base)),
          (tx('Бонус прыжка'), '×${Fmt.x(g.bonusMul, 2)}'),
        ]),
        Note(tx('Добыча базы = 0,5 × ядро × клетки × бонус × скорость. Искру нельзя потерять.')),
        if (shop.boosted)
          Note(
            tx('Ускорение добычи ×{x}: ещё {t}.', {
              'x': boostMul.toInt(),
              't': '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
            }),
          )
        else if (shop.supporter || shop.ads != null) ...[
          const SizedBox(height: 8),
          ActBtn(
            shop.supporter
                ? tx('Ускорить добычу ×{x}', {'x': boostMul.toInt()})
                : tx('Видео: добыча ×{x}', {'x': boostMul.toInt()}),
            shop.canBoost ? ctl.boost : null,
            key: const ValueKey('spark-boost'),
            right: tx('{n} мин', {'n': boostTime.inMinutes}),
            primary: true,
          ),
        ],
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
                  Text(tx('Ваша клетка'), style: h2(C.gold)),
                  Text(
                    tx('Уровень {lv} (+{p}%) · до {next}-го {t}', {
                      'lv': lv,
                      'p': lv * 10,
                      'next': lv + 1,
                      't': Fmt.clock(nx - c.held),
                    }),
                    style: const TextStyle(color: C.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Bar((c.held - from) / (nx - from), height: 4),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ActBtn(
              tx('Укрепить +{n}', {'n': Fmt.n1(gain)}),
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
              tagLeft: tx('защита {n}', {'n': Fmt.n(def.floor())}),
              tagRight: '${Game.usedCap(c)} / $cap',
              onEmptySlot: full ? null : () => _buildMenu(context, c.key),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _statBars(g, c),
        const SizedBox(height: 8),
        KV([
          (tx('Защита'), tx('{n} · ур. укрепления {l}', {'n': Fmt.n(def.floor()), 'l': c.defLvl})),
          (tx('Сильнейший сосед'), th > 0 ? Fmt.n(th.ceil()) : '—'),
          (tx('Башни'), tx('+{n}% защиты', {'n': Fmt.n(Game.towerPct(Game.bL(c, 'tower')))})),
          (
            tx('Ячейки строений'),
            tx('{u} из {cap} · новая через {t}', {'u': Game.usedCap(c), 'cap': cap, 't': Fmt.clock(Game.nextSlotIn(c))}),
          ),
          (tx('Во владении'), Fmt.clock(c.held)),
        ]),
        if (danger) Note(tx('Сосед почти сравнялся с защитой.'), kind: 'bad'),
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
          title: Text(tx('Построить в ячейке')),
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
                          b.name + (Game.bL(c, b.id) > 0 ? tx(' ({n} ур.)', {'n': Game.bL(c, b.id) + 1}) : ''),
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
      'mine' => tx('+{n}/с', {'n': Fmt.n1(g.mineRate(c, l))}),
      'factory' => '+${Fmt.n1(g.factPct(c, l))}%',
      _ => tx('+{n}% защиты', {'n': Fmt.n(Game.towerPct(l))}),
    };
    final next = switch (b.id) {
      'mine' => tx('+{n} материи/с', {'n': Fmt.n1(g.mineRate(c, l + 1))}),
      'factory' => tx('+{n}% в сумму заводов', {'n': Fmt.n1(g.factPct(c, l + 1))}),
      _ => tx('+{n}% защиты', {'n': Fmt.n(Game.towerPct(l + 1))}),
    };
    final syn = l > 1 && b.id != 'tower' ? tx(' · комплекс +{n}%', {'n': (l - 1) * 10}) : '';
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
                Text(l > 0 ? '$now$syn' : tx('не построено'), style: const TextStyle(color: C.muted, fontSize: 12)),
              ],
            ),
          ),
          Tooltip(
            message: '${l > 0 ? tx('Улучшить') : tx('Построить')}: $next',
            child: ActBtn(
              '+',
              !full && g.s.matter >= cost ? () => ctl.act((g) => g.build(c.key, b.id)) : null,
              right: Fmt.n(cost),
            ),
          ),
          if (l > 0) ...[
            const SizedBox(width: 6),
            _Confirm(label: '−', confirm: tx('Понизить?'), onConfirm: () => ctl.act((g) => g.lower(c.key, b.id))),
          ],
        ],
      ),
    );
  }

  Widget _dark(Game g, Cell c) {
    final t = Defs.tiers[c.tier]!;
    final paused = g.s.paused, rate = g.growRate(c), left = math.max(0, (c.growth - c.t) / rate);
    final grow = KV([
      (tx('Мощь'), Fmt.n(c.might.ceil())),
      (tx('После шага'), '≈${Fmt.n((c.might * (1 + (c.dev - 1) * g.darkF) + 0.2).ceil())}'),
      (tx('До шага'), paused ? tx('пауза') : tx('{n} с', {'n': left.toStringAsFixed(0)})),
      (tx('Уровень клетки'), '${Game.cellLvl(c)} (+${Game.cellLvl(c) * 10}%)'),
    ]);
    if (!c.alive) {
      final cost = c.might.ceil(), lack = g.s.matter < cost;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tx('Свободная клетка'), style: h2()),
          Text(tx('Защитник побеждён. Клетку можно взять за материю, равную мощи.'), style: const TextStyle(color: C.muted)),
          const SizedBox(height: 6),
          _statBars(g, c),
          const SizedBox(height: 6),
          grow,
          const SizedBox(height: 10),
          ActBtn(
            lack ? tx('Нужно ещё {n}', {'n': Fmt.n((cost - g.s.matter).ceil())}) : tx('Захватить'),
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
        if (c.tier == 'epic') Text(tx('очень опасна'), style: const TextStyle(color: C.bad)),
        if (c.tier == 'legend') Text(tx('смертельно опасна, соседи растут ×2'), style: const TextStyle(color: C.bad)),
        const SizedBox(height: 8),
        _portrait(PlasmaPortrait.entity(tier: c.tier)),
        const SizedBox(height: 8),
        KV([
          (tx('Здоровье'), Fmt.n(f.maxHp.round())),
          (tx('Удар по вам'), tx('{n} раз в {cd} с', {'n': Fmt.n(hit.round()), 'cd': Fmt.x(f.cd)})),
          (tx('Награда за победу'), '+${Fmt.n((f.matter * 0.5).floor())}'),
          (tx('Штраф за поражение'), '−${Fmt.n((f.pen * 0.5).floor())}'),
          (tx('Шанс артефакта'), '${Fmt.x(art)}%'),
        ]),
        if (f.traits.isNotEmpty) ...[const SizedBox(height: 6), Text(tx('Способности сущности'), style: h2())],
        for (final tr in f.traits)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.warn.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: C.warn.withValues(alpha: 0.6)),
                  ),
                  child: traitIcon(tr, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${Defs.traits[tr]!.name}\n',
                          style: const TextStyle(color: C.warn, fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: Defs.traits[tr]!.desc,
                          style: const TextStyle(color: C.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        grow,
        const SizedBox(height: 8),
        Note('${lab.label[0].toUpperCase()}${lab.label.substring(1)} · ${g.fcMatter(fc)}', kind: lab.kind),
        const SizedBox(height: 14),
        Center(
          child: SizedBox(
            width: 220,
            height: 52,
            child: FilledButton.icon(
              key: const ValueKey('to-battle'),
              style: FilledButton.styleFrom(
                backgroundColor: C.gold,
                foregroundColor: const Color(0xFF221A08),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => ctl.act((g) => g.startBattle(g.foeFromCell(c), c.key)),
              icon: const Icon(Icons.flash_on, size: 22),
              label: Text(tx('В бой')),
            ),
          ),
        ),
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
        Text(tx('Параметры искры'), style: h2()),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.stars, size: 18, color: C.gold),
            const SizedBox(width: 4),
            Text(tx('{n} ОП', {'n': g.s.op}), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
            _ModeBtn(opMode, (m) => setState(() => opMode = m)),
            const SizedBox(width: 6),
            ActBtn(
              tx('Купить +{n}', {'n': ob.n}),
              ob.n > 0 && g.s.matter >= ob.cost ? () => ctl.act((g) => g.buyOp(opMode)) : null,
              right: Fmt.n(ob.cost),
              primary: true,
            ),
          ],
        ),
        Text(
          tx('Каждое следующее ОП дороже на 1,5%; следующее — {n} материи', {'n': Fmt.n(ob.next)}),
          style: const TextStyle(color: C.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Center(
          child: SizedBox(width: 230, height: 230, child: CustomPaint(painter: _RadarPainter(g))),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(tx('Параметры'), style: const TextStyle(color: C.muted)),
            ),
            _ModeBtn(parMode, (m) => setState(() => parMode = m)),
          ],
        ),
        const SizedBox(height: 6),
        // 3 столбика × 2 строки
        for (var row = 0; row < 2; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < 3; col++) ...[
                  if (col > 0) const SizedBox(width: 6),
                  Expanded(child: _param(g, Defs.params[row * 3 + col])),
                ],
              ],
            ),
          ),
        const SizedBox(height: 4),
        KV([
          (tx('Здоровье в бою'), Fmt.n(g.maxHp().round())),
          (tx('Делитель урона тьмы'), Fmt.x(g.defDiv(), 2)),
          (tx('Сила атаки'), '×${Fmt.x(g.powMul(), 2)}'),
          (tx('Медитация'), '×${Fmt.x(g.med(), 2)}'),
          (tx('Откат хода'), tx('{n} с', {'n': Fmt.x(g.turnCd(), 2)})),
          (tx('Управление'), tx('+{n}% к клеткам', {'n': Fmt.x(g.ctrlPct, 1)})),
        ]),
        Note(
          tx(
            'Перекос: параметр выше среднего по всем шести на 50% теряет 10% силы, на 100% — 25%, на 150% — 50%. '
            'Кольца на диаграмме — границы штрафов.',
          ),
        ),
      ],
    );
  }

  Widget _param(Game g, ParamDef p) {
    final e = g.eff(p.id), x = g.parInfo(p.id, parMode), col = Color(p.color);
    final can = x.n > 0 && g.s.op >= x.cost;
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          decoration: BoxDecoration(
            color: col.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: e.pen > 0 ? C.bad.withValues(alpha: 0.7) : col.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              // справа — место под кнопку справки; длинное название ужимается, а не обрезается
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(paramIcons[p.id], size: 16, color: col),
                      const SizedBox(width: 4),
                      Text(p.name, style: const TextStyle(fontSize: 12, color: C.muted)),
                    ],
                  ),
                ),
              ),
              Text(
                '${g.s.char[p.id]}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: col),
              ),
              SizedBox(
                height: 16,
                child: e.pen > 0
                    ? Text(tx('штраф −{n}%', {'n': (e.pen * 100).round()}), style: const TextStyle(color: C.bad, fontSize: 11))
                    : null,
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: double.infinity,
                height: 30,
                child: FilledButton(
                  onPressed: can ? () => widget.ctl.act((g) => g.parUp(p.id, parMode)) : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    backgroundColor: C.btn,
                    foregroundColor: C.ink,
                    side: BorderSide(color: can ? col.withValues(alpha: 0.5) : C.line),
                  ),
                  child: FittedBox(
                    child: Text(tx('+{n} · {cost} ОП', {'n': x.n, 'cost': Fmt.n(x.cost)}), style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            key: ValueKey('par-info-${p.id}'),
            tooltip: tx('О параметре «{name}»', {'name': p.name}),
            onPressed: () => _help(context, g, p),
            icon: const Icon(Icons.info_outline, size: 16, color: C.muted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 26, height: 26),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  /// Расширенная справка о параметре с текущими числами
  void _help(BuildContext context, Game g, ParamDef p) {
    final e = g.eff(p.id), v = g.s.char[p.id] ?? 1, col = Color(p.color);
    String x2(double v) => Fmt.x(v, 2);
    final (what, now) = switch (p.id) {
      'life' => (
        tx(
          'Запас здоровья искры в бою: 60 единиц и ещё 40 за каждое очко Жизни. Если здоровье кончится, бой проигран '
          'и спишется штраф материей.',
        ),
        tx('Здоровье в бою: {n}', {'n': Fmt.n(g.maxHp().round())}),
      ),
      'defense' => (
        tx(
          'Каждый удар сущности тьмы делится на делитель Защиты: 1 и ещё 0,2 за каждое очко сверх первого. '
          'Покров и ослабление врага снижают урон дополнительно.',
        ),
        tx('Делитель урона: {n}', {'n': x2(g.defDiv())}),
      ),
      'power' => (
        tx(
          'Множитель силы ваших атак и атакующих способностей: +20% за каждое очко сверх первого. '
          'Некоторые эры усиливают или ослабляют его.',
        ),
        tx('Сила атаки: ×{n}', {'n': x2(g.powMul())}),
      ),
      'meditation' => (
        tx(
          'Сколько материи искра вкладывает в каждый ход: 1 и ещё 0,3 за каждое очко сверх первого. '
          'Атака стоит 5 материи × Медитацию и во столько же раз сильнее. Урон и лечение способностей тоже растут от Медитации. Чем она выше, тем дороже бой, но тем он короче.',
        ),
        tx('Медитация ×{m}, атака стоит {c} материи', {'m': x2(g.med()), 'c': math.max(1, (Bal.atkCost * g.med()).ceil())}),
      ),
      'speed' => (
        tx(
          'Как быстро откатывается ход искры: 1,4 с, делённые на 1 + 0,1 за каждое очко сверх первого. '
          'Эры и «Ускорение» меняют откат.',
        ),
        tx('Откат хода: {n} с', {'n': Fmt.x(g.turnCd(), 2)}),
      ),
      _ => (
        tx(
          'Защита всех ваших клеток растёт на 1% за каждое очко Управления сверх первого (проценты складываются '
          'умножением). Сильнее защита — реже тьма отнимает клетки.',
        ),
        tx('Бонус к защите клеток: +{n}%', {'n': Fmt.x(g.ctrlPct, 1)}),
      ),
    };
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        key: ValueKey('par-help-${p.id}'),
        backgroundColor: C.panel,
        title: Row(
          children: [
            Icon(paramIcons[p.id], color: col),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${p.name}: $v', style: TextStyle(color: col)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(what),
              const SizedBox(height: 10),
              Text(now, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                tx(
                  'Перекос: если параметр больше среднего по всем шести (сейчас {avg}) в 1,5 раза, '
                  'его действие слабеет на 10%, в 2 раза — на 25%, в 2,5 раза — на 50%.',
                  {'avg': Fmt.x(g.parAvg, 1)},
                ),
                style: const TextStyle(color: C.muted, fontSize: 13),
              ),
              if (e.pen > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    tx('Сейчас штраф −{p}%: действует как {e} вместо {v}.', {
                      'p': (e.pen * 100).round(),
                      'e': Fmt.x(e.v, 1),
                      'v': v,
                    }),
                    style: const TextStyle(color: C.bad, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(tx('Понятно')))],
      ),
    );
  }
}

/// Круговая диаграмма параметров: самый большой параметр — край диаграммы,
/// кольца — границы штрафов за перекос (видны, когда штраф появился)
class _RadarPainter extends CustomPainter {
  _RadarPainter(this.g);
  final Game g;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.shortestSide / 2 - 26;
    final ps = Defs.params, n = ps.length;
    final vals = [for (final p in ps) (g.s.char[p.id] ?? 1).toDouble()];
    final mx = vals.reduce(math.max), avg = g.parAvg;
    Offset at(int i, double k) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      return c + Offset(math.cos(a), math.sin(a)) * r * k;
    }

    final grid = Paint()
      ..color = C.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final k in [0.25, 0.5, 0.75, 1.0]) {
      canvas.drawPath(Path()..addPolygon([for (var i = 0; i < n; i++) at(i, k)], true), grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(c, at(i, 1), grid);
    }
    // кольца штрафов: только когда хоть один параметр получил штраф
    final anyPen = vals.any((v) => Game.penFor(v, avg) > 0);
    if (anyPen) {
      for (final (k, p) in Game.penSteps) {
        final rr = k * avg / mx;
        if (rr > 1.0001) continue;
        final hit = vals.any((v) => v > k * avg);
        canvas.drawCircle(
          c,
          r * rr,
          Paint()
            ..color = C.bad.withValues(alpha: hit ? 0.75 : 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '−${(p * 100).round()}%',
            style: TextStyle(color: C.bad.withValues(alpha: 0.9), fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, c + Offset(r * rr * 0.5, r * rr * 0.866) + const Offset(3, -2));
      }
    }
    final poly = [for (var i = 0; i < n; i++) at(i, vals[i] / mx)];
    canvas.drawPath(Path()..addPolygon(poly, true), Paint()..color = C.gold.withValues(alpha: 0.22));
    canvas.drawPath(
      Path()..addPolygon(poly, true),
      Paint()
        ..color = C.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < n; i++) {
      final col = Color(ps[i].color);
      canvas.drawCircle(poly[i], 4, Paint()..color = col);
      final tp = TextPainter(
        text: TextSpan(
          text: '${ps[i].name}\n${vals[i].toInt()}',
          style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w700, height: 1.1),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final p = at(i, 1.0) + (at(i, 1.0) - c) / r * 16;
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => true;
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
        Text(tx('Способности'), style: h2()),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: C.violet),
            const SizedBox(width: 4),
            Text(tx('{n} ОС', {'n': g.s.os}), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
            _ModeBtn(osMode, (m) => setState(() => osMode = m)),
            const SizedBox(width: 6),
            ActBtn(
              tx('Купить +{n}', {'n': ob.n}),
              ob.n > 0 && g.s.matter >= ob.cost ? () => ctl.act((g) => g.buyOs(osMode)) : null,
              right: Fmt.n(ob.cost),
              primary: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(tx('Ячейки'), style: const TextStyle(color: C.muted)),
            ),
            _ModeBtn(abMode, (m) => setState(() => abMode = m)),
          ],
        ),
        for (var i = 0; i < g.s.abilities.length; i++) _slot(g, i),
        Note(
          tx(
            'Новые способности выпадают после побед над сущностями того же ранга. Уровень стоит ОС: низшая 1, редкая 3, эпическая 10 за уровень.',
          ),
        ),
      ],
    );
  }

  Widget _slot(Game g, int i) {
    final a = g.s.abilities[i];
    if (a == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.line),
              ),
              child: const Icon(Icons.add, size: 18, color: C.line),
            ),
            const SizedBox(width: 10),
            Text(tx('Ячейка {n} пуста', {'n': i + 1}), style: const TextStyle(color: C.muted)),
          ],
        ),
      );
    }
    final d = Defs.abilities[a.id]!, x = g.abInfo(i, abMode);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(Defs.tierColor[d.tier]!).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Color(Defs.tierColor[d.tier]!).withValues(alpha: 0.7)),
            ),
            child: Center(child: abilityIcon(a.id, size: 24)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx('{name}, ур. {l}', {'name': d.name, 'l': a.lvl}), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${g.abDesc(a)} · ${tx('{n} материи · откат {cd} с', {'n': Fmt.n(Game.abCost(a)), 'cd': Fmt.x(d.cd)})}',
                  style: const TextStyle(color: C.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          ActBtn(
            '+${x.n}',
            x.n > 0 && g.s.os >= x.cost ? () => widget.ctl.act((g) => g.abUp(i, abMode)) : null,
            right: tx('{n} ОС', {'n': Fmt.n(x.cost)}),
          ),
          const SizedBox(width: 6),
          _Confirm(label: '×', confirm: tx('Удалить?'), onConfirm: () => widget.ctl.act((g) => g.abDelete(i))),
        ],
      ),
    );
  }
}

/* ---------- артефакты ---------- */
class ArtPanel extends StatelessWidget {
  const ArtPanel(this.ctl, {super.key});
  final GameController ctl;

  static const perRow = 5;

  @override
  Widget build(BuildContext context) {
    final g = ctl.game, n = g.s.artifacts.length;
    // ряд пустых ячеек; заполнился ряд — появляется следующий
    final slots = (n ~/ perRow + 1) * perRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tx('Артефакты'), style: h2()),
        const SizedBox(height: 4),
        Text(
          n == 0 ? tx('Пока пусто. Артефакты выпадают после побед.') : tx('Нажмите на артефакт, чтобы применить его.'),
          style: const TextStyle(color: C.muted),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, box) {
            const gap = 8.0;
            final w = (box.maxWidth - gap * (perRow - 1)) / perRow;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (var i = 0; i < slots; i++) SizedBox(width: w, height: w, child: _slot(context, g, i))],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(tx('Виды'), style: const TextStyle(color: C.muted)),
        const SizedBox(height: 4),
        for (final a in Defs.arts.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                artIcon(a.id, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${a.name} — ${a.short}', style: TextStyle(color: Color(a.color), fontSize: 13)),
                ),
              ],
            ),
          ),
        Note(tx('Шанс артефакта за победу: 4% / 12% / 25% / 100% по рангу сущности, умноженный на агрессивность мира и эру.')),
      ],
    );
  }

  Widget _slot(BuildContext context, Game g, int i) {
    if (i >= g.s.artifacts.length) {
      return Container(
        decoration: BoxDecoration(
          color: C.bg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.line),
        ),
      );
    }
    final a = g.s.artifacts[i], d = Defs.arts[a.type]!, col = Color(d.color);
    return Tooltip(
      message: '${g.artTitle(a)}: ${g.artDesc(a)}',
      child: InkWell(
        key: ValueKey('art-$i'),
        onTap: () => _use(context, g, i),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: col.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: col.withValues(alpha: 0.75)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              artIcon(a.type, size: 24),
              const SizedBox(height: 2),
              FittedBox(child: Text(g.artBadge(a), style: const TextStyle(fontSize: 11))),
            ],
          ),
        ),
      ),
    );
  }

  /// Артефакт на клетку — выбор клетки на карте; остальные — окно с описанием и подтверждением
  void _use(BuildContext context, Game g, int i) {
    final a = g.s.artifacts[i], d = Defs.arts[a.type]!;
    if (d.target != 'player') {
      ctl.startArtPick(i);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.panel,
        title: Row(
          children: [
            artIcon(a.type, size: 26),
            const SizedBox(width: 8),
            Expanded(child: Text(g.artTitle(a), style: h2())),
          ],
        ),
        content: Text(g.artDesc(a)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('Отмена'))),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ctl.act((g) => g.applyArt(i));
            },
            style: FilledButton.styleFrom(backgroundColor: C.goldBg, foregroundColor: C.gold),
            child: Text(tx('Применить')),
          ),
        ],
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

class TechPanel extends StatefulWidget {
  const TechPanel(this.ctl, {super.key});
  final GameController ctl;
  @override
  State<TechPanel> createState() => _TechPanelState();
}

class _TechPanelState extends State<TechPanel> {
  // все узлы дерева одного размера; дерево двигается пальцем и масштабируется
  static const nodeW = 124.0, nodeH = 140.0, gapX = 14.0, gapY = 44.0;
  static const treeW = 6 * nodeW + 5 * gapX, treeH = 3 * nodeH + 2 * gapY;
  final view = TransformationController();
  double? _fitFor;

  GameController get ctl => widget.ctl;

  @override
  void dispose() {
    view.dispose();
    super.dispose();
  }

  /// Вписать дерево по ширине окна
  /// Вписать дерево; при открытии — не мельче 75%, чтобы подписи читались (остальное — перетаскиванием)
  void _fit(double w, {bool all = false}) {
    final k = all ? math.min(1.0, w / treeW) : math.max(math.min(1.0, w / treeW), 0.75);
    view.value = Matrix4.identity()
      ..translateByDouble((w - treeW * k) / 2, 8, 0, 1)
      ..scaleByDouble(k, k, 1, 1);
    _fitFor = w;
  }

  void _zoom(double f, double w) {
    final m = view.value.clone(), c = Offset(w / 2, 180);
    final k = (m.getMaxScaleOnAxis() * f).clamp(0.3, 2.0) / m.getMaxScaleOnAxis();
    view.value = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1)
      ..multiply(m);
  }

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
            Text(tx('Технологии'), style: h2()),
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
        Text(
          tx(
            'Пульсары изредка выпадают после побед над сущностями. Технология открывается, когда изучен '
            'хотя бы 1-й ранг предыдущей. Технологии и их ранги сохраняются при прыжке.',
          ),
          style: const TextStyle(color: C.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            if (_fitFor != w) _fit(w);
            // центры узлов на холсте дерева
            double x3(int j) => j * (nodeW + gapX) + nodeW / 2;
            double x2(int i) => (x3(2 * i) + x3(2 * i + 1)) / 2;
            const y1 = 0.0, y2 = nodeH + gapY, y3 = 2 * (nodeH + gapY);
            Widget at(double cx, double y, TechDef t) =>
                Positioned(left: cx - nodeW / 2, top: y, width: nodeW, height: nodeH, child: _node(context, g, t));
            return Container(
              height: 400,
              decoration: BoxDecoration(
                color: C.bg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    InteractiveViewer(
                      key: const ValueKey('tech-tree'),
                      transformationController: view,
                      constrained: false,
                      minScale: 0.3,
                      maxScale: 2,
                      boundaryMargin: const EdgeInsets.all(200),
                      child: SizedBox(
                        width: treeW,
                        height: treeH + 16,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _TreeLinks([
                                  for (var i = 0; i < l2.length; i++)
                                    (Offset(treeW / 2, y1 + nodeH), Offset(x2(i), y2), g.techOpen(l2[i])),
                                  for (var j = 0; j < l3.length; j++)
                                    (Offset(x2(j ~/ 2), y2 + nodeH), Offset(x3(j), y3), g.techOpen(l3[j])),
                                ]),
                              ),
                            ),
                            at(treeW / 2, y1, l1.first),
                            for (var i = 0; i < l2.length; i++) at(x2(i), y2, l2[i]),
                            for (var j = 0; j < l3.length; j++) at(x3(j), y3, l3[j]),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Column(
                        children: [
                          for (final (ic, f, tip) in [
                            (Icons.add, () => _zoom(1.25, w), tx('Крупнее')),
                            (Icons.remove, () => _zoom(0.8, w), tx('Мельче')),
                            (Icons.fit_screen, () => _fit(w, all: true), tx('Вписать')),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton.filledTonal(
                                  tooltip: tip,
                                  padding: EdgeInsets.zero,
                                  iconSize: 18,
                                  onPressed: f,
                                  icon: Icon(ic),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(tx('Дерево можно двигать пальцем и масштабировать.'), style: const TextStyle(color: C.muted, fontSize: 11)),
        const SizedBox(height: 14),
        Text(tx('Прыжок искры'), style: h2()),
        const SizedBox(height: 4),
        Text(g.worldTrend().info, style: const TextStyle(color: C.muted, fontSize: 13)),
        const SizedBox(height: 4),
        // сам прыжок — только кнопкой в правом верхнем углу главного экрана
        Text(
          g.hasTech('jump')
              ? tx('Прыжок даст +{n} к бонусу. Совершить его — кнопкой в правом верхнем углу экрана.', {
                  'n': Fmt.x(g.rebirthGain(), 2),
                })
              : tx('Изучите «Прыжок», чтобы открыть кнопку прыжка в правом верхнем углу экрана.'),
          style: const TextStyle(color: C.gold, fontSize: 13),
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
                  tooltip: tx('О технологии «{name}»', {'name': t.name}),
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
          const Spacer(),
          if (t.soon)
            Text(tx('скоро'), style: const TextStyle(color: C.muted, fontSize: 12))
          else if (cost == null)
            Text(t.ranks > 1 ? tx('все ранги') : tx('изучено'), style: const TextStyle(color: C.ok, fontSize: 12))
          else if (!open)
            Text(tx('закрыто'), style: const TextStyle(color: C.muted, fontSize: 12))
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(r == 0 ? tx('Изучить') : tx('Ранг {n}', {'n': r + 1}), style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text('$cost', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      const Icon(pulsarIcon, size: 13),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

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
                    tx('Ранг {n}: {what} ×{x} · {c} пульсаров', {
                      'n': i + 1,
                      'what': t.what,
                      'x': Fmt.x(1 + t.per * (i + 1), 2),
                      'c': t.rankCost(i),
                      'w': plural(t.rankCost(i), 'пульсар', 'пульсара', 'пульсаров', en1: 'pulsar', enMany: 'pulsars'),
                    }),
                    style: TextStyle(color: i < r ? C.ok : C.muted, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                r == 0
                    ? tx('Пока не изучена.')
                    : tx('Сейчас: ранг {r} из {n}, {what} ×{x}.', {
                        'r': r,
                        'n': t.ranks,
                        'what': t.what,
                        'x': Fmt.x(g.techMul(t.id), 2),
                      }),
                style: const TextStyle(color: C.gold),
              ),
            ] else if (!t.soon) ...[
              const SizedBox(height: 8),
              Text(
                r > 0
                    ? tx('Изучено.')
                    : tx('Стоит {n} пульсар.', {
                        'n': t.cost,
                        'w': plural(t.cost, 'пульсар', 'пульсара', 'пульсаров', en1: 'pulsar', enMany: 'pulsars'),
                      }),
                style: const TextStyle(color: C.gold),
              ),
            ],
            if (need.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                tx('Нужна технология: {need} (хотя бы 1-й ранг).', {'need': need}),
                style: const TextStyle(color: C.muted, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('Понятно')))],
      ),
    );
  }
}

/// Линии дерева: от нижнего края родителя к верхнему краю ребёнка; золотые — путь открыт
class _TreeLinks extends CustomPainter {
  _TreeLinks(this.links);
  final List<(Offset, Offset, bool)> links;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (a, b, lit) in links) {
      final mid = (a.dy + b.dy) / 2;
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(a.dx, mid)
          ..lineTo(b.dx, mid)
          ..lineTo(b.dx, b.dy),
        Paint()
          ..color = lit ? C.gold.withValues(alpha: 0.85) : C.line
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_TreeLinks old) => true;
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
        Text(
          '${e.desc} · ${tx('осталось {t} из {n} мин', {'t': '${l ~/ 60}:${(l % 60).toString().padLeft(2, '0')}', 'n': (g.s.era!.dur / 60).round()})}',
        ),
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
                          TextSpan(
                            text: tx(' · сейчас'),
                            style: const TextStyle(color: C.gold),
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
        Note(
          tx(
            'Эра длится от 1 до 10 минут игрового времени (на паузе не идёт). Зелёные помогают вам, красные — тьме, жёлтые — смешанные.',
          ),
        ),
      ],
    );
  }
}

/* ---------- аккаунт (вкладка окна «Настройки») ---------- */
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

  /// Подтверждение сброса: перечисляем всё, что пропадёт
  Future<void> _askReset(BuildContext context) async {
    final sync = widget.ctl.sync, login = sync != null && sync.on ? sync.user?.login : null;
    final lost = [
      tx('все клетки, материя и укрепления'),
      tx('параметры искры, ОП и ОС'),
      tx('способности и сборки'),
      tx('артефакты'),
      tx('технологии, пульсары, бонус прыжка и прыжки'),
      tx('статистика и рекорды'),
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const ValueKey('reset-dialog'),
        backgroundColor: C.panel,
        title: Text(tx('Начать заново?')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              login != null
                  ? tx('Будет стёрт весь прогресс учётной записи «{login}»:', {'login': login})
                  : tx('Будет стёрт весь прогресс на этом устройстве:'),
            ),
            const SizedBox(height: 6),
            for (final t in lost)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(Icons.close, size: 14, color: C.bad),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(t)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              login != null
                  ? tx('Новое начало сразу сохранится на сервере вместо прежнего. Отменить это нельзя.')
                  : tx('Отменить это нельзя.'),
              style: const TextStyle(color: C.bad),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx('Отмена'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.bad),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tx('Стереть всё')),
          ),
        ],
      ),
    );
    if (ok == true) widget.ctl.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    final sync = widget.ctl.sync;
    final List<Widget> acc;
    if (sync == null || !sync.on) {
      acc = [
        Text(
          tx('Сервер учётных записей недоступен: прогресс хранится только на этом устройстве.'),
          style: const TextStyle(color: C.muted),
        ),
      ];
    } else if (sync.user == null) {
      acc = [
        Row(
          children: [
            ChoiceChip(label: Text(tx('Вход')), selected: mode == 'login', onSelected: (_) => setState(() => mode = 'login')),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(tx('Регистрация')),
              selected: mode == 'register',
              onSelected: (_) => setState(() => mode = 'register'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: login,
          decoration: InputDecoration(labelText: tx('Имя')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: pass,
          obscureText: true,
          decoration: InputDecoration(labelText: tx('Пароль')),
        ),
        if (mode == 'register')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tx('Почта не нужна, поэтому забытый пароль восстановить нельзя.'),
              style: const TextStyle(color: C.warn, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        ActBtn(
          mode == 'login' ? tx('Войти') : tx('Создать'),
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
          ActBtn(tx('Сохранить'), sync.busy ? null : () => sync.cloudSave(manual: true), primary: true),
          ActBtn(tx('Выйти'), busy ? null : () => _run(sync.logout)),
          ActBtn(tx('Сменить пароль'), () => setState(() => mode = 'password')),
          ActBtn(tx('Удалить учётную запись'), () => setState(() => mode = 'delete'), danger: true),
        ]),
        if (mode == 'password') ...[
          const SizedBox(height: 8),
          TextField(
            controller: pass,
            obscureText: true,
            decoration: InputDecoration(labelText: tx('Текущий пароль')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: pass2,
            obscureText: true,
            decoration: InputDecoration(labelText: tx('Новый пароль')),
          ),
          const SizedBox(height: 8),
          ActBtn(
            tx('Сменить (остальные устройства выйдут)'),
            busy ? null : () => _run(() => sync.api.changePassword(pass.text, pass2.text)),
          ),
        ],
        if (mode == 'delete') ...[
          const SizedBox(height: 8),
          TextField(
            controller: pass,
            obscureText: true,
            decoration: InputDecoration(labelText: tx('Пароль для подтверждения')),
          ),
          const SizedBox(height: 8),
          ActBtn(tx('Удалить навсегда'), busy ? null : () => _run(() => sync.deleteAccount(pass.text)), danger: true),
        ],
      ];
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tx('Учётная запись'), style: h2()),
        const SizedBox(height: 6),
        ...acc,
        if (err != null) Note(err!, kind: 'bad'),
        const SizedBox(height: 14),
        ActBtn(tx('Начать заново'), () => _askReset(context), danger: true),
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
  static Map<String, String> get tops => {
    'matter': tx('Материя за всё время'),
    'cells': tx('Больше всего клеток одновременно'),
    'kills': tx('Очки за сущности'),
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
      return Text(tx('Рейтинги появляются, когда работает сервер учётных записей.'), style: const TextStyle(color: C.muted));
    }
    final t = table;
    String v(double x) => by == 'matter' ? Fmt.n(x) : Fmt.n(x.round());
    Widget row(int place, String login, double value, {bool me = false}) => Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: me ? C.goldBg : (place.isOdd ? C.bg.withValues(alpha: 0.35) : null),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: place >= 1 && place <= 3
                ? Icon(Icons.emoji_events, size: 18, color: [C.gold, const Color(0xFFC9D1E0), const Color(0xFFD08A4E)][place - 1])
                : Text('$place', style: const TextStyle(color: C.muted)),
          ),
          Expanded(
            child: Text(
              login,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: me ? C.gold : C.ink, fontWeight: me ? FontWeight.w700 : null),
            ),
          ),
          Text(v(value), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Рейтинги'), style: h2()),
        const SizedBox(height: 8),
        // три вкладки сверху переключают таблицу ниже
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'matter', icon: const Icon(Icons.blur_on, size: 16), label: Text(tx('Материя'))),
            ButtonSegment(value: 'cells', icon: const Icon(Icons.hexagon_outlined, size: 16), label: Text(tx('Клетки'))),
            ButtonSegment(value: 'kills', icon: const Icon(Icons.gps_fixed, size: 16), label: Text(tx('Сущности'))),
          ],
          selected: {by},
          onSelectionChanged: (x) {
            setState(() {
              by = x.first;
              table = null;
              err = null;
            });
            _load();
          },
        ),
        const SizedBox(height: 6),
        Text(
          tops[by]! + (by == 'kills' ? tx(' (низшая 1, редкая 3, эпическая 10, легендарная 500)') : ''),
          style: const TextStyle(color: C.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (err != null) Note(err!, kind: 'bad'),
        if (t == null && err == null) const LinearProgressIndicator(),
        if (t != null) ...[
          // видно 10 мест, дальше список прокручивается до 100-го
          Container(
            height: 10 * 36 + 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.line),
            ),
            padding: const EdgeInsets.all(4),
            child: t.list.isEmpty
                ? Center(
                    child: Text(tx('Пока никого нет.'), style: const TextStyle(color: C.muted)),
                  )
                : ListView.builder(
                    key: const ValueKey('top-list'),
                    itemCount: t.list.length,
                    itemExtent: 36,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: row(i + 1, t.list[i].login, t.list[i].value, me: t.list[i].login == sync.user?.login),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(tx('Ваше место'), style: const TextStyle(color: C.muted, fontSize: 12)),
          const SizedBox(height: 4),
          if (sync.user == null)
            Text(tx('Войдите в учётную запись, чтобы попасть в рейтинг.'), style: const TextStyle(color: C.muted))
          else if (t.me == null)
            Text(
              tx('{login}: пока нет результата в этом рейтинге.', {'login': sync.user!.login}),
              style: const TextStyle(color: C.muted),
            )
          else
            row(t.me!.rank ?? 0, tx('{login} · из {n}', {'login': t.me!.login, 'n': t.total}), t.me!.value, me: true),
        ],
        Note(tx('Показатели обновляются при каждом сохранении на сервере и хранятся как максимум.')),
      ],
    );
  }
}
