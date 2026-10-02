// Мелкие общие элементы интерфейса
import 'package:flutter/material.dart';

import 'theme.dart';

/// Кнопка действия: подпись слева, цена или пояснение справа
class ActBtn extends StatelessWidget {
  const ActBtn(this.label, this.onTap, {super.key, this.right, this.primary = false, this.danger = false});
  final String label;
  final String? right;
  final VoidCallback? onTap;
  final bool primary, danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFF4A1C2C)
        : primary
        ? C.goldBg
        : C.btn;
    final fg = danger
        ? C.bad
        : primary
        ? C.gold
        : C.ink;
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        side: BorderSide(color: onTap == null ? C.line : fg.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          if (right != null) ...[
            const SizedBox(width: 8),
            Text(right!, style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.75))),
          ],
        ],
      ),
    );
  }
}

/// Таблица «название — значение»
class KV extends StatelessWidget {
  const KV(this.rows, {super.key});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (k, v) in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(k, style: const TextStyle(color: C.muted)),
              ),
              Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
    ],
  );
}

class Note extends StatelessWidget {
  const Note(this.text, {super.key, this.kind = 'info'});
  final String text, kind;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: C.kind(kind).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: C.kind(kind).withValues(alpha: 0.4)),
    ),
    child: Text(text, style: TextStyle(color: kind == 'info' ? C.ink : C.kind(kind))),
  );
}

/// Шкала с подписью: здоровье в бою, прогресс уровня клетки
class Bar extends StatelessWidget {
  const Bar(this.value, {super.key, this.color = C.gold, this.height = 8, this.label});
  final double value;
  final Color color;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.isFinite ? value.clamp(0, 1) : 0,
          minHeight: height,
          color: color,
          backgroundColor: C.line,
        ),
      ),
      if (label != null)
        Text(
          label!,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 3)]),
        ),
    ],
  );
}

/// Окно поверх игры (бой, защита, прыжок, учётная запись)
class Overlay2 extends StatelessWidget {
  const Overlay2({super.key, required this.child, this.onClose, this.maxWidth = 520});
  final Widget child;
  final VoidCallback? onClose;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: GestureDetector(
      onTap: onClose,
      child: ColoredBox(
        color: const Color(0xB3080514),
        child: SafeArea(
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: C.panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.line),
                ),
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget tierChip(String tier, String name) {
  final col = Color(_tierColors[tier] ?? 0xFFA49DBD);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: col.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: col.withValues(alpha: 0.6)),
    ),
    child: Text(name.toLowerCase(), style: TextStyle(color: col, fontSize: 12)),
  );
}

const _tierColors = {'low': 0xFFA49DBD, 'rare': 0xFF5FB2E6, 'epic': 0xFFEF6B90, 'legend': 0xFFFF8A3D};
