import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/auth_session.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../../dreams/presentation/dreams_screen.dart';
import '../../recurring/presentation/recurring_expense_screen.dart';
import '../../recurring/presentation/recurring_income_screen.dart';
import './summary_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 4; // เริ่มต้นที่หน้าสรุปยอด (Dashboard)

  final ApiClient _apiClient = ApiClient();
  final String _activeUserId = AuthSession.userId ?? '5b2d488d-75a0-4ea4-8f14-43047d256c8d';

  double _todaySpent = 0.0;
  double _monthSpent = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchHeaderTotals();
  }

  Future<void> _fetchHeaderTotals() async {
    try {
      final response = await _apiClient.get('/transactions?user_id=eq.$_activeUserId');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final now = DateTime.now();

        double todaySum = 0.0;
        double monthSum = 0.0;

        for (var tx in data) {
          if (tx['type'] == 'expense') {
            final dateStr = tx['transaction_date'] ?? '';
            final date = DateTime.tryParse(dateStr);
            if (date == null) continue;

            final amt = (tx['amount'] as num).toDouble();

            if (date.year == now.year && date.month == now.month) {
              monthSum += amt;
            }
            if (date.year == now.year && date.month == now.month && date.day == now.day) {
              todaySum += amt;
            }
          }
        }

        setState(() {
          _todaySpent = todaySum;
          _monthSpent = monthSum;
        });
      }
    } catch (e) {
      // ดำเนินการเงียบ
    }
  }

  void _showCalendarBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return const _CalendarBottomSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const TransactionsScreen(),
      const RecurringExpenseScreen(),
      const RecurringIncomeScreen(),
      const DreamsScreen(),
      SummaryScreen(onRefreshHeader: _fetchHeaderTotals),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      body: SafeArea(
        child: Column(
          children: [
            // แผงโปรไฟล์ผู้ใช้งานด้านบนสุด (Profile Bar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6F4F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AuthSession.displayName ?? 'วรธน นำทอง',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'วันนี้: ฿${_todaySpent.toStringAsFixed(0)}  |  เดือนนี้: ฿${_monthSpent.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedIndex != 4)
                    IconButton(
                      icon: const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      onPressed: _showCalendarBottomSheet,
                    ),
                ],
              ),
            ),
            Expanded(
              child: screens[_selectedIndex],
            ),
            // แผงแถบเมนูนำทางล่างสุด (Bottom Navigation Bar) ปรับดีไซน์ตามรูปแบบที่ถูกแก้ตรงตามภาพครอป
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              ),
              child: Row(
                children: [
                  _buildBottomTab(0, Icons.chat_bubble_outline, Icons.chat_bubble, 'แชต', const Color(0xFF00A88F)),
                  _buildBottomTab(1, Icons.assignment_outlined, Icons.assignment, 'รายจ่าย', const Color(0xFFFF1744)),
                  _buildBottomTab(2, Icons.trending_up_outlined, Icons.trending_up, 'รายรับ', const Color(0xFF10B981)),
                  _buildBottomTab(3, Icons.star_outline, Icons.star, 'ความฝัน', const Color(0xFFF59E0B)),
                  _buildBottomTab(4, Icons.bar_chart_outlined, Icons.bar_chart, 'สรุปยอด', const Color(0xFF1E293B)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ตัวสร้างปุ่มแบบเรียบหรู คลาสสิก ไม่มีขอบกรอบสี่เหลี่ยมหนาๆ ครอบไอคอนอีกต่อไปตามความพึงพอใจและภาพครอปของผู้ใช้
  Widget _buildBottomTab(int index, IconData outlineIcon, IconData filledIcon, String label, Color activeColor) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          _fetchHeaderTotals();
        },
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? filledIcon : outlineIcon,
                color: isSelected ? activeColor : const Color(0xFF94A3B8),
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? activeColor : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarCell {
  final int day;
  final int month;
  final int year;
  final bool isCurrentMonth;

  _CalendarCell({
    required this.day,
    required this.month,
    required this.year,
    required this.isCurrentMonth,
  });
}

class _CalendarBottomSheet extends StatefulWidget {
  const _CalendarBottomSheet();

  @override
  State<_CalendarBottomSheet> createState() => _CalendarBottomSheetState();
}

class _CalendarBottomSheetState extends State<_CalendarBottomSheet> {
  final ApiClient _apiClient = ApiClient();
  final String _activeUserId = AuthSession.userId ?? '5b2d488d-75a0-4ea4-8f14-43047d256c8d';

  bool _isLoading = true;
  List<dynamic> _transactions = [];
  double _grandTotal = 0.0;

  int _currentYear = 2026;
  int _currentMonth = 8;
  int _selectedDay = 1;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    try {
      final response = await _apiClient.get(
        '/transactions?user_id=eq.$_activeUserId',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        double total = 0.0;
        for (var tx in data) {
          if (tx['type'] == 'expense') {
            total += (tx['amount'] as num).toDouble();
          }
        }
        setState(() {
          _transactions = data;
          _grandTotal = total;
          _isLoading = false;
        });
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

  List<_CalendarCell> _generateCells() {
    List<_CalendarCell> cells = [];
    DateTime firstDay = DateTime(_currentYear, _currentMonth, 1);
    DateTime prevMonthEnd = DateTime(_currentYear, _currentMonth, 0);
    DateTime currentMonthEnd = DateTime(_currentYear, _currentMonth + 1, 0);

    int firstWeekday = firstDay.weekday;
    int startOffset = firstWeekday == 7 ? 0 : firstWeekday;

    int prevMonthDays = prevMonthEnd.day;
    for (int i = startOffset - 1; i >= 0; i--) {
      cells.add(_CalendarCell(
        day: prevMonthDays - i,
        month: _currentMonth == 1 ? 12 : _currentMonth - 1,
        year: _currentMonth == 1 ? _currentYear - 1 : _currentYear,
        isCurrentMonth: false,
      ));
    }

    for (int i = 1; i <= currentMonthEnd.day; i++) {
      cells.add(_CalendarCell(
        day: i,
        month: _currentMonth,
        year: _currentYear,
        isCurrentMonth: true,
      ));
    }

    int remaining = 42 - cells.length;
    for (int i = 1; i <= remaining; i++) {
      cells.add(_CalendarCell(
        day: i,
        month: _currentMonth == 12 ? 1 : _currentMonth + 1,
        year: _currentMonth == 12 ? _currentYear + 1 : _currentYear,
        isCurrentMonth: false,
      ));
    }

    return cells;
  }

  String _getMonthName(int month) {
    const names = [
      'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
      'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
    ];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final cells = _generateCells();
    final thYear = _currentYear + 543;

    final monthlyExpenses = _transactions.where((tx) {
      final dateStr = tx['transaction_date'] ?? '';
      final date = DateTime.tryParse(dateStr);
      return date != null &&
          date.year == _currentYear &&
          date.month == _currentMonth &&
          tx['type'] == 'expense';
    }).toList();

    double monthlyTotal = monthlyExpenses.fold(0.0, (sum, item) {
      return sum + (item['amount'] as num).toDouble();
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F4F1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'ปฏิทินรายจ่าย',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          'ดูรายจ่ายแยกตามวัน',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_getMonthName(_currentMonth)} $thYear',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Color(0xFF64748B)),
                          onPressed: () {
                            setState(() {
                              if (_currentMonth == 1) {
                                _currentMonth = 12;
                                _currentYear--;
                              } else {
                                _currentMonth--;
                              }
                              _selectedDay = 1;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                          onPressed: () {
                            setState(() {
                              if (_currentMonth == 12) {
                                _currentMonth = 1;
                                _currentYear++;
                              } else {
                                _currentMonth++;
                              }
                              _selectedDay = 1;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    Text('อา.', style: TextStyle(color: Color(0xFF00A88F), fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('จ.', style: TextStyle(color: Color(0xFF00A88F), fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('อ.', style: TextStyle(color: Color(0xFF00A88F), fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('พ.', style: TextStyle(color: Color(0xFF00A88F), fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('พฤ.', style: TextStyle(color: Color(0xFF00A88F), fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('ศ.', style: TextStyle(color: Color(0xFF00A88F), fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('ส.', style: TextStyle(color: Color(0xFF00A88F), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                _isLoading
                    ? const SizedBox(
                        height: 280,
                        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.95,
                        ),
                        itemCount: 42,
                        itemBuilder: (context, index) {
                          final cell = cells[index];
                          final date = DateTime(cell.year, cell.month, cell.day);

                          double spent = 0.0;
                          for (var tx in _transactions) {
                            final txDateStr = tx['transaction_date'] ?? '';
                            final txDate = DateTime.tryParse(txDateStr);
                            if (txDate != null &&
                                txDate.year == date.year &&
                                txDate.month == date.month &&
                                txDate.day == date.day &&
                                tx['type'] == 'expense') {
                              spent += (tx['amount'] as num).toDouble();
                            }
                          }

                          final isSelected = cell.isCurrentMonth && _selectedDay == cell.day;

                          return GestureDetector(
                            onTap: () {
                              if (cell.isCurrentMonth) {
                                setState(() {
                                  _selectedDay = cell.day;
                                });
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE6F4F1)
                                    : (cell.isCurrentMonth ? const Color(0xFFF8FAFC) : Colors.transparent),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : (cell.isCurrentMonth ? const Color(0xFFF1F5F9) : Colors.transparent),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${cell.day}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: cell.isCurrentMonth
                                          ? (isSelected ? AppTheme.primaryColor : const Color(0xFF1E293B))
                                          : const Color(0xFFCBD5E1),
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (spent > 0) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '฿${spent.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'รายการเดือน${_getMonthName(_currentMonth)} $thYear',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ),
                    Text(
                      'รวม ฿${monthlyTotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: monthlyExpenses.isEmpty
                      ? Center(
                          child: Text(
                            'ไม่มีรายจ่ายในเดือนนี้',
                            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                          ),
                        )
                      : ListView.builder(
                          itemCount: monthlyExpenses.length,
                          itemBuilder: (context, index) {
                            final tx = monthlyExpenses[index];
                            final amount = (tx['amount'] as num).toDouble();
                            return Card(
                              elevation: 0,
                              color: const Color(0xFFF8FAFC),
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                title: Text(tx['note'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('หมวดหมู่: ค่าใช้จ่ายรายวัน', style: TextStyle(color: Colors.grey[500])),
                                trailing: Text(
                                  '-฿${amount.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
                        children: [
                          const TextSpan(text: 'รายจ่ายรวมทุกวัน: '),
                          TextSpan(
                            text: '฿${_grandTotal.toStringAsFixed(0)}',
                            style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'ปิดหน้าต่าง',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
