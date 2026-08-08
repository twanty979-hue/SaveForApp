import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:app/core/localization/app_material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/split_list_card.dart';
import '../../../core/widgets/shared_icon_selector.dart';
import '../../auth/domain/auth_session.dart';

class RecurringIncomeScreen extends StatefulWidget {
  final bool embedded;
  final ValueListenable<int>? addRequest;

  const RecurringIncomeScreen({
    super.key,
    this.embedded = false,
    this.addRequest,
  });

  @override
  State<RecurringIncomeScreen> createState() => _RecurringIncomeScreenState();
}

class _RecurringIncomeScreenState extends State<RecurringIncomeScreen> {
  final ApiClient _apiClient = ApiClient();
  final String _activeUserId =
      AuthSession.userId ?? '5b2d488d-75a0-4ea4-8f14-43047d256c8d';

  bool _isLoading = true;
  List<dynamic> _incomeSources = [];
  List<dynamic> _transactions = [];
  List<dynamic> _customCategories = [];

  // รายการหมวดหมู่รายรับประจำพร้อมไอคอนสำหรับแสดงผลในแบบกริด (Grid Category Selector)
  final List<Map<String, dynamic>> _categoriesList = [
    {'name': 'เงินเดือน', 'icon': Icons.work_outline},
    {'name': 'Freelance', 'icon': Icons.phone_android_outlined},
    {'name': 'ธุรกิจ', 'icon': Icons.storefront_outlined},
    {'name': 'ลงทุน', 'icon': Icons.trending_up_outlined},
    {'name': 'ขายของ', 'icon': Icons.shopping_cart_outlined},
    {'name': 'โบนัส', 'icon': Icons.card_giftcard_outlined},
    {'name': 'ค่าเช่า', 'icon': Icons.business_outlined},
    {'name': 'ค่าคอมมิชชั่น', 'icon': Icons.percent_outlined},
    {'name': 'ค่าตอบแทน', 'icon': Icons.redeem_outlined},
    {'name': 'รายได้เสริม', 'icon': Icons.flash_on_outlined},
    {'name': 'อื่นๆ', 'icon': Icons.more_horiz_outlined},
  ];

