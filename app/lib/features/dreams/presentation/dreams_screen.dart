import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:app/core/localization/app_material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/shared_icon_selector.dart';
import '../../../core/widgets/split_list_card.dart';
import '../../auth/domain/auth_session.dart';

class DreamsScreen extends StatefulWidget {
  final bool embedded;
  final ValueListenable<int>? addRequest;

  const DreamsScreen({super.key, this.embedded = false, this.addRequest});

  @override
  State<DreamsScreen> createState() => _DreamsScreenState();
}

class _DreamsScreenState extends State<DreamsScreen> {
  final ApiClient _apiClient = ApiClient();
  final String _activeUserId =
      AuthSession.userId ?? '5b2d488d-75a0-4ea4-8f14-43047d256c8d';

  List<dynamic> _dreams = [];
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  List<dynamic> _customCategories = [];
  final List<Map<String, dynamic>> _dreamCategories = [
    {'name': 'บ้าน', 'icon': Icons.home_outlined, 'key': 'Home'},
    {'name': 'รถยนต์', 'icon': Icons.directions_car_outlined, 'key': 'Car'},
    {
      'name': 'มอเตอร์ไซค์',
      'icon': Icons.two_wheeler_outlined,
      'key': 'Motorcycle',
    },
    {'name': 'ท่องเที่ยว', 'icon': Icons.flight_outlined, 'key': 'Plane'},
    {'name': 'iPhone', 'icon': Icons.phone_android_outlined, 'key': 'Phone'},
    {
      'name': 'MacBook',
      'icon': Icons.laptop_chromebook_outlined,
      'key': 'Laptop',
    },
    {'name': 'iPad', 'icon': Icons.tablet_android_outlined, 'key': 'iPad'},
    {'name': 'กล้อง', 'icon': Icons.camera_alt_outlined, 'key': 'Camera'},
    {'name': 'เรียนต่อ', 'icon': Icons.school_outlined, 'key': 'Graduation'},
    {'name': 'แต่งงาน', 'icon': Icons.favorite_border_outlined, 'key': 'Heart'},
    {'name': 'กองทุน', 'icon': Icons.account_balance_outlined, 'key': 'Fund'},
    {'name': 'หุ้น', 'icon': Icons.candlestick_chart_outlined, 'key': 'Stock'},
    {'name': 'ทองคำ', 'icon': Icons.diamond_outlined, 'key': 'Gold'},
    {
      'name': 'คริปโต',
      'icon': Icons.currency_bitcoin_outlined,
      'key': 'Crypto',
    },
    {
      'name': 'ร้านอาหาร',
      'icon': Icons.restaurant_outlined,
      'key': 'Restaurant',
    },
    {'name': 'ธุรกิจ', 'icon': Icons.storefront_outlined, 'key': 'Business'},
    {'name': 'เกษียณ', 'icon': Icons.elderly_outlined, 'key': 'Retire'},
    {'name': 'สุขภาพ', 'icon': Icons.fitness_center_outlined, 'key': 'Health'},
    {'name': 'เสื้อผ้า', 'icon': Icons.checkroom_outlined, 'key': 'Clothes'},
    {'name': 'รองเท้า', 'icon': Icons.ice_skating_outlined, 'key': 'Shoes'},
    {'name': 'นาฬิกา', 'icon': Icons.watch_outlined, 'key': 'Watch'},
    {'name': 'กระเป๋า', 'icon': Icons.backpack_outlined, 'key': 'Bag'},
    {'name': 'เครื่องเสียง', 'icon': Icons.headphones_outlined, 'key': 'Audio'},
    {'name': 'เกม', 'icon': Icons.sports_esports_outlined, 'key': 'Game'},
    {'name': 'อื่นๆ', 'icon': Icons.more_horiz_outlined, 'key': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    widget.addRequest?.addListener(_handleAddRequest);
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant DreamsScreen oldWidget) {
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
    if (mounted) _showAddDreamBottomSheet();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ดึงข้อมูลเป้าหมายความฝัน
      final dreamsResponse = await _apiClient.get(
        '/dreams?user_id=eq.$_activeUserId&order=created_at.desc',
      );

      // ดึงประวัติธุรกรรมเพื่อเอามาใช้นับยอดจำนวนครั้งที่หยอดกระปุกสำเร็จจริง
      final txResponse = await _apiClient.get(
        '/transactions?user_id=eq.$_activeUserId',
      );

      // ดึงหมวดหมู่ custom ของผู้ใช้
      final customCatResponse = await _apiClient.get(
        '/user_categories?user_id=eq.$_activeUserId&category_type=eq.dream',
      );

      if (dreamsResponse.statusCode == 200 && txResponse.statusCode == 200) {
        setState(() {
          _dreams = jsonDecode(dreamsResponse.body);
          _transactions = jsonDecode(txResponse.body);
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

  // นับจำนวนครั้งที่ผู้ใช้หยอดกระปุกจริง โดยเช็ก dream_id หรือข้อความ "[ออม] หยอดกระปุก: [ชื่อฝัน]"
  int _getDepositCount(String title, [String? dreamId]) {
    final searchKey = '[ออม] หยอดกระปุก: $title';
    return _transactions.where((tx) {
      if (dreamId != null && tx['dream_id']?.toString() == dreamId) {
        return true;
      }
      return tx['note'] == searchKey;
    }).length;
  }

  Widget _buildIcon(String? iconName, {double size = 24, Color? color}) {
    if (iconName == null || iconName.isEmpty) {
      return Icon(Icons.star_border_outlined, size: size, color: color);
    }
    
    for (var cat in _dreamCategories) {
      if (cat['key'] == iconName) {
        return Icon(cat['icon'] as IconData, size: size, color: color);
      }
    }
    
    // ถ้าไม่เจอใน _dreamCategories ลองดึงจาก SharedIconSelector (สำหรับ custom categories)
    return PhosphorIcon(SharedIconSelector.getIconData(iconName), size: size, color: color);
  }

  // ฟังก์ชันยิงอัปเดตสลับติดดาวความสนใจขึ้นเน็ตคลาวด์จริง
  Future<void> _toggleStar(String id, bool currentStarred) async {
    try {
      final body = {'is_starred': !currentStarred};
      // ส่ง PUT/POST ไปยัง Supabase dreams?id=eq.xxx
      final response = await _apiClient.patch('/dreams?id=eq.$id', body: body);
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        _fetchData();
      }
    } catch (e) {
      // ขัดข้องเครือข่าย
    }
  }

  // ลบความฝันออกจากคลาวด์จริง
  Future<void> _deleteDream(String id) async {
    try {
      final response = await _apiClient.delete('/dreams?id=eq.$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          _fetchData();
        }
      }
    } catch (e) {
      debugPrint('[DreamsScreen] Error deleting dream: $e');
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
            'คุณแน่ใจหรือไม่ว่าต้องการลบเป้าหมายความฝันนี้? ข้อมูลเงินออมทั้งหมดในเป้าหมายนี้จะหายไปอย่างถาวร',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
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
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                _deleteDream(id);
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

  // หน้าต่างยืนยันการหยอดกระปุกเก็บออมจริง (Quick Deposit Bottom Sheet)
  void _showDepositDialog(
    String dreamId,
    String dreamTitle,
    double currentSaved,
    double targetAmt,
  ) {
    final depositController = TextEditingController();
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'หยอดกระปุก: $dreamTitle',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (errorText != null) ...[
                    Text(
                      errorText!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: depositController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'จำนวนเงินออมครั้งนี้ (บาท)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixText: '฿ ',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final amt =
                            double.tryParse(depositController.text.trim()) ??
                            0.0;
                        if (amt <= 0) {
                          setModalState(() {
                            errorText = 'กรุณากรอกจำนวนเงินออมมากกว่า 0 บาท';
                          });
                          return;
                        }

                        // 1. ส่งรายการออมเข้าไปที่ตารางธุรกรรม (transactions) เพื่อเก็บประวัติการทำรายการออม
                        try {
                          final txBody = {
                            'user_id': _activeUserId,
                            'type': 'expense', // ออมเงินลดจากกระเป๋าหลัก
                            'amount': amt,
                            'note': '[ออม] หยอดกระปุก: $dreamTitle',
                            'dream_id': dreamId,
                            'source': 'dream_saving',
                            'transaction_date': DateTime.now()
                                .toUtc()
                                .toIso8601String(),
                          };

                          var txResp = await _apiClient.post(
                            '/transactions',
                            body: txBody,
                          );
                          // Fallback if migration 003 has not been run yet
                          if (txResp.statusCode >= 400 && txResp.body.contains('column')) {
                            txResp = await _apiClient.post(
                              '/transactions',
                              body: {
                                'user_id': _activeUserId,
                                'type': 'expense',
                                'amount': amt,
                                'note': '[ออม] หยอดกระปุก: $dreamTitle',
                                'transaction_date': DateTime.now().toUtc().toIso8601String(),
                              },
                            );
                          }

                          // 2. อัปเดตตารางยอดออมสะสม (current_amount) ในตาราง dreams
                          final newCurrent = currentSaved + amt;
                          final dreamBody = {'current_amount': newCurrent};
                          final dreamResp = await _apiClient.patch(
                            '/dreams?id=eq.$dreamId',
                            body: dreamBody,
                          );

                          if (txResp.statusCode == 201 &&
                              (dreamResp.statusCode == 200 || dreamResp.statusCode == 204)) {
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                            _fetchData();
                          }
                        } catch (e) {
                          // จัดการขัดข้อง
                        }
                      },
                      child: const Text(
                        'ยืนยันหยอดกระปุก',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // หน้าต่างสร้างเป้าหมายใหม่ (ตามดีไซน์รูปที่สอง)
  void _showAddDreamBottomSheet({Map<String, dynamic>? dreamToEdit}) {
    final titleController = TextEditingController(
      text: dreamToEdit?['title']?.toString(),
    );
    final targetController = TextEditingController(
      text: dreamToEdit?['target_amount']?.toString(),
    );
    final initialController = TextEditingController(
      text: dreamToEdit?['current_amount']?.toString(),
    );
    final monthlyController = TextEditingController(
      text: dreamToEdit?['monthly_saving_target']?.toString(),
    );
    String selectedIcon = dreamToEdit?['icon']?.toString() ?? 'Home';

    int activeStep = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4.5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),

                    // Header with luxury icon pod and dual-line title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (activeStep == 1) ...[
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setModalState(() {
                                    activeStep = 0;
                                  });
                                },
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 15,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ] else ...[
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E8FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.savings_rounded,
                                  size: 20,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dreamToEdit != null
                                      ? (activeStep == 0
                                            ? 'แก้ไขหมวดหมู่เป้าหมาย'
                                            : 'แก้ไขรายละเอียดเป้าหมาย')
                                      : (activeStep == 0
                                            ? 'เลือกหมวดหมู่เป้าหมาย'
                                            : 'กรอกรายละเอียดเป้าหมาย'),
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  activeStep == 0
                                      ? 'ขั้นตอน 1 จาก 2 : เลือกไอคอนเป้าหมาย'
                                      : 'ขั้นตอน 2 จาก 2 : กำหนดยอดเงินออม',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(99),
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF64748B),
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    if (activeStep == 0) ...[
                      Text(
                        'หมวดหมู่ความฝัน',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF334155),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 230,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = (constraints.maxWidth - 16) / 3;
                            const cardHeight = 54.0;

                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ..._dreamCategories.map((cat) {
                                    final catName = cat['name'] as String;
                                    final catIcon = cat['icon'] as IconData;
                                    final catKey = cat['key'] as String;
                                    final isSelected = selectedIcon == catKey;

                                    return GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          selectedIcon = catKey;
                                        });
                                      },
                                      child: Container(
                                        width: cardWidth,
                                        height: cardHeight,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? (isDark
                                                  ? const Color(0xFF581C87).withValues(alpha: 0.35)
                                                  : const Color(0xFFF5F3FF))
                                              : (isDark
                                                  ? const Color(0xFF1E293B)
                                                  : Colors.white),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF8B5CF6)
                                                : (isDark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFE8E0D2)),
                                            width: isSelected ? 1.6 : 1,
                                          ),
                                          boxShadow: [
                                            if (isSelected)
                                              BoxShadow(
                                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              catIcon,
                                              size: 19,
                                              color: isSelected
                                                  ? const Color(0xFF8B5CF6)
                                                  : (isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(0xFF64748B)),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              catName,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: isSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: isSelected
                                                    ? (isDark
                                                        ? const Color(0xFFD8B4FE)
                                                        : const Color(0xFF7C3AED))
                                                    : (isDark
                                                        ? const Color(0xFFCBD5E1)
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
                                  
                                  ..._customCategories.map((cat) {
                                    final catName = cat['name'] as String;
                                    final catKey = cat['icon'] as String;
                                    final isSelected = selectedIcon == catKey;

                                    return GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          selectedIcon = catKey;
                                        });
                                      },
                                      child: Container(
                                        width: cardWidth,
                                        height: cardHeight,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? (isDark
                                                  ? const Color(0xFF581C87).withValues(alpha: 0.35)
                                                  : const Color(0xFFF5F3FF))
                                              : (isDark
                                                  ? const Color(0xFF1E293B)
                                                  : Colors.white),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF8B5CF6)
                                                : (isDark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFE8E0D2)),
                                            width: isSelected ? 1.6 : 1,
                                          ),
                                          boxShadow: [
                                            if (isSelected)
                                              BoxShadow(
                                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _buildIcon(
                                              catKey,
                                              size: 19,
                                              color: isSelected
                                                  ? const Color(0xFF8B5CF6)
                                                  : (isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(0xFF64748B)),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              catName,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: isSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: isSelected
                                                    ? (isDark
                                                        ? const Color(0xFFD8B4FE)
                                                        : const Color(0xFF7C3AED))
                                                    : (isDark
                                                        ? const Color(0xFFCBD5E1)
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
                                      Navigator.pop(context);
                                      _startCustomCategoryFlow();
                                    },
                                    child: Container(
                                      width: cardWidth,
                                      height: cardHeight,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF334155)
                                              : const Color(0xFFCBD5E1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_rounded,
                                            size: 20,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'เพิ่ม',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF64748B),
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
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setModalState(() {
                              activeStep = 1;
                            });
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'ต่อไป',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      _DreamInputField(
                        controller: titleController,
                        title: 'ความฝัน / เป้าหมายการออม',
                        hint: context.tr('เช่น ซื้อบ้าน, เที่ยวญี่ปุ่น', 'e.g. buy a house, travel to Japan'),
                      ),
                      const SizedBox(height: 16),
                      _DreamAmountInputField(
                        controller: targetController,
                        title: 'จำนวนเงินที่ต้องการเก็บ (บาท)',
                        hint: context.tr('ระบุจำนวนเงิน เช่น 50,000', 'Enter amount, e.g. 50,000'),
                        onChanged: () => setModalState(() {}),
                      ),
                      const SizedBox(height: 16),
                      _DreamAmountInputField(
                        controller: initialController,
                        title: 'เงินออมเริ่มต้นที่มี (บาท)',
                        hint: context.tr('ถ้าไม่มีระบุ 0', 'If none, enter 0'),
                        onChanged: () => setModalState(() {}),
                      ),
                      const SizedBox(height: 16),
                      _DreamAmountInputField(
                        controller: monthlyController,
                        title: 'ตั้งเป้าเก็บเงินต่อเดือน (บาท)',
                        hint: context.tr('ระบุจำนวนเงิน เช่น 2,000', 'Enter amount, e.g. 2,000'),
                        onChanged: () => setModalState(() {}),
                      ),
                      const SizedBox(height: 16),
                      _buildEstimationCard(targetController, initialController, monthlyController),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    activeStep = 0;
                                  });
                                },
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                                label: const Text(
                                  'ย้อนกลับ',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () async {
                                  final title = titleController.text.trim();
                                  final target = double.tryParse(targetController.text.replaceAll(',', '').trim()) ?? 0.0;
                                  final initial = double.tryParse(initialController.text.replaceAll(',', '').trim()) ?? 0.0;
                                  final monthly = double.tryParse(monthlyController.text.replaceAll(',', '').trim()) ?? 0.0;

                                  if (title.isEmpty || target <= 0) return;

                                  try {
                                    final body = {
                                      'user_id': _activeUserId,
                                      'title': title,
                                      'target_amount': target,
                                      'current_amount': initial,
                                      'icon': selectedIcon,
                                      'monthly_saving_target': monthly,
                                      'is_starred': dreamToEdit?['is_starred'] ?? false,
                                    };

                                    final response = dreamToEdit != null
                                        ? await _apiClient.patch(
                                            '/dreams?id=eq.${dreamToEdit['id']}',
                                            body: body,
                                          )
                                        : await _apiClient.post(
                                            '/dreams',
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
                                    //
                                  }
                                },
                                icon: Icon(
                                  dreamToEdit != null ? Icons.check_rounded : Icons.add_task_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  dreamToEdit != null ? 'บันทึกการแก้ไข' : 'สร้างเป้าหมาย',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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

  void _startCustomCategoryFlow({String? initialIcon}) async {
    // 1. Show Icon Picker First
    final selectedIcon = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SharedIconPickerWidget(initialIconRawData: initialIcon);
      },
    );

    if (selectedIcon != null) {
      _showNameCategoryDialog(selectedIcon); // 2. Show Name Dialog
    } else {
      // If user swiped down to close without picking, reopen the main sheet
      _showAddDreamBottomSheet();
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText: 'เช่น คอนเสิร์ต, เลี้ยงแมว',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.normal,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        borderSide: BorderSide(color: Theme.of(context).primaryColor),
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
                            _showAddDreamBottomSheet(); // กลับไปหน้าเดิม
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
                            backgroundColor: Theme.of(context).primaryColor,
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
                                      'category_type': 'dream',
                                      'name': categoryName.trim(),
                                      'icon': selectedIconStr,
                                    };
                                    final response = await _apiClient.post('/user_categories', body: body);
                                    if (response.statusCode == 201 || response.statusCode == 200) {
                                      if (context.mounted) {
                                        Navigator.pop(context); // ปิด bottom sheet
                                      }
                                      await _fetchData(); // ดึงข้อมูลใหม่
                                      if (mounted) {
                                        _showAddDreamBottomSheet(); // กลับไปหน้าเลือกหมวดหมู่
                                      }
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

  Widget _buildEstimationCard(
    TextEditingController targetController,
    TextEditingController initialController,
    TextEditingController monthlyController,
  ) {
    final target = double.tryParse(targetController.text.replaceAll(',', '').trim()) ?? 0.0;
    final initial = double.tryParse(initialController.text.replaceAll(',', '').trim()) ?? 0.0;
    final monthly = double.tryParse(monthlyController.text.replaceAll(',', '').trim()) ?? 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    String message = '';
    IconData icon = Icons.calculate_outlined;
    Color accentColor = const Color(0xFF64748B);
    Color bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    if (target <= 0) {
      message = 'ระบุจำนวนเงินเป้าหมายเพื่อคำนวณระยะเวลา';
      icon = Icons.savings_outlined;
      accentColor = const Color(0xFF64748B);
      bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    } else if (initial >= target) {
      message = 'เป้าหมายสำเร็จแล้ว! เงินเริ่มต้นถึงเป้าหมายแล้ว 🎉';
      icon = Icons.emoji_events_rounded;
      accentColor = const Color(0xFF10B981);
      bgColor = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5);
    } else if (monthly <= 0) {
      message = 'ระบุยอดเงินที่ต้องการเก็บต่อเดือน เพื่อดูเวลาที่ต้องใช้';
      icon = Icons.calendar_today_rounded;
      accentColor = const Color(0xFF3B82F6);
      bgColor = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF);
    } else {
      final remaining = target - initial;
      final months = (remaining / monthly).ceil();
      message = 'คุณจะบรรลุเป้าหมายนี้ได้ในอีกประมาณ $months เดือน 🚀';
      icon = Icons.rocket_launch_rounded;
      accentColor = const Color(0xFF8B5CF6);
      bgColor = isDark ? const Color(0xFF581C87).withValues(alpha: 0.25) : const Color(0xFFF5F3FF);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDreamListCard({
    required dynamic dream,
    required String id,
    required double target,
    required double current,
    required double monthly,
    required bool isStarred,
    required double progress,
    required int depositCount,
    required int monthsRemaining,
  }) {
    final accent = isStarred ? const Color(0xFFFF9800) : Theme.of(context).primaryColor;
    return SplitListCard(
      height: 146,
      leadingWidth: 94,
      iconContainerSize: 56,
      iconSize: 26,
      icon: _buildIcon(dream['icon']?.toString(), size: 28, color: accent),
      accentColor: accent,
      leadingColor: isStarred ? const Color(0xFFFFF3E0) : const Color(0xFFDDF6F1),
      borderColor: isStarred
          ? const Color(0xFFFFB000)
          : const Color(0xFFE2E8F0),
      glowColor: isStarred ? const Color(0xFFFFB000) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isStarred) ...[
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFB000),
                  size: 18,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  dream['title']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                height: 28,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                  onSelected: (value) {
                    if (value == 'star') {
                      _toggleStar(id, isStarred);
                    } else if (value == 'edit') {
                      _showAddDreamBottomSheet(dreamToEdit: dream);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(id);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'star',
                      child: Text(isStarred ? 'ยกเลิกติดดาว' : 'ติดดาว'),
                    ),
                    PopupMenuItem(value: 'edit', child: Text(context.tr('แก้ไข', 'Edit'))),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'ลบ',
                        style: TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'หยอดแล้ว $depositCount ครั้ง',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: RichText(
                  maxLines: 1,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                    ),
                    children: [
                      TextSpan(
                        text: '฿${formatMoney(current)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text: ' / ฿${formatMoney(target)}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  current >= target
                      ? 'ยินดีด้วย! บรรลุเป้าหมายแล้ว 🎉'
                      : (monthly > 0
                          ? 'เดือนละ ฿${formatMoney(monthly)} • อีก $monthsRemaining เดือน'
                          : 'ยังไม่ระบุยอดออมรายเดือน'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!widget.embedded) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    onPressed: () => _showDepositDialog(
                      id,
                      dream['title']?.toString() ?? '',
                      current,
                      target,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'หยอด',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          'กระปุกความฝัน',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _showAddDreamBottomSheet(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF1744), // สีแดงชมพูสด
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

                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                      : _dreams.isEmpty
                      ? Center(
                          child: Text(
                            'ยังไม่มีรายการเป้าหมายออมเงินความฝันของคุณ',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          itemCount: _dreams.length,
                          itemBuilder: (context, index) {
                            final rawDream = _dreams[index];
                            final dream = rawDream is Map
                                ? Map<String, dynamic>.from(rawDream)
                                : <String, dynamic>{};
                            final id = dream['id'];
                            final target = num.tryParse(dream['target_amount']?.toString() ?? '')?.toDouble() ?? 0.0;
                            final current = num.tryParse(dream['current_amount']?.toString() ?? '')?.toDouble() ?? 0.0;
                            final monthly = num.tryParse(dream['monthly_saving_target']?.toString() ?? '')?.toDouble() ?? 0.0;
                            final isStarred =
                                dream['is_starred'] as bool? ?? false;
                            final progress = target > 0
                                ? (current / target).clamp(0.0, 1.0)
                                : 0.0;
                            final depositCount = _getDepositCount(
                              dream['title'] ?? '',
                              dream['id']?.toString(),
                            );

                            // คำนวณจำนวนเดือนที่ต้องเก็บต่อ
                            int monthsRemaining = 0;
                            if (monthly > 0) {
                              monthsRemaining = ((target - current) / monthly)
                                  .ceil();
                              if (monthsRemaining < 0) monthsRemaining = 0;
                            }

                            return _buildDreamListCard(
                              dream: dream,
                              id: id.toString(),
                              target: target,
                              current: current,
                              monthly: monthly,
                              isStarred: isStarred,
                              progress: progress.toDouble(),
                              depositCount: depositCount,
                              monthsRemaining: monthsRemaining,
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

class _DreamInputField extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final String hint;

  const _DreamInputField({
    required this.controller,
    required this.title,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE8E0D2),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF8B5CF6),
                width: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DreamAmountInputField extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final String hint;
  final VoidCallback? onChanged;

  const _DreamAmountInputField({
    required this.controller,
    required this.title,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (_) => onChanged?.call(),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.normal,
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                widthFactor: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr('บาท', 'THB'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE8E0D2),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF8B5CF6),
                width: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
