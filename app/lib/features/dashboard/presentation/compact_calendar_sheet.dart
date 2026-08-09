import 'dart:convert';

import 'package:app/core/localization/app_material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/auth_session.dart';

class CompactCalendarSheet extends StatefulWidget {
  const CompactCalendarSheet({super.key});

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
    while (cells.length < 42) {
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
    final target = DateTime(_year, _month + offset, 1);
    setState(() {
      _year = target.year;
      _month = target.month;
      _day = 1;
    });
  }

  Future<void> _showTransactionFormModal({Map<String, dynamic>? editingTransaction}) async {
    final isEdit = editingTransaction != null;
    final noteController = TextEditingController(text: isEdit ? editingTransaction['note']?.toString() : '');
    final amountController = TextEditingController(text: isEdit ? (editingTransaction['amount'] as num?)?.toDouble().toStringAsFixed(0) : '');
    
    String type = isEdit ? (editingTransaction['type']?.toString() ?? 'expense') : 'expense';
    String category = isEdit ? (editingTransaction['category']?.toString() ?? 'ค่าอาหาร') : 'ค่าอาหาร';

    final expenseCategories = ['ค่าอาหาร', 'ค่าเช่า', 'ค่าเดินทาง', 'ค่าไฟ', 'ค่าน้ำ', 'ค่าอินเทอร์เน็ต', 'ค่ามือถือ', 'ท่องเที่ยว', 'อื่นๆ'];
    final incomeCategories = ['เงินเดือน', 'Freelance', 'ธุรกิจ', 'ลงทุน', 'ขายของ', 'โบนัส', 'อื่นๆ'];

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
          final categories = type == 'income' ? incomeCategories : expenseCategories;
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
                              : context.tr('จดรายการย้อนหลัง', 'Record Transaction'),
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
                                  title: Text(context.tr('ลบรายการนี้?', 'Delete this?')),
                                  content: Text(context.tr('คุณต้องการลบรายการนี้ใช่หรือไม่?', 'Are you sure you want to delete this?')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: Text(context.tr('ยกเลิก', 'Cancel')),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(context.tr('ลบ', 'Delete')),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                setSheetState(() => saving = true);
                                try {
                                  await _apiClient.delete('/transactions?id=eq.${editingTransaction['id']}');
                                  await _loadTransactions();
                                } catch (_) {}
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text(context.tr('รายจ่าย', 'Expense'))),
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
                            label: Center(child: Text(context.tr('รายรับ', 'Income'))),
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
                        hintText: context.tr('เช่น ค่าอาหารกลางวัน, เงินเดือน', 'e.g., Lunch, Salary'),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                if (note.isEmpty || amount == null || amount <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(context.tr('กรุณากรอกข้อมูลให้ถูกต้อง', 'Please fill in correct info'))),
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
                                      await _apiClient.patch('/transactions?id=eq.${editingTransaction['id']}', body);
                                    } else {
                                      final selectedDate = DateTime(_year, _month, _day, 12, 0, 0);
                                      final body = {
                                        'user_id': userId,
                                        'note': note,
                                        'amount': amount,
                                        'type': type,
                                        'category': category,
                                        'transaction_date': selectedDate.toUtc().toIso8601String(),
                                      };
                                      await _apiClient.post('/transactions', body);
                                    }
                                    await _loadTransactions();
                                  }
                                } catch (_) {}

                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              },
                        child: saving
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
    setState(() {
      _year = date.year;
      _month = date.month;
      _day = date.day;
    });
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
    final cells = _calendarCells();
    final selectedTransactions = _selectedTransactions;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: context.pageColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 24),
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 10),
                _buildHeader(context),
                const SizedBox(height: 9),
                _buildMonthNavigator(),
                const SizedBox(height: 7),
                const _WeekdayHeader(),
                const SizedBox(height: 5),
                _buildCalendar(cells),
                const SizedBox(height: 13),
                _buildSelectedDateHeader(selectedTransactions.length),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _isLoading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          height: 70,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : _buildSelectedTransactions(selectedTransactions),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFFE6F4F1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            color: AppTheme.primaryColor,
            size: 17,
          ),
        ),
        const SizedBox(width: 9),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ปฏิทินรายการ',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              Text(
                'แตะวันที่เพื่อดูสิ่งที่จดไว้',
                style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'ปิด',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 19),
        ),
      ],
    );
  }

  Widget _buildMonthNavigator() {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${_monthName(_month)} ${_year + 543}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        _MonthButton(
          icon: Icons.chevron_left_rounded,
          onTap: () => _changeMonth(-1),
        ),
        const SizedBox(width: 5),
        _MonthButton(
          icon: Icons.chevron_right_rounded,
          onTap: () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _buildCalendar(List<_CompactCalendarCell> cells) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        final cell = cells[index];
        final selected =
            cell.date.year == _year &&
            cell.date.month == _month &&
            cell.date.day == _day;
        final hasTransactions = _hasTransactions(cell.date);
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _selectDate(cell.date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primaryColor
                  : cell.inCurrentMonth
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : Colors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppTheme.primaryColor
                    : (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE9EDF2)),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${cell.date.day}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : cell.inCurrentMonth
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : const Color(0xFF334155))
                        : (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF475569)
                            : const Color(0xFFB8C1CC)),
                  ),
                ),
                if (hasTransactions) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedDateHeader(int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$_day ${_monthName(_month)} ${_year + 543}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF1E293B),
            ),
          ),
        ),
        Text(
          '$count รายการ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showTransactionFormModal(),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add,
              size: 16,
              color: Colors.white,
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
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9EDF2)),
        ),
        child: const Column(
          children: [
            Icon(Icons.event_note_rounded, size: 25, color: Color(0xFFB8C1CC)),
            SizedBox(height: 5),
            Text(
              'วันนี้ยังไม่ได้จดรายการ',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final tx = transactions[index] as Map<String, dynamic>;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showTransactionFormModal(editingTransaction: tx),
          child: _TransactionRow(
            transaction: tx,
          ),
        );
      },
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

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส']
          .map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MonthButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 19, color: const Color(0xFF475569)),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const _TransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final rawNote = transaction['note']?.toString() ?? 'รายการ';
    final saving = rawNote.startsWith('[ออม]');
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
        .replaceAll('[รายจ่ายประจำ]', '')
        .replaceAll('[รายรับประจำ]', '')
        .replaceAll('[ออม] หยอดกระปุก:', '')
        .trim();
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EDF2)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 9),
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
                  typeLabel,
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
