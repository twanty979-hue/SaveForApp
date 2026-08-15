import 'dart:convert';
import 'package:app/core/localization/app_material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../auth/domain/auth_session.dart';

class SummaryScreen extends StatefulWidget {
  final VoidCallback? onRefreshHeader;
  const SummaryScreen({super.key, this.onRefreshHeader});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final ApiClient _apiClient = ApiClient();
  final String _activeUserId =
      AuthSession.userId ?? '5b2d488d-75a0-4ea4-8f14-43047d256c8d';

  bool _isLoading = true;
  String _selectedSegment =
      'เดือนนี้'; // 'เดือนนี้', 'เดือนที่แล้ว', '30 วัน', 'ทั้งหมด'

  List<dynamic> _transactions = [];
  List<dynamic> _dreams = [];
  List<dynamic> _incomeSources = [];

  // สำหรับปฏิทินรายจ่ายรายวันแบบแสดงในแดชบอร์ด (ตามภาพที่สาม)
  int _calendarYear = 2026;
  int _calendarMonth = 8;

  @override
  void initState() {
    super.initState();
    _fetchSummaryData();
  }

  Future<void> _fetchSummaryData() async {
    try {
      final txResponse = await _apiClient.get(
        '/transactions?user_id=eq.$_activeUserId',
      );
      final dreamResponse = await _apiClient.get(
        '/dreams?user_id=eq.$_activeUserId',
      );
      final incomeResponse = await _apiClient.get(
        '/recurring/sources?user_id=eq.$_activeUserId',
      );

      if (txResponse.statusCode == 200 &&
          dreamResponse.statusCode == 200 &&
          incomeResponse.statusCode == 200) {
        setState(() {
          _transactions = jsonDecode(txResponse.body);
          _dreams = jsonDecode(dreamResponse.body);
          _incomeSources = jsonDecode(incomeResponse.body);
          _isLoading = false;
        });
        if (widget.onRefreshHeader != null) {
          widget.onRefreshHeader!();
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // คำนวณยอดเงินตามประเภทและช่วงเวลาที่เลือก
  Map<String, double> _calculateMetrics() {
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    double totalSavings = 0.0;

    final now = DateTime.now();

    // 1. คำนวณเงินออมสะสมจากคลังความฝัน (ไม่ขึ้นกับฟิลเตอร์เวลาของรายรับรายจ่าย)
    for (var dream in _dreams) {
      totalSavings += (dream['current_amount'] as num).toDouble();
    }

    // 2. คำนวณรายรับ (จากแหล่งรายรับและรายการเงินฝาก)
    for (var source in _incomeSources) {
      totalIncome += (source['amount'] as num).toDouble();
    }

    // 3. กรองธุรกรรมตามเซกเมนต์ช่วงเวลา
    for (var tx in _transactions) {
      final dateStr = tx['transaction_date'] ?? '';
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      bool isInRange = false;
      if (_selectedSegment == 'เดือนนี้') {
        isInRange = date.year == now.year && date.month == now.month;
      } else if (_selectedSegment == 'เดือนที่แล้ว') {
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        isInRange = date.year == prevYear && date.month == prevMonth;
      } else if (_selectedSegment == '30 วัน') {
        isInRange = now.difference(date).inDays <= 30;
      } else {
        isInRange = true; // ทั้งหมด
      }

      if (isInRange) {
        final amt = (tx['amount'] as num).toDouble();
        if (tx['type'] == 'expense') {
          totalExpense += amt;
        } else if (tx['type'] == 'income') {
          totalIncome += amt;
        }
      }
    }

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'savings': totalSavings,
      'net': totalIncome - totalExpense,
    };
  }

  // ตัวสร้างกริดวันปฏิทิน 42 ช่อง
  List<DateTime> _generateCalendarDays() {
    List<DateTime> days = [];
    final firstDay = DateTime(_calendarYear, _calendarMonth, 1);
    final prevMonthEnd = DateTime(_calendarYear, _calendarMonth, 0);
    final currentMonthEnd = DateTime(_calendarYear, _calendarMonth + 1, 0);

    final startOffset = firstDay.weekday == 7 ? 0 : firstDay.weekday;

    // เดือนก่อนหน้า
    for (int i = startOffset - 1; i >= 0; i--) {
      days.add(
        DateTime(
          _calendarMonth == 1 ? _calendarYear - 1 : _calendarYear,
          _calendarMonth == 1 ? 12 : _calendarMonth - 1,
          prevMonthEnd.day - i,
        ),
      );
    }
    // เดือนปัจจุบัน
    for (int i = 1; i <= currentMonthEnd.day; i++) {
      days.add(DateTime(_calendarYear, _calendarMonth, i));
    }
    // เดือนถัดไป
    final remaining = 42 - days.length;
    for (int i = 1; i <= remaining; i++) {
      days.add(
        DateTime(
          _calendarMonth == 12 ? _calendarYear + 1 : _calendarYear,
          _calendarMonth == 12 ? 1 : _calendarMonth + 1,
          i,
        ),
      );
    }

    return days;
  }

  String _getMonthName(int month) {
    const names = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFBFD),
        appBar: AppBar(title: Text(context.tr('สรุปยอด', 'Summary'))),
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    final metrics = _calculateMetrics();
    final income = metrics['income']!;
    final expense = metrics['expense']!;
    final savings = metrics['savings']!;
    final net = metrics['net']!;

    // คำนวณร้อยละส่วนต่างรายรับรายจ่าย
    double incomePercent = 0.0;
    double expensePercent = 0.0;
    if (income + expense > 0) {
      incomePercent = (income / (income + expense)) * 100;
      expensePercent = (expense / (income + expense)) * 100;
    } else {
      expensePercent = 100; // ดีฟอลต์หากไม่มีประวัติรายการ
    }

    final calendarDays = _generateCalendarDays();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        title: Text(context.tr('สรุปยอด', 'Summary')),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: ResponsiveLayout(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ส่วนหัววิเคราะห์แดชบอร์ด
              Row(
                children: [
                  const Text(
                    'วิเคราะห์แดชบอร์ด',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.sync, color: Color(0xFF00A88F)),
                    onPressed: _fetchSummaryData,
                  ),
                ],
              ),
              Text(
                'รายงานประจำเดือน ${_getMonthName(DateTime.now().month)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // ปุ่มเซกเมนต์ช่วงเวลา
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: ['เดือนนี้', 'เดือนที่แล้ว', '30 วัน', 'ทั้งหมด']
                      .map((seg) {
                        final isSelected = _selectedSegment == seg;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSegment = seg;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                seg,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF64748B),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),

              // การ์ดแสดงผลสถิติ 4 ช่อง
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  // 1. รายรับรวม
                  _buildMetricCard(
                    title: 'รายรับรวม',
                    value: '฿${income.toStringAsFixed(0)}',
                    valueColor: const Color(0xFF10B981),
                    subtitle: 'คลิกเพื่อดูรายละเอียด',
                    icon: Icons.trending_up,
                  ),
                  // 2. รายจ่ายรวม
                  _buildMetricCard(
                    title: 'รายจ่ายรวม',
                    value: '฿${expense.toStringAsFixed(0)}',
                    valueColor: const Color(0xFFEF4444),
                    subtitle: 'คลิกเพื่อดูรายละเอียด',
                    icon: Icons.trending_down,
                  ),
                  // 3. เงินออมสะสม
                  _buildMetricCard(
                    title: 'เงินออมสะสม',
                    value: '฿${savings.toStringAsFixed(0)}',
                    valueColor: const Color(0xFFF59E0B),
                    subtitle: 'คลิกเพื่อดูเงินออม',
                    icon: Icons.savings_outlined,
                  ),
                  // 4. คงเหลือสุทธิ
                  _buildMetricCard(
                    title: 'คงเหลือสุทธิ',
                    value: '฿${net.toStringAsFixed(0)}',
                    valueColor: net >= 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    subtitle: 'เทียบ รายรับ-รายจ่าย',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // การ์ดอัตราส่วนรายรับรายจ่าย (Ratio Bar Card)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'รายรับ (${incomePercent.toStringAsFixed(0)}%)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        Text(
                          'รายจ่าย (${expensePercent.toStringAsFixed(0)}%)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // แถบสัดส่วน
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          children: [
                            if (incomePercent > 0)
                              Expanded(
                                flex: incomePercent.round(),
                                child: Container(
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            if (expensePercent > 0)
                              Expanded(
                                flex: expensePercent.round(),
                                child: Container(
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // หัวตารางปฏิทินรายจ่าย
              const Text(
                'ปฏิทินรายจ่าย',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),

              // กล่องปฏิทินรายจ่ายแสดงผลแบบ Inline (ตามรูปภาพ)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // ตัวนำทางเดือนปี
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: () {
                            setState(() {
                              if (_calendarMonth == 1) {
                                _calendarMonth = 12;
                                _calendarYear--;
                              } else {
                                _calendarMonth--;
                              }
                            });
                          },
                        ),
                        Text(
                          '${_getMonthName(_calendarMonth)} ${_calendarYear + 543}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: () {
                            setState(() {
                              if (_calendarMonth == 12) {
                                _calendarMonth = 1;
                                _calendarYear++;
                              } else {
                                _calendarMonth++;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // วันในสัปดาห์
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          'อา',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'จ',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'อ',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'พ',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'พฤ',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'ศ',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'ส',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // กริดวัน 42 ช่อง
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 0.95,
                          ),
                      itemCount: 42,
                      itemBuilder: (context, index) {
                        final dayDate = calendarDays[index];
                        final isCurrentMonth = dayDate.month == _calendarMonth;

                        // คำนวณรายจ่ายของวัน
                        double spent = 0.0;
                        for (var tx in _transactions) {
                          final txDateStr = tx['transaction_date'] ?? '';
                          final txDate = DateTime.tryParse(txDateStr);
                          if (txDate != null &&
                              txDate.year == dayDate.year &&
                              txDate.month == dayDate.month &&
                              txDate.day == dayDate.day &&
                              tx['type'] == 'expense') {
                            spent += (tx['amount'] as num).toDouble();
                          }
                        }

                        // ในรูปภาพมีไฮไลต์ขอบสีเขียวหนาสำหรับวันที่เลือกหรือวันนี้ที่มีประวัติ
                        final isHighlighted = spent > 0 && isCurrentMonth;

                        return Container(
                          decoration: BoxDecoration(
                            color: isHighlighted
                                ? const Color(0xFFE6F4F1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isHighlighted
                                  ? AppTheme.primaryColor
                                  : Colors.transparent,
                              width: isHighlighted ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${dayDate.day}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentMonth
                                      ? (isHighlighted
                                            ? AppTheme.primaryColor
                                            : const Color(0xFF334155))
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              if (spent > 0 && isCurrentMonth) ...[
                                const SizedBox(height: 1),
                                Text(
                                  spent.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ส่วนคำแนะนำการเงินส่วนตัว (Personal Finance Advice)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xFFD97706),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'คำแนะนำการเงินส่วนตัว',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'สิงหาคมนี้ คุณมียอดรายจ่ายประจำเกิดขึ้น ฿${expense.toStringAsFixed(0)} และเก็บออมเงินได้สำเร็จในระดับหนึ่งแล้ว พยายามควบคุมยอดค่าใช้จ่ายที่ไม่จำเป็นเพื่อรักษาสมดุลของกระปุกออมเงินของคุณนะครับ',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB45309),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ตัวสรุปหน้าตา Metric Card (รายรับ/รายจ่าย/ออม)
  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color valueColor,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 9, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
