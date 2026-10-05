#!/usr/bin/env python3
"""Прогон бота на изменённой копии ядра — без правок исходника игры.

python3 tool/balance/variant.py <вариант> [часы] [сиды] [стратегии]
Копирует lib/core во временную папку, применяет замены варианта и запускает run.dart.
Варианты — словарь VARIANTS ниже: файл -> список (было, стало).
"""
import os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.environ.get('BALANCE_TMP', '/tmp/iskra-balance')

# Рекомендованные правки, по шагам (каждый следующий вариант включает предыдущие)
ECON = [
    # мир 1: меньше снежного кома — шахта окупается ~100 с вместо 25 с, бой не приносит больше, чем стоит
    ('defs.dart', 'mineCost = 30.0', 'mineCost = 60.0'),
    ('game.dart', 'l * 1.2 * mult(st(c, \'m\'))', 'l * 0.6 * mult(st(c, \'m\'))'),
    ('defs.dart', 'foeReward = 2.5', 'foeReward = 1.2'),
]
JUMP = [
    # тьма от прыжков растёт медленно: +8% за прыжок вместо ×2 за 3 и ×5 за 10
    ('defs.dart', 'darkJumpA = 0.282, darkJumpP = 1.151', 'darkJumpA = 0.08, darkJumpP = 1.0'),
]
POWER = [
    # бонус прыжка усиливает искру в бою: урон и здоровье × (1 + бонус)^0,5
    ('game.dart', 'double maxHp() => 60 + 40 * eff(\'life\').v;',
     'double maxHp() => (60 + 40 * eff(\'life\').v) * math.pow(bonusMul, 0.5);'),
    ('game.dart', "double powMul() => (1 + 0.125 * (eff('power').v - 1)) * eraV('pAtk');",
     "double powMul() => (1 + 0.125 * (eff('power').v - 1)) * eraV('pAtk') * math.pow(bonusMul, 0.5);"),
]
CAPS = [
    # длительности и доли способностей с потолком: прирост +0,2 с (+1%) за уровень, плавно упирается в потолок —
    # действие не дольше половины отката, «Поглощение» не больше 35% здоровья
    ('game.dart', "      case 'absorb':\n        return d.base + 0.01 * l;",
     "      case 'absorb':\n        return 0.35 - 0.2 * math.exp(-0.01 * l / 0.2);"),
    ('game.dart', "      default:\n        return d.base + 0.2 * l;",
     "      default:\n        final cap = 0.5 * d.cd;\n        return cap - (cap - d.base) * math.exp(-0.2 * l / (cap - d.base));"),
]
HEAL = [
    # лечение растёт на 5% за уровень вместо 15%
    ('game.dart', "return maxHp() * d.base / 100 * (1 + 0.15 * l); // лечение", "return maxHp() * d.base / 100 * (1 + 0.05 * l); // лечение"),
]
PULSAR = [
    # пульсары за прыжок: 1 + рекорд клеток / 5 (дерево технологий иначе недостижимо)
    ('meta.dart', '    s.rebirths++;\n', '    s.rebirths++;\n    s.pulsars += 1 + s.worldMax ~/ 5;\n'),
]

ECON_B = [
    ('defs.dart', 'mineCost = 30.0', 'mineCost = 60.0'),
    ('game.dart', 'l * 1.2 * mult(st(c, \'m\'))', 'l * 0.5 * mult(st(c, \'m\'))'),
    ('defs.dart', 'facCost = 45.0', 'facCost = 90.0'),
    ('defs.dart', 'foeReward = 2.5', 'foeReward = 1.0'),
]
SOFT = [
    # мягкий старт: шесть соседей искры всегда низшего ранга (меньше «пустых» стартов)
    ('game.dart', '    final tier = rollTier(d);\n', "    final tier = d <= 1 ? 'low' : rollTier(d);\n"),
]
ECON_C = ECON_B + [
    # тьма вокруг большой области сильнее: +0,9 мощи новой клетки за каждую свою клетку вместо +0,6
    ('game.dart', 'own.length * 0.6;', 'own.length * 0.9;'),
]

GAIN_LIN = [
    # прибавка бонуса за мир линейна по рекорду клеток: 0,08 × клетки (было 0,02 × клетки^1,5) — без взрыва на 3-м мире
    ('meta.dart', 'jsRound(0.02 * math.pow(s.worldMax, 1.5) * math.pow(aggr, 2.5) * 100) / 100',
     'jsRound(0.08 * s.worldMax * math.pow(aggr, 2.5) * 100) / 100'),
]


def power(p):
    return [(f, a, b.replace('0.5)', f'{p})')) for f, a, b in POWER]


def jump(a):
    return [('defs.dart', 'darkJumpA = 0.282, darkJumpP = 1.151', f'darkJumpA = {a}, darkJumpP = 1.0')]


