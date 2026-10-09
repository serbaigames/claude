// Значки способностей, особенностей сущностей и артефактов.
// Символы Юникода из веб-версии есть не во всех шрифтах, поэтому в интерфейсе — значки Material.
import 'package:flutter/material.dart';

import '../core/game.dart';
import 'theme.dart';

const abilityIcons = <String, IconData>{
  'spark_strike': Icons.flare,
  'veil': Icons.shield_moon_outlined,
  'feed': Icons.healing,
  'discharge': Icons.bolt,
  'vampire': Icons.bloodtype,
  'haste': Icons.fast_forward_rounded,
  'nova': Icons.brightness_7,
  'dark_shield': Icons.hexagon,
  'absorb': Icons.radio_button_checked,
  'ember': Icons.local_fire_department,
  'daze': Icons.blur_circular,
  'mend': Icons.spa,
  'lance': Icons.trending_flat,
  'wither': Icons.trending_down,
  'harvest': Icons.grass,
  'mirror': Icons.flip,
  'finisher': Icons.dangerous_outlined,
  'dispel': Icons.block,
};

const traitIcons = <String, IconData>{
  'regen': Icons.healing,
  'shell': Icons.hexagon_outlined,
  'rage': Icons.whatshot,
  'ward': Icons.shield_outlined,
  'leech': Icons.water_drop,
  'stun': Icons.offline_bolt_outlined,
};

const artIcons = <String, IconData>{
  'energy': Icons.diamond,
  'force': Icons.change_history,
  'matter': Icons.circle,
  'clot': Icons.blur_on,
  'core': Icons.wb_sunny,
  'bulwark': Icons.security,
  'bloom': Icons.local_florist,
  'frost': Icons.ac_unit,
  'tome': Icons.menu_book,
  'rune': Icons.auto_fix_high,
  'glass': Icons.hourglass_bottom,
};

const paramIcons = <String, IconData>{
  'life': Icons.favorite,
  'defense': Icons.shield,
  'power': Icons.flash_on,
  'meditation': Icons.self_improvement,
  'speed': Icons.speed,
  'control': Icons.hub,
};

/// Значок способности в цвете её ранга
Widget abilityIcon(String id, {double size = 22, bool dim = false}) {
  final d = Defs.abilities[id];
  final col = Color(Defs.tierColor[d?.tier ?? 'low'] ?? 0xFFA49DBD);
  return Icon(abilityIcons[id] ?? Icons.auto_awesome, size: size, color: dim ? col.withValues(alpha: 0.45) : col);
}

/// Значок особенности сущности; [off] — отключена «Рассеиванием»
Widget traitIcon(String id, {double size = 16, bool off = false}) =>
    Icon(traitIcons[id] ?? Icons.help_outline, size: size, color: off ? C.muted : C.warn);

/// Значок артефакта в его цвете
Widget artIcon(String type, {double size = 22, bool dim = false}) {
  final col = Color(Defs.arts[type]?.color ?? 0xFFA49DBD);
  return Icon(artIcons[type] ?? Icons.category, size: size, color: dim ? col.withValues(alpha: 0.4) : col);
}
