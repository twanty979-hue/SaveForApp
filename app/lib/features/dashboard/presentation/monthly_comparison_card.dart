import 'dart:math' as math;

import 'package:app/core/localization/app_material.dart';
import 'package:app/core/theme/app_theme.dart';

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
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.points.isNotEmpty ? widget.points.length - 1 : 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didUpdateWidget(covariant MonthlyComparisonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _currentIndex = widget.points.isNotEmpty ? widget.points.length - 1 : 0;
      _pageController.dispose();
      _pageController = PageController(initialPage: _currentIndex);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _move(int delta) {
    if (widget.points.isEmpty) return;
    final targetPage = (_currentIndex + delta).clamp(0, widget.points.length - 1);
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Find maximum only within points to scale correctly
    final maximum = widget.points.fold<double>(1, (current, point) {
      return math.max(
        current,
        math.max(point.income, math.max(point.expense, point.saving)),
      );
    });

    final hasPrev = _currentIndex > 0;
    final hasNext = _currentIndex < widget.points.length - 1;

    return Container(
      height: 188,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เปรียบเทียบรายเดือน',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const Text(
                      'ปัดซ้าย–ขวาเพื่อดูเดือนอื่น',
                      style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              _ChartArrow(
                icon: Icons.chevron_left_rounded,
                onTap: hasPrev ? () => _move(-1) : null,
              ),
              const SizedBox(width: 4),
              _ChartArrow(
                icon: Icons.chevron_right_rounded,
                onTap: hasNext ? () => _move(1) : null,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartLegend(label: context.tr('รายรับ', 'Income'), color: const Color(0xFF21B894)),
              const SizedBox(width: 12),
              _ChartLegend(label: context.tr('รายจ่าย', 'Expense'), color: const Color(0xFFFF7181)),
              const SizedBox(width: 12),
              _ChartLegend(label: context.tr('เงินออม', 'Savings'), color: const Color(0xFF9A74E8)),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: widget.points.isEmpty
                ? const Center(
                    child: Text(
                      'ไม่มีข้อมูลการเงิน',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  )
                : PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemCount: widget.points.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final point = widget.points[index];
                      return Center(
                        child: SizedBox(
                          width: 220,
                          child: _MonthBarGroup(point: point, maximum: maximum),
                        ),
                      );
                    },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 82,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ValueBar(
                value: point.income,
                maximum: maximum,
                color: const Color(0xFF21B894),
              ),
              const SizedBox(width: 16),
              _ValueBar(
                value: point.expense,
                maximum: maximum,
                color: const Color(0xFFFF7181),
              ),
              const SizedBox(width: 16),
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
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
    final height = value <= 0 ? 3.0 : 8 + (value / maximum * 52);
    final formattedValue = value >= 1000000 
        ? '${(value / 1000000).toStringAsFixed(1)}M'
        : value >= 1000 
            ? '${(value / 1000).toStringAsFixed(1)}k' 
            : value.toStringAsFixed(0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (value > 0)
          Text(
            '฿$formattedValue',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          )
        else
          const Text(
            '--',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFFCBD5E1),
            ),
          ),
        const SizedBox(height: 3),
        Tooltip(
          message: '฿${value.toStringAsFixed(0)}',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            width: 24,
            height: height,
            decoration: BoxDecoration(
              color: value <= 0 ? const Color(0xFFE2E8F0) : color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _ChartLegend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          style: TextStyle(
            fontSize: 9, 
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _ChartArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ChartArrow({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onTap == null;

    return Material(
      color: disabled
          ? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9).withValues(alpha: 0.5))
          : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 26,
          height: 26,
          child: Icon(
            icon, 
            size: 18, 
            color: disabled
                ? const Color(0xFF64748B).withValues(alpha: 0.3)
                : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
