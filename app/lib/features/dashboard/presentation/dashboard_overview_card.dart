import 'dart:math' as math;

import 'package:app/core/localization/app_material.dart';

import '../../../core/theme/app_theme.dart';

class DashboardOverviewCard extends StatelessWidget {
  final double income;
  final double expense;
  final double saving;
  final List<double> dailyOutflow;
  final bool expanded;
  final VoidCallback onToggle;
  final String title;
  final bool showToggle;
  final bool showDailyBars;

  const DashboardOverviewCard({
    super.key,
    required this.income,
    required this.expense,
    required this.saving,
    required this.dailyOutflow,
    required this.expanded,
    required this.onToggle,
    this.title = 'ภาพรวมเดือนนี้',
    this.showToggle = true,
    this.showDailyBars = true,
  });

  double get balance => income - expense - saving;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      height: expanded ? (showDailyBars ? 215 : 160) : 48,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRect(
        child: Column(
          children: [
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Text(
                    'คงเหลือ ฿${_money(balance)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: balance >= 0
                          ? AppTheme.primaryColor
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  if (showToggle) ...[
                    const SizedBox(width: 3),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onToggle,
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: AnimatedRotation(
                          turns: expanded ? 0 : 0.5,
                          duration: const Duration(milliseconds: 220),
                          child: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 19,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  SizedBox(
                    width: 102,
                    height: 102,
                    child: CustomPaint(
                      painter: _FinanceDonutPainter(
                        income: income,
                        expense: expense,
                        saving: saving,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'คงเหลือ',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            Text(
                              '฿${_compactMoney(balance)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: balance >= 0
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      children: [
                        _OverviewLegend(
                          label: context.tr('รายรับ', 'Income'),
                          amount: income,
                          color: const Color(0xFF21B894),
                        ),
                        const SizedBox(height: 7),
                        _OverviewLegend(
                          label: context.tr('รายจ่าย', 'Expenses'),
                          amount: expense,
                          color: const Color(0xFFFF7181),
                        ),
                        const SizedBox(height: 7),
                        _OverviewLegend(
                          label: context.tr('เงินออม', 'Savings'),
                          amount: saving,
                          color: const Color(0xFF9A74E8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showDailyBars) ...[
                const SizedBox(height: 5),
                _SevenDayBars(values: dailyOutflow),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _money(double value) {
    final absolute = value.abs().round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < absolute.length; index++) {
      if (index > 0 && (absolute.length - index) % 3 == 0) buffer.write(',');
      buffer.write(absolute[index]);
    }
    return '${value < 0 ? '-' : ''}$buffer';
  }

  static String _compactMoney(double value) {
    final absolute = value.abs();
    final sign = value < 0 ? '-' : '';
    if (absolute >= 1000000) {
      return '$sign${(absolute / 1000000).toStringAsFixed(1)}M';
    }
    if (absolute >= 1000) {
      return '$sign${(absolute / 1000).toStringAsFixed(1)}K';
    }
    return '$sign${absolute.toStringAsFixed(0)}';
  }
}

class _OverviewLegend extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _OverviewLegend({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Text(
          '฿${DashboardOverviewCard._money(amount)}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

class _SevenDayBars extends StatelessWidget {
  final List<double> values;

  const _SevenDayBars({required this.values});

  @override
  Widget build(BuildContext context) {
    final normalized = values.length == 7 ? values : List<double>.filled(7, 0);
    final maximum = normalized.fold<double>(
      1,
      (current, value) => math.max(current, value),
    );
    final now = DateTime.now();
    const weekdayLabels = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

    return SizedBox(
      height: 49,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final value = normalized[index];
          final date = now.subtract(Duration(days: 6 - index));
          final isToday = index == 6;
          final barHeight = value <= 0 ? 3.0 : 6 + (value / maximum * 23);
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  width: 13,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: value <= 0
                        ? const Color(0xFFE2E8F0)
                        : isToday
                        ? const Color(0xFFFF7181)
                        : const Color(0xFFFFBCC4),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  weekdayLabels[date.weekday - 1],
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isToday
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _FinanceDonutPainter extends CustomPainter {
  final double income;
  final double expense;
  final double saving;

  const _FinanceDonutPainter({
    required this.income,
    required this.expense,
    required this.saving,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 9;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final basePaint = Paint()
      ..color = const Color(0xFFEEF2F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, basePaint);

    final total = income + expense + saving;
    if (total <= 0) return;
    const gap = 0.055;
    var start = -math.pi / 2;
    final segments = [
      (income, const Color(0xFF21B894)),
      (expense, const Color(0xFFFF7181)),
      (saving, const Color(0xFF9A74E8)),
    ];
    for (final segment in segments) {
      if (segment.$1 <= 0) continue;
      final sweep = segment.$1 / total * math.pi * 2;
      final paint = Paint()
        ..color = segment.$2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        bounds,
        start + gap / 2,
        math.max(0, sweep - gap),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _FinanceDonutPainter oldDelegate) {
    return income != oldDelegate.income ||
        expense != oldDelegate.expense ||
        saving != oldDelegate.saving;
  }
}
