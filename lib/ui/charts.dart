import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models.dart';
import 'design.dart';

class Sparkline extends StatelessWidget {
  const Sparkline(this.values, {super.key, this.color = Palette.mint});
  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) => LedgerScope.of(context).hidden
      ? const SizedBox.shrink()
      : CustomPaint(painter: _LinePainter(values, color: color, compact: true));
}

class BalanceChart extends StatelessWidget {
  const BalanceChart({
    super.key,
    required this.values,
    required this.start,
    required this.end,
  });
  final List<int> values;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    if (LedgerScope.of(context).hidden) return const _ChartHidden();
    final low = values.reduce(min);
    final high = values.reduce(max);
    return Semantics(
      label:
          'Balance history. Started at ${money(values.first)}. Ended at ${money(values.last)}.',
      child: Column(
        children: [
          SizedBox(
            height: 118,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _LinePainter(values, color: Palette.mint),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final level in [high, (high + low) ~/ 2, low])
                      Text(
                        money(level),
                        style: textStyle(
                          10,
                          color: Palette.secondary,
                          tabular: true,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                shortDate(start),
                style: textStyle(11, color: Palette.secondary),
              ),
              Text(
                shortDate(end),
                style: textStyle(11, color: Palette.secondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter(this.values, {required this.color, this.compact = false});
  final List<int> values;
  final Color color;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final margin = compact ? 4.0 : 7.0;
    final height = size.height - margin * 2;
    final low = values.reduce(min);
    final high = values.reduce(max);
    final line = Path();
    for (var index = 0; index < values.length; index++) {
      final x =
          margin +
          (size.width - margin * 2) * index / max(1, values.length - 1);
      final y =
          margin +
          height * (high == low ? .5 : (high - values[index]) / (high - low));
      if (index == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    final grid = Paint()
      ..color = (compact ? Palette.greenLine : Palette.line).withValues(
        alpha: .7,
      );
    for (final fraction in [.0, .5, 1.0]) {
      final y = margin + height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final fill = Path.from(line)
      ..lineTo(size.width - margin, size.height)
      ..lineTo(margin, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .23), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.8 : 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.compact != compact;
}

class SpendingDonut extends StatelessWidget {
  const SpendingDonut({
    super.key,
    required this.slices,
    required this.onSelect,
  });
  final Map<Category, int> slices;
  final ValueChanged<Category> onSelect;

  @override
  Widget build(BuildContext context) {
    final hidden = LedgerScope.of(context).hidden;
    final total = slices.values.fold(0, (sum, amount) => sum + amount);
    const diameter = 164.0;
    return SizedBox.square(
      dimension: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTapUp: hidden
                  ? null
                  : (event) {
                      final delta =
                          event.localPosition -
                          const Offset(diameter / 2, diameter / 2);
                      if (delta.distance < 57 || delta.distance > 82) return;
                      final position =
                          ((atan2(delta.dy, delta.dx) + pi / 2 + 2 * pi) %
                              (2 * pi)) /
                          (2 * pi);
                      var cumulative = 0.0;
                      for (final slice in slices.entries) {
                        cumulative += slice.value / total;
                        if (position <= cumulative) {
                          onSelect(slice.key);
                          return;
                        }
                      }
                    },
              child: CustomPaint(painter: _DonutPainter(hidden ? {} : slices)),
            ),
          ),
          IgnorePointer(
            child: SizedBox(
              width: 105,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TOTAL SPENT',
                    style: textStyle(
                      9,
                      color: Palette.secondary,
                      spacing: 1,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  MoneyText(
                    total,
                    size: 18,
                    weight: FontWeight.w900,
                    fit: true,
                    align: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.slices);
  final Map<Category, int> slices;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = (Offset.zero & size).deflate(stroke / 2 + 2);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawOval(rect, pen..color = Palette.line);
    final total = slices.values.fold(0, (sum, amount) => sum + amount);
    var start = -pi / 2;
    for (final slice in slices.entries) {
      final sweep = 2 * pi * slice.value / total;
      final gap = slices.length == 1 ? 0.0 : min(.04, sweep * .3);
      canvas.drawArc(
        rect,
        start + gap / 2,
        sweep - gap,
        false,
        pen..color = categoryVisual(slice.key).color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices;
}

class SpendingBars extends StatefulWidget {
  const SpendingBars({
    super.key,
    required this.labels,
    required this.values,
    this.color = Palette.mint,
  });
  final List<String> labels;
  final List<int> values;
  final Color color;

  @override
  State<SpendingBars> createState() => _SpendingBarsState();
}

class _SpendingBarsState extends State<SpendingBars> {
  int? _selected;

  @override
  void didUpdateWidget(covariant SpendingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labels.join('|') != widget.labels.join('|')) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    if (LedgerScope.of(context).hidden) return const _ChartHidden();
    final selected = _selected ?? widget.values.length - 1;
    final peak = max(1, widget.values.reduce(max));
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.labels[selected],
                style: textStyle(12, color: Palette.secondary),
              ),
            ),
            MoneyText(widget.values[selected], size: 14),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 113,
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    4,
                    (_) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Palette.line,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var index = 0; index < widget.values.length; index++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: index == selected,
                          label:
                              '${widget.labels[index]}, ${money(widget.values[index])}',
                          child: InkWell(
                            onTap: () => setState(() => _selected = index),
                            borderRadius: BorderRadius.circular(8),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                widthFactor: .59,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOut,
                                  height: widget.values[index] == 0
                                      ? 2
                                      : max(
                                          4,
                                          109 * widget.values[index] / peak,
                                        ),
                                  decoration: BoxDecoration(
                                    color: widget.color.withValues(
                                      alpha: index == selected ? 1 : .42,
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (index, label) in widget.labels.indexed)
              Expanded(
                child: Text(
                  widget.labels.length > 8 && index.isOdd && index != selected
                      ? ''
                      : label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: textStyle(
                    10,
                    color: index == selected ? widget.color : Palette.secondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChartHidden extends StatelessWidget {
  const _ChartHidden();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 115,
    child: Center(
      child: Text(
        'Amounts are hidden',
        style: TextStyle(fontSize: 13, color: Palette.secondary),
      ),
    ),
  );
}
