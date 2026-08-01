import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../auth/domain/auth_session.dart';

class DreamsScreen extends StatefulWidget {
  const DreamsScreen({super.key});

  @override
  State<DreamsScreen> createState() => _DreamsScreenState();
}

class _DreamsScreenState extends State<DreamsScreen> {
  final ApiClient _apiClient = ApiClient();
  final String _activeUserId = AuthSession.userId ?? '5b2d488d-75a0-4ea4-8f14-43047d256c8d';

  List<dynamic> _dreams = [];
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _dreamCategories = [
    {'name': 'บ้าน', 'icon': Icons.home_outlined, 'key': 'Home'},
    {'name': 'รถยนต์', 'icon': Icons.directions_car_outlined, 'key': 'Car'},
    {'name': 'มอเตอร์ไซค์', 'icon': Icons.two_wheeler_outlined, 'key': 'Motorcycle'},
    {'name': 'ท่องเที่ยว', 'icon': Icons.flight_outlined, 'key': 'Plane'},
    {'name': 'iPhone', 'icon': Icons.phone_android_outlined, 'key': 'Phone'},
    {'name': 'MacBook', 'icon': Icons.laptop_chromebook_outlined, 'key': 'Laptop'},
    {'name': 'iPad', 'icon': Icons.tablet_android_outlined, 'key': 'iPad'},
    {'name': 'กล้อง', 'icon': Icons.camera_alt_outlined, 'key': 'Camera'},
    {'name': 'เรียนต่อ', 'icon': Icons.school_outlined, 'key': 'Graduation'},
    {'name': 'แต่งงาน', 'icon': Icons.favorite_border_outlined, 'key': 'Heart'},
    {'name': 'กองทุน', 'icon': Icons.account_balance_outlined, 'key': 'Fund'},
    {'name': 'หุ้น', 'icon': Icons.candlestick_chart_outlined, 'key': 'Stock'},
    {'name': 'ทองคำ', 'icon': Icons.diamond_outlined, 'key': 'Gold'},
    {'name': 'คริปโต', 'icon': Icons.currency_bitcoin_outlined, 'key': 'Crypto'},
    {'name': 'ร้านอาหาร', 'icon': Icons.restaurant_outlined, 'key': 'Restaurant'},
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
    _fetchData();
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
      // ใน Supabase การลบเรียกใช้ POST หรือ method คล้ายคลึงในการทำ API proxy
      final response = await _apiClient.post('/dreams?id=eq.$id', headers: {'Prefer': 'return=representation'}, body: null); // หรือใช้ DELETE
      // เพื่อความสะดวกในการใช้งานกับ Proxy ปัจจุบัน หากส่งผลลัพธ์ผ่าน
      if (response.statusCode == 200) {
        _fetchData();
      }
    } catch (e) {
      // จัดการผิดพลาด
    }
  }

  // หน้าต่างยืนยันการหยอดกระปุกเก็บออมจริง (Quick Deposit Bottom Sheet)
  void _showDepositDialog(String dreamId, String dreamTitle, double currentSaved, double targetAmt) {
    final depositController = TextEditingController();
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (errorText != null) ...[
                    Text(errorText!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: depositController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'จำนวนเงินออมครั้งนี้ (บาท)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final amt = double.tryParse(depositController.text.trim()) ?? 0.0;
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
                            'transaction_date': DateTime.now().toUtc().toIso8601String(),
                          };

                          final txResp = await _apiClient.post('/transactions', body: txBody);

                          // 2. อัปเดตตารางยอดออมสะสม (current_amount) ในตาราง dreams
                          final newCurrent = currentSaved + amt;
                          final dreamBody = {
                            'current_amount': newCurrent,
                          };
                          final dreamResp = await _apiClient.post('/dreams?id=eq.$dreamId', body: dreamBody);

                          if (txResp.statusCode == 201 && dreamResp.statusCode == 200) {
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
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
  void _showAddDreamBottomSheet() {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final initialController = TextEditingController();
    final monthlyController = TextEditingController();
    String selectedIcon = 'Home';

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
                                child: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              activeStep == 0 ? 'เลือกหมวดหมู่เป้าหมาย' : 'กรอกรายละเอียดเป้าหมาย',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (activeStep == 0) ...[
                      const Text(
                        'หมวดหมู่ความฝัน',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 220, // แสดงหมวดหมู่ชัดเจนขึ้นเมื่อไม่ต้องแสดง TextFields
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
                            backgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Text('ชื่อเป้าหมาย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'เช่น ซื้อ iPhone 16',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      const Text('ราคาเป้าหมาย (บาท)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: targetController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'เช่น 40000',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      const Text('เงินตั้งต้นที่มีอยู่แล้ว (บาท)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: initialController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'ถ้าเริ่มจากศูนย์ให้เว้นว่างไว้',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      const Text('เป้าหมายที่ต้องเก็บต่อเดือน (บาท)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: monthlyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'เพื่อใช้คำนวณเวลา (ไม่บังคับ)',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                            backgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 38),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () async {
                            final title = titleController.text.trim();
                            final target = double.tryParse(targetController.text.trim()) ?? 0.0;
                            final initial = double.tryParse(initialController.text.trim()) ?? 0.0;
                            final monthly = double.tryParse(monthlyController.text.trim()) ?? 0.0;

                            if (title.isEmpty || target <= 0) return;

                            try {
                              final body = {
                                'user_id': _activeUserId,
                                'title': title,
                                'target_amount': target,
                                'current_amount': initial,
                                'icon': selectedIcon,
                                'monthly_saving_target': monthly,
                                'is_starred': false,
                              };

                              final response = await _apiClient.post('/dreams', body: body);
                              if (response.statusCode == 200 || response.statusCode == 201) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                _fetchData();
                              }
                            } catch (e) {
                              // จัดการผิดพลาด
                            }
                          },
                          child: const Text(
                            'สร้างเป้าหมาย',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(
            child: FloatingBackground(),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // สหส่วนหัวแบบพรีเมียมของหน้าความฝัน
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'กระปุกความฝัน',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'เก็บเงินทีละนิด พิชิตเป้าหมาย',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      // ปุ่มบวกกลมสีชมพูขวาบน (FAB สไตล์หัวแอนดรอยด์ตามรูปที่หนึ่ง)
                      GestureDetector(
                        onTap: _showAddDreamBottomSheet,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF1744), // สีชมพูแดงสว่าง
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                      : _dreams.isEmpty
                          ? Center(
                              child: Text(
                                'ยังไม่มีรายการเป้าหมายออมเงินความฝันของคุณ',
                                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _dreams.length,
                              itemBuilder: (context, index) {
                                final dream = _dreams[index];
                                final id = dream['id'];
                                final target = (dream['target_amount'] as num).toDouble();
                                final current = (dream['current_amount'] as num).toDouble();
                                final monthly = (dream['monthly_saving_target'] as num).toDouble();
                                final isStarred = dream['is_starred'] as bool? ?? false;
                                final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
                                final depositCount = _getDepositCount(dream['title'] ?? '');

                                // คำนวณจำนวนเดือนที่ต้องเก็บต่อ
                                int monthsRemaining = 0;
                                if (monthly > 0) {
                                  monthsRemaining = ((target - current) / monthly).ceil();
                                  if (monthsRemaining < 0) monthsRemaining = 0;
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    // หากติดดาว (isStarred) ให้เปลี่ยนพื้นหลังเป็นสีส้มเหลืองนวลขอบหนาตามแบบรูปภาพที่หนึ่ง
                                    color: isStarred ? const Color(0xFFFFFBEB) : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isStarred ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // กล่องแสดงผลไอคอนเป้าหมายสีสะท้อนหมวดหมู่
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: isStarred ? const Color(0xFFFEF3C7) : const Color(0xFFE6F4F1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              _getIconData(dream['icon']),
                                              color: isStarred ? const Color(0xFFD97706) : AppTheme.primaryColor,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  dream['title'] ?? '',
                                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${(progress * 100).toStringAsFixed(0)}% สำเร็จแล้ว',
                                                  style: TextStyle(fontSize: 12, color: isStarred ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // แผงปุ่ม Action (ดาวส้ม, แก้ไข, ลบ)
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () => _toggleStar(id, isStarred),
                                                child: Icon(
                                                  isStarred ? Icons.star : Icons.star_border,
                                                  color: isStarred ? Colors.amber : const Color(0xFFCBD5E1),
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.edit_outlined, color: Color(0xFFCBD5E1), size: 20),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () => _deleteDream(id),
                                                child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      
                                      // ป้ายประวัติการหยอดกระปุก (คำนวณจำนวนครั้งจริงจากธุรกรรม)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isStarred ? const Color(0xFFFEF3C7) : const Color(0xFFE6F4F1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.history,
                                              size: 12,
                                              color: isStarred ? const Color(0xFFD97706) : AppTheme.primaryColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'หยอดแล้ว $depositCount ครั้ง',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isStarred ? const Color(0xFFD97706) : AppTheme.primaryColor,
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
                                          backgroundColor: isStarred ? const Color(0xFFFDE68A).withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
                                          valueColor: AlwaysStoppedAnimation<Color>(isStarred ? const Color(0xFFD97706) : const Color(0xFF2563EB)),
                                          minHeight: 5,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      
                                      // ยอดเงินเก็บได้เทียบกับเป้าหมาย
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          RichText(
                                            text: TextSpan(
                                              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                                              children: [
                                                const TextSpan(text: 'เก็บได้ '),
                                                TextSpan(
                                                  text: '฿${current.toStringAsFixed(0)}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            'เป้าหมาย ฿${target.toStringAsFixed(0)}',
                                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // ป้ายข้อมูลคำนวณเป้าหมายรายเดือนตามแบบรูปภาพ
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isStarred ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'เป้าหมาย: เก็บเดือนละ ฿${monthly.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isStarred ? const Color(0xFFB45309) : const Color(0xFF15803D),
                                              ),
                                            ),
                                            Text(
                                              monthly > 0 ? '(อีก $monthsRemaining เดือน)' : '(ยังไม่ระบุรายเดือน)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isStarred ? const Color(0xFFB45309) : const Color(0xFF15803D),
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
                                                  backgroundColor: const Color(0xFFF59E0B), // ปุ่มส้มเหลืองทึบ
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  elevation: 0,
                                                ),
                                                onPressed: () => _showDepositDialog(id, dream['title'] ?? '', current, target),
                                                icon: const Icon(Icons.savings_outlined, color: Colors.white, size: 18),
                                                label: const Text(
                                                  'หยอดกระปุก',
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                ),
                                              )
                                            : OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(color: AppTheme.primaryColor),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                onPressed: () => _showDepositDialog(id, dream['title'] ?? '', current, target),
                                                icon: const Icon(Icons.savings_outlined, color: AppTheme.primaryColor, size: 18),
                                                label: const Text(
                                                  'หยอดกระปุก',
                                                  style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
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