  @override
  void initState() {
    super.initState();
    widget.addRequest?.addListener(_handleAddRequest);
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant RecurringIncomeScreen oldWidget) {
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
    if (mounted) _showAddIncomeBottomSheet();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sourcesResp = await _apiClient.get(
        '/recurring/sources?user_id=eq.$_activeUserId&order=created_at.desc',
      );
      final txResp = await _apiClient.get(
        '/transactions?user_id=eq.$_activeUserId',
      );
      final customCatResponse = await _apiClient.get(
        '/user_categories?user_id=eq.$_activeUserId&category_type=eq.income',
      );

      if (sourcesResp.statusCode == 200 && txResp.statusCode == 200) {
        setState(() {
          _incomeSources = jsonDecode(sourcesResp.body);
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

  double _getReceivedAmountThisMonth(String id, String name) {
    final now = DateTime.now();
    double total = 0.0;
    for (var tx in _transactions) {
      final dateStr = tx['transaction_date'] ?? '';
      final date = DateTime.tryParse(dateStr);
      final txIncomeSourceId = tx['income_source_id']?.toString();
      final note = tx['note']?.toString() ?? '';
      final cleanNote = note
          .replaceAll('[รายรับประจำ]', '')
          .trim()
          .toLowerCase();
      final cleanName = name.trim().toLowerCase();
      final isMatch =
          txIncomeSourceId == id ||
          cleanNote == cleanName ||
          (cleanNote.isNotEmpty &&
              cleanName.isNotEmpty &&
              (cleanNote.contains(cleanName) || cleanName.contains(cleanNote)));

      if (date != null &&
          date.year == now.year &&
          date.month == now.month &&
          tx['type'] == 'income' &&
          isMatch) {
        total += (tx['amount'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return total;
  }

  Future<void> _deleteSource(String id) async {
    try {
      final response = await _apiClient.delete('/recurring/sources?id=eq.$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        _fetchData();
      }
    } catch (e) {
      // จัดการข้อผิดพลาดเงียบ
    }
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
            'คุณแน่ใจหรือไม่ว่าต้องการลบรายการรายรับประจำนี้? ข้อมูลนี้จะหายไปอย่างถาวร',
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
                _deleteSource(id);
              },
              child: const Text(
                'ยืนยันลบ',
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

  void _showAddIncomeBottomSheet({Map<String, dynamic>? incomeToEdit}) {
    final nameController = TextEditingController(
      text: incomeToEdit?['name']?.toString(),
    );
    final amountController = TextEditingController(
      text: incomeToEdit?['amount']?.toString(),
    );
    final dueDayController = TextEditingController(
      text: incomeToEdit?['due_day']?.toString() ?? '5',
    );
    String selectedCategory =
        incomeToEdit?['category']?.toString() ?? 'เงินเดือน';
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
                              incomeToEdit != null
                                  ? (activeStep == 0
                                        ? 'แก้ไขหมวดหมู่รายรับ'
                                        : 'แก้ไขรายละเอียดรายรับ')
                                  : (activeStep == 0
                                        ? 'เลือกหมวดหมู่รายรับ'
                                        : 'กรอกรายละเอียดรายรับ'),
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
                        'ประเภทรายรับ',
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
                                                  : const Color(0xFFE6F4F1))
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
                                                  : const Color(0xFFE6F4F1))
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
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: isSelected
                                                    ? AppTheme.primaryColor
                                                    : (Theme.of(context).brightness == Brightness.dark
                                                        ? const Color(0xFFE2E8F0)
                                                        : const Color(0xFF475569)),
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
                      // ชื่อรายรับ
                      Text(
                        'ชื่อรายรับ',
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
                          hintText: context.tr('เช่น เงินเดือนประจำ', 'e.g. regular salary'),
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
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // จำนวนเงินและวันที่ครบกำหนด
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
                                      borderSide: const BorderSide(
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
                                  'รับวันที่',
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
                                      borderSide: const BorderSide(
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

                              final response = incomeToEdit != null
                                  ? await _apiClient.patch(
                                      '/recurring/sources?id=eq.${incomeToEdit['id']}',
                                      body: body,
                                    )
                                  : await _apiClient.post(
                                      '/recurring/sources',
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
                            incomeToEdit != null
                                ? 'บันทึกการแก้ไข'
                                : '+ เพิ่มรายรับประจำ',
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
    return Icons.business_center_outlined;
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
      _showAddIncomeBottomSheet();
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
                      hintText: context.tr('เช่น เงินปันผล, ค่าเช่า', 'e.g. dividend, rent'),
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
                        borderSide: const BorderSide(color: AppTheme.primaryColor),
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
                            _showAddIncomeBottomSheet(); // กลับไปหน้าเดิม
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
                                      'category_type': 'income',
                                      'name': categoryName.trim(),
                                      'icon': selectedIconStr,
                                    };
                                    final response = await _apiClient.post('/user_categories', body: body);
                                    if (response.statusCode == 201 || response.statusCode == 200) {
                                      Navigator.pop(context); // ปิด bottom sheet
                                      await _fetchData();
                                      _showAddIncomeBottomSheet();
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

  Widget _buildIncomeListCard({
    required dynamic source,
    required String id,
    required String name,
    required double amount,
    required String category,
    required int dueDay,
    required double receivedAmount,
  }) {
    final progress = amount > 0
        ? (receivedAmount / amount).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final hasReceived = receivedAmount > 0;
    const accent = Color(0xFF10B981);
    return SplitListCard(
      height: 122,
      leadingWidth: 86,
      iconContainerSize: 48,
      iconSize: 25,
      icon: _getIconForCategory(category),
      accentColor: accent,
      leadingColor: const Color(0xFFDDF8ED),
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
                onEdit: () => _showAddIncomeBottomSheet(incomeToEdit: source),
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
                  '฿${receivedAmount.toStringAsFixed(0)} / ฿${amount.toStringAsFixed(0)}',
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
            hasReceived
                ? 'รับแล้ว ฿${receivedAmount.toStringAsFixed(0)}'
                : 'ยังไม่ได้รับเดือนนี้',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: hasReceived ? accent : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalIncomeExpected = 0.0;
    double totalIncomeReceived = 0.0;

    for (var source in _incomeSources) {
      final amt = (source['amount'] as num).toDouble();
      totalIncomeExpected += amt;
      final id = source['id'] as String? ?? '';
      final name = source['name'] as String? ?? '';
      final receivedAmt = _getReceivedAmountThisMonth(id, name);
      totalIncomeReceived += receivedAmt;
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
                // หัวข้อเรื่องและปุ่มเพิ่ม (FAB) ปรับขึ้นไปอยู่ด้านบนสุดแทน Profile Bar
                if (widget.embedded)
                  const SizedBox(height: 4)
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      border: Border(
                        bottom: BorderSide(
                          color: context.borderColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (Navigator.canPop(context)) ...[
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Color(0xFF0F172A),
                              size: 18,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 10),
                        ],
                        const Text(
                          'รายรับประจำ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _showAddIncomeBottomSheet,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981), // สีเขียวมิ้นต์สด
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // การ์ดสรุปเปรียบเทียบรายเดือนขอบกรอบสีเขียวสด
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
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ยอดรับรายรับสะสมเดือนนี้',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '฿${totalIncomeReceived.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'จากเป้าหมายตามแผนทั้งหมด ฿${totalIncomeExpected.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                // รายการการ์ดประวัติรายรับประจำ
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : _incomeSources.isEmpty
                      ? Center(
                          child: Text(
                            'ยังไม่มีรายการแผนรายรับประจำของคุณ',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _incomeSources.length,
                          itemBuilder: (context, index) {
                            final source = _incomeSources[index];
                            final id = source['id'] ?? '';
                            final name = source['name'] ?? '';
                            final amount = (source['amount'] as num).toDouble();
                            final category = source['category'] ?? 'ทั่วไป';
                            final dueDay = source['due_day'] ?? 1;
                            final receivedAmt = _getReceivedAmountThisMonth(
                              id,
                              name,
                            );
                            final hasReceived = receivedAmt > 0;

                            if (source is Map<String, dynamic>) {
                              return _buildIncomeListCard(
                                source: source,
                                id: id.toString(),
                                name: name.toString(),
                                amount: amount,
                                category: category.toString(),
                                dueDay: dueDay is int
                                    ? dueDay
                                    : int.tryParse(dueDay.toString()) ?? 1,
                                receivedAmount: receivedAmt,
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
                                      // ไอคอนกล่องกลมมนสีเขียวอ่อน
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD1FAE5),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          _getIconForCategory(category),
                                          color: const Color(0xFF10B981),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // หัวข้อชื่อและป้ายกำกับ inline
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
                                                    color: hasReceived
                                                        ? const Color(
                                                            0xFFE6F4F1,
                                                          )
                                                        : const Color(
                                                            0xFFF1F5F9,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: hasReceived
                                                          ? const Color(
                                                              0xFF5ED5A8,
                                                            )
                                                          : const Color(
                                                              0xFFCBD5E1,
                                                            ),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        hasReceived
                                                            ? Icons
                                                                  .check_circle_outline
                                                            : Icons
                                                                  .watch_later_outlined,
                                                        size: 10,
                                                        color: hasReceived
                                                            ? AppTheme
                                                                  .primaryColor
                                                            : const Color(
                                                                0xFF64748B,
                                                              ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        hasReceived
                                                            ? 'รับแล้ว ฿${receivedAmt.toStringAsFixed(0)}'
                                                            : 'ยังไม่ได้รับ',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: hasReceived
                                                              ? AppTheme
                                                                    .primaryColor
                                                              : const Color(
                                                                  0xFF64748B,
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
                                        onTap: () => _showAddIncomeBottomSheet(
                                          incomeToEdit: source,
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
