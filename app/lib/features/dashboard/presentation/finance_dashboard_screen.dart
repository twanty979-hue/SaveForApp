import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:app/core/localization/app_material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../auth/domain/auth_session.dart';
import '../../../core/services/subscription_service.dart';
import '../../subscription/presentation/subscription_paywall_sheet.dart';
import 'monthly_comparison_card.dart';

bool isTransferTransaction(dynamic tx) => _checkIsTransferTransaction(tx);

bool _checkIsTransferTransaction(dynamic tx) {
  if (tx is! Map) return false;
  final type = tx['type']?.toString();
  final source = tx['source']?.toString();
  final note = tx['note']?.toString() ?? '';
  final metadata = tx['metadata'] is Map ? tx['metadata'] as Map : null;
  final transferType = metadata?['transfer_type']?.toString();
  return type == 'transfer' ||
      source == 'transfer' ||
      transferType == 'own_account' ||
      note.startsWith('[ย้ายเงิน') ||
      note.contains('[ย้ายเงิน');
}

class FinanceDashboardScreen extends StatefulWidget {
  final VoidCallback? onRefreshHeader;

  const FinanceDashboardScreen({super.key, this.onRefreshHeader});

  static bool isTransfer(dynamic tx) => _checkIsTransferTransaction(tx);
  static bool isTransferTransaction(dynamic tx) => _checkIsTransferTransaction(tx);

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = ApiClient();

  late final ScrollController _scrollController;
  late final AnimationController _refreshAnimController;

  int _visibleCount = 8;
  List<dynamic> _transactions = [];
  int _selectedPeriod = 0;
  bool _loading = true;

