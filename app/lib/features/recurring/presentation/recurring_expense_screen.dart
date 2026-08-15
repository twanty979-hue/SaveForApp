import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:app/core/localization/app_material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/split_list_card.dart';
import '../../../core/widgets/shared_icon_selector.dart';
import '../../auth/domain/auth_session.dart';

class RecurringExpenseScreen extends StatefulWidget {
  final bool embedded;
  final ValueListenable<int>? addRequest;

  const RecurringExpenseScreen({
    super.key,
    this.embedded = false,
    this.addRequest,
  });

  @override
  State<RecurringExpenseScreen> createState() => _RecurringExpenseScreenState();
}

class _RecurringExpenseScreenState extends State<RecurringExpenseScreen> {
  final ApiClient _apiClient = ApiClient();
  final String _activeUserId =
      AuthSession.userId ?? '5b2d488d-75a0-4ea4-8f14-43047d256c8d';

  bool _isLoading = true;
  List<dynamic> _fixedExpenses = [];
  List<dynamic> _transactions = [];
  List<dynamic> _customCategories = [];

  // รายการหมวดหมู่พร้อมไอคอนสำหรับแสดงผลในแบบกริด (Grid Category Selector) ตรงตามภาพ
  final List<Map<String, dynamic>> _categoriesList = [
    {'name': 'ค่าเช่า', 'icon': Icons.home_outlined},
    {'name': 'ผ่อนรถ', 'icon': Icons.directions_car_outlined},
    {'name': 'ค่าไฟ', 'icon': Icons.flash_on_outlined},
    {'name': 'ค่าน้ำ', 'icon': Icons.water_drop_outlined},
    {'name': 'ค่าอินเทอร์เน็ต', 'icon': Icons.wifi},
    {'name': 'ค่ามือถือ', 'icon': Icons.phone_android_outlined},
    {'name': 'ค่าเรียน', 'icon': Icons.school_outlined},
    {'name': 'ค่าประกัน', 'icon': Icons.shield_outlined},
    {'name': 'สมาชิกยิม', 'icon': Icons.fitness_center_outlined},
    {'name': 'สมาชิก Netflix', 'icon': Icons.tv_outlined},
    {'name': 'สมาชิก Spotify', 'icon': Icons.music_note_outlined},
    {'name': 'ค่าอาหาร', 'icon': Icons.local_cafe_outlined},
    {'name': 'ค่ารักษา', 'icon': Icons.favorite_border_outlined},
    {'name': 'ออมเงิน', 'icon': Icons.savings_outlined},
    {'name': 'อื่นๆ', 'icon': Icons.more_horiz_outlined},
  ];

