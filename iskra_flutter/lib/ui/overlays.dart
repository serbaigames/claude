// Окна поверх карты: бой, «Клетка под ударом!», прыжок искры, выбор сохранения, вступление.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/game.dart';
import '../net/cloud_sync.dart';
import 'battle_scene.dart';
import 'controller.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';

/* ---------- бой ---------- */
class BattleOverlay extends StatelessWidget {
  const BattleOverlay(this.ctl, {super.key});
  final GameController ctl;

  @override
  Widget build(BuildContext context) {
    return Overlay2(
      maxWidth: 560,
      child: ValueListenableBuilder<int>(
        valueListenable: ctl.frameTick,
        builder: (context, _, _) {
          final g = ctl.game, b = g.b;
          if (b == null) return const SizedBox.shrink();
          final f = b.foe, t = Defs.tiers[f.tier]!;
          final full = g.turnCd() * (b.haste > 0 ? 0.5 : 1);
          // продолжительные эффекты: (значок, подпись, осталось секунд, полезный ли)
          final fx = <(Widget, String, double, bool)>[
            if (b.shield > 0) (abilityIcon('veil', size: 16), 'Покров: урон по вам −50%', b.shield, true),
            if (b.immune > 0) (abilityIcon('dark_shield', size: 16), 'Неуязвимость', b.immune, true),
            if (b.haste > 0) (abilityIcon('haste', size: 16), 'Ускорение ходов', b.haste, true),
            if (b.mend > 0) (abilityIcon('mend', size: 16), 'Восстановление здоровья', b.mend, true),
            if (b.refl > 0) (abilityIcon('mirror', size: 16), 'Зеркало: удары отражаются', b.refl, true),
            if (b.weak > 0) (abilityIcon('wither', size: 16), 'Враг ослаблен', b.weak, true),
            if (b.dot > 0) (abilityIcon('ember', size: 16), 'Враг горит', b.dot, true),
            if (b.dispel > 0) (abilityIcon('dispel', size: 16), 'Особенности врага отключены', b.dispel, true),
            if (b.started && !b.over && g.wardOn())
              (traitIcon('ward', size: 16), 'Щит врага: урон по нему не проходит', 10 - f.wt % 10, false),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(child: Text(f.name, style: h2())),
                  const SizedBox(width: 8),
                  tierChip(f.tier, t.name),
                  if (f.dist > 1) Text('  ×${f.dist}', style: const TextStyle(color: C.muted)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (context, box) => SizedBox(
                    height: math.min(box.maxWidth * 9 / 16, 230),
                    child: Stack(
                      children: [
                        Positioned.fill(child: BattleScene(b)),
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 6,
                          child: Wrap(
                            key: const ValueKey('battle-fx'),
                            spacing: 4,
                            runSpacing: 4,
                            children: [for (final e in fx) _fxChip(e.$1, e.$2, e.$3, e.$4)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Враг', style: TextStyle(color: C.muted, fontSize: 12)),
              Bar(
                f.hp / f.maxHp,
                color: Color(Defs.tierColor[f.tier]!),
                height: 14,
                label: '${math.max(0, f.hp.ceil())} / ${f.maxHp.round()}',
              ),
              const SizedBox(height: 4),
              Bar(f.t / f.cd, color: C.bad.withValues(alpha: 0.6), height: 4),
              if (f.traits.isNotEmpty) const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 2,
                children: [
                  for (final k in f.traits)
                    Tooltip(
                      message: Defs.traits[k]!.desc,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          traitIcon(k, size: 14, off: b.dispel > 0),
                          const SizedBox(width: 3),
                          Text(Defs.traits[k]!.name, style: TextStyle(fontSize: 12, color: b.dispel > 0 ? C.muted : C.warn)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Искра', style: TextStyle(color: C.muted, fontSize: 12)),
              Bar(b.hp / b.maxHp, color: C.ok, height: 14, label: '${math.max(0, b.hp.ceil())} / ${b.maxHp.round()}'),
              const SizedBox(height: 4),
              Bar(b.cd > 0 ? (full - b.cd) / full : 1, color: C.gold, height: 4),
              const SizedBox(height: 6),
              Text('Свободная материя: ${Fmt.n(g.s.matter)}', style: const TextStyle(color: C.gold)),
              const SizedBox(height: 6),
              Text(b.status, style: TextStyle(color: b.over ? (b.won ? C.ok : C.bad) : C.ink)),
              const SizedBox(height: 8),
              if (!b.started && !b.over) ...[
                _forecast(g, b),
                const SizedBox(height: 8),
                ActBtn('Начать бой', () => ctl.act((g) => g.battleStart()), primary: true),
              ],
              if (b.choice != null) _choice(g, b) else if (b.started && !b.over) _abilities(g, b),
              const SizedBox(height: 8),
              ActBtn(b.over ? 'Закрыть' : 'Отступить', () => ctl.act((g) => g.closeBattle()), danger: !b.over && b.started),
              if (!b.started && !b.over)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'До начала боя отступить можно без штрафа',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: C.muted, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView(
                  children: [for (final l in b.log.take(30)) Text(l, style: const TextStyle(fontSize: 12, color: C.muted))],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Значок эффекта с таймером: зелёный — полезный, красный — вредный
  Widget _fxChip(Widget icon, String tip, double left, bool good) {
    final col = good ? C.ok : C.bad;
    return Tooltip(
      message: tip,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 2, 6, 2),
        decoration: BoxDecoration(
          color: const Color(0xC0100C1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: col.withValues(alpha: 0.8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 3),
            Text(
              math.max(0.1, left).toStringAsFixed(1),
              style: TextStyle(
                color: col,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _forecast(Game g, Battle b) {
    final c = g.cell(b.cell);
    if (c == null) return const SizedBox.shrink();
    final fc = g.fightForecast(c), lab = GameForecast.forecastLabel(fc.p);
    return Note('${lab.label} · ${g.fcMatter(fc)}', kind: lab.kind);
  }

  Widget _abilities(Game g, Battle b) => Row(
    children: [
      for (var i = 0; i < g.s.abilities.length; i++)
        Expanded(
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _abilityTile(g, b, i)),
        ),
    ],
  );

  Widget _abilityTile(Game g, Battle b, int i) {
    final a = g.s.abilities[i];
    if (a == null) {
      return Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.line),
        ),
        child: const Text('пусто', style: TextStyle(color: C.muted, fontSize: 12)),
      );
    }
    final d = Defs.abilities[a.id]!, info = g.actInfo('ab$i')!, col = Color(Defs.tierColor[d.tier]!);
    final can = info.ready && g.s.matter >= info.cost;
    final left = b.abCd[i];
    return Tooltip(
      message: '${d.name}: ${g.abDesc(a)}; откат ${Fmt.x(d.cd)} с',
      child: InkWell(
        onTap: can ? () => ctl.act((g) => g.doAction('ab$i')) : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: col.withValues(alpha: can ? 0.16 : 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: col.withValues(alpha: can ? 0.8 : 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    abilityIcon(a.id, size: 22, dim: left > 0),
                    if (left > 0)
                      Text(
                        Fmt.x(left),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                        ),
                      ),
                  ],
                ),
              ),
              Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
              Text('${info.cost.toInt()} мат.', style: const TextStyle(fontSize: 10, color: C.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choice(Game g, Battle b) {
    final ch = b.choice!, d = Defs.abilities[ch.id]!, os = Defs.tiers[ch.tier]!.os;
    if (ch.dup) {
      final a = g.s.abilities.firstWhere((x) => x?.id == ch.id)!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('«${d.name}» уже есть. Можно повысить её уровень бесплатно или взять очки способностей.'),
          const SizedBox(height: 6),
          ActBtn('Повысить до ур. ${a.lvl + 1}', () => ctl.act((g) => g.resolveChoice('up')), primary: true),
          const SizedBox(height: 6),
          ActBtn('Взять очки способностей', () => ctl.act((g) => g.resolveChoice('skip')), right: '+$os ОС'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${d.name} — ${g.abDesc(AbilitySlot(ch.id))}. Все ячейки заняты: выберите, какую способность заменить.'),
        for (var i = 0; i < g.s.abilities.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ActBtn(
              'Заменить «${Defs.abilities[g.s.abilities[i]!.id]!.name}», ур. ${g.s.abilities[i]!.lvl}',
              () => ctl.act((g) => g.resolveChoice('$i')),
              right: 'вернётся ${g.s.abilities[i]!.inv ~/ 2} ОС',
            ),
          ),
        const SizedBox(height: 6),
        ActBtn('Не брать', () => ctl.act((g) => g.resolveChoice('skip')), right: '+$os ОС'),
      ],
    );
  }
}

/* ---------- клетка под ударом ---------- */
class DefendOverlay extends StatelessWidget {
  const DefendOverlay(this.ctl, {super.key});
  final GameController ctl;

  @override
  Widget build(BuildContext context) {
    final g = ctl.game;
    if (!g.defendValid()) return const SizedBox.shrink();
    final d = g.def!, n = g.cell(d.own)!, c = g.cell(d.att)!, t = Defs.tiers[c.tier]!;
    final fc = g.fightForecast(c), lab = GameForecast.forecastLabel(fc.p);
    return Overlay2(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Клетка под ударом!', style: h2(C.bad)),
          const SizedBox(height: 8),
          Text(
            '${t.foe} (${t.name.toLowerCase()}) мощью ${Fmt.n(c.might.ceil())} прорывает защиту вашей клетки '
            '(${Fmt.n(g.cellDef(n).floor())}). Игра на паузе.',
          ),
          const SizedBox(height: 6),
          const Text(
            'Защитите клетку в бою — при победе сущность будет побеждена. Если отступить или проиграть, клетка перейдёт к тьме.',
            style: TextStyle(color: C.muted),
          ),
          Note('${lab.label} · ${g.fcMatter(fc)}', kind: lab.kind),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: ActBtn('Бежать', () => ctl.act((g) => g.defendFlee()), danger: true)),
              const SizedBox(width: 8),
              Expanded(child: ActBtn('Защитить', () => ctl.act((g) => g.defendFight()), primary: true)),
            ],
          ),
        ],
      ),
    );
  }
}

/* ---------- прыжок искры ---------- */
class JumpOverlay extends StatelessWidget {
  const JumpOverlay(this.ctl, {super.key});
  final GameController ctl;

  @override
  Widget build(BuildContext context) {
    final g = ctl.game, defeat = ctl.jumpDefeat;
    final gain = g.rebirthGain(), b0 = g.bonusMul, b1 = b0 + gain;
    double inc(double x) => math.pow(x, Bal.bonusPow).toDouble();
    String x2(double v) => Fmt.x(v, 2);
    return Overlay2(
      onClose: ctl.closeJump,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(defeat ? 'Искра угасает — прыжок неизбежен' : 'Прыжок искры', style: h2(defeat ? C.bad : C.gold)),
          if (defeat)
            const Text(
              'Материя ушла в минус: в этой области вселенной искре больше не на что опереться.',
              style: TextStyle(color: C.bad),
            ),
          const SizedBox(height: 6),
          const Text(
            'Искра прыгает в новую область вселенной, сжигая все накопленные ресурсы на своё развитие. '
            'Рост начнётся сначала, но уже с бонусами от текущего воплощения.',
          ),
          const SizedBox(height: 10),
          Text('Итоги этого мира', style: h2()),
          KV([
            ('Время в мире', Fmt.time(g.s.worldTime)),
            ('Рекорд клеток', '${g.s.worldMax}'),
            ('Клеток сейчас', '${g.own.length}'),
            ('Побеждено сущностей', '${g.s.wk}'),
            ('Добыто материи', Fmt.n(g.s.we)),
            ('Агрессивность', '×${x2(g.aggr)}'),
          ]),
          const SizedBox(height: 10),
          Text('Что даст прыжок', style: h2()),
          _change('Бонус искры', '×${x2(b0)}', '×${x2(b1)}'),
          _change('Добыча от бонуса', '×${x2(inc(b0))}', '×${x2(inc(b1))}'),
          _change('Цена ОП и ОС', '÷${x2(math.sqrt(b0))}', '÷${x2(math.sqrt(b1))}'),
          _change('Рост тьмы', '÷${x2(math.sqrt(b0))}', '÷${x2(math.sqrt(b1))}'),
          _change('Скорость искры', '×${x2(g.sparkSpeed)}', '×${x2(1 + 0.15 * (g.s.rebirths + 1))}'),
          _change('Новая область', null, '×${x2(g.s.nextAggr ?? 1)} — ${Game.aggrName(g.s.nextAggr ?? 1)}'),
          const SizedBox(height: 8),
          const Text(
            'Сгорит: клетки, материя, параметры персонажа, ОП, ОС и навыки (кроме Искрового удара). '
            'Останется: бонус искры, ядра, артефакты, рекорды и учётная запись.',
            style: TextStyle(color: C.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!defeat) ...[Expanded(child: ActBtn('Остаться', ctl.closeJump)), const SizedBox(width: 8)],
              Expanded(child: ActBtn('Прыгнуть', ctl.doJump, primary: true)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Строка «было → станет»: новое значение, которое изменится при прыжке, — зелёным
Widget _change(String k, String? from, String to) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2),
  child: Row(
    children: [
      Expanded(
        child: Text(k, style: const TextStyle(color: C.muted)),
      ),
      if (from != null) ...[
        Text(from, style: const TextStyle(fontWeight: FontWeight.w700)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.arrow_forward, size: 14, color: C.muted),
        ),
      ],
      Text(
        to,
        style: const TextStyle(fontWeight: FontWeight.w700, color: C.ok),
      ),
    ],
  ),
);

/* ---------- выбор сохранения при конфликте устройств ---------- */
class ConflictOverlay extends StatelessWidget {
  const ConflictOverlay(this.ctl, this.c, this.onPick, {super.key});
  final GameController ctl;
  final SyncConflict c;
  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) {
    String when(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      String p(int v) => v.toString().padLeft(2, '0');
      return '${d.day}.${p(d.month)} ${p(d.hour)}:${p(d.minute)}';
    }

    return Overlay2(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Какой прогресс оставить?', style: h2()),
          const SizedBox(height: 6),
          Text(
            c.justLoggedIn
                ? 'В учётной записи уже есть сохранение, и на этом устройстве тоже есть прогресс. Выберите, какое продолжить — второе будет заменено.'
                : 'На сервере есть сохранение с другого устройства, которое новее, чем здесь. Выберите, какое продолжить — второе будет заменено.',
          ),
          const SizedBox(height: 10),
          ActBtn(
            'С сервера',
            () => onPick(true),
            right: c.serverData == null ? null : CloudSync.saveSummary(c.serverData!),
            primary: true,
          ),
          Text(
            'сохранено ${when(c.server.saved > 0 ? c.server.saved : c.server.updated)}',
            style: const TextStyle(color: C.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ActBtn('С этого устройства', () => onPick(false), right: CloudSync.saveSummary(ctl.game.s.toJson())),
        ],
      ),
    );
  }
}

/* ---------- вступление ---------- */
class IntroOverlay extends StatelessWidget {
  const IntroOverlay(this.ctl, {super.key});
  final GameController ctl;

  @override
  Widget build(BuildContext context) => Overlay2(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Искра во тьме', style: h2(C.gold).copyWith(fontSize: 24)),
        const SizedBox(height: 8),
        const Text('Вы — искра в мире шестигранников. Видно только одну клетку вокруг ваших владений, дальше — тьма.'),
        const SizedBox(height: 6),
        const Text(
          'Нажмите на фиолетовую клетку рядом с искрой и атакуйте живущую в ней сущность. '
          'После победы клетку можно захватить за материю, равную её мощи.',
        ),
        const SizedBox(height: 6),
        const Text(
          'Клетки тьмы растут. Если мощь соседа станет выше защиты вашей клетки, тьма заберёт её вместе со строениями. '
          'Искру потерять нельзя.',
        ),
        const SizedBox(height: 6),
        const Text(
          'Стройте шахты и заводы, укрепляйте защиту, прокачивайте персонажа и собирайте способности. '
          'Когда станет тесно — совершите прыжок искры и получите бонус.',
        ),
        const SizedBox(height: 12),
        ActBtn('Начать', () => ctl.act((g) => g.s.introSeen = true), primary: true),
      ],
    ),
  );
}