  // Interactive Feature States ("ลูกเล่น")
  bool _isPrivacyMode = false;
  int _selectedChartMode = 0; // 0: Monthly, 1: 7-Day Outflow, 2: Category Breakdown
  String? _selectedDonutCategory; // null: Net, 'income', 'expense', 'saving'
  String _selectedTxType = 'all'; // 'all', 'income', 'expense', 'saving', 'transfer'
  String? _selectedCategoryFilter; // Filter by spending category
  String _searchQuery = '';
  bool _showSearch = false;
  int? _expandedTxId;
  int? _highlightedMonthIndex;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadPrivacyMode();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadPrivacyMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isPrivacyMode = prefs.getBool('pref_finance_dashboard_privacy') ?? false;
      });
    }
  }

  Future<void> _togglePrivacyMode() async {
    HapticFeedback.lightImpact();
    final next = !_isPrivacyMode;
    setState(() => _isPrivacyMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_finance_dashboard_privacy', next);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_visibleCount < _filteredTransactions.length) {
      setState(() {
        _visibleCount = math.min(_visibleCount + 8, _filteredTransactions.length);
      });
    }
  }

  Future<void> _load() async {
    final userId = AuthSession.userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _refreshAnimController.repeat();
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
    } finally {
      if (mounted) {
        _refreshAnimController.stop();
        _refreshAnimController.reset();
      }
    }
  }

  DateTime? _dateOf(dynamic transaction) => DateTime.tryParse(
    transaction['transaction_date']?.toString() ?? '',
  )?.toLocal();

  bool _inSelectedPeriod(DateTime date) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 0: // เดือนนี้
        return date.year == now.year && date.month == now.month;
      case 1: // เดือนก่อน
        final prev = DateTime(now.year, now.month - 1, 1);
        return date.year == prev.year && date.month == prev.month;
      case 2: // 30 วันล่าสุด
        final today = DateTime(now.year, now.month, now.day);
        final day = DateTime(date.year, date.month, date.day);
        final diff = today.difference(day).inDays;
        return diff >= 0 && diff < 30;
      default: // ทั้งหมด
        return true;
    }
  }

  List<dynamic> get _filteredTransactions {
    return _transactions.where((tx) {
      final date = _dateOf(tx);
      if (date == null || !_inSelectedPeriod(date)) return false;

      // Filter by type
      final isTransfer = isTransferTransaction(tx);
      final rawNote = tx['note']?.toString() ?? '';
      final source = tx['source']?.toString();
      final dreamId = tx['dream_id']?.toString();
      final isSaving = !isTransfer && (source == 'dream_saving' || dreamId != null || rawNote.startsWith('[ออม]'));
      final isIncome = !isTransfer && tx['type'] == 'income';
      final isExpense = !isTransfer && !isSaving && tx['type'] == 'expense';

      if (_selectedTxType == 'income' && !isIncome) return false;
      if (_selectedTxType == 'expense' && !isExpense) return false;
      if (_selectedTxType == 'saving' && !isSaving) return false;
      if (_selectedTxType == 'transfer' && !isTransfer) return false;

      // Filter by category if selected
      if (_selectedCategoryFilter != null && isExpense) {
        final cat = _detectCategory(rawNote);
        if (cat.name != _selectedCategoryFilter) return false;
      }

      // Search query filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final note = rawNote.toLowerCase();
        final amount = tx['amount']?.toString() ?? '';
        if (!note.contains(q) && !amount.contains(q)) return false;
      }

      return true;
    }).toList();
  }

  // All transactions within the selected period (regardless of list filters)
  List<dynamic> get _periodTransactions {
    return _transactions.where((tx) {
      final date = _dateOf(tx);
      return date != null && _inSelectedPeriod(date);
    }).toList();
  }

  _DashboardMetrics get _metrics {
    var income = 0.0;
    var expense = 0.0;
    var saving = 0.0;
    for (final transaction in _periodTransactions) {
      if (isTransferTransaction(transaction)) continue;
      final amount =
          num.tryParse(transaction['amount']?.toString() ?? '')?.toDouble() ?? 0.0;
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
      if (transaction['type'] == 'income' || isTransferTransaction(transaction)) continue;
      final date = _dateOf(transaction);
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      final difference = today.difference(day).inDays;
      if (difference >= 0 && difference < 7) {
        result[6 - difference] +=
            num.tryParse(transaction['amount']?.toString() ?? '')?.toDouble() ?? 0.0;
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
      if (isTransferTransaction(transaction)) continue;
      final date = _dateOf(transaction);
      if (date == null) continue;
      final index = months.indexWhere(
        (month) => month.year == date.year && month.month == date.month,
      );
      if (index < 0) continue;
      final amount =
          num.tryParse(transaction['amount']?.toString() ?? '')?.toDouble() ?? 0.0;
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

  // Category Breakdown Calculation
  List<_CategoryBreakdown> get _categoryBreakdowns {
    final map = <String, double>{};
    var totalExpense = 0.0;

    for (final tx in _periodTransactions) {
      if (isTransferTransaction(tx)) continue;
      if (tx['type'] != 'expense') continue;
      final note = tx['note']?.toString() ?? '';
      final source = tx['source']?.toString();
      final dreamId = tx['dream_id']?.toString();
      if (source == 'dream_saving' || dreamId != null || note.startsWith('[ออม]')) continue;

      final amount = num.tryParse(tx['amount']?.toString() ?? '')?.toDouble() ?? 0.0;
      if (amount <= 0) continue;

      final cat = _detectCategory(note);
      map[cat.name] = (map[cat.name] ?? 0.0) + amount;
      totalExpense += amount;
    }

    if (totalExpense <= 0) return [];

    final list = map.entries.map((e) {
      final cat = _kCategories.firstWhere(
        (c) => c.name == e.key,
        orElse: () => _CategoryMeta('อื่นๆ / เบ็ดเตล็ด', 'Other / Misc', Icons.category_rounded, const Color(0xFF64748B)),
      );
      return _CategoryBreakdown(
        meta: cat,
        amount: e.value,
        percentage: (e.value / totalExpense) * 100,
      );
    }).toList();

    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  // Daily Burn Rate Calculation
  double get _dailyBurnRate {
    final expense = _metrics.expense;
    if (expense <= 0) return 0.0;
    final now = DateTime.now();
    int days = 1;
    switch (_selectedPeriod) {
      case 0: // เดือนนี้: จำนวนวันที่ผ่านมาในเดือนนี้
        days = math.max(1, now.day);
        break;
      case 1: // เดือนก่อน: 30 วัน
        days = 30;
        break;
      case 2: // 30 วัน
        days = 30;
        break;
      default: // ทั้งหมด: คำนวณจากช่วงวันที่
        days = 30;
    }
    return expense / days;
  }

  String get _periodTitle {
    switch (_selectedPeriod) {
      case 0:
        return 'เดือนนี้';
      case 1:
        return 'เดือนก่อน';
      case 2:
        return '30 วันล่าสุด';
      default:
        return 'ทั้งหมด';
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    final savingRate = metrics.income <= 0 ? 0.0 : (metrics.saving / metrics.income * 100);
    final spendingRate = metrics.income <= 0 ? 0.0 : (metrics.expense / metrics.income * 100);

    return Scaffold(
      backgroundColor: context.pageColor,
      body: Stack(
        children: [
          const Positioned.fill(child: FloatingBackground()),
          SafeArea(
            child: ResponsiveLayout(
              maxWidth: 820,
              child: Column(
                children: [
                  _ModernDashboardHeader(
                    isPrivacyMode: _isPrivacyMode,
                    onTogglePrivacy: _togglePrivacyMode,
                    onRefresh: _load,
                    refreshAnim: _refreshAnimController,
                  ),
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
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
                              children: [
                                // 1. Modern Capsule Period Selector
                                _PeriodCapsuleSelector(
                                  labels: [
                                    context.tr('เดือนนี้', 'This month'),
                                    context.tr('เดือนก่อน', 'Prev month'),
                                    context.tr('30 วัน', '30 days'),
                                    context.tr('ทั้งหมด', 'All'),
                                  ],
                                  selectedIndex: _selectedPeriod,
                                  onSelected: (index) async {
                                    HapticFeedback.selectionClick();
                                    // Gate 'เดือนก่อน' (index 1) and 'ทั้งหมด' (index 3) behind SaveFor PRO
                                    if ((index == 1 || index == 3) && !SubscriptionService.instance.isPro) {
                                      final upgraded = await SubscriptionPaywallSheet.show(
                                        context,
                                        reason: context.tr(
                                          'ปลดล็อกดูภาพรวมเดือนก่อนและประวัติย้อนหลังทั้งหมดด้วย SaveFor PRO',
                                          'Unlock previous months and all financial history with SaveFor PRO',
                                        ),
                                      );
                                      if (!upgraded) return;
                                    }
                                    setState(() {
                                      _selectedPeriod = index;
                                      _visibleCount = 8;
                                      _selectedCategoryFilter = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 14),

                                // 2. Hero Interactive Overview Card (Interactive Donut & Touch Inspector)
                                _HeroFinancialCard(
                                  periodTitle: _periodTitle,
                                  metrics: metrics,
                                  isPrivacyMode: _isPrivacyMode,
                                  selectedDonutCategory: _selectedDonutCategory,
                                  onSelectDonutCategory: (cat) {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _selectedDonutCategory =
                                          _selectedDonutCategory == cat ? null : cat;
                                    });
                                  },
                                ),
                                const SizedBox(height: 14),

                                // 3. Interactive Multi-Mode Chart Hub ("ลูกเล่นสลับดูกราฟ 3 โหมด")
                                _InteractiveChartHub(
                                  selectedMode: _selectedChartMode,
                                  onSelectMode: (mode) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedChartMode = mode);
                                  },
                                  isPrivacyMode: _isPrivacyMode,
                                  monthlyPoints: _monthlyComparison,
                                  dailyOutflow: _lastSevenDayOutflow,
                                  categoryBreakdowns: _categoryBreakdowns,
                                  highlightedMonthIndex: _highlightedMonthIndex,
                                  onHighlightMonth: (idx) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _highlightedMonthIndex = idx);
                                  },
                                  selectedCategoryFilter: _selectedCategoryFilter,
                                  onSelectCategoryFilter: (catName) {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _selectedCategoryFilter =
                                          _selectedCategoryFilter == catName ? null : catName;
                                    });
                                  },
                                ),
                                const SizedBox(height: 14),

                                // 4. 4-Card Smart Financial KPI Grid
                                _FinancialKpiGrid(
                                  savingRate: savingRate,
                                  spendingRate: spendingRate,
                                  dailyBurnRate: _dailyBurnRate,
                                  totalTxCount: _periodTransactions.length,
                                  isPrivacyMode: _isPrivacyMode,
                                ),
                                const SizedBox(height: 20),

                                // 5. Interactive Recent Transactions Header & Filter Chips
                                _RecentTransactionsHeader(
                                  totalCount: _filteredTransactions.length,
                                  showSearch: _showSearch,
                                  searchQuery: _searchQuery,
                                  onToggleSearch: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _showSearch = !_showSearch;
                                      if (!_showSearch) _searchQuery = '';
                                    });
                                  },
                                  onSearchChanged: (q) => setState(() => _searchQuery = q),
                                ),
                                const SizedBox(height: 8),

                                // Type Filter Chips
                                _TransactionTypeChips(
                                  selectedType: _selectedTxType,
                                  selectedCategoryFilter: _selectedCategoryFilter,
                                  onClearCategoryFilter: () {
                                    setState(() => _selectedCategoryFilter = null);
                                  },
                                  onSelectType: (type) {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _selectedTxType = type;
                                      _visibleCount = 8;
                                    });
                                  },
                                ),
                                const SizedBox(height: 10),

                                // 6. Interactive Recent Transactions List with Accordion Detail
                                _InteractiveRecentTransactionsList(
                                  transactions: _filteredTransactions,
                                  visibleCount: _visibleCount,
                                  isPrivacyMode: _isPrivacyMode,
                                  expandedId: _expandedTxId,
                                  onToggleExpand: (id) {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _expandedTxId = _expandedTxId == id ? null : id;
                                    });
                                  },
                                  onLoadMore: _loadMore,
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

// -------------------------------------------------------------
// Models & Helpers
// -------------------------------------------------------------

class _DashboardMetrics {
  final double income;
  final double expense;
  final double saving;

  const _DashboardMetrics({
    required this.income,
    required this.expense,
    required this.saving,
  });

  double get balance => income - expense - saving;
  double get totalFlow => income + expense + saving;
}

class _CategoryMeta {
  final String name;
  final String enName;
  final IconData icon;
  final Color color;

  const _CategoryMeta(this.name, this.enName, this.icon, this.color);
}

class _CategoryBreakdown {
  final _CategoryMeta meta;
  final double amount;
  final double percentage;

  const _CategoryBreakdown({
    required this.meta,
    required this.amount,
    required this.percentage,
  });
}

final List<_CategoryMeta> _kCategories = [
  const _CategoryMeta('อาหาร & เครื่องดื่ม', 'Food & Drinks', Icons.restaurant_rounded, Color(0xFFF97316)),
  const _CategoryMeta('เดินทาง & ยานพาหนะ', 'Transport & Fuel', Icons.directions_car_rounded, Color(0xFF3B82F6)),
  const _CategoryMeta('ช้อปปิ้ง & สินค้า', 'Shopping', Icons.shopping_bag_rounded, Color(0xFFEC4899)),
  const _CategoryMeta('บิล & ค่าใช้จ่ายประจำ', 'Bills & Utilities', Icons.receipt_long_rounded, Color(0xFFEAB308)),
  const _CategoryMeta('บุคคล & โอนเงิน', 'People & Transfers', Icons.person_rounded, Color(0xFF6366F1)),
  const _CategoryMeta('สุขภาพ & ความงาม', 'Health & Beauty', Icons.spa_rounded, Color(0xFF14B8A6)),
  const _CategoryMeta('บันเทิง & ท่องเที่ยว', 'Entertainment', Icons.movie_filter_rounded, Color(0xFF8B5CF6)),
  const _CategoryMeta('อื่นๆ / เบ็ดเตล็ด', 'Other / Misc', Icons.category_rounded, Color(0xFF64748B)),
];

_CategoryMeta _detectCategory(String rawNote) {
  final text = rawNote.toLowerCase();
  if (text.contains('ข้าว') ||
      text.contains('อาหาร') ||
      text.contains('ขนม') ||
      text.contains('กาแฟ') ||
      text.contains('ชา') ||
      text.contains('น้ำ') ||
      text.contains('ก๋วยเตี๋ยว') ||
      text.contains('หมูกระทะ') ||
      text.contains('ชาบู') ||
      text.contains('kfc') ||
      text.contains('grabfood') ||
      text.contains('lineman') ||
      text.contains('7-eleven') ||
      text.contains('เซเว่น') ||
      text.contains('มื้อ') ||
      text.contains('กิน')) {
    return _kCategories[0];
  }
  if (text.contains('ไรเดอร์') ||
      text.contains('ขับ') ||
      text.contains('น้ำมัน') ||
      text.contains('ปั๊ม') ||
      text.contains('bts') ||
      text.contains('mrt') ||
      text.contains('รถ') ||
      text.contains('วิน') ||
      text.contains('ทางด่วน') ||
      text.contains('bolt') ||
      text.contains('grab')) {
    return _kCategories[1];
  }
  if (text.contains('shopee') ||
      text.contains('lazada') ||
      text.contains('เสื้อ') ||
      text.contains('กางเกง') ||
      text.contains('รองเท้า') ||
      text.contains('ของ') ||
      text.contains('tiktok') ||
      text.contains('ซื้อ') ||
      text.contains('ห้าง') ||
      text.contains('lotus') ||
      text.contains('big c')) {
    return _kCategories[2];
  }
  if (text.contains('ค่าไฟ') ||
      text.contains('ค่าน้ำ') ||
      text.contains('เน็ต') ||
      text.contains('ค่าห้อง') ||
      text.contains('ค่าเช่า') ||
      text.contains('บิล') ||
      text.contains('ประกัน') ||
      text.contains('บัตรเครดิต')) {
    return _kCategories[3];
  }
  if (text.contains('นาย') ||
      text.contains('นาง') ||
      text.contains('น.ส.') ||
      text.contains('โอน') ||
      text.contains('promptpay') ||
      text.contains('พร้อมเพย์') ||
      text.contains('บจก.')) {
    return _kCategories[4];
  }
  return _kCategories[7];
}

String _fmtMoney(double value, {bool compact = false, bool isPrivacy = false}) {
  if (isPrivacy) return '••••••';
  if (compact) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
  final isNeg = value < 0;
  final absVal = value.abs();
  final whole = absVal.truncate();
  final s = whole.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  // If decimal exists
  final dec = ((absVal - whole) * 100).round();
  if (dec > 0) {
    buf.write('.${dec.toString().padLeft(2, '0')}');
  }
  return '${isNeg ? '-' : ''}${buf.toString()}';
}

// -------------------------------------------------------------
// Component 1: Modern Header with Privacy & Refresh
// -------------------------------------------------------------

class _ModernDashboardHeader extends StatelessWidget {
  final bool isPrivacyMode;
  final VoidCallback onTogglePrivacy;
  final VoidCallback onRefresh;
  final AnimationController refreshAnim;

  const _ModernDashboardHeader({
    required this.isPrivacyMode,
    required this.onTogglePrivacy,
    required this.onRefresh,
    required this.refreshAnim,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          // Back button
          Material(
            color: context.surfaceColor,
            elevation: 0,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.selectionClick();
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.tr('แดชบอร์ดการเงิน', 'Financial dashboard'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<bool>(
                      valueListenable: SubscriptionService.instance.isProNotifier,
                      builder: (context, isPro, _) {
                        return GestureDetector(
                          onTap: () {
                            SubscriptionPaywallSheet.show(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              gradient: isPro
                                  ? const LinearGradient(
                                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                    )
                                  : null,
                              color: isPro ? null : AppTheme.primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isPro
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPro) ...[
                                  const Icon(Icons.stars_rounded, color: Colors.white, size: 10),
                                  const SizedBox(width: 3),
                                ],
                                Text(
                                  'PRO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: isPro ? Colors.white : AppTheme.primaryColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr(
                    'ภาพรวมกระแสเงินสดและการตัดสินใจ',
                    'A clearer view for better decisions',
                  ),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Privacy toggle button (Eye icon)
          Material(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTogglePrivacy,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor),
                ),
                child: Icon(
                  isPrivacyMode ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 19,
                  color: isPrivacyMode ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Refresh button with animation
          Material(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onRefresh,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor),
                ),
                child: RotationTransition(
                  turns: refreshAnim,
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: AppTheme.primaryColor,
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

// -------------------------------------------------------------
// Component 2: Modern Period Capsule Selector
// -------------------------------------------------------------

class _PeriodCapsuleSelector extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PeriodCapsuleSelector({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFECEFF3),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isSelected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF334155) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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

// -------------------------------------------------------------
// Component 3: Hero Financial Card (Donut + Touch Inspector)
// -------------------------------------------------------------

class _HeroFinancialCard extends StatelessWidget {
  final String periodTitle;
  final _DashboardMetrics metrics;
  final bool isPrivacyMode;
  final String? selectedDonutCategory;
  final ValueChanged<String> onSelectDonutCategory;

  const _HeroFinancialCard({
    required this.periodTitle,
    required this.metrics,
    required this.isPrivacyMode,
    required this.selectedDonutCategory,
    required this.onSelectDonutCategory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balance = metrics.balance;
    final isHealthy = balance >= 0;

    // Active inspection data
    String centerLabel = context.tr('คงเหลือสุทธิ', 'Net Balance');
    String centerValue = '฿${_fmtMoney(balance, compact: true, isPrivacy: isPrivacyMode)}';
    Color centerColor = isHealthy ? AppTheme.primaryColor : const Color(0xFFF43F5E);
    String centerSub = '';

    if (selectedDonutCategory == 'income') {
      centerLabel = context.tr('รายรับ', 'Income');
      centerValue = '฿${_fmtMoney(metrics.income, compact: true, isPrivacy: isPrivacyMode)}';
      centerColor = const Color(0xFF10B981);
      final pct = metrics.totalFlow > 0 ? (metrics.income / metrics.totalFlow * 100) : 0.0;
      centerSub = '${pct.toStringAsFixed(0)}% ของเงินหมุนเวียน';
    } else if (selectedDonutCategory == 'expense') {
      centerLabel = context.tr('รายจ่าย', 'Expense');
      centerValue = '฿${_fmtMoney(metrics.expense, compact: true, isPrivacy: isPrivacyMode)}';
      centerColor = const Color(0xFFF43F5E);
      final pct = metrics.totalFlow > 0 ? (metrics.expense / metrics.totalFlow * 100) : 0.0;
      centerSub = '${pct.toStringAsFixed(0)}% ของเงินหมุนเวียน';
    } else if (selectedDonutCategory == 'saving') {
      centerLabel = context.tr('เงินออม', 'Savings');
      centerValue = '฿${_fmtMoney(metrics.saving, compact: true, isPrivacy: isPrivacyMode)}';
      centerColor = const Color(0xFF8B5CF6);
      final pct = metrics.totalFlow > 0 ? (metrics.saving / metrics.totalFlow * 100) : 0.0;
      centerSub = '${pct.toStringAsFixed(0)}% ของเงินหมุนเวียน';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header inside card
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: isHealthy ? AppTheme.primaryColor : const Color(0xFFF43F5E),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isHealthy ? AppTheme.primaryColor : const Color(0xFFF43F5E))
                          .withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ภาพรวม$periodTitle',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),

              // Health Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isHealthy
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFF43F5E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHealthy ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      size: 12,
                      color: isHealthy ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isHealthy
                          ? context.tr('คล่องตัวดี', 'Healthy')
                          : context.tr('รายจ่ายเกิน', 'Deficit'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isHealthy ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Donut + 3 Stat Bars
          Row(
            children: [
              // Interactive Donut Chart
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSelectDonutCategory('');
                },
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: _ModernDonutChartPainter(
                      income: metrics.income,
                      expense: metrics.expense,
                      saving: metrics.saving,
                      selectedCategory: selectedDonutCategory,
                      isDark: isDark,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              centerLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              centerValue,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: centerColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (centerSub.isNotEmpty)
                              Text(
                                centerSub,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w600,
                                  color: centerColor.withValues(alpha: 0.8),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // 3 Category Stat Buttons (Interactive)
              Expanded(
                child: Column(
                  children: [
                    _DonutLegendPill(
                      categoryKey: 'income',
                      label: context.tr('รายรับ (Income)', 'Income'),
                      amount: metrics.income,
                      color: const Color(0xFF10B981),
                      icon: Icons.north_east_rounded,
                      isSelected: selectedDonutCategory == 'income',
                      isPrivacy: isPrivacyMode,
                      onTap: () => onSelectDonutCategory('income'),
                    ),
                    const SizedBox(height: 8),
                    _DonutLegendPill(
                      categoryKey: 'expense',
                      label: context.tr('รายจ่าย (Expense)', 'Expenses'),
                      amount: metrics.expense,
                      color: const Color(0xFFF43F5E),
                      icon: Icons.south_west_rounded,
                      isSelected: selectedDonutCategory == 'expense',
                      isPrivacy: isPrivacyMode,
                      onTap: () => onSelectDonutCategory('expense'),
                    ),
                    const SizedBox(height: 8),
                    _DonutLegendPill(
                      categoryKey: 'saving',
                      label: context.tr('เงินออม (Savings)', 'Savings'),
                      amount: metrics.saving,
                      color: const Color(0xFF8B5CF6),
                      icon: Icons.savings_rounded,
                      isSelected: selectedDonutCategory == 'saving',
                      isPrivacy: isPrivacyMode,
                      onTap: () => onSelectDonutCategory('saving'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hint under donut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 13,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    selectedDonutCategory == null
                        ? context.tr(
                            'แตะที่แถบสีหรือวงแหวน เพื่อดูสัดส่วนและรายละเอียด',
                            'Tap ring or category pills to inspect percentage',
                          )
                        : context.tr(
                            'แตะอีกครั้งเพื่อกลับสู่ยอดสุทธิรวม',
                            'Tap again to reset back to net balance view',
                          ),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
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

class _DonutLegendPill extends StatelessWidget {
  final String categoryKey;
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final bool isPrivacy;
  final VoidCallback onTap;

  const _DonutLegendPill({
    required this.categoryKey,
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.isPrivacy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.25 : 0.12)
                : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
              Text(
                '฿${_fmtMoney(amount, isPrivacy: isPrivacy)}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter for Interactive Donut
class _ModernDonutChartPainter extends CustomPainter {
  final double income;
  final double expense;
  final double saving;
  final String? selectedCategory;
  final bool isDark;

  const _ModernDonutChartPainter({
    required this.income,
    required this.expense,
    required this.saving,
    required this.selectedCategory,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 13.0;

    // Track background ring
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF334155).withValues(alpha: 0.4) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    final total = income + expense + saving;
    if (total <= 0) return;

    final incomeAngle = (income / total) * 2 * math.pi;
    final expenseAngle = (expense / total) * 2 * math.pi;
    final savingAngle = (saving / total) * 2 * math.pi;

    var startAngle = -math.pi / 2;

    void drawArcSegment(double sweepAngle, Color color, bool isCurrent) {
      if (sweepAngle <= 0.005) return;
      final paint = Paint()
        ..color = isCurrent ? color : color.withValues(alpha: selectedCategory == null ? 1.0 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCurrent ? strokeWidth + 3 : strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + 0.04,
        sweepAngle - 0.08,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    drawArcSegment(incomeAngle, const Color(0xFF10B981), selectedCategory == 'income');
    drawArcSegment(expenseAngle, const Color(0xFFF43F5E), selectedCategory == 'expense');
    drawArcSegment(savingAngle, const Color(0xFF8B5CF6), selectedCategory == 'saving');
  }

  @override
  bool shouldRepaint(covariant _ModernDonutChartPainter old) {
    return old.income != income ||
        old.expense != expense ||
        old.saving != saving ||
        old.selectedCategory != selectedCategory ||
        old.isDark != isDark;
  }
}

// -------------------------------------------------------------
// Component 4: Interactive Chart Hub (3 Modes Switcher)
// -------------------------------------------------------------

class _InteractiveChartHub extends StatelessWidget {
  final int selectedMode;
  final ValueChanged<int> onSelectMode;
  final bool isPrivacyMode;
  final List<MonthlyFinancePoint> monthlyPoints;
  final List<double> dailyOutflow;
  final List<_CategoryBreakdown> categoryBreakdowns;
  final int? highlightedMonthIndex;
  final ValueChanged<int?> onHighlightMonth;
  final String? selectedCategoryFilter;
  final ValueChanged<String> onSelectCategoryFilter;

  const _InteractiveChartHub({
    required this.selectedMode,
    required this.onSelectMode,
    required this.isPrivacyMode,
    required this.monthlyPoints,
    required this.dailyOutflow,
    required this.categoryBreakdowns,
    required this.highlightedMonthIndex,
    required this.onHighlightMonth,
    required this.selectedCategoryFilter,
    required this.onSelectCategoryFilter,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with 3 Tab Switchers
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('ศูนย์วิเคราะห์การเงิน', 'Financial Insights'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _MiniChartTab(
                      label: context.tr('รายเดือน', 'Monthly'),
                      icon: Icons.bar_chart_rounded,
                      isSelected: selectedMode == 0,
                      onTap: () => onSelectMode(0),
                    ),
                    _MiniChartTab(
                      label: context.tr('7 วัน', '7-Day'),
                      icon: Icons.show_chart_rounded,
                      isSelected: selectedMode == 1,
                      onTap: () => onSelectMode(1),
                    ),
                    _MiniChartTab(
                      label: context.tr('หมวดหมู่', 'Category'),
                      icon: Icons.pie_chart_outline_rounded,
                      isSelected: selectedMode == 2,
                      onTap: () => onSelectMode(2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Content according to selectedMode
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: selectedMode == 0
                ? _MonthlyPanoramicBarChart(
                    points: monthlyPoints,
                    isPrivacy: isPrivacyMode,
                    highlightedIndex: highlightedMonthIndex,
                    onHighlight: onHighlightMonth,
                  )
                : selectedMode == 1
                ? _SevenDayOutflowChart(
                    outflow: dailyOutflow,
                    isPrivacy: isPrivacyMode,
                  )
                : _CategoryBreakdownList(
                    breakdowns: categoryBreakdowns,
                    isPrivacy: isPrivacyMode,
                    selectedFilter: selectedCategoryFilter,
                    onSelectFilter: onSelectCategoryFilter,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MiniChartTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MiniChartTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF334155) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? AppTheme.primaryColor
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Sub-Mode A: Monthly Panoramic Bar Chart with Interactive Inspector
// -------------------------------------------------------------

class _MonthlyPanoramicBarChart extends StatelessWidget {
  final List<MonthlyFinancePoint> points;
  final bool isPrivacy;
  final int? highlightedIndex;
  final ValueChanged<int?> onHighlight;

  const _MonthlyPanoramicBarChart({
    required this.points,
    required this.isPrivacy,
    required this.highlightedIndex,
    required this.onHighlight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (points.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(
            context.tr('ไม่มีข้อมูลเปรียบเทียบ', 'No comparison data'),
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    final maxVal = points.fold<double>(1.0, (cur, p) {
      return math.max(cur, math.max(p.income, math.max(p.expense, p.saving)));
    });

    // Default to latest month if none highlighted
    final activeIdx = highlightedIndex ?? (points.length - 1);
    final activePoint = points[activeIdx.clamp(0, points.length - 1)];

    final monthNames = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];

    return Column(
      children: [
        // Active Month Tooltip Inspector Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${monthNames[activePoint.month.month - 1]} ${(activePoint.month.year + 543) % 100}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MiniStatValue(
                      label: context.tr('รับ', 'In'),
                      amount: activePoint.income,
                      color: const Color(0xFF10B981),
                      isPrivacy: isPrivacy,
                    ),
                    _MiniStatValue(
                      label: context.tr('จ่าย', 'Out'),
                      amount: activePoint.expense,
                      color: const Color(0xFFF43F5E),
                      isPrivacy: isPrivacy,
                    ),
                    _MiniStatValue(
                      label: context.tr('ออม', 'Save'),
                      amount: activePoint.saving,
                      color: const Color(0xFF8B5CF6),
                      isPrivacy: isPrivacy,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Panoramic Bar Chart ScrollView
        SizedBox(
          height: 125,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            reverse: false,
            physics: const BouncingScrollPhysics(),
            itemCount: points.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final p = points[index];
              final isCurrent = index == activeIdx;
              final incomeH = (p.income / maxVal) * 80;
              final expenseH = (p.expense / maxVal) * 80;
              final savingH = (p.saving / maxVal) * 80;

              return GestureDetector(
                onTap: () => onHighlight(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? (isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? AppTheme.primaryColor : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Bars
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Income bar
                            _RoundedVerticalBar(
                              height: math.max(3.0, incomeH),
                              color: const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 2.5),
                            // Expense bar
                            _RoundedVerticalBar(
                              height: math.max(3.0, expenseH),
                              color: const Color(0xFFF43F5E),
                            ),
                            const SizedBox(width: 2.5),
                            // Saving bar
                            _RoundedVerticalBar(
                              height: math.max(2.0, savingH),
                              color: const Color(0xFF8B5CF6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        monthNames[p.month.month - 1],
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                          color: isCurrent
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniStatValue extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isPrivacy;

  const _MiniStatValue({
    required this.label,
    required this.amount,
    required this.color,
    required this.isPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
        ),
        Text(
          '฿${_fmtMoney(amount, compact: true, isPrivacy: isPrivacy)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RoundedVerticalBar extends StatelessWidget {
  final double height;
  final Color color;

  const _RoundedVerticalBar({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7.5,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Sub-Mode B: 7-Day Outflow Daily Chart
// -------------------------------------------------------------

class _SevenDayOutflowChart extends StatelessWidget {
  final List<double> outflow;
  final bool isPrivacy;

  const _SevenDayOutflowChart({required this.outflow, required this.isPrivacy});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxVal = outflow.fold<double>(1.0, math.max);
    final daysOfWeek = ['6 วันก่อน', '5 วันก่อน', '4 วันก่อน', '3 วันก่อน', '2 วันก่อน', 'เมื่อวาน', 'วันนี้'];
    final maxIndex = outflow.indexOf(maxVal);

    return Column(
      children: [
        // Daily spending bars
        SizedBox(
          height: 140,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final val = outflow[index];
              final isPeak = index == maxIndex && val > 0;
              final height = (val / maxVal) * 85;

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isPeak)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '🔥 สูงสุด',
                        style: TextStyle(fontSize: 7.5, color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    )
                  else
                    const SizedBox(height: 14),

                  Text(
                    val <= 0 ? '0' : _fmtMoney(val, compact: true, isPrivacy: isPrivacy),
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: isPeak ? const Color(0xFFF43F5E) : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 20,
                    height: math.max(6.0, height),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isPeak
                            ? [const Color(0xFFF43F5E), const Color(0xFFFB7185)]
                            : [
                                AppTheme.primaryColor,
                                AppTheme.primaryColor.withValues(alpha: 0.6),
                              ],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    daysOfWeek[index],
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// Sub-Mode C: Category Spending Breakdown
// -------------------------------------------------------------

class _CategoryBreakdownList extends StatelessWidget {
  final List<_CategoryBreakdown> breakdowns;
  final bool isPrivacy;
  final String? selectedFilter;
  final ValueChanged<String> onSelectFilter;

  const _CategoryBreakdownList({
    required this.breakdowns,
    required this.isPrivacy,
    required this.selectedFilter,
    required this.onSelectFilter,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (breakdowns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Column(
            children: [
              Icon(Icons.category_outlined, size: 28, color: const Color(0xFF94A3B8)),
              const SizedBox(height: 6),
              Text(
                context.tr('ยังไม่มีข้อมูลรายจ่ายในหมวดหมู่นี้', 'No categorized expense data'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: List.generate(math.min(5, breakdowns.length), (index) {
        final item = breakdowns[index];
        final isSelected = selectedFilter == item.meta.name;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelectFilter(item.meta.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? item.meta.color.withValues(alpha: isDark ? 0.2 : 0.08)
                    : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? item.meta.color : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: item.meta.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.meta.icon, size: 14, color: item.meta.color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.meta.name,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        '${item.percentage.toStringAsFixed(0)}%  ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '฿${_fmtMoney(item.amount, isPrivacy: isPrivacy)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: item.meta.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (item.percentage / 100).clamp(0.0, 1.0),
                      minHeight: 4.5,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation(item.meta.color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// -------------------------------------------------------------
// Component 5: 4-Card Smart Financial KPI Grid
// -------------------------------------------------------------

class _FinancialKpiGrid extends StatelessWidget {
  final double savingRate;
  final double spendingRate;
  final double dailyBurnRate;
  final int totalTxCount;
  final bool isPrivacyMode;

  const _FinancialKpiGrid({
    required this.savingRate,
    required this.spendingRate,
    required this.dailyBurnRate,
    required this.totalTxCount,
    required this.isPrivacyMode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.savings_rounded,
                color: const Color(0xFF8B5CF6),
                title: context.tr('อัตราการออม', 'Savings Rate'),
                value: '${savingRate.toStringAsFixed(0)}%',
                subtitle: savingRate >= 20 ? '🎉 บรรลุเป้าหมาย' : '🎯 แนะนำ 20%+',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.pie_chart_rounded,
                color: spendingRate > 100
                    ? const Color(0xFFF43F5E)
                    : spendingRate > 75
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981),
                title: context.tr('ใช้จ่ายต่อรายรับ', 'Expense/Income'),
                value: '${spendingRate.toStringAsFixed(0)}%',
                subtitle: spendingRate > 100 ? '⚠️ ระวังใช้เกินตัว' : '✅ คุมงบได้ดี',
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFEF4444),
                title: context.tr('เฉลี่ยจ่ายต่อวัน', 'Daily Burn'),
                value: '฿${_fmtMoney(dailyBurnRate, compact: true, isPrivacy: isPrivacyMode)}',
                subtitle: context.tr('ความเร็วการใช้เงิน', 'Spending speed'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF06B6D4),
                title: context.tr('จำนวนรายการ', 'Activity'),
                value: '$totalTxCount',
                subtitle: context.tr('รายการบันทึก', 'Recorded entries'),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;
  final bool isDark;

  const _KpiCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
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

// -------------------------------------------------------------
// Component 6: Recent Transactions Header & Filter Chips
// -------------------------------------------------------------

class _RecentTransactionsHeader extends StatelessWidget {
  final int totalCount;
  final bool showSearch;
  final String searchQuery;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;

  const _RecentTransactionsHeader({
    required this.totalCount,
    required this.showSearch,
    required this.searchQuery,
    required this.onToggleSearch,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    context.tr('รายการล่าสุด', 'Recent entries'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$totalCount',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.tr('ค้นหา', 'Search'),
              onPressed: onToggleSearch,
              icon: Icon(
                showSearch ? Icons.close_rounded : Icons.search_rounded,
                size: 20,
                color: showSearch ? const Color(0xFFF43F5E) : AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        if (showSearch)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: TextField(
              autofocus: true,
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: context.tr('พิมพ์คำค้น เช่น ขนม, ค่าไฟ, ชื่อผู้รับ...', 'Search by keyword...'),
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TransactionTypeChips extends StatelessWidget {
  final String selectedType;
  final String? selectedCategoryFilter;
  final VoidCallback onClearCategoryFilter;
  final ValueChanged<String> onSelectType;

  const _TransactionTypeChips({
    required this.selectedType,
    required this.selectedCategoryFilter,
    required this.onClearCategoryFilter,
    required this.onSelectType,
  });

  @override
  Widget build(BuildContext context) {
    final types = [
      {'key': 'all', 'th': 'ทั้งหมด', 'en': 'All'},
      {'key': 'income', 'th': 'รายรับ', 'en': 'Income'},
      {'key': 'expense', 'th': 'รายจ่าย', 'en': 'Expense'},
      {'key': 'saving', 'th': 'เงินออม', 'en': 'Savings'},
      {'key': 'transfer', 'th': 'ย้ายเงิน', 'en': 'Transfers'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          if (selectedCategoryFilter != null) ...[
            GestureDetector(
              onTap: onClearCategoryFilter,
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedCategoryFilter!,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
          ...types.map((t) {
            final isSelected = selectedType == t['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                showCheckmark: false,
                label: Text(context.tr(t['th']!, t['en']!)),
                labelStyle: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
                selected: isSelected,
                selectedColor: AppTheme.primaryColor,
                backgroundColor: context.surfaceColor,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primaryColor : context.borderColor,
                  ),
                ),
                onSelected: (_) => onSelectType(t['key']!),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Component 7: Interactive Recent Transactions with Accordion
// -------------------------------------------------------------

class _InteractiveRecentTransactionsList extends StatelessWidget {
  final List<dynamic> transactions;
  final int visibleCount;
  final bool isPrivacyMode;
  final int? expandedId;
  final ValueChanged<int> onToggleExpand;
  final VoidCallback onLoadMore;

  const _InteractiveRecentTransactionsList({
    required this.transactions,
    required this.visibleCount,
    required this.isPrivacyMode,
    required this.expandedId,
    required this.onToggleExpand,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 32, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(
              context.tr('ไม่พบรายการที่ตรงกับเงื่อนไข', 'No matching transactions'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    final visible = transactions.take(visibleCount).toList();
    final hasMore = visible.length < transactions.length;
    final remaining = transactions.length - visible.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          ...List.generate(visible.length, (index) {
            final tx = Map<String, dynamic>.from(visible[index] as Map);
            final id = int.tryParse(tx['id']?.toString() ?? '') ?? index;
            final isExpanded = expandedId == id;

            return _TransactionAccordionTile(
              transaction: tx,
              isExpanded: isExpanded,
              isPrivacy: isPrivacyMode,
              showDivider: index < visible.length - 1 || hasMore,
              onTap: () => onToggleExpand(id),
            );
          }),

          // Load More button
          if (hasMore)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                onTap: onLoadMore,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ดูเพิ่มอีก 8 รายการ (เหลืออีก $remaining)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (transactions.length > 8)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'แสดงครบทั้งหมดแล้ว (${transactions.length} รายการ)',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionAccordionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final bool isExpanded;
  final bool isPrivacy;
  final bool showDivider;
  final VoidCallback onTap;

  const _TransactionAccordionTile({
    required this.transaction,
    required this.isExpanded,
    required this.isPrivacy,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawNote = transaction['note']?.toString() ?? 'รายการ';
    final source = transaction['source']?.toString();
    final dreamId = transaction['dream_id']?.toString();
    final isTransfer = FinanceDashboardScreen.isTransferTransaction(transaction);
    final isSaving = !isTransfer && (source == 'dream_saving' || dreamId != null || rawNote.startsWith('[ออม]'));
    final isIncome = !isTransfer && transaction['type'] == 'income';

    final Color color = isTransfer
        ? const Color(0xFF06B6D4)
        : isSaving
        ? const Color(0xFF8B5CF6)
        : isIncome
        ? const Color(0xFF10B981)
        : const Color(0xFFF43F5E);

    final cleanNote = rawNote
        .replaceAll(RegExp(r'\[สลิป\s+[^\]]+\]'), '')
        .replaceAll(RegExp(r'\[ย้ายเงิน\s+[^\]]+\]'), '')
        .replaceAll('[ย้ายเงิน]', '')
        .replaceAll(RegExp(r'\[Ref:[^\]]+\]'), '')
        .replaceAll('[รายจ่ายประจำ]', '')
        .replaceAll('[รายรับประจำ]', '')
        .replaceAll('[ออม] หยอดกระปุก:', '')
        .trim();

    final date = DateTime.tryParse(transaction['transaction_date']?.toString() ?? '')?.toLocal();
    final amount = num.tryParse(transaction['amount']?.toString() ?? '')?.toDouble() ?? 0.0;
    final cat = _detectCategory(rawNote);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  // Icon Avatar
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isTransfer
                          ? Icons.swap_horiz_rounded
                          : isSaving
                          ? Icons.savings_rounded
                          : isIncome
                          ? Icons.north_east_rounded
                          : cat.icon,
                      size: 19,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title & Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cleanNote.isEmpty
                              ? (isTransfer ? 'ย้ายเงินระหว่างบัญชี' : 'รายการทั่วไป')
                              : cleanNote,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (date != null)
                              Text(
                                '${date.day}/${date.month}/${date.year + 543}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              ),
                            if (!isTransfer && !isIncome && !isSaving) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFCBD5E1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: cat.color,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Amount & Arrow
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isTransfer
                            ? '฿${_fmtMoney(amount, isPrivacy: isPrivacy)}'
                            : '${isIncome ? '+' : '-'}฿${_fmtMoney(amount, isPrivacy: isPrivacy)}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Accordion Expansion Detail
        if (isExpanded)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                    label: context.tr('บันทึกฉบับเต็ม', 'Original note'),
                    value: rawNote,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _DetailRow(
                    label: context.tr('ประเภท', 'Type'),
                    value: isTransfer
                        ? 'ย้ายเงินระหว่างบัญชี'
                        : isSaving
                        ? 'หยอดกระปุกออมเงิน'
                        : isIncome
                        ? 'รายรับ'
                        : 'รายจ่าย (${cat.name})',
                    isDark: isDark,
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 6),
                    _DetailRow(
                      label: context.tr('เวลาที่บันทึก', 'Timestamp'),
                      value: '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น. (วันที่ ${date.day}/${date.month}/${date.year + 543})',
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
            ),
          ),

        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DetailRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
