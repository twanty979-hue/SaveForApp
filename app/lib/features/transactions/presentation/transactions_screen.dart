import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../auth/domain/auth_session.dart';
import '../../dreams/presentation/dreams_screen.dart';
import '../../recurring/presentation/recurring_expense_screen.dart';
import '../../recurring/presentation/recurring_income_screen.dart';

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final bool isThinking;
  final Map<String, dynamic>? cardData;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.isThinking = false,
    this.cardData,
  });
}

class QuickSuggestion {
  final String id;
  final String name;
  final IconData icon;

  QuickSuggestion({
    required this.id,
    required this.name,
    required this.icon,
  });
}

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // รายชื่อ AI ผู้ช่วยทั้ง 3 ตัว พร้อมการระบุสีและสัญลักษณ์ฝั่งขวาตามความต้องการ
    final List<Map<String, dynamic>> aiBots = [
      {
        'id': 'expense',
        'name': 'น้องเพนกวินรายจ่าย',
        'emoji': '🐧',
        'avatarAsset': 'assets/images/penguin_avatar.jpg',
        'intro': 'สวัสดีครับผม! ผม น้องเพนกวินรายจ่าย 🐧 ยินดีที่ได้ช่วยคุมรายจ่ายนะครับ! พิมพ์บอกค่าใช้จ่ายได้เลย เช่น "ค่าข้าว 80" หรือ "ชานมไข่มุก 65"',
        'successMsg': 'บันทึกรายจ่ายเรียบร้อยแล้วครับ! ประหยัดวันละนิด จิตแจ่มใสนะครับ 🐧❄️',
        'themeColor': const Color(0xFFEF4444), // สีส้มแดงรายจ่าย
        'iconColor': const Color(0xFFF97316),
        'avatarColor': const Color(0xFFEF4444),
        'cardIcon': Icons.trending_down_outlined, // ไอคอนรายจ่าย
      },
      {
        'id': 'income',
        'name': 'น้องเหมียวรายรับ',
        'emoji': '🐱',
        'avatarAsset': 'assets/images/cat_avatar.jpg',
        'intro': 'เหมียววว~ สวัสดีค่ะ! หนู น้องเหมียวรายรับ 🐱 พร้อมรับรายรับเฮงๆ ของคุณแล้ว! พิมพ์บอกรายรับมาเลย เช่น "เงินเดือน 30000" หรือ "ขายของได้ 1500"',
        'successMsg': 'เย้! บันทึกรายรับเรียบร้อยแล้วค่ะ! ขอให้เงินทองไหลมาเทมา เฮงๆ นะคะเหมียว! 🐱✨',
        'themeColor': const Color(0xFF10B981), // สีเขียวรายรับ
        'iconColor': const Color(0xFF059669),
        'avatarColor': const Color(0xFF10B981),
        'cardIcon': Icons.payments_outlined, // ไอคอนเงินรายรับ
      },
      {
        'id': 'dream',
        'name': 'น้องหมีปั้นฝัน',
        'emoji': '🐻',
        'avatarAsset': 'assets/images/bear_avatar.jpg',
        'intro': 'สวัสดีครับ! ผม น้องหมีปั้นฝัน 🐻 ยินดีที่ได้ช่วยคุณออมเงินเพื่อล่าฝันครับ! บอกจำนวนเงินที่ต้องการหยอดกระปุกมาได้เลย เช่น "ซื้อรองเท้า 200" หรือ "เที่ยวญี่ปุ่น 1500"',
        'successMsg': 'ยอดเยี่ยมมากครับ! บันทึกเงินออมเรียบร้อยแล้ว ความฝันเข้าใกล้มาอีกก้าวแล้วนะครับ 🐻✨',
        'themeColor': const Color(0xFFFBBF24), // สีทองม่วงความฝัน (ใช้ขอบทอง ไอคอนม่วง)
        'iconColor': const Color(0xFF8B5CF6),
        'avatarColor': const Color(0xFF8B5CF6),
        'cardIcon': Icons.auto_awesome, // ไอคอนความฝันประกายดาว
      },
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: FloatingBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView.separated(
                      itemCount: aiBots.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final bot = aiBots[index];
                        final Color mainColor = bot['themeColor'] as Color;
                        final Color iconColor = bot['iconColor'] as Color;
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatConversationScreen(bot: bot),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.015),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            child: Row(
                              children: [
                                // แถบสีบ่งบอกประเภทแบบกลมมน (Vertical Status Pill)
                                Container(
                                  width: 4.5,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: mainColor,
                                    borderRadius: BorderRadius.circular(2.25),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // รูปอวาตาร์ภาพวาดการ์ตูนสุดสวย
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    image: DecorationImage(
                                      image: AssetImage(bot['avatarAsset'] as String),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // รายละเอียดบอท (ชื่อ และสถานะออนไลน์ คลีนๆ)
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          bot['name'] as String,
                                          style: const TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // ป้ายสถานะ Online คลีนๆ
                                      Row(
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF10B981),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'ออนไลน์',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: Color(0xFF10B981),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // ไอคอนระบุประเภทด้านขวาสุด เรียบร้อยสวยงาม
                                Icon(
                                  bot['cardIcon'] as IconData,
                                  color: iconColor.withValues(alpha: 0.8),
                                  size: 20,
                                ),
                              ],
                            ),
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

class ChatConversationScreen extends StatefulWidget {
  final Map<String, dynamic> bot;
  const ChatConversationScreen({super.key, required this.bot});

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final List<Message> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  List<QuickSuggestion> _quickSuggestions = [];
  List<Map<String, dynamic>> _rawSuggestions = [];

  IconData _getIconForExpenseCategory(String category) {
    switch (category) {
      case 'ค่าเช่า': return Icons.home_outlined;
      case 'ค่าเดินทาง': return Icons.directions_car_outlined;
      case 'ค่าเน็ต/โทรศัพท์': return Icons.language_outlined;
      case 'ค่าน้ำ/ค่าไฟ': return Icons.lightbulb_outline;
      case 'ประกัน/ภาษี': return Icons.security_outlined;
      case 'สตรีมมิ่ง/บันเทิง': return Icons.play_circle_outline;
      case 'ชำระหนี้': return Icons.credit_card_outlined;
      case 'ครอบครัว/บุตร': return Icons.family_restroom_outlined;
      case 'สุขภาพ/ยารักษาโรค': return Icons.medical_services_outlined;
      case 'การศึกษา': return Icons.school_outlined;
      default: return Icons.more_horiz_outlined;
    }
  }

  IconData _getIconForIncomeCategory(String category) {
    switch (category) {
      case 'เงินเดือน': return Icons.work_outline;
      case 'Freelance': return Icons.phone_android_outlined;
      case 'ธุรกิจ': return Icons.storefront_outlined;
      case 'ลงทุน': return Icons.trending_up_outlined;
      case 'ขายของ': return Icons.shopping_cart_outlined;
      case 'โบนัส': return Icons.card_giftcard_outlined;
      case 'ค่าเช่า': return Icons.business_outlined;
      case 'ค่าคอมมิชชั่น': return Icons.percent_outlined;
      case 'ค่าตอบแทน': return Icons.redeem_outlined;
      case 'รายได้เสริม': return Icons.flash_on_outlined;
      default: return Icons.more_horiz_outlined;
    }
  }

  IconData _getIconForDreamKey(String? key) {
    switch (key) {
      case 'Home': return Icons.home_outlined;
      case 'Car': return Icons.directions_car_outlined;
      case 'Motorcycle': return Icons.two_wheeler_outlined;
      case 'Plane': return Icons.flight_outlined;
      case 'Phone': return Icons.phone_android_outlined;
      case 'Laptop': return Icons.laptop_chromebook_outlined;
      case 'iPad': return Icons.tablet_android_outlined;
      case 'Camera': return Icons.camera_alt_outlined;
      case 'Graduation': return Icons.school_outlined;
      case 'Heart': return Icons.favorite_border_outlined;
      case 'Fund': return Icons.account_balance_outlined;
      case 'Stock': return Icons.candlestick_chart_outlined;
      case 'Gold': return Icons.diamond_outlined;
      case 'Crypto': return Icons.currency_bitcoin_outlined;
      case 'Restaurant': return Icons.restaurant_outlined;
      case 'Business': return Icons.storefront_outlined;
      case 'Retire': return Icons.elderly_outlined;
      case 'Health': return Icons.fitness_center_outlined;
      case 'Clothes': return Icons.checkroom_outlined;
      case 'Shoes': return Icons.ice_skating_outlined;
      case 'Watch': return Icons.watch_outlined;
      case 'Bag': return Icons.backpack_outlined;
      case 'Audio': return Icons.headphones_outlined;
      case 'Game': return Icons.sports_esports_outlined;
      default: return Icons.auto_awesome;
    }
  }

  String get _activeUserId {
    if (AuthSession.userId == null) {
      throw Exception('เข้าถึงข้อมูลโดยไม่ได้รับอนุญาต กรุณาเข้าสู่ระบบก่อน');
    }
    return AuthSession.userId!;
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadQuickSuggestions();
    await _loadPastTransactions();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadQuickSuggestions() async {
    final botId = widget.bot['id'] as String;
    String endpoint = '';
    if (botId == 'expense') {
      endpoint = '/recurring/expenses?user_id=eq.$_activeUserId';
    } else if (botId == 'income') {
      endpoint = '/recurring/sources?user_id=eq.$_activeUserId';
    } else if (botId == 'dream') {
      endpoint = '/dreams?user_id=eq.$_activeUserId';
    }

    if (endpoint.isEmpty) return;

    try {
      final response = await _apiClient.get(endpoint);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Map<String, dynamic>> parsedData = List<Map<String, dynamic>>.from(data);

        // ดึงรายการธุรกรรมในเดือนปัจจุบันเพื่อฟิลเตอร์ตัวที่ทำไปแล้วออก
        final txResponse = await _apiClient.get('/transactions?user_id=eq.$_activeUserId');
        if (txResponse.statusCode == 200) {
          final List<dynamic> txList = jsonDecode(txResponse.body);
          final now = DateTime.now();

          // คำนวณหาตัวเลือกที่ไม่ซ้ำซ้อน
          final List<QuickSuggestion> filteredSuggestions = [];
          for (var item in parsedData) {
            final name = (botId == 'dream' ? item['title'] : item['name'])?.toString() ?? '';
            final id = item['id']?.toString() ?? '';
            if (name.isEmpty) continue;

            double totalPaid = 0.0;
            for (var tx in txList) {
              final dateStr = tx['transaction_date'] ?? '';
              final date = DateTime.tryParse(dateStr);
              if (date != null && date.year == now.year && date.month == now.month) {
                if (botId == 'expense' && (tx['fixed_expense_id']?.toString() == id || tx['note']?.toString() == '[รายจ่ายประจำ] $name' || tx['note']?.toString() == name)) {
                  totalPaid += (tx['amount'] as num?)?.toDouble() ?? 0.0;
                } else if (botId == 'income' && (tx['income_source_id']?.toString() == id || tx['note']?.toString() == '[รายรับประจำ] $name' || tx['note']?.toString() == name)) {
                  totalPaid += (tx['amount'] as num?)?.toDouble() ?? 0.0;
                }
              }
            }
            final expectedAmt = (item['amount'] as num?)?.toDouble() ?? 0.0;
            final isAlreadyDone = totalPaid >= expectedAmt;

            if (botId == 'dream') {
              final target = (item['target_amount'] as num?)?.toDouble() ?? 0.0;
              final current = (item['current_amount'] as num?)?.toDouble() ?? 0.0;
              if (current >= target) continue; // ข้ามหากเก็บเต็มแล้ว
            } else if (isAlreadyDone) {
              continue; // ข้ามหากจ่าย/รับครบยอดตามแผนในเดือนนี้แล้ว
            }

            // เลือกไอคอนที่ตรงกับหมวดหมู่ของรายการแนะนำด่วน
            IconData iconData = Icons.auto_awesome;
            if (botId == 'expense') {
              iconData = _getIconForExpenseCategory(item['category']?.toString() ?? '');
            } else if (botId == 'income') {
              iconData = _getIconForIncomeCategory(item['category']?.toString() ?? '');
            } else if (botId == 'dream') {
              iconData = _getIconForDreamKey(item['icon']?.toString() ?? '');
            }

            filteredSuggestions.add(QuickSuggestion(
              id: id,
              name: name,
              icon: iconData,
            ));
          }

          setState(() {
            _rawSuggestions = parsedData;
            _quickSuggestions = filteredSuggestions;
          });
        }
      }
    } catch (e) {
      // Fail silently
    }
  }

  void _onSuggestionTap(String suggestion) {
    setState(() {
      _inputController.text = "$suggestion ";
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
    });
    _focusNode.requestFocus();
  }

  Future<void> _loadPastTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.get(
        '/transactions?user_id=eq.$_activeUserId&order=transaction_date.asc',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final botId = widget.bot['id'] as String;
        final now = DateTime.now();

        // Pre-calculate monthly accumulated sums by item name
        final Map<String, double> accumulatedMap = {};
        for (var tx in data) {
          final dateStr = tx['transaction_date'] ?? '';
          final date = DateTime.tryParse(dateStr);
          if (date != null && date.year == now.year && date.month == now.month) {
            final noteText = tx['note']?.toString() ?? '';
            final txAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
            final cleanNote = noteText.replaceAll('[รายจ่ายประจำ]', '').replaceAll('[รายรับประจำ]', '').replaceAll('[ออม] หยอดกระปุก:', '').trim().toLowerCase();
            accumulatedMap[cleanNote] = (accumulatedMap[cleanNote] ?? 0.0) + txAmount;
          }
        }

        setState(() {
          _messages.clear();
          // - ข้อความต้อนรับ
          _messages.add(
            Message(
              text: widget.bot['intro'] as String,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );

          for (var tx in data) {
            final name = tx['note'] ?? '';
            final amount = (tx['amount'] as num).toDouble();
            final dateStr = tx['transaction_date'] ?? '';
            final timestamp = DateTime.tryParse(dateStr) ?? DateTime.now();
            final type = tx['type'] ?? 'expense';

            bool isMatching = false;
            String displayName = name;
            String category = 'รายจ่าย';

            if (name.startsWith('[ออม] หยอดกระปุก: ')) {
              displayName = name.replaceAll('[ออม] หยอดกระปุก: ', '');
              category = 'เงินออม';
              if (botId == 'dream') isMatching = true;
            } else if (name.startsWith('[รายจ่ายประจำ] ')) {
              displayName = name.replaceAll('[รายจ่ายประจำ] ', '');
              category = 'รายจ่าย';
              if (botId == 'expense') isMatching = true;
            } else if (name.startsWith('[รายรับประจำ] ')) {
              displayName = name.replaceAll('[รายรับประจำ] ', '');
              category = 'รายรับ';
              if (botId == 'income') isMatching = true;
            } else if (type == 'income') {
              category = 'รายรับ';
              if (botId == 'income') isMatching = true;
            } else {
              category = 'รายจ่าย';
              if (botId == 'expense') isMatching = true;
            }

            if (isMatching) {
              final cleanName = displayName.trim().toLowerCase();
              double budget = 0.0;
              bool hasBudget = false;

              for (var sugg in _rawSuggestions) {
                final suggName = (botId == 'dream' ? sugg['title'] : sugg['name'])?.toString().toLowerCase();
                if (suggName == cleanName) {
                  hasBudget = true;
                  if (botId == 'expense' || botId == 'income') {
                    budget = (sugg['amount'] as num?)?.toDouble() ?? 0.0;
                  } else if (botId == 'dream') {
                    budget = (sugg['target_amount'] as num?)?.toDouble() ?? 0.0;
                  }
                  break;
                }
              }

              final totalAccumulated = accumulatedMap[cleanName] ?? amount;

              _messages.add(
                Message(
                  text: '',
                  isUser: false,
                  timestamp: timestamp,
                  cardData: {
                    'name': displayName,
                    'amount': amount,
                    'category': category,
                    'hasBudget': hasBudget,
                    'budget': budget,
                    'totalAccumulated': totalAccumulated,
                  },
                ),
              );
            }
          }
        });
        _scrollToBottom();
      } else {
        _showErrorPlaceholder();
      }
    } catch (e) {
      _showErrorPlaceholder();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorPlaceholder() {
    setState(() {
      _messages.clear();
      _messages.add(
        Message(
          text: widget.bot['intro'] as String,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Map<String, dynamic>> _parseInput(String input, String botId) {
    final RegExp regex = RegExp(r'([+*-]?[^\d\s]+)\s*(\d+)');
    final matches = regex.allMatches(input);
    List<Map<String, dynamic>> results = [];

    // กรณีพิมพ์แบบปกติ เช่น "อาหาร 50" ไม่มีเครื่องหมายนำหน้า
    if (matches.isEmpty) {
      // ลองจับคู่คำทั่วไปที่มีตัวเลข เช่น "ข้าวผัด 80"
      final RegExp simpleRegex = RegExp(r'([^\d\s]+)\s*(\d+)');
      final simpleMatch = simpleRegex.firstMatch(input);
      if (simpleMatch != null) {
        final name = simpleMatch.group(1)?.trim() ?? '';
        final amountStr = simpleMatch.group(2) ?? '0';
        final amount = double.tryParse(amountStr) ?? 0.0;
        
        if (name.isNotEmpty && amount > 0) {
          String type = 'expense';
          String note = name;
          String category = 'รายจ่าย';

          if (botId == 'income') {
            type = 'income';
            category = 'รายรับ';
          } else if (botId == 'dream') {
            type = 'expense';
            category = 'เงินออม';
            note = '[ออม] หยอดกระปุก: $name';
          }

          results.add({
            'name': name,
            'note': note,
            'amount': amount,
            'type': type,
            'category': category,
          });
          return results;
        }
      }
    }

    for (var match in matches) {
      final name = match.group(1)?.trim() ?? '';
      final amountStr = match.group(2) ?? '0';
      final amount = double.tryParse(amountStr) ?? 0.0;
      if (name.isNotEmpty && amount > 0) {
        String type = 'expense';
        String note = name;
        String category = 'รายจ่าย';

        if (name.startsWith('+')) {
          type = 'income';
          category = 'รายรับ';
          note = name.substring(1).trim();
        } else if (name.startsWith('*')) {
          type = 'expense';
          category = 'เงินออม';
          final dreamTitle = name.substring(1).trim();
          note = '[ออม] หยอดกระปุก: $dreamTitle';
        } else if (name.startsWith('-')) {
          type = 'expense';
          category = 'รายจ่าย';
          note = name.substring(1).trim();
        } else {
          // หากไม่มีเครื่องหมายนำหน้า ให้เลือกประเภทตามชนิดของ Bot ตัวนั้นๆ
          if (botId == 'income') {
            type = 'income';
            category = 'รายรับ';
          } else if (botId == 'dream') {
            type = 'expense';
            category = 'เงินออม';
            note = '[ออม] หยอดกระปุก: $name';
          }
        }

        results.add({
          'name': name.replaceAll(RegExp(r'^[+*-]'), '').trim(),
          'note': note,
          'amount': amount,
          'type': type,
          'category': category,
        });
      }
    }
    return results;
  }

  void _handleSendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        Message(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
    });
    _inputController.clear();
    _scrollToBottom();

    final thinkingMessage = Message(
      text: 'กำลังบันทึกข้อมูล . . .',
      isUser: false,
      timestamp: DateTime.now(),
      isThinking: true,
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        _messages.add(thinkingMessage);
      });
      _scrollToBottom();
    });

    final botId = widget.bot['id'] as String;

    Future.delayed(const Duration(milliseconds: 1000), () async {
      final parsedItems = _parseInput(text, botId);

      setState(() {
        _messages.remove(thinkingMessage);
      });

      if (parsedItems.isEmpty) {
        setState(() {
          _messages.add(
            Message(
              text: 'ขออภัยครับ ฉันไม่เข้าใจรูปแบบของคุณ ลองป้อนใหม่ เช่น "ข้าวผัด 60" หรือ "เงินเดือน 20000" นะครับ',
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
            ),
          );
        });
        _scrollToBottom();
        return;
      }

      for (var item in parsedItems) {
        final name = item['name'] as String;
        final note = item['note'] as String;
        final amount = item['amount'] as double;
        final type = item['type'] as String;
        final category = item['category'] as String;

        try {
          String? fixedExpenseId;
          String? incomeSourceId;
          String finalNote = note;

          // ตรวจหา ID ที่มีชื่อตรงกับรายการแนะนำด่วน เพื่อเชื่อมโยง Foreign Key และจัดรูปแบบ Prefix ในฐานข้อมูล
          Map<String, dynamic>? matchedSuggestion;
          for (var sugg in _rawSuggestions) {
            final suggName = (botId == 'dream' ? sugg['title'] : sugg['name'])?.toString().toLowerCase();
            if (suggName == name.toLowerCase()) {
              matchedSuggestion = sugg;
              break;
            }
          }

          if (matchedSuggestion != null) {
            final suggestionId = matchedSuggestion['id']?.toString();
            if (botId == 'expense') {
              fixedExpenseId = suggestionId;
              finalNote = '[รายจ่ายประจำ] $name';
            } else if (botId == 'income') {
              incomeSourceId = suggestionId;
              finalNote = '[รายรับประจำ] $name';
            } else if (botId == 'dream') {
              finalNote = '[ออม] หยอดกระปุก: $name';
            }
          }

          final Map<String, dynamic> body = {
            'user_id': _activeUserId,
            'type': type,
            'amount': amount,
            'note': finalNote,
            'transaction_date': DateTime.now().toUtc().toIso8601String(),
          };
          if (fixedExpenseId != null) {
            body['fixed_expense_id'] = fixedExpenseId;
          }
          if (incomeSourceId != null) {
            body['income_source_id'] = incomeSourceId;
          }

          final response = await _apiClient.post('/transactions', body: body);

          if (response.statusCode == 200 || response.statusCode == 201) {
            // อัปเดตยอดสะสมความฝันอัตโนมัติหากเป็นเงินออม
            if (note.startsWith('[ออม] หยอดกระปุก: ')) {
              final dreamTitle = note.replaceAll('[ออม] หยอดกระปุก: ', '').trim();
              final dreamsResp = await _apiClient.get('/dreams?user_id=eq.$_activeUserId&title=eq.$dreamTitle');
              if (dreamsResp.statusCode == 200) {
                final List<dynamic> matchingDreams = jsonDecode(dreamsResp.body);
                if (matchingDreams.isNotEmpty) {
                  final dream = matchingDreams.first;
                  final double newSaved = (dream['current_amount'] as num).toDouble() + amount;
                  await _apiClient.post('/dreams?id=eq.${dream['id']}', body: {
                    'current_amount': newSaved,
                  });
                }
              }
            }

            double budget = 0.0;
            bool hasBudget = false;
            if (matchedSuggestion != null) {
              hasBudget = true;
              if (botId == 'expense' || botId == 'income') {
                budget = (matchedSuggestion['amount'] as num?)?.toDouble() ?? 0.0;
              } else if (botId == 'dream') {
                budget = (matchedSuggestion['target_amount'] as num?)?.toDouble() ?? 0.0;
              }
            }

            double totalAccumulated = 0.0;
            try {
              final txResponseForSum = await _apiClient.get('/transactions?user_id=eq.$_activeUserId');
              if (txResponseForSum.statusCode == 200) {
                final List<dynamic> txList = jsonDecode(txResponseForSum.body);
                final now = DateTime.now();
                for (var tx in txList) {
                  final dateStr = tx['transaction_date'] ?? '';
                  final date = DateTime.tryParse(dateStr);
                  final noteText = tx['note']?.toString() ?? '';
                  final txAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                  
                  if (date != null && date.year == now.year && date.month == now.month) {
                    final cleanNote = noteText.replaceAll('[รายจ่ายประจำ]', '').replaceAll('[รายรับประจำ]', '').replaceAll('[ออม] หยอดกระปุก:', '').trim().toLowerCase();
                    final cleanName = name.trim().toLowerCase();
                    if (cleanNote == cleanName || (cleanNote.isNotEmpty && cleanName.isNotEmpty && (cleanNote.contains(cleanName) || cleanName.contains(cleanNote)))) {
                      totalAccumulated += txAmount;
                    }
                  }
                }
              }
            } catch (e) {
              totalAccumulated = amount;
            }

            final String replyText = hasBudget
                ? widget.bot['successMsg'] as String
                : 'คุณยังไม่ได้สร้างรายการนี้ที่หน้า Planning ลองไปสร้างดูนะ!';

            setState(() {
              _messages.add(
                Message(
                  text: replyText,
                  isUser: false,
                  timestamp: DateTime.now(),
                ),
              );
              _messages.add(
                Message(
                  text: '',
                  isUser: false,
                  timestamp: DateTime.now(),
                  cardData: {
                    'name': name,
                    'amount': amount,
                    'category': category,
                    'hasBudget': hasBudget,
                    'budget': budget,
                    'totalAccumulated': totalAccumulated,
                  },
                ),
              );
            });
            // รีโหลดข้อมูลรายการทางลัด เพื่อตัดรายการที่ถูกทำไปแล้วออกทันที
            _loadQuickSuggestions();
          } else {
            _addLocalFallbackMessage(name, amount, category);
          }
        } catch (e) {
          _addLocalFallbackMessage(name, amount, category);
        }
      }
      _scrollToBottom();
    });
  }

  void _addLocalFallbackMessage(String name, double amount, String category) {
    setState(() {
      _messages.add(
        Message(
          text: 'บันทึกสำเร็จชั่วคราวในเครื่อง (ขัดข้องด้านการเชื่อมต่อระบบคลาวด์)',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      _messages.add(
        Message(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          cardData: {
            'name': name,
            'amount': amount,
            'category': category,
            'hasBudget': false,
            'budget': 0.0,
            'totalAccumulated': amount,
          },
        ),
      );
    });
  }

  Widget _buildBotAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        image: DecorationImage(
          image: AssetImage(widget.bot['avatarAsset'] as String),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    if (message.cardData != null) {
      final card = message.cardData!;
      final name = card['name'] ?? '';
      final amount = (card['amount'] as num?)?.toDouble() ?? 0.0;
      final category = card['category'] ?? 'รายจ่าย';
      
      final bool hasBudget = card['hasBudget'] as bool? ?? false;
      final double budget = (card['budget'] as num?)?.toDouble() ?? 0.0;
      final double totalAccumulated = (card['totalAccumulated'] as num?)?.toDouble() ?? amount;

      Color categoryColor = const Color(0xFF10B981);
      Color headerBgColor = const Color(0xFFE6F4F1); // Emerald pastel
      IconData headerIcon = Icons.trending_up_outlined;

      if (category == 'รายจ่าย') {
        categoryColor = const Color(0xFFEF4444);
        headerBgColor = const Color(0xFFFEE2E2); // Rose-100 pastel
        headerIcon = Icons.trending_down_outlined;
      } else if (category == 'เงินออม') {
        categoryColor = const Color(0xFFF59E0B);
        headerBgColor = const Color(0xFFFEF3C7); // Amber-100 pastel
        headerIcon = Icons.auto_awesome;
      }

      final double progress = budget > 0 ? (totalAccumulated / budget).clamp(0.0, 1.0) : 0.0;

      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 280,
          margin: const EdgeInsets.only(left: 48, right: 48, top: 4, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ส่วนหัวการ์ด (Header Block)
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: headerBgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        headerIcon,
                        size: 40,
                        color: categoryColor.withValues(alpha: 0.8),
                      ),
                    ),
                    if (!hasBudget)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444), width: 1),
                          ),
                          child: const Text(
                            'ไม่มีงบ',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ส่วนรายละเอียด
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '฿${amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${totalAccumulated.toStringAsFixed(0)} / ${budget.toStringAsFixed(0)} บาท',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: categoryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          hasBudget ? categoryColor : const Color(0xFFEF4444),
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isUser ? 64 : 16,
          right: isUser ? 16 : 64,
          top: 4,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: message.isThinking
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
                  ),
                ],
              )
            : Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final botName = widget.bot['name'] as String;
    final botColor = widget.bot['avatarColor'] as Color;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                image: DecorationImage(
                  image: AssetImage(widget.bot['avatarAsset'] as String),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  botName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'กำลังตอบกลับความรู้การเงิน',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.bot['id'] == 'expense'
                  ? Icons.assignment_outlined
                  : widget.bot['id'] == 'income'
                      ? Icons.trending_up_outlined
                      : Icons.star_outline,
              color: botColor,
              size: 22,
            ),
            tooltip: widget.bot['id'] == 'expense'
                ? 'ดูรายการแผนรายจ่ายประจำ'
                : widget.bot['id'] == 'income'
                    ? 'ดูรายการแผนรายรับประจำ'
                    : 'ดูกระปุกความฝัน',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    final botId = widget.bot['id'] as String;
                    if (botId == 'expense') {
                      return const RecurringExpenseScreen();
                    } else if (botId == 'income') {
                      return const RecurringIncomeScreen();
                    } else {
                      return const DreamsScreen();
                    }
                  },
                ),
              ).then((_) {
                _loadQuickSuggestions();
              });
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: FloatingBackground()),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isUser = message.isUser;
                    final showAvatar = !isUser && (index == 0 || _messages[index - 1].isUser);

                    if (showAvatar) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBotAvatar(),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMessageBubble(message),
                          ),
                        ],
                      );
                    } else {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser) const SizedBox(width: 40),
                          Expanded(
                            child: _buildMessageBubble(message),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2),
                  ),
                ),
              
              // กล่องรายการทางลัดสำหรับกรอกข้อมูลอัตโนมัติ (Quick Chips)
              if (_quickSuggestions.isNotEmpty)
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _quickSuggestions[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ActionChip(
                          avatar: Icon(
                            suggestion.icon,
                            size: 16,
                            color: botColor,
                          ),
                          label: Text(
                            suggestion.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: botColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: botColor.withValues(alpha: 0.08),
                          side: BorderSide(color: botColor.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onPressed: () => _onSuggestionTap(suggestion.name),
                        ),
                      );
                    },
                  ),
                ),
                
              Container(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom + 4
                      : 12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_note_outlined, color: Color(0xFF64748B), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _inputController,
                                focusNode: _focusNode,
                                decoration: InputDecoration(
                                  hintText: 'พิมพ์บอก$botName เช่น ข้าวผัด 50',
                                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _handleSendMessage(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _handleSendMessage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: botColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