VARIANTS = {
    'caps': CAPS,
    'caps_heal': CAPS + HEAL,
    'econB': ECON_B,
    'econC': ECON_C,
    'base': [],
    'nojump': [('defs.dart', 'darkJumpA = 0.282', 'darkJumpA = 0.0')],
    'econ': ECON,
    'jump': JUMP,
    'econ_jump': ECON + JUMP,
    'econ_jump_power': ECON + JUMP + POWER,
    'full': ECON + JUMP + POWER + CAPS + PULSAR,
    'B_soft': ECON_B + SOFT,
    'B_jump': ECON_B + SOFT + JUMP,
    'B_power': ECON_B + SOFT + JUMP + POWER,
    'B_full': ECON_B + SOFT + JUMP + POWER + CAPS + PULSAR,
    'F1': ECON_B + SOFT + jump(0.08) + power(0.3) + CAPS + PULSAR + GAIN_LIN,
    # итоговый рекомендованный набор
    'R': ECON_B + SOFT + jump(0.04) + power(0.3) + CAPS + HEAL + PULSAR + GAIN_LIN,
    'R2': ECON_B + SOFT + jump(0.04) + power(0.3) + CAPS + HEAL + PULSAR + GAIN_LIN + [
        ('game.dart', '..might = c.might + 1', '..might = c.might * 0.5 + 1')],
    'R3': ECON_B + SOFT + jump(0.04) + power(0.3) + CAPS + HEAL + PULSAR + GAIN_LIN + [
        ('game.dart', '..might = c.might + 1', '..might = c.might * 0.5 + 1'),
        ('defs.dart', 'bonusPow = 0.75', 'bonusPow = 0.6')],
    'R4': ECON_B + SOFT + jump(0.04) + power(0.3) + CAPS + HEAL + PULSAR + GAIN_LIN + [
        ('game.dart', '..might = c.might + 1', '..might = c.might * 0.5 + 1'),
        ('defs.dart', 'bonusPow = 0.75', 'bonusPow = 0.5')],
    'F3': ECON_B + SOFT + jump(0.04) + power(0.3) + CAPS + PULSAR + GAIN_LIN,
    'F4': ECON_B + SOFT + jump(0.06) + power(0.35) + CAPS + PULSAR + GAIN_LIN,
    'F2': ECON_B + SOFT + jump(0.08) + power(0.3) + CAPS + PULSAR,
    'p20j08': ECON_B + SOFT + jump(0.08) + power(0.2) + CAPS + PULSAR,
    'p30j08': ECON_B + SOFT + jump(0.08) + power(0.3) + CAPS + PULSAR,
    'p30j15': ECON_B + SOFT + jump(0.15) + power(0.3) + CAPS + PULSAR,
    'p40j20': ECON_B + SOFT + jump(0.2) + power(0.4) + CAPS + PULSAR,
}

# Ровный рост (2026-10-05), поверх ядра ветки интерфейса (CORE=.../lib/core)
PAR = [
    ('game.dart', "double defDiv() => 1 + 0.125 * (eff('defense').v - 1);", "double defDiv() => 1 + 0.2 * (eff('defense').v - 1);"),
    ('game.dart', "(1 + 0.125 * (eff('power').v - 1))", "(1 + 0.2 * (eff('power').v - 1))"),
    ('game.dart', "double med() => 1 + 0.5 * (eff('meditation').v - 1);", "double med() => 1 + 0.3 * (eff('meditation').v - 1);"),
    ('game.dart', "1.4 / (1 + 0.06 * (eff('speed').v - 1))", "1.4 / (1 + 0.1 * (eff('speed').v - 1))"),
]


def foe(h, a):
    return [('defs.dart', 'foeHp = 2.5, foeAtk = 0.5,', f'foeHp = {h}, foeAtk = {a},')]


for h, a in [(1.0, 1.25), (1.25, 1.0), (0.8, 1.5), (1.5, 0.8), (1.2, 1.4), (1.0, 1.6), (1.3, 1.3), (0.9, 1.8), (1.2, 1.6), (1.1, 1.5)]:
    VARIANTS[f'E{h}_{a}'] = foe(h, a)
    VARIANTS[f'P{h}_{a}'] = PAR + foe(h, a)
VARIANTS['P'] = PAR


def cost(c):
    return [('battle.dart', '(4 * med()).ceil()', f'({c} * med()).ceil()'),
            ('forecast.dart', '(4 * md).ceil()', f'({c} * md).ceil()'),
            ('forecast.dart', '(4 * med()).ceil()', f'({c} * med()).ceil()')]


for c in (5, 6, 8):
    VARIANTS[f'C{c}'] = PAR + foe(1.0, 1.6) + cost(c)


def build(name, extra=None):
    patches = VARIANTS[name] + (extra or [])
    d = os.path.join(OUT, name)
    shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(os.environ.get('CORE') or os.path.join(ROOT, 'lib', 'core'), os.path.join(d, 'lib', 'core'))
    os.makedirs(os.path.join(d, 'tool', 'balance'))
    for f in ('bot.dart', 'run.dart', 'abtest.dart'):
        shutil.copy(os.path.join(ROOT, 'tool', 'balance', f), os.path.join(d, 'tool', 'balance', f))
    for f, a, b in patches:
        p = os.path.join(d, 'lib', 'core', f)
        s = open(p, encoding='utf-8').read()
        if a not in s:
            sys.exit(f'{name}: не найдено в {f}: {a!r}')
        open(p, 'w', encoding='utf-8').write(s.replace(a, b))
    return d


if __name__ == '__main__':
    name = sys.argv[1]
    hours = sys.argv[2] if len(sys.argv) > 2 else '15'
    seeds = sys.argv[3] if len(sys.argv) > 3 else '3'
    strats = sys.argv[4] if len(sys.argv) > 4 else ''
    script = sys.argv[5] if len(sys.argv) > 5 else 'run.dart'
    d = build(name)
    out = os.path.join(OUT, f'{name}.json')
    args = ['dart', 'run', f'tool/balance/{script}'] + ([hours, seeds, strats, out] if script == 'run.dart' else [])
    subprocess.run(args, cwd=d, check=True)
