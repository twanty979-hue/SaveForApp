import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:app/core/localization/app_material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/auth_session.dart';

class CompactCalendarSheet extends StatefulWidget {
  final void Function(DateTime)? onDateSelected;

  const CompactCalendarSheet({super.key, this.onDateSelected});

  @override
  State<CompactCalendarSheet> createState() => _CompactCalendarSheetState();
}

class _CompactCalendarSheetState extends State<CompactCalendarSheet> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _transactions = const [];
  bool _isLoading = true;

  late int _year;
  late int _month;
  late int _day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _day = now.day;
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final userId = AuthSession.userId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
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
            : const [];
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DateTime? _transactionDate(dynamic transaction) {
    final parsed = DateTime.tryParse(
      transaction['transaction_date']?.toString() ?? '',
    );
    return parsed?.toLocal();
  }

  List<dynamic> get _selectedTransactions {
    return _transactions.where((transaction) {
      final date = _transactionDate(transaction);
      return date != null &&
          date.year == _year &&
          date.month == _month &&
          date.day == _day;
    }).toList();
  }

  bool _hasTransactions(DateTime date) {
    return _transactions.any((transaction) {
      final transactionDate = _transactionDate(transaction);
      return transactionDate != null &&
          transactionDate.year == date.year &&
          transactionDate.month == date.month &&
          transactionDate.day == date.day;
    });
  }

  List<_CompactCalendarCell> _calendarCells() {
    final firstDay = DateTime(_year, _month, 1);
    final previousMonthEnd = DateTime(_year, _month, 0);
    final currentMonthEnd = DateTime(_year, _month + 1, 0);
    final sundayBasedOffset = firstDay.weekday == 7 ? 0 : firstDay.weekday;
    final cells = <_CompactCalendarCell>[];

    for (var index = sundayBasedOffset - 1; index >= 0; index--) {
      final date = DateTime(
        previousMonthEnd.year,
        previousMonthEnd.month,
        previousMonthEnd.day - index,
      );
      cells.add(_CompactCalendarCell(date: date, inCurrentMonth: false));
    }
    for (var day = 1; day <= currentMonthEnd.day; day++) {
      cells.add(
        _CompactCalendarCell(
          date: DateTime(_year, _month, day),
          inCurrentMonth: true,
        ),
      );
    }
    var nextDay = 1;
    final totalRows = (cells.length / 7).ceil();
    final targetLength = totalRows * 7;
    while (cells.length < targetLength) {
      cells.add(
        _CompactCalendarCell(
          date: DateTime(_year, _month + 1, nextDay++),
          inCurrentMonth: false,
        ),
      );
    }
    return cells;
  }

  void _changeMonth(int offset) {
    HapticFeedback.selectionClick();
    final target = DateTime(_year, _month + offset, 1);
    setState(() {
      _year = target.year;
      _month = target.month;
      _day = 1;
    });
  }

  Future<void> _showTransactionFormModal({
    Map<String, dynamic>? editingTransaction,
  }) async {
    final isEdit = editingTransaction != null;
    final noteController = TextEditingController(
      text: isEdit ? editingTransaction['note']?.toString() : '',
    );
    final amountController = TextEditingController(
      text: isEdit
          ? (num.tryParse(editingTransaction['amount']?.toString() ?? '')
                  ?.toDouble()
                  .toStringAsFixed(0) ??
              '')
          : '',
    );

    String type = isEdit
        ? (editingTransaction['type']?.toString() ?? 'expense')
        : 'expense';
    String category = isEdit
        ? (editingTransaction['category']?.toString() ?? 'ค่าอาหาร')
        : 'ค่าอาหาร';

    final expenseCategories = [
      'ค่าอาหาร',
      'ค่าเช่า',
      'ค่าเดินทาง',
      'ค่าไฟ',
      'ค่าน้ำ',
      'ค่าอินเทอร์เน็ต',
      'ค่ามือถือ',
      'ท่องเที่ยว',
      'อื่นๆ',
    ];
    final incomeCategories = [
      'เงินเดือน',
      'Freelance',
      'ธุรกิจ',
      'ลงทุน',
      'ขายของ',
      'โบนัส',
      'อื่นๆ',
    ];

    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final categories = type == 'income'
              ? incomeCategories
              : expenseCategories;
          if (!categories.contains(category)) {
            category = categories.first;
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit
                              ? context.tr('แก้ไขรายการ', 'Edit Transaction')
                              : context.tr(
                                  'จดรายการย้อนหลัง',
                                  'Record Transaction',
                                ),
                          style: TextStyle(
                            color: context.primaryTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isEdit)
                          IconButton(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(
                                    context.tr('ลบรายการนี้?', 'Delete this?'),
                                  ),
                                  content: Text(
                                    context.tr(
                                      'คุณต้องการลบรายการนี้ใช่หรือไม่?',
                                      'Are you sure you want to delete this?',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(
                                        context.tr('ยกเลิก', 'Cancel'),
                                      ),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFEF4444,
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(context.tr('ลบ', 'Delete')),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                setSheetState(() => saving = true);
                                try {
                                  await _apiClient.delete(
                                    '/transactions?id=eq.${editingTransaction['id']}',
                                  );
                                  await _loadTransactions();
                                } catch (_) {}
                                if (sheetContext.mounted && Navigator.canPop(sheetContext)) {
                                  Navigator.pop(sheetContext);
                                }
                              }
                            },
                            icon: const Icon(
                              Icons.delete_forever_rounded,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Center(
                              child: Text(context.tr('รายจ่าย', 'Expense')),
                            ),
                            selected: type == 'expense',
                            onSelected: (val) {
                              if (val) {
                                setSheetState(() {
                                  type = 'expense';
                                  category = expenseCategories.first;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: Center(
                              child: Text(context.tr('รายรับ', 'Income')),
                            ),
                            selected: type == 'income',
                            onSelected: (val) {
                              if (val) {
                                setSheetState(() {
                                  type = 'income';
                                  category = incomeCategories.first;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: context.tr('ชื่อรายการ', 'Item Name'),
                        hintText: context.tr(
                          'เช่น ค่าอาหารกลางวัน, เงินเดือน',
                          'e.g., Lunch, Salary',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr('จำนวนเงิน', 'Amount'),
                        prefixText: '฿ ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('หมวดหมู่', 'Category'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => category = val);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final note = noteController.text.trim();
                                final amountStr = amountController.text.trim();
                                final amount = double.tryParse(amountStr);
                                if (note.isEmpty ||
                                    amount == null ||
                                    amount <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr(
                                          'กรุณากรอกข้อมูลให้ถูกต้อง',
                                          'Please fill in correct info',
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setSheetState(() => saving = true);

                                try {
                                  final userId = AuthSession.userId;
                                  if (userId != null) {
                                    if (isEdit) {
                                      final body = {
                                        'note': note,
                                        'amount': amount,
                                        'type': type,
                                        'category': category,
                                      };
                                      await _apiClient.patch(
                                        '/transactions?id=eq.${editingTransaction['id']}',
                                        body: body,
                                      );
                                    } else {
                                      final selectedDate = DateTime(
                                        _year,
                                        _month,
                                        _day,
                                        12,
                                        0,
                                        0,
                                      );
                                      final body = {
                                        'user_id': userId,
                                        'note': note,
                                        'amount': amount,
                                        'type': type,
                                        'category': category,
                                        'transaction_date': selectedDate
                                            .toUtc()
                                            .toIso8601String(),
                                      };
                                      await _apiClient.post(
                                        '/transactions',
                                        body: body,
                                      );
                                    }
                                    await _loadTransactions();
                                  }
                                } catch (_) {}

                                if (sheetContext.mounted && Navigator.canPop(sheetContext)) {
                                  Navigator.pop(sheetContext);
                                }
                              },
                        child: saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(context.tr('บันทึก', 'Save')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _selectDate(DateTime date) {
    HapticFeedback.selectionClick();
    final isAlreadySelected =
        date.year == _year && date.month == _month && date.day == _day;

    if (isAlreadySelected && widget.onDateSelected != null) {
      widget.onDateSelected!(date);
    } else {
      setState(() {
        _year = date.year;
        _month = date.month;
        _day = date.day;
      });
    }
  }

  String _monthName(int month) => const [
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
  ][month - 1];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cells = _calendarCells();
    final selectedTransactions = _selectedTransactions;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFBF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 32,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header matching SlipScanDateSheet
            _buildHeader(context),

            const SizedBox(height: 14),

            // Embedded Custom Calendar Card (SaveForApp Luxury Theme)
            _buildCalendarCard(cells, today),

            const SizedBox(height: 14),

            // Selected Date Summary Header
            _buildSelectedDateHeader(selectedTransactions.length),

            const SizedBox(height: 10),

            // Transactions List or Empty State
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 80,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      ),
                    )
                  : _buildSelectedTransactions(selectedTransactions),
            ),

            const SizedBox(height: 16),

            // Bottom Action CTA Button matching SlipScanDateSheet style
            _buildBottomActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E0D2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.calendar_month_rounded,
            color: AppTheme.primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ปฏิทินรายการ',
                style: TextStyle(
                  fontFamily: 'SukhumvitSet',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'แตะวันที่เพื่อดูสิ่งที่จดไว้',
                style: TextStyle(
                  fontFamily: 'SukhumvitSet',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'จดรายการใหม่',
          onPressed: () => _showTransactionFormModal(),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_rounded,
              size: 18,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        IconButton(
          tooltip: 'ปิด',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCard(List<_CompactCalendarCell> cells, DateTime today) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E0D2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        children: [
          // Centered Month Navigator
          Row(
            children: [
              InkWell(
                onTap: () => _changeMonth(-1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_monthName(_month)} ${_year + 543}',
                    style: const TextStyle(
                      fontFamily: 'SukhumvitSet',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _changeMonth(1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Weekdays header
          Row(
            children: const ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontFamily: 'SukhumvitSet',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 8),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              return _buildCalendarCell(
                cell: cells[index],
                today: today,
              );
            },
          ),

          const SizedBox(height: 12),

          // Legend
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(
                  color: AppTheme.primaryColor,
                  label: 'วันที่เลือก',
                  isSolid: true,
                ),
                _buildLegendItem(
                  color: AppTheme.primaryColor,
                  label: 'มีรายการจดไว้',
                  isDot: true,
                ),
                _buildLegendItem(
                  color: AppTheme.primaryColor,
                  borderColor: AppTheme.primaryColor,
                  label: 'วันนี้',
                  isBorderOnly: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCell({
    required _CompactCalendarCell cell,
    required DateTime today,
  }) {
    final date = cell.date;
    final isSelected =
        date.year == _year && date.month == _month && date.day == _day;
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final hasTx = _hasTransactions(date);

    Color bgColor = Colors.transparent;
    Color textColor = const Color(0xFF1E293B);
    Border? border;
    List<BoxShadow>? shadows;
    FontWeight fontWeight = FontWeight.w600;

    if (isSelected) {
      bgColor = AppTheme.primaryColor;
      textColor = Colors.white;
      fontWeight = FontWeight.w700;
      shadows = [
        BoxShadow(
          color: AppTheme.primaryColor.withValues(alpha: 0.35),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (cell.inCurrentMonth) {
      bgColor = Colors.white;
      if (isToday) {
        border = Border.all(color: AppTheme.primaryColor, width: 1.5);
        textColor = AppTheme.primaryColor;
        fontWeight = FontWeight.w700;
      } else {
        border = Border.all(color: const Color(0xFFE2E8F0));
        textColor = const Color(0xFF1E293B);
      }
    } else {
      bgColor = const Color(0xFFFAFAFA);
      border = Border.all(color: const Color(0xFFF1F5F9));
      textColor = const Color(0xFFCBD5E1);
      fontWeight = FontWeight.w400;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectDate(date),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: border,
            boxShadow: shadows,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontFamily: 'SukhumvitSet',
                  fontSize: 12.5,
                  fontWeight: fontWeight,
                  color: textColor,
                ),
              ),
              if (hasTx)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 4.5,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                )
              else if (isToday && !isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 4.5,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    Color? borderColor,
    bool isSolid = false,
    bool isDot = false,
    bool isBorderOnly = false,
  }) {
    Widget indicator;
    if (isDot) {
      indicator = Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    } else if (isBorderOnly) {
      indicator = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: borderColor ?? color, width: 1.5),
        ),
      );
    } else {
      indicator = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1)
              : null,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'SukhumvitSet',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDateHeader(int count) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.event_note_rounded,
            color: AppTheme.primaryColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$_day ${_monthName(_month)} ${_year + 543}',
            style: const TextStyle(
              fontFamily: 'SukhumvitSet',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: count == 0
                ? const Color(0xFFF1F5F9)
                : AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count รายการ',
            style: TextStyle(
              fontFamily: 'SukhumvitSet',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: count == 0
                  ? const Color(0xFF64748B)
                  : AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedTransactions(List<dynamic> transactions) {
    final key = ValueKey('$_year-$_month-$_day');
    if (transactions.isEmpty) {
      return Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8E0D2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.edit_calendar_rounded,
                size: 22,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'วันนี้ยังไม่ได้จดรายการ',
              style: TextStyle(
                fontFamily: 'SukhumvitSet',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'แตะปุ่มด้านล่างเพื่อเพิ่มรายการสำหรับวันนี้',
              style: TextStyle(
                fontFamily: 'SukhumvitSet',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      key: key,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = Map<String, dynamic>.from(transactions[index] as Map);
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showTransactionFormModal(editingTransaction: tx),
          child: _TransactionRow(transaction: tx),
        );
      },
    );
  }

  Widget _buildBottomActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          final selectedDate = DateTime(_year, _month, _day);
          if (widget.onDateSelected != null) {
            widget.onDateSelected!(selectedDate);
          } else {
            _showTransactionFormModal();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.onDateSelected != null
                  ? Icons.check_circle_outline_rounded
                  : Icons.add_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              widget.onDateSelected != null
                  ? 'เลือกวันที่ $_day ${_monthName(_month)}'
                  : 'จดรายการวันที่ $_day ${_monthName(_month)}',
              style: const TextStyle(
                fontFamily: 'SukhumvitSet',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactCalendarCell {
  final DateTime date;
  final bool inCurrentMonth;

  const _CompactCalendarCell({
    required this.date,
    required this.inCurrentMonth,
  });
}

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const _TransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final rawNote = transaction['note']?.toString() ?? 'รายการ';
    final source = transaction['source']?.toString();
    final dreamId = transaction['dream_id']?.toString();
    final saving =
        source == 'dream_saving' || dreamId != null || rawNote.startsWith('[ออม]');
    final income = transaction['type'] == 'income';
    final color = saving
        ? const Color(0xFF8B5CF6)
        : income
        ? const Color(0xFF16A085)
        : const Color(0xFFEF4444);
    final icon = saving
        ? Icons.auto_awesome_rounded
        : income
        ? Icons.north_east_rounded
        : Icons.south_west_rounded;
    final typeLabel = saving
        ? 'เงินออม'
        : income
        ? 'รายรับ'
        : 'รายจ่าย';
    final note = rawNote
        .replaceAll(RegExp(r'\[สลิป\s+[^\]]+\]'), '')
        .replaceAll(RegExp(r'\[Ref:[^\]]+\]'), '')
        .replaceAll('[รายจ่ายประจำ]', '')
        .replaceAll('[รายรับประจำ]', '')
        .replaceAll('[ออม] หยอดกระปุก:', '')
        .trim();
    final amount =
        num.tryParse(transaction['amount']?.toString() ?? '')?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E0D2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
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
                    fontFamily: 'SukhumvitSet',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  typeLabel,
                  style: const TextStyle(
                    fontFamily: 'SukhumvitSet',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${income ? '+' : '-'}฿${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontFamily: 'SukhumvitSet',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
