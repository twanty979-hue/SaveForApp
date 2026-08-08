import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:app/core/localization/app_material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
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

      if (dreamsResponse.statusCode == 200 && txResponse.statusCode == 200) {
        setState(() {
          _dreams = jsonDecode(dreamsResponse.body);
          _transactions = jsonDecode(txResponse.body);
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

  // นับจำนวนครั้งที่ผู้ใช้หยอดกระปุกจริง โดยเช็กคำว่า "[ออม] หยอดกระปุก: [ชื่อฝัน]" ในโน้ตธุรกรรม
  int _getDepositCount(String title) {
    final searchKey = '[ออม] หยอดกระปุก: $title';
    return _transactions.where((tx) => tx['note'] == searchKey).length;
  }

  IconData _getIconData(String? iconName) {
    for (var cat in _dreamCategories) {
      if (cat['key'] == iconName) {
        return cat['icon'] as IconData;
      }
    }
    return Icons.star_border_outlined;
  }

  // ฟังก์ชันยิงอัปเดตสลับติดดาวความสนใจขึ้นเน็ตคลาวด์จริง
  Future<void> _toggleStar(String id, bool currentStarred) async {
    try {
      final body = {'is_starred': !currentStarred};
      // ส่ง PUT/POST ไปยัง Supabase dreams?id=eq.xxx
      final response = await _apiClient.post('/dreams?id=eq.$id', body: body);
      if (response.statusCode == 200 || response.statusCode == 201) {
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
        _fetchData();
      }
    } catch (e) {
      // จัดการผิดพลาด
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
                        backgroundColor: AppTheme.primaryColor,
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
                            'transaction_date': DateTime.now()
                                .toUtc()
                                .toIso8601String(),
                          };

                          final txResp = await _apiClient.post(
                            '/transactions',
                            body: txBody,
                          );

                          // 2. อัปเดตตารางยอดออมสะสม (current_amount) ในตาราง dreams
                          final newCurrent = currentSaved + amt;
                          final dreamBody = {'current_amount': newCurrent};
                          final dreamResp = await _apiClient.post(
                            '/dreams?id=eq.$dreamId',
                            body: dreamBody,
                          );

                          if (txResp.statusCode == 201 &&
                              dreamResp.statusCode == 200) {
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (activeStep == 1) ...[
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    activeStep = 0;
                                  });
                                },
                                child: const Icon(
                                  Icons.arrow_back_ios,
                                  size: 18,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              dreamToEdit != null
                                  ? (activeStep == 0
                                        ? 'แก้ไขหมวดหมู่เป้าหมาย'
                                        : 'แก้ไขรายละเอียดเป้าหมาย')
                                  : (activeStep == 0
                                        ? 'เลือกหมวดหมู่เป้าหมาย'
                                        : 'กรอกรายละเอียดเป้าหมาย'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (activeStep == 0) ...[
                      const Text(
                        'หมวดหมู่ความฝัน',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height:
                            220, // แสดงหมวดหมู่ชัดเจนขึ้นเมื่อไม่ต้องแสดง TextFields
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = (constraints.maxWidth - 16) / 3;
                            const cardHeight = 48.0;

                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _dreamCategories.map((cat) {
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
                                            ? const Color(0xFFE6F4F1)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : const Color(0xFFE2E8F0),
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
                                                : const Color(0xFF64748B),
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
                                                  : const Color(0xFF475569),
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
                            backgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 38),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            setModalState(() {
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
                      _DreamInputField(
                        controller: titleController,
                        title: 'ความฝัน / เป้าหมายการออม',
                        hint: 'เช่น ซื้อบ้าน, เที่ยวญี่ปุ่น',
                      ),
                      const SizedBox(height: 16),
                      _DreamSliderInputField(
                        controller: targetController,
                        title: 'จำนวนเงินเป้าหมาย (บาท)',
                        initialMax: 1000000,
                      ),
                      const SizedBox(height: 16),
                      _DreamSliderInputField(
                        controller: initialController,
                        title: 'เงินตั้งต้นที่มีอยู่แล้ว (บาท)',
                        initialMax: 100000,
                      ),
                      const SizedBox(height: 16),
                      _DreamSliderInputField(
                        controller: monthlyController,
                        title: 'เป้าหมายที่ต้องเก็บต่อเดือน (บาท)',
                        initialMax: 20000,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () {
                              setModalState(() {
                                activeStep = 0;
                              });
                            },
                            child: const Text(
                              'ย้อนกลับ',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
                              child: Text(
                                dreamToEdit != null ? 'บันทึกการแก้ไข' : 'สร้างเป้าหมาย',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
    final accent = isStarred ? const Color(0xFFD97706) : AppTheme.primaryColor;
    return SplitListCard(
      height: 148,
      leadingWidth: 94,
      iconContainerSize: 50,
      iconSize: 26,
      icon: _getIconData(dream['icon']?.toString()),
      accentColor: accent,
      leadingColor: isStarred
          ? const Color(0xFFFEF3C7)
          : const Color(0xFFDDF6F1),
      borderColor: isStarred
          ? const Color(0xFFF6C453)
          : const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dream['title']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                height: 28,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xFF64748B),
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
          Text(
            'หยอดแล้ว $depositCount ครั้ง',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: accent,
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
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                    children: [
                      TextSpan(
                        text: '฿${current.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text: ' / ฿${target.toStringAsFixed(0)}',
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFEFF1F5),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  monthly > 0
                      ? 'เดือนละ ฿${monthly.toStringAsFixed(0)} • อีก $monthsRemaining เดือน'
                      : 'ยังไม่ระบุยอดออมรายเดือน',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 29,
                child: OutlinedButton(
                  onPressed: () => _showDepositDialog(
                    id,
                    dream['title']?.toString() ?? '',
                    current,
                    target,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.65)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text(
                    'หยอด',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
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
          const Positioned.fill(child: FloatingBackground()),
          SafeArea(
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
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
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
                            final dream = _dreams[index];
                            final id = dream['id'];
                            final target = (dream['target_amount'] as num)
                                .toDouble();
                            final current = (dream['current_amount'] as num)
                                .toDouble();
                            final monthly =
                                (dream['monthly_saving_target'] as num)
                                    .toDouble();
                            final isStarred =
                                dream['is_starred'] as bool? ?? false;
                            final progress = target > 0
                                ? (current / target).clamp(0.0, 1.0)
                                : 0.0;
                            final depositCount = _getDepositCount(
                              dream['title'] ?? '',
                            );

                            // คำนวณจำนวนเดือนที่ต้องเก็บต่อ
                            int monthsRemaining = 0;
                            if (monthly > 0) {
                              monthsRemaining = ((target - current) / monthly)
                                  .ceil();
                              if (monthsRemaining < 0) monthsRemaining = 0;
                            }

                            if (dream is Map<String, dynamic>) {
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
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                // หากติดดาว (isStarred) ให้เปลี่ยนพื้นหลังเป็นสีส้มเหลืองนวลขอบหนาตามแบบรูปภาพที่หนึ่ง
                                color: isStarred
                                    ? const Color(0xFFFFFBEB)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isStarred
                                      ? const Color(0xFFFDE68A)
                                      : const Color(0xFFE2E8F0),
                                  width: isStarred ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.01),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // กล่องแสดงผลไอคอนเป้าหมายสีสะท้อนหมวดหมู่
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isStarred
                                              ? const Color(0xFFFEF3C7)
                                              : const Color(0xFFE6F4F1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          _getIconData(dream['icon']),
                                          color: isStarred
                                              ? const Color(0xFFD97706)
                                              : AppTheme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              dream['title'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${(progress * 100).toStringAsFixed(0)}% สำเร็จแล้ว',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isStarred
                                                    ? const Color(0xFFD97706)
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // แผงปุ่ม Action (ดาวส้ม, แก้ไข, ลบ)
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () =>
                                                _toggleStar(id, isStarred),
                                            child: Icon(
                                              isStarred
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: isStarred
                                                  ? Colors.amber
                                                  : const Color(0xFFCBD5E1),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () =>
                                                _showAddDreamBottomSheet(
                                                  dreamToEdit: dream,
                                                ),
                                            child: const Icon(
                                              Icons.edit_outlined,
                                              color: Color(0xFFCBD5E1),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () =>
                                                _showDeleteConfirmation(id),
                                            child: const Icon(
                                              Icons.delete_outline,
                                              color: Color(0xFFEF4444),
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // ป้ายประวัติการหยอดกระปุก (คำนวณจำนวนครั้งจริงจากธุรกรรม)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isStarred
                                          ? const Color(0xFFFEF3C7)
                                          : const Color(0xFFE6F4F1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 12,
                                          color: isStarred
                                              ? const Color(0xFFD97706)
                                              : AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'หยอดแล้ว $depositCount ครั้ง',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isStarred
                                                ? const Color(0xFFD97706)
                                                : AppTheme.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // แถบสเกลแสดงสถานะโปรเกรส
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: isStarred
                                          ? const Color(
                                              0xFFFDE68A,
                                            ).withValues(alpha: 0.3)
                                          : const Color(0xFFF1F5F9),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isStarred
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF2563EB),
                                      ),
                                      minHeight: 5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // ยอดเงินเก็บได้เทียบกับเป้าหมาย
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF1E293B),
                                          ),
                                          children: [
                                            const TextSpan(text: 'เก็บได้ '),
                                            TextSpan(
                                              text:
                                                  '฿${current.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'เป้าหมาย ฿${target.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // ป้ายข้อมูลคำนวณเป้าหมายรายเดือนตามแบบรูปภาพ
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isStarred
                                          ? const Color(0xFFFEF3C7)
                                          : const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'เป้าหมาย: เก็บเดือนละ ฿${monthly.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isStarred
                                                ? const Color(0xFFB45309)
                                                : const Color(0xFF15803D),
                                          ),
                                        ),
                                        Text(
                                          monthly > 0
                                              ? '(อีก $monthsRemaining เดือน)'
                                              : '(ยังไม่ระบุรายเดือน)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isStarred
                                                ? const Color(0xFFB45309)
                                                : const Color(0xFF15803D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // ปุ่มกดหยอดกระปุก (สไลด์เปลี่ยนสีตามสถานะติดดาว)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 40,
                                    child: isStarred
                                        ? ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFF59E0B,
                                              ), // ปุ่มส้มเหลืองทึบ
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              elevation: 0,
                                            ),
                                            onPressed: () => _showDepositDialog(
                                              id,
                                              dream['title'] ?? '',
                                              current,
                                              target,
                                            ),
                                            icon: const Icon(
                                              Icons.savings_outlined,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'หยอดกระปุก',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          )
                                        : OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: AppTheme.primaryColor,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () => _showDepositDialog(
                                              id,
                                              dream['title'] ?? '',
                                              current,
                                              target,
                                            ),
                                            icon: const Icon(
                                              Icons.savings_outlined,
                                              color: AppTheme.primaryColor,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'หยอดกระปุก',
                                              style: TextStyle(
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
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

class _DreamInputField extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final String hint;
  final TextInputType keyboardType;

  const _DreamInputField({
    required this.controller,
    required this.title,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DreamSliderInputField extends StatefulWidget {
  final TextEditingController controller;
  final String title;
  final double initialMax;

  const _DreamSliderInputField({
    required this.controller,
    required this.title,
    this.initialMax = 100000,
  });

  @override
  State<_DreamSliderInputField> createState() => _DreamSliderInputFieldState();
}

class _DreamSliderInputFieldState extends State<_DreamSliderInputField> {
  double _sliderValue = 0;
  late double _currentMax;

  @override
  void initState() {
    super.initState();
    _currentMax = widget.initialMax;
    widget.controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text.replaceAll(',', '');
    final value = double.tryParse(text) ?? 0;
    
    if (value > _currentMax) {
      _currentMax = value * 1.5;
      if (_currentMax == 0) _currentMax = widget.initialMax;
    }
    
    final clamped = value.clamp(0.0, _currentMax);
    if (clamped != _sliderValue) {
      setState(() {
        _sliderValue = clamped;
      });
    }
  }

  String _formatNumber(double val) {
    final str = val.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 120,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: widget.controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.5,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(right: 12, bottom: 4),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: AppTheme.primaryColor,
            inactiveTrackColor: const Color(0xFFE2E8F0),
            thumbColor: Colors.white,
            overlayColor: AppTheme.primaryColor.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 3),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: _sliderValue,
            max: _currentMax == 0 ? 100000 : _currentMax,
            onChanged: (val) {
              setState(() {
                _sliderValue = val;
                final formatted = _formatNumber(val);
                widget.controller.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              });
            },
          ),
        ),
      ],
    );
  }
}
