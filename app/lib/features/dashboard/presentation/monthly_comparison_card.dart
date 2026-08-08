import 'dart:math' as math;

import 'package:app/core/localization/app_material.dart';

class MonthlyFinancePoint {
  final DateTime month;
  final double income;
  final double expense;
  final double saving;

  const MonthlyFinancePoint({
    required this.month,
    required this.income,
    required this.expense,
    required this.saving,
  });
}

class MonthlyComparisonCard extends StatefulWidget {
  final List<MonthlyFinancePoint> points;

  const MonthlyComparisonCard({super.key, required this.points});

  @override
  State<MonthlyComparisonCard> createState() => _MonthlyComparisonCardState();
}

class _MonthlyComparisonCardState extends State<MonthlyComparisonCard> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToLatest();
  }

  @override
  void didUpdateWidget(covariant MonthlyComparisonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) _scrollToLatest();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) {
        _controller.jumpTo(_controller.position.maxScrollExtent);
      }
    });
  }

  void _move(double direction) {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + direction * 250).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maximum = widget.points.fold<double>(1, (current, point) {
      return math.max(
        current,
        math.max(point.income, math.max(point.expense, point.saving)),
      );
    });
    final groupWidth = (MediaQuery.sizeOf(context).width - 56) / 3;

    return Container(
      height: 188,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เปรียบเทียบรายเดือน',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'ปัดซ้าย–ขวาเพื่อดูเดือนอื่น',
                      style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              _ChartArrow(
                icon: Icons.chevron_left_rounded,
                onTap: () => _move(-1),
              ),
              const SizedBox(width: 4),
              _ChartArrow(
                icon: Icons.chevron_right_rounded,
                onTap: () => _move(1),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartLegend(label: context.tr('รายรับ', 'Income'), color: Color(0xFF21B894)),
              SizedBox(width: 12),
              _ChartLegend(label: context.tr('รายจ่าย', 'Expense'), color: Color(0xFFFF7181)),
              SizedBox(width: 12),
              _ChartLegend(label: context.tr('เงินออม', 'Savings'), color: Color(0xFF9A74E8)),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: ClipRect(
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: widget.points.map((point) {
                    return SizedBox(
                      width: groupWidth,
                      child: _MonthBarGroup(point: point, maximum: maximum),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBarGroup extends StatelessWidget {
  final MonthlyFinancePoint point;
  final double maximum;

  const _MonthBarGroup({required this.point, required this.maximum});

  @override
  Widget build(BuildContext context) {
    final buddhistYear = (point.month.year + 543).toString();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 76,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ValueBar(
                value: point.income,
                maximum: maximum,
                color: const Color(0xFF21B894),
              ),
              const SizedBox(width: 5),
              _ValueBar(
                value: point.expense,
                maximum: maximum,
                color: const Color(0xFFFF7181),
              ),
              const SizedBox(width: 5),
              _ValueBar(
                value: point.saving,
                maximum: maximum,
                color: const Color(0xFF9A74E8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_monthLabel(point.month.month)} ${buddhistYear.substring(2)}',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  String _monthLabel(int month) => [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ][month - 1];
}

class _ValueBar extends StatelessWidget {
  final double value;
  final double maximum;
  final Color color;

  const _ValueBar({
    required this.value,
    required this.maximum,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final height = value <= 0 ? 3.0 : 8 + value / maximum * 64;
    return Tooltip(
      message: '฿${value.toStringAsFixed(0)}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        width: 10,
        height: height,
        decoration: BoxDecoration(
          color: value <= 0 ? const Color(0xFFE2E8F0) : color,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final String label;
  final Color color;

  _ChartLegend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class _ChartArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ChartArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 26,
          height: 26,
          child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }
}