  @override
  void initState() {
    super.initState();
    widget.addRequest?.addListener(_handleAddRequest);
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant RecurringExpenseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.addRequest != widget.addRequest) {
      oldWidget.addRequest?.removeListener(_handleAddRequest);
      widget.addRequest?.addListener(_handleAddRequest);
    }
  }

  @override
  void dispose() {
    widget.addRequest?.removeListener(_handleAddRequest);
    super.dispose();
  }

  void _handleAddRequest() {
    if (mounted) _showAddExpenseBottomSheet();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final expensesResp = await _apiClient.get(
        '/recurring/expenses?user_id=eq.$_activeUserId&order=created_at.desc',
      );
      final txResp = await _apiClient.get(
        '/transactions?user_id=eq.$_activeUserId',
      );
      final customCatResponse = await _apiClient.get(
        '/user_categories?user_id=eq.$_activeUserId&category_type=eq.expense',
      );

      if (expensesResp.statusCode == 200 && txResp.statusCode == 200) {
        setState(() {
          _fixedExpenses = jsonDecode(expensesResp.body);
          _transactions = jsonDecode(txResp.body);
          if (customCatResponse.statusCode == 200) {
            _customCategories = jsonDecode(customCatResponse.body);
          }
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

  double _getPaidAmountThisMonth(String id, String name) {
    final now = DateTime.now();
    double total = 0.0;
    for (var tx in _transactions) {
      final dateStr = tx['transaction_date'] ?? '';
      final date = DateTime.tryParse(dateStr);
      final txFixedExpenseId = tx['fixed_expense_id']?.toString();
      final note = tx['note']?.toString() ?? '';
      final cleanNote = note
          .replaceAll('[รายจ่ายประจำ]', '')
          .trim()
          .toLowerCase();
      final cleanName = name.trim().toLowerCase();
      final isMatch =
          txFixedExpenseId == id ||
          cleanNote == cleanName ||
          (cleanNote.isNotEmpty &&
              cleanName.isNotEmpty &&
              (cleanNote.contains(cleanName) || cleanName.contains(cleanNote)));

      if (date != null &&
          date.year == now.year &&
          date.month == now.month &&
          tx['type'] == 'expense' &&
          isMatch) {
        total += (tx['amount'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return total;
  }

  void _showDeleteConfirmation(String id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text(
                'ยืนยันการลบ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: const Text(
            'คุณแน่ใจหรือไม่ว่าต้องการลบรายการรายจ่ายประจำนี้? ข้อมูลนี้จะหายไปอย่างถาวร',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'ยกเลิก',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                _deleteExpense(id);
              },
              child: const Text(
                'ลบข้อมูล',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteExpense(String id) async {
    try {
      final response = await _apiClient.delete('/recurring/expenses?id=eq.$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        _fetchData();
      }
    } catch (e) {
      // จัดการข้อผิดพลาดเงียบ
    }
  }

  // หน้าต่างเพิ่มรายจ่ายประจำดีไซน์พรีเมียม ถอดแบบจากภาพที่สองและสามเป๊ะๆ
  void _showAddExpenseBottomSheet({Map<String, dynamic>? expenseToEdit}) {
    final nameController = TextEditingController(
      text: expenseToEdit?['name']?.toString(),
    );
    final amountController = TextEditingController(
      text: expenseToEdit?['amount']?.toString(),
    );
    final dueDayController = TextEditingController(
      text: expenseToEdit?['due_day']?.toString() ?? '5',
    );
    String selectedCategory =
        expenseToEdit?['category']?.toString() ?? 'ค่าเช่า';
    int activeStep = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ส่วนหัวหน้าต่าง
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (activeStep == 1) ...[
                              GestureDetector(
                                onTap: () {
                                  setSheetState(() {
                                    activeStep = 0;
                                  });
                                },
                                child: Icon(
                                  Icons.arrow_back_ios,
                                  size: 18,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              expenseToEdit != null
                                  ? (activeStep == 0
                                        ? 'แก้ไขหมวดหมู่รายจ่าย'
                                        : 'แก้ไขรายละเอียดรายจ่าย')
                                  : (activeStep == 0
                                        ? 'เลือกหมวดหมู่รายจ่าย'
                                        : 'กรอกรายละเอียดรายจ่าย'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Color(0xFF64748B),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (activeStep == 0) ...[
                      Text(
                        'หมวดหมู่รายจ่าย',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 220,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = (constraints.maxWidth - 16) / 3;
                            const cardHeight = 48.0;

                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ..._categoriesList.map((cat) {
                                    final catName = cat['name'] as String;
                                    final catIcon = cat['icon'] as IconData;
                                    final isSelected =
                                        selectedCategory == catName;

                                    return GestureDetector(
                                      onTap: () {
                                        setSheetState(() {
                                          selectedCategory = catName;
                                        });
                                      },
                                      child: Container(
                                        width: cardWidth,
                                        height: cardHeight,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? (Theme.of(context).brightness == Brightness.dark
                                                  ? AppTheme.primaryColor.withValues(alpha: 0.18)
                                                  : const Color(0xFFF0FDF4))
                                              : (Theme.of(context).brightness == Brightness.dark
                                                  ? const Color(0xFF1E293B)
                                                  : const Color(0xFFF8FAFC)),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.primaryColor
                                                : (Theme.of(context).brightness == Brightness.dark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFE2E8F0)),
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              catIcon,
                                              size: 16,
                                              color: isSelected
                                                  ? AppTheme.primaryColor
                                                  : (Theme.of(context).brightness == Brightness.dark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(0xFF64748B)),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              catName,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? AppTheme.primaryColor
                                                    : (Theme.of(context).brightness == Brightness.dark
                                                        ? const Color(0xFFE2E8F0)
                                                        : const Color(0xFF475569)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),

                                  ..._customCategories.map((cat) {
                                    final catName = cat['name'] as String;
                                    final catIconString = cat['icon'] as String;
                                    final isSelected = selectedCategory == catName;

                                    return GestureDetector(
                                      onTap: () {
                                        setSheetState(() {
                                          selectedCategory = catName;
                                        });
                                      },
                                      child: Container(
                                        width: cardWidth,
                                        height: cardHeight,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? (Theme.of(context).brightness == Brightness.dark
                                                  ? AppTheme.primaryColor.withValues(alpha: 0.18)
                                                  : const Color(0xFFF0FDF4))
                                              : (Theme.of(context).brightness == Brightness.dark
                                                  ? const Color(0xFF1E293B)
                                                  : const Color(0xFFF8FAFC)),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.primaryColor
                                                : (Theme.of(context).brightness == Brightness.dark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFE2E8F0)),
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            PhosphorIcon(
                                              SharedIconSelector.getIconData(catIconString),
                                              size: 16,
                                              color: isSelected ? AppTheme.primaryColor : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              catName,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: isSelected ? AppTheme.primaryColor : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),

                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context); // ปิด bottom sheet เดิมก่อน
                                      _startCustomCategoryFlow();
                                    },
                                    child: Container(
                                      width: cardWidth,
                                      height: cardHeight,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                          width: 1,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add,
                                            size: 16,
                                            color: Color(0xFF475569),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'เพิ่ม',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.center,
                        child: Text(
                          '1/2',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.normal,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 38),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            setSheetState(() {
                              activeStep = 1;
                            });
                          },
                          child: const Text(
                            'ต่อไป',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // ชื่อรายจ่าย
                      Text(
                        'ชื่อรายจ่าย',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: context.tr('เช่น ค่าเช่าห้อง', 'e.g. room rent'),
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ฟิลด์จำนวนเงินและวันที่ครบกำหนดเคียงคู่ซ้ายขวาตามรูปภาพ
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'จำนวนเงิน (บาท)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: amountController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ครบวันที่',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: dueDayController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '5',
                                    hintStyle: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Align(
                        alignment: Alignment.center,
                        child: Text(
                          '2/2',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.normal,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // ปุ่มกดเพิ่มรายจ่ายประจำสีเข้มหรูตามรูปภาพ
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 38),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final amount =
                                double.tryParse(amountController.text.trim()) ??
                                0.0;
                            final dueDay =
                                int.tryParse(dueDayController.text.trim()) ?? 1;

                            if (name.isEmpty || amount <= 0) return;

                            try {
                              final body = {
                                'user_id': _activeUserId,
                                'name': name,
                                'amount': amount,
                                'category': selectedCategory,
                                'due_day': dueDay,
                              };

                              final response = expenseToEdit != null
                                  ? await _apiClient.patch(
                                      '/recurring/expenses?id=eq.${expenseToEdit['id']}',
                                      body: body,
                                    )
                                  : await _apiClient.post(
                                      '/recurring/expenses',
                                      body: body,
                                    );

                              if (response.statusCode == 200 ||
                                  response.statusCode == 201 ||
                                  response.statusCode == 204) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                _fetchData();
                              }
                            } catch (e) {
                              // จัดการข้อผิดพลาดเงียบ
                            }
                          },
                          child: Text(
                            expenseToEdit != null
                                ? 'บันทึกการแก้ไข'
                                : '+ เพิ่มรายจ่ายประจำ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  dynamic _getIconForCategory(String category) {
    for (var cat in _categoriesList) {
      if (cat['name'] == category) {
        return cat['icon'] as IconData;
      }
    }
    for (var cat in _customCategories) {
      if (cat['name'] == category) {
        return SharedIconSelector.buildIcon(cat['icon'] as String, size: 28);
      }
    }
    return Icons.home_outlined;
  }

  void _startCustomCategoryFlow({String? initialIcon}) async {
    final selectedIcon = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SharedIconPickerWidget(initialIconRawData: initialIcon);
      },
    );

    if (selectedIcon != null) {
      _showNameCategoryDialog(selectedIcon);
    } else {
      _showAddExpenseBottomSheet();
    }
  }

  void _showNameCategoryDialog(String selectedIconStr) {
    String categoryName = '';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _startCustomCategoryFlow(initialIcon: selectedIconStr);
                        },
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      SharedIconSelector.buildIcon(selectedIconStr, size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'ตั้งชื่อหมวดหมู่ใหม่',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ชื่อหมวดหมู่',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    onChanged: (value) {
                      setDialogState(() {
                        categoryName = value;
                      });
                    },
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText: context.tr('เช่น ค่าไฟ, ช้อปปิ้ง', 'e.g. electricity, shopping'),
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.normal,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: isSaving ? null : () {
                            Navigator.pop(context);
                            _showAddExpenseBottomSheet(); // กลับไปหน้าเดิม
                          },
                          child: const Text(
                            'ยกเลิก',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          onPressed: isSaving || categoryName.trim().isEmpty
                              ? null
                              : () async {
                                  setDialogState(() => isSaving = true);
                                  try {
                                    final body = {
                                      'user_id': _activeUserId,
                                      'category_type': 'expense',
                                      'name': categoryName.trim(),
                                      'icon': selectedIconStr,
                                    };
                                    final response = await _apiClient.post('/user_categories', body: body);
                                    if (response.statusCode == 201 || response.statusCode == 200) {
                                      Navigator.pop(context); // ปิด bottom sheet
                                      await _fetchData(); // ดึงข้อมูลใหม่
                                      _showAddExpenseBottomSheet(); // กลับไปหน้าเลือกหมวดหมู่
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก')),
                                        );
                                      }
                                      setDialogState(() => isSaving = false);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อ')),
                                      );
                                    }
                                    setDialogState(() => isSaving = false);
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text(
                                  'บันทึก',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExpenseListCard({
    required dynamic expense,
    required String id,
    required String name,
    required double amount,
    required String category,
    required int dueDay,
    required double paidAmount,
  }) {
    final progress = amount > 0
        ? (paidAmount / amount).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final hasPaid = paidAmount > 0;
    const accent = Color(0xFFEF4444);
    return SplitListCard(
      height: 122,
      leadingWidth: 86,
      iconContainerSize: 48,
      iconSize: 25,
      icon: _getIconForCategory(category),
      accentColor: accent,
      leadingColor: const Color(0xFFFFE7E9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              CardActionMenu(
                onEdit: () =>
                    _showAddExpenseBottomSheet(expenseToEdit: expense),
                onDelete: () => _showDeleteConfirmation(id),
              ),
            ],
          ),
          Text(
            '$category • ครบวันที่ $dueDay',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  '฿${paidAmount.toStringAsFixed(0)} / ฿${amount.toStringAsFixed(0)}',
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFEFF1F5),
              valueColor: const AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hasPaid
                ? 'ชำระแล้ว ฿${paidAmount.toStringAsFixed(0)}'
                : 'ยังไม่ได้ชำระเดือนนี้',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: hasPaid ? AppTheme.primaryColor : accent,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalExpenseExpected = 0.0;
    double totalExpensePaid = 0.0;

    for (var exp in _fixedExpenses) {
      final amt = (exp['amount'] as num).toDouble();
      totalExpenseExpected += amt;
      final id = exp['id'] as String? ?? '';
      final name = exp['name'] as String? ?? '';
      final paidAmt = _getPaidAmountThisMonth(id, name);
      totalExpensePaid += paidAmt;
    }

    return Scaffold(
      backgroundColor: widget.embedded ? Colors.transparent : context.pageColor,
      body: Stack(
        children: [
          if (!widget.embedded)
            const Positioned.fill(child: FloatingBackground()),
          SafeArea(
            child: ResponsiveLayout(
              maxWidth: 800,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // หัวข้อเรื่องและปุ่มเพิ่ม (FAB) ดีไซน์พรีเมียมตามรูปภาพแรก
                if (widget.embedded)
                  const SizedBox(height: 4)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Row(
                              children: [
                                Text(
                                  'รายจ่ายประจำ',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text('🎟️', style: TextStyle(fontSize: 20)),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              'ค่าใช้จ่ายที่ต้องจ่ายทุกเดือน',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: _showAddExpenseBottomSheet,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF1744), // สีแดงชมพูสด
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // การ์ดสรุปเปรียบเทียบความคืบหน้ารายเดือน ขอบกรอบสีเขียวสด
                if (!widget.embedded)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF10B981),
                        width: 1.5,
                      ), // กรอบสีเขียวสด
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ยอดชำระรายจ่ายสะสมเดือนนี้',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '฿${totalExpensePaid.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'จากเป้าหมายตามแผนทั้งหมด ฿${totalExpenseExpected.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                // รายการการ์ดประวัติรายจ่ายประจำ
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : _fixedExpenses.isEmpty
                      ? Center(
                          child: Text(
                            'ยังไม่มีรายการแผนรายจ่ายประจำของคุณ',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _fixedExpenses.length,
                          itemBuilder: (context, index) {
                            final expense = _fixedExpenses[index];
                            final id = expense['id'] ?? '';
                            final name = expense['name'] ?? '';
                            final amount = (expense['amount'] as num)
                                .toDouble();
                            final category = expense['category'] ?? 'ทั่วไป';
                            final dueDay = expense['due_day'] ?? 1;
                            final paidAmt = _getPaidAmountThisMonth(id, name);
                            final hasPaid = paidAmt > 0;

                            if (expense is Map<String, dynamic>) {
                              return _buildExpenseListCard(
                                expense: expense,
                                id: id.toString(),
                                name: name.toString(),
                                amount: amount,
                                category: category.toString(),
                                dueDay: dueDay is int
                                    ? dueDay
                                    : int.tryParse(dueDay.toString()) ?? 1,
                                paidAmount: paidAmt,
                              );
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.01),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // ไอคอนกล่องกลมมนสีฟ้าอ่อนตามภาพอ้างอิงแรก
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFDBEAFE,
                                          ), // ฟ้าพาสเทล
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          _getIconForCategory(category),
                                          color: const Color(
                                            0xFF2563EB,
                                          ), // น้ำเงินน้ำทะเล
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // หัวข้อชื่อและป้ายกำกับ inline ชนติดกันตามภาพเป๊ะ
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    name,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: hasPaid
                                                        ? const Color(
                                                            0xFFE6F4F1,
                                                          )
                                                        : const Color(
                                                            0xFFFFF1F2,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: hasPaid
                                                          ? const Color(
                                                              0xFF5ED5A8,
                                                            )
                                                          : const Color(
                                                              0xFFFECDD3,
                                                            ),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        hasPaid
                                                            ? Icons
                                                                  .check_circle_outlined
                                                            : Icons
                                                                  .watch_later_outlined,
                                                        size: 10,
                                                        color: hasPaid
                                                            ? AppTheme
                                                                  .primaryColor
                                                            : const Color(
                                                                0xFFEF4444,
                                                              ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        hasPaid
                                                            ? 'จ่ายแล้ว ฿${paidAmt.toStringAsFixed(0)}'
                                                            : 'ยังไม่ได้จ่าย',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: hasPaid
                                                              ? AppTheme
                                                                    .primaryColor
                                                              : const Color(
                                                                  0xFFEF4444,
                                                                ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$category - ครบวันที่ $dueDay',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '฿${amount.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showAddExpenseBottomSheet(
                                          expenseToEdit: expense,
                                        ),
                                        child: const Icon(
                                          Icons.edit_outlined,
                                          color: Color(0xFF94A3B8),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: () =>
                                            _showDeleteConfirmation(id),
                                        child: const Icon(
                                          Icons.delete_outline,
                                          color: Color(0xFFEF4444),
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
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
