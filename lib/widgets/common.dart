import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: color == null ? Border.all(color: AppColors.line) : null,
        ),
        child: child,
      );
}

/// A two-way pill switch, e.g. "Photo of food | Barcode".
class PillToggle<T> extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.dark = false,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.12) : AppColors.ink.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          for (final e in options.entries)
            Expanded(
              child: Semantics(
                selected: e.key == value,
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e.key == value ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: e.key == value ? w800 : w700,
                        color: e.key == value
                            ? AppColors.ink
                            : (dark ? Colors.white : const Color(0xFF3E4F46)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Large selectable buttons laid out in a row (wrap on small screens).
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.height = 50,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, e) in options.entries.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Pill(
              label: e.value,
              selected: e.key == value,
              height: height,
              onTap: () => onChanged(e.key),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap, required this.height});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.green : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.green : AppColors.chipBorder, width: 2),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? w800 : w700,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The calorie ring on the Today screen.
class CalorieRing extends StatelessWidget {
  const CalorieRing({super.key, required this.eaten, required this.goal, this.size = 150});
  final double eaten;
  final int goal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final left = math.max(0, goal - eaten).round();
    final over = eaten > goal;
    return Semantics(
      label: '${eaten.round()} of $goal calories eaten',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(goal == 0 ? 0 : (eaten / goal).clamp(0, 1).toDouble(), over),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(over ? '${(eaten - goal).round()}' : '$left',
                    style: const TextStyle(fontSize: 32, fontWeight: w800, height: 1)),
                Text(over ? 'kcal over' : 'kcal left',
                    style: const TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.pct, this.over);
  final double pct;
  final bool over;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 15.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final bg = Paint()
      ..color = AppColors.greenSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fg = Paint()
      ..color = over ? const Color(0xFFB4530B) : AppColors.green
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(r, 0, math.pi * 2, false, bg);
    if (pct > 0) canvas.drawArc(r, -math.pi / 2, math.pi * 2 * pct, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct || old.over != over;
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, required this.color, required this.background, this.height = 14});
  final double value;
  final Color color;
  final Color background;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1).toDouble(),
          minHeight: height,
          color: color,
          backgroundColor: background,
        ),
      );
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.protein});
  final String label;
  final String value;
  final bool protein;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: protein ? AppColors.blueSoft : AppColors.greenSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 15, fontWeight: w700, color: protein ? AppColors.blueDark : AppColors.greenDark)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 28, fontWeight: w800)),
            ),
          ],
        ),
      );
}

class MealIcon extends StatelessWidget {
  const MealIcon(this.meal, {super.key});
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg) = switch (meal) {
      Meal.breakfast => (Icons.wb_sunny_outlined, const Color(0xFFB4530B), const Color(0xFFFFF1E0)),
      Meal.lunch => (Icons.rice_bowl_outlined, AppColors.green, AppColors.greenSoft),
      Meal.snack => (Icons.apple, const Color(0xFFA3324F), const Color(0xFFFCE8EE)),
      Meal.dinner => (Icons.nightlight_outlined, const Color(0xFF3B4A8C), const Color(0xFFEEF0F7)),
    };
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: fg, size: 24),
    );
  }
}

/// Section title used across screens, with an optional action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: w800))),
            if (action != null)
              TextButton(
                onPressed: onAction,
                child: Text(action!, style: const TextStyle(fontSize: 15, fontWeight: w800)),
              ),
          ],
        ),
      );
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text, style: const TextStyle(fontSize: 16)),
      behavior: SnackBarBehavior.floating,
    ));
}
