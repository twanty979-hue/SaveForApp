import 'dart:convert';

import 'package:app/core/localization/app_material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../auth/domain/auth_session.dart';
import 'dashboard_overview_card.dart';
import 'monthly_comparison_card.dart';

class FinanceDashboardScreen extends StatefulWidget {
  final VoidCallback? onRefreshHeader;

  const FinanceDashboardScreen({super.key, this.onRefreshHeader});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  final ApiClient _apiClient = ApiClient();
  final List<String> _periods = ['เดือนนี้', 'เดือนก่อน', '30 วัน', 'ทั้งหมด'];

  List<dynamic> _transactions = [];
  int _selectedPeriod = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = AuthSession.userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final response = await _apiClient.get(
        '/transactions?user_id=eq.$userId&order=transaction_date.desc',
      );
      if (!mounted) return;
      setState(() {
        _transactions = response.statusCode == 200
            ? jsonDecode(response.body) as List<dynamic>
            : [];
        _loading = false;
      });
      widget.onRefreshHeader?.call();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _dateOf(dynamic transaction) => DateTime.tryParse(
    transaction['transaction_date']?.toString() ?? '',
  )?.toLocal();

  bool _inSelectedPeriod(DateTime date) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 0:
        return date.year == now.year && date.month == now.month;
      case 1:
        final previous = DateTime(now.year, now.month - 1, 1);
        return date.year == previous.year && date.month == previous.month;
      case 2:
        final today = DateTime(now.year, now.month, now.day);
        final day = DateTime(date.year, date.month, date.day);
        final difference = today.difference(day).inDays;
        return difference >= 0 && difference < 30;
      default:
        return true;
    }
  }

  List<dynamic> get _filteredTransactions {
    return _transactions.where((transaction) {
      final date = _dateOf(transaction);
      return date != null && _inSelectedPeriod(date);
    }).toList();
  }

  _DashboardMetrics get _metrics {
    var income = 0.0;
    var expense = 0.0;
    var saving = 0.0;
    for (final transaction in _filteredTransactions) {
      final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
      final note = transaction['note']?.toString() ?? '';
      final source = transaction['source']?.toString();
      final dreamId = transaction['dream_id']?.toString();
      final isSaving = source == 'dream_saving' || dreamId != null || note.startsWith('[ออม]');
      if (transaction['type'] == 'income') {
        income += amount;
      } else if (isSaving) {
        saving += amount;
      } else if (transaction['type'] == 'expense') {
        expense += amount;
      }
    }
    return _DashboardMetrics(income: income, expense: expense, saving: saving);
  }

  List<double> get _lastSevenDayOutflow {
    final result = List<double>.filled(7, 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final transaction in _transactions) {
      if (transaction['type'] == 'income') continue;
      final date = _dateOf(transaction);
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      final difference = today.difference(day).inDays;
      if (difference >= 0 && difference < 7) {
        result[6 - difference] +=
            (transaction['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    return result;
  }

  List<MonthlyFinancePoint> get _monthlyComparison {
    final now = DateTime.now();
    final months = List.generate(
      12,
      (index) => DateTime(now.year, now.month - 11 + index, 1),
    );
    final income = List<double>.filled(months.length, 0);
    final expense = List<double>.filled(months.length, 0);
    final saving = List<double>.filled(months.length, 0);

    for (final transaction in _transactions) {
      final date = _dateOf(transaction);
      if (date == null) continue;
      final index = months.indexWhere(
        (month) => month.year == date.year && month.month == date.month,
      );
      if (index < 0) continue;
      final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
      final note = transaction['note']?.toString() ?? '';
      final source = transaction['source']?.toString();
      final dreamId = transaction['dream_id']?.toString();
      final isSaving = source == 'dream_saving' || dreamId != null || note.startsWith('[ออม]');
      if (transaction['type'] == 'income') {
        income[index] += amount;
      } else if (isSaving) {
        saving[index] += amount;
      } else if (transaction['type'] == 'expense') {
        expense[index] += amount;
      }
    }

    return List.generate(
      months.length,
      (index) => MonthlyFinancePoint(
        month: months[index],
        income: income[index],
        expense: expense[index],
        saving: saving[index],
      ),
    );
  }

  String get _overviewTitle {
    switch (_selectedPeriod) {
      case 0:
        return 'ภาพรวมเดือนนี้';
      case 1:
        return 'ภาพรวมเดือนก่อน';
      case 2:
        return 'ภาพรวม 30 วัน';
      default:
        return 'ภาพรวมทั้งหมด';
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    final savingRate = metrics.income <= 0
        ? 0.0
        : metrics.saving / metrics.income * 100;
    final spendingRate = metrics.income <= 0
        ? 0.0
        : metrics.expense / metrics.income * 100;

    return Scaffold(
      backgroundColor: context.pageColor,
      body: Stack(
        children: [
          const Positioned.fill(child: FloatingBackground()),
          SafeArea(
            child: ResponsiveLayout(
              maxWidth: 800,
              child: Column(
                children: [
                  _DashboardHeader(onRefresh: _load),
                  Expanded(
                    child: _loading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : RefreshIndicator(
                            color: AppTheme.primaryColor,
                            onRefresh: _load,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                              children: [
                                _PeriodSelector(
                                  labels: _periods,
                                  selectedIndex: _selectedPeriod,
                                  onSelected: (index) =>
                                      setState(() => _selectedPeriod = index),
                                ),
                                const SizedBox(height: 12),
                                DashboardOverviewCard(
                                  income: metrics.income,
                                  expense: metrics.expense,
                                  saving: metrics.saving,
                                  dailyOutflow: _lastSevenDayOutflow,
                                  expanded: true,
                                  showToggle: false,
                                  showDailyBars: false,
                                  title: _overviewTitle,
                                  onToggle: () {},
                                ),
                                const SizedBox(height: 12),
                                MonthlyComparisonCard(
                                  points: _monthlyComparison,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _InsightCard(
                                        icon: Icons.savings_outlined,
                                        label: context.tr(
                                          'อัตราการออม',
                                          'Savings Rate',
                                        ),
                                        value:
                                            '${savingRate.toStringAsFixed(0)}%',
                                        color: const Color(0xFF8B5CF6),
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: _InsightCard(
                                        icon: Icons.pie_chart_outline_rounded,
                                        label: context.tr(
                                          'ใช้ต่อรายรับ',
                                          'Expense/Income',
                                        ),
                                        value:
                                            '${spendingRate.toStringAsFixed(0)}%',
                                        color: const Color(0xFFEF6677),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'รายการล่าสุด',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${_filteredTransactions.length} รายการ',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _RecentTransactions(
                                  transactions: _filteredTransactions,
                                ),
                              ],
                            ),
                          ),
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

class _DashboardMetrics {
  final double income;
  final double expense;
  final double saving;

  const _DashboardMetrics({
    required this.income,
    required this.expense,
    required this.saving,
  });
}

class _DashboardHeader extends StatelessWidget {
  final VoidCallback onRefresh;

  const _DashboardHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Material(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(context),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 17),
              ),
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'แดชบอร์ดการเงิน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172033),
                  ),
                ),
                Text(
                  'ภาพรวมที่ช่วยให้ตัดสินใจง่ายขึ้น',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: onRefresh,
            icon: Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PeriodSelector({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F5),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF7B8492),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InsightCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  final List<dynamic> transactions;

  const _RecentTransactions({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.borderColor),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long_outlined, color: Color(0xFFB8C1CC)),
            SizedBox(height: 6),
            Text(
              'ยังไม่มีรายการในช่วงนี้',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    final visible = transactions.take(8).toList();
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: List.generate(visible.length, (index) {
          final transaction = visible[index] as Map<String, dynamic>;
          return _RecentTransactionRow(
            transaction: transaction,
            showDivider: index < visible.length - 1,
          );
        }),
      ),
    );
  }
}

class _RecentTransactionRow extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final bool showDivider;

  const _RecentTransactionRow({
    required this.transaction,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final rawNote = transaction['note']?.toString() ?? 'รายการ';
    final source = transaction['source']?.toString();
    final dreamId = transaction['dream_id']?.toString();
    final saving = source == 'dream_saving' || dreamId != null || rawNote.startsWith('[ออม]');
    final income = transaction['type'] == 'income';
    final color = saving
        ? const Color(0xFF8B5CF6)
        : income
        ? const Color(0xFF16A085)
        : const Color(0xFFEF6677);
    final note = rawNote
        .replaceAll(RegExp(r'\[สลิป\s+[^\]]+\]'), '')
        .replaceAll(RegExp(r'\[Ref:[^\]]+\]'), '')
        .replaceAll('[รายจ่ายประจำ]', '')
        .replaceAll('[รายรับประจำ]', '')
        .replaceAll('[ออม] หยอดกระปุก:', '')
        .trim();
    final date = DateTime.tryParse(
      transaction['transaction_date']?.toString() ?? '',
    )?.toLocal();
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFF0F3F6)))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              saving
                  ? Icons.auto_awesome_rounded
                  : income
                  ? Icons.north_east_rounded
                  : Icons.south_west_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.isEmpty ? 'รายการ' : note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  date == null
                      ? ''
                      : '${date.day}/${date.month}/${date.year + 543}',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Text(
            '${income ? '+' : '-'}฿${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
