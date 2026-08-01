import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../auth/domain/auth_session.dart';

class RecurringIncomeScreen extends StatefulWidget {
  const RecurringIncomeScreen({super.key});

  @override
  State<RecurringIncomeScreen> createState() => _RecurringIncomeScreenState();
}

class _RecurringIncomeScreenState extends State<RecurringIncomeScreen> {
  final ApiClient _apiClient = ApiClient();
  final String _activeUserId = AuthSession.userId ?? '5b2d488d-75a0-4ea4-8f14-43047d256c8d';

  bool _isLoading = true;
  List<dynamic> _incomeSources = [];
  List<dynamic> _transactions = [];

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
    _fetchData();
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

      if (sourcesResp.statusCode == 200 && txResp.statusCode == 200) {
        setState(() {
          _incomeSources = jsonDecode(sourcesResp.body);
          _transactions = jsonDecode(txResp.body);
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
      final cleanNote = note.replaceAll('[รายรับประจำ]', '').trim().toLowerCase();
      final cleanName = name.trim().toLowerCase();
      final isMatch = txIncomeSourceId == id ||
                      cleanNote == cleanName ||
                      (cleanNote.isNotEmpty && cleanName.isNotEmpty && (cleanNote.contains(cleanName) || cleanName.contains(cleanNote)));

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

  Future<void> _recordIncomeReceipt(String id, String name, double amount) async {
    try {
      final body = {
        'user_id': _activeUserId,
        'type': 'income',
        'amount': amount,
        'note': '[รายรับประจำ] $name',
        'income_source_id': id,
        'transaction_date': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _apiClient.post('/transactions', body: body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchData();
      }
    } catch (e) {
      // จัดการข้อผิดพลาดเงียบ
    }
  }

  void _showRecordIncomeDialog(String id, String name, double defaultAmt) {
    final amountController = TextEditingController(text: defaultAmt <= 0 ? '' : defaultAmt.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'บันทึกรับเงิน: $name',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ระบุจำนวนเงินที่ได้รับ (บาท)',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '0.00',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (amt > 0) {
                  Navigator.pop(context);
                  _recordIncomeReceipt(id, name, amt);
                }
              },
              child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final nameController = TextEditingController(text: incomeToEdit?['name']?.toString());
    final amountController = TextEditingController(text: incomeToEdit?['amount']?.toString());
    final dueDayController = TextEditingController(text: incomeToEdit?['due_day']?.toString() ?? '5');
    String selectedCategory = incomeToEdit?['category']?.toString() ?? 'เงินเดือน';
    int activeStep = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                                child: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              incomeToEdit != null
                                  ? (activeStep == 0 ? 'แก้ไขหมวดหมู่รายรับ' : 'แก้ไขรายละเอียดรายรับ')
                                  : (activeStep == 0 ? 'เลือกหมวดหมู่รายรับ' : 'กรอกรายละเอียดรายรับ'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Color(0xFF64748B), size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (activeStep == 0) ...[
                      const Text(
                        'ประเภทรายรับ',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
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
                                children: _categoriesList.map((cat) {
                                  final catName = cat['name'] as String;
                                  final catIcon = cat['icon'] as IconData;
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
                                        color: isSelected ? const Color(0xFFE6F4F1) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            catIcon,
                                            size: 16,
                                            color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            catName,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected ? AppTheme.primaryColor : const Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
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
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.normal, color: Color(0xFFCBD5E1)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else ...[
                      // ชื่อรายรับ
                      const Text(
                        'ชื่อรายรับ',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'เช่น เงินเดือนประจำ',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primaryColor),
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
                                const Text(
                                  'จำนวนเงิน (บาท)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: amountController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppTheme.primaryColor),
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
                                const Text(
                                  'รับวันที่',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: dueDayController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '5',
                                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppTheme.primaryColor),
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
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.normal, color: Color(0xFFCBD5E1)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 38),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                            final dueDay = int.tryParse(dueDayController.text.trim()) ?? 1;

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
                                  ? await _apiClient.patch('/recurring/sources?id=eq.${incomeToEdit['id']}', body: body)
                                  : await _apiClient.post('/recurring/sources', body: body);

                              if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
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
                            incomeToEdit != null ? 'บันทึกการแก้ไข' : '+ เพิ่มรายรับประจำ',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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

  IconData _getIconForCategory(String category) {
    for (var cat in _categoriesList) {
      if (cat['name'] == category) {
        return cat['icon'] as IconData;
      }
    }
    return Icons.business_center_outlined;
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
      backgroundColor: const Color(0xFFFAFBFD),
      body: Stack(
        children: [
          const Positioned.fill(
            child: FloatingBackground(),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // หัวข้อเรื่องและปุ่มเพิ่ม (FAB) ปรับขึ้นไปอยู่ด้านบนสุดแทน Profile Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                  ),
                  child: Row(
                    children: [
                      if (Navigator.canPop(context)) ...[
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 18),
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
                          child: const Icon(Icons.add, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                // การ์ดสรุปเปรียบเทียบรายเดือนขอบกรอบสีเขียวสด
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ยอดรับรายรับสะสมเดือนนี้',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '฿${totalIncomeReceived.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'จากเป้าหมายตามแผนทั้งหมด ฿${totalIncomeExpected.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                // รายการการ์ดประวัติรายรับประจำ
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                      : _incomeSources.isEmpty
                          ? Center(
                              child: Text(
                                'ยังไม่มีรายการแผนรายรับประจำของคุณ',
                                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _incomeSources.length,
                              itemBuilder: (context, index) {
                                final source = _incomeSources[index];
                                final id = source['id'] ?? '';
                                final name = source['name'] ?? '';
                                final amount = (source['amount'] as num).toDouble();
                                final category = source['category'] ?? 'ทั่วไป';
                                final dueDay = source['due_day'] ?? 1;
                                final receivedAmt = _getReceivedAmountThisMonth(id, name);
                                final hasReceived = receivedAmt > 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                              borderRadius: BorderRadius.circular(12),
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
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // หัวข้อชื่อและป้ายกำกับ inline
                                                Row(
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: hasReceived ? const Color(0xFFE6F4F1) : const Color(0xFFF1F5F9),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(
                                                          color: hasReceived ? const Color(0xFF5ED5A8) : const Color(0xFFCBD5E1),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            hasReceived ? Icons.check_circle_outline : Icons.watch_later_outlined,
                                                            size: 10,
                                                            color: hasReceived ? AppTheme.primaryColor : const Color(0xFF64748B),
                                                          ),
                                                          const SizedBox(width: 2),
                                                          Text(
                                                            hasReceived ? 'รับแล้ว ฿${receivedAmt.toStringAsFixed(0)}' : 'ยังไม่ได้รับ',
                                                            style: TextStyle(
                                                              fontSize: 8,
                                                              fontWeight: FontWeight.bold,
                                                              color: hasReceived ? AppTheme.primaryColor : const Color(0xFF64748B),
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
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '฿${amount.toStringAsFixed(0)}',
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // ปุ่มกดบันทึกการชำระเงินขอบเขียวสด
                                          SizedBox(
                                            height: 36,
                                            child: hasReceived
                                                ? OutlinedButton.icon(
                                                    style: OutlinedButton.styleFrom(
                                                      side: const BorderSide(color: AppTheme.primaryColor, width: 1.2),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                                    ),
                                                    onPressed: () => _showRecordIncomeDialog(id, name, amount - receivedAmt),
                                                    icon: const Icon(Icons.check_circle_outline, color: AppTheme.primaryColor, size: 16),
                                                    label: const Text(
                                                      'บันทึกรับเงิน',
                                                      style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                  )
                                                : OutlinedButton.icon(
                                                    style: OutlinedButton.styleFrom(
                                                      side: const BorderSide(color: AppTheme.primaryColor, width: 1.2),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                                    ),
                                                    onPressed: () => _recordIncomeReceipt(id, name, amount),
                                                    icon: const Icon(Icons.check_circle_outline, color: AppTheme.primaryColor, size: 16),
                                                    label: const Text(
                                                      'บันทึกรับเงิน',
                                                      style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                          ),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () => _showAddIncomeBottomSheet(incomeToEdit: source),
                                                child: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 18),
                                              ),
                                              const SizedBox(width: 12),
                                              GestureDetector(
                                                onTap: () => _showDeleteConfirmation(id),
                                                child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                                              ),
                                            ],
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
        ],
      ),
    );
  }
}
