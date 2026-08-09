import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:app/core/localization/app_material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_icon_selector.dart';
import '../../auth/domain/auth_session.dart';
import '../../../core/settings/app_settings.dart';

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
  final dynamic icon;
  final String type;

  const QuickSuggestion({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
  });
}

class TransactionsScreen extends StatefulWidget {
  final double topPadding;
  final GlobalKey? inputKey;

  const TransactionsScreen({super.key, this.topPadding = 16, this.inputKey});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with WidgetsBindingObserver {
  final List<Message> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ApiClient _apiClient = ApiClient();
  final AudioPlayer _aiReplyPlayer = AudioPlayer();
  bool _isLoading = false;
  bool _canSend = false;
  bool _showQuickSuggestions = true;

  List<Map<String, dynamic>> _rawSuggestions = [];
  List<QuickSuggestion> _quickSuggestions = [];
  String _inputType = 'expense';

  static const String _introText =
      'ระบบบันทึกรายการอัตโนมัติเปิดใช้งานแล้ว ระบุรายการและจำนวนเงินที่ต้องการบันทึก เช่น "ค่าห้อง 3500" หรือเลือกรายการด่วนด้านล่าง';

  String get _activeUserId {
    if (AuthSession.userId == null) {
      throw Exception('เข้าถึงข้อมูลโดยไม่ได้รับอนุญาต กรุณาเข้าสู่ระบบก่อน');
    }
    return AuthSession.userId!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(_handleInputFocusChange);
    _inputController.addListener(_handleInputChanged);
    _initData();
  }

  Future<void> _initData() async {
    _addIntroMessage();
    await _loadQuickSuggestions();
    await _loadPastTransactions();
  }

  void _addIntroMessage() {
    setState(() {
      _messages.add(
        Message(text: _introText, isUser: false, timestamp: DateTime.now()),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_handleInputFocusChange);
    _inputController.removeListener(_handleInputChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _aiReplyPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAiReplySound() async {
    try {
      await _aiReplyPlayer.stop();
      await _aiReplyPlayer.play(AssetSource('sounds/ai_reply.mp3'));
    } catch (_) {
      // เสียงไม่ควรขัดจังหวะการใช้งานแชทหากอุปกรณ์ไม่พร้อม
    }
  }

  void _handleInputChanged() {
    final canSend = _inputController.text.trim().isNotEmpty;
    if (mounted && _canSend != canSend) {
      setState(() {
        _canSend = canSend;
      });
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_focusNode.hasFocus) {
      _keepLatestMessageVisible();
    }
  }

  void _handleInputFocusChange() {
    if (!_focusNode.hasFocus) return;
    _keepLatestMessageVisible();
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (mounted && _focusNode.hasFocus) {
        _keepLatestMessageVisible();
      }
    });
  }

  void _keepLatestMessageVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _loadQuickSuggestions() async {
    try {
      final List<Map<String, dynamic>> allRaw = [];

      // โหลดข้อมูลจาก 3 แหล่งพร้อมกัน
      final responses = await Future.wait([
        _apiClient.get('/recurring/expenses?user_id=eq.$_activeUserId'),
        _apiClient.get('/recurring/sources?user_id=eq.$_activeUserId'),
        _apiClient.get('/dreams?user_id=eq.$_activeUserId'),
      ]);

      final List<dynamic> expensesData = responses[0].statusCode == 200
          ? jsonDecode(responses[0].body)
          : [];
      final List<dynamic> incomesData = responses[1].statusCode == 200
          ? jsonDecode(responses[1].body)
          : [];
      final List<dynamic> dreamsData = responses[2].statusCode == 200
          ? jsonDecode(responses[2].body)
          : [];
      // --- Expenses ---
      for (var item in expensesData) {
        item['bot_type'] = 'expense';
        allRaw.add(item);
        final name = item['name']?.toString().trim() ?? '';
        if (name == 'ค่าใช้จ่ายรายเดือน') continue;
        _addQuickSuggestion(
          item,
          type: 'expense',
          name: name,
          icon: _getIconForExpenseCategory(item['category']?.toString() ?? ''),
        );
      }

      // --- Incomes ---
      for (var item in incomesData) {
        item['bot_type'] = 'income';
        allRaw.add(item);
        _addQuickSuggestion(
          item,
          type: 'income',
          name: item['name']?.toString() ?? '',
          icon: _getIconForIncomeCategory(item['category']?.toString() ?? ''),
        );
      }

      // --- Dreams ---
      for (var item in dreamsData) {
        item['bot_type'] = 'dream';
        allRaw.add(item);
        _addQuickSuggestion(
          item,
          type: 'dream',
          name: item['title']?.toString() ?? '',
          icon: _getIconForDreamKey(item['icon']?.toString()),
        );
      }

      setState(() {
        _rawSuggestions = allRaw;
        _quickSuggestions = _quickSuggestionsFromRaw(allRaw);
      });
    } catch (e) {
      // Fail silently
    }
  }

  void _addQuickSuggestion(
    Map<String, dynamic> item, {
    required String type,
    required String name,
    required dynamic icon,
  }) {
    if (name.trim().isEmpty) return;
    item['quick_type'] = type;
    item['quick_name'] = name;
    item['quick_icon'] = icon;
  }

  dynamic _getIconForExpenseCategory(String category) {
    if (category.contains('|')) {
      return SharedIconSelector.buildIcon(category, size: 28);
    }
    switch (category) {
      case 'ค่าเช่า':
        return Icons.home_outlined;
      case 'ผ่อนรถ':
        return Icons.directions_car_outlined;
      case 'ค่าไฟ':
        return Icons.flash_on_outlined;
      case 'ค่าน้ำ':
        return Icons.water_drop_outlined;
      case 'ค่าอินเทอร์เน็ต':
        return Icons.wifi;
      case 'ค่ามือถือ':
        return Icons.phone_android_outlined;
      case 'ค่าเรียน':
        return Icons.school_outlined;
      case 'ค่าประกัน':
        return Icons.shield_outlined;
      case 'สมาชิกยิม':
        return Icons.fitness_center_outlined;
      case 'สมาชิก Netflix':
        return Icons.tv_outlined;
      case 'สมาชิก Spotify':
        return Icons.music_note_outlined;
      case 'ค่าอาหาร':
        return Icons.local_cafe_outlined;
      case 'ค่ารักษา':
        return Icons.favorite_border_outlined;
      case 'ออมเงิน':
        return Icons.savings_outlined;
      default:
        return Icons.more_horiz_outlined;
    }
  }

  dynamic _getIconForIncomeCategory(String category) {
    if (category.contains('|')) {
      return SharedIconSelector.buildIcon(category, size: 28);
    }
    switch (category) {
      case 'เงินเดือน':
        return Icons.work_outline;
      case 'Freelance':
        return Icons.phone_android_outlined;
      case 'ธุรกิจ':
        return Icons.storefront_outlined;
      case 'ลงทุน':
        return Icons.trending_up_outlined;
      case 'ขายของ':
        return Icons.shopping_cart_outlined;
      case 'โบนัส':
        return Icons.card_giftcard_outlined;
      case 'ค่าเช่า':
        return Icons.business_outlined;
      case 'ค่าคอมมิชชั่น':
        return Icons.percent_outlined;
      case 'ค่าตอบแทน':
        return Icons.redeem_outlined;
      case 'รายได้เสริม':
        return Icons.flash_on_outlined;
      default:
        return Icons.more_horiz_outlined;
    }
  }

  dynamic _getIconForDreamKey(String? key) {
    if (key != null && key.contains('|')) {
      return SharedIconSelector.buildIcon(key, size: 28);
    }
    switch (key) {
      case 'Home':
        return Icons.home_outlined;
      case 'Car':
        return Icons.directions_car_outlined;
      case 'Motorcycle':
        return Icons.two_wheeler_outlined;
      case 'Plane':
        return Icons.flight_outlined;
      case 'Phone':
        return Icons.phone_android_outlined;
      case 'Laptop':
        return Icons.laptop_chromebook_outlined;
      case 'iPad':
        return Icons.tablet_android_outlined;
      case 'Camera':
        return Icons.camera_alt_outlined;
      case 'Graduation':
        return Icons.school_outlined;
      case 'Heart':
        return Icons.favorite_border_outlined;
      case 'Fund':
        return Icons.account_balance_outlined;
      case 'Stock':
        return Icons.candlestick_chart_outlined;
      case 'Gold':
        return Icons.diamond_outlined;
      case 'Crypto':
        return Icons.currency_bitcoin_outlined;
      case 'Restaurant':
        return Icons.restaurant_outlined;
      case 'Business':
        return Icons.storefront_outlined;
      case 'Retire':
        return Icons.elderly_outlined;
      case 'Health':
        return Icons.fitness_center_outlined;
      case 'Clothes':
        return Icons.checkroom_outlined;
      case 'Shoes':
        return Icons.ice_skating_outlined;
      case 'Watch':
        return Icons.watch_outlined;
      case 'Bag':
        return Icons.backpack_outlined;
      case 'Audio':
        return Icons.headphones_outlined;
      case 'Game':
        return Icons.sports_esports_outlined;
      default:
        return Icons.more_horiz_outlined;
    }
  }

  List<QuickSuggestion> _quickSuggestionsFromRaw(
    List<Map<String, dynamic>> items,
  ) {
    return items
        .where((item) => item['quick_name'] != null)
        .map(
          (item) => QuickSuggestion(
            id: item['id']?.toString() ?? item['quick_name'].toString(),
            name: item['quick_name'].toString(),
            icon: item['quick_icon'] as dynamic,
            type: item['quick_type'].toString(),
          ),
        )
        .toList();
  }

  void _onSuggestionTap(QuickSuggestion suggestion) {
    setState(() {
      _inputType = suggestion.type;
    });
    _inputController.text = '${suggestion.name} ';
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
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
        final now = DateTime.now();

        // Pre-calculate monthly accumulated sums
        final Map<String, double> accumulatedMap = {};
        for (var tx in data) {
          final dateStr = tx['transaction_date'] ?? '';
          final date = DateTime.tryParse(dateStr);
          if (date != null &&
              date.year == now.year &&
              date.month == now.month) {
            final txAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
            final txFixedExpenseId = tx['fixed_expense_id']?.toString();
            final txIncomeSourceId = tx['income_source_id']?.toString();

            if (txFixedExpenseId != null) {
              accumulatedMap['expense_id_$txFixedExpenseId'] =
                  (accumulatedMap['expense_id_$txFixedExpenseId'] ?? 0.0) +
                  txAmount;
            } else if (txIncomeSourceId != null) {
              accumulatedMap['income_id_$txIncomeSourceId'] =
                  (accumulatedMap['income_id_$txIncomeSourceId'] ?? 0.0) +
                  txAmount;
            }

            final noteText = tx['note']?.toString() ?? '';
            final cleanNote = noteText
                .replaceAll('[รายจ่ายประจำ]', '')
                .replaceAll('[รายรับประจำ]', '')
                .replaceAll('[ออม] หยอดกระปุก:', '')
                .trim()
                .toLowerCase();
            accumulatedMap[cleanNote] =
                (accumulatedMap[cleanNote] ?? 0.0) + txAmount;
          }
        }

        setState(() {
          // Keep intro message
          final introMsg = _messages.isNotEmpty
              ? _messages.first
              : Message(
                  text: _introText,
                  isUser: false,
                  timestamp: DateTime.now(),
                );
          _messages.clear();
          _messages.add(introMsg);

          for (var tx in data) {
            final name = tx['note'] ?? '';
            final amount = (tx['amount'] as num).toDouble();
            final dateStr = tx['transaction_date'] ?? '';
            final timestamp = DateTime.tryParse(dateStr) ?? DateTime.now();
            final type = tx['type'] ?? 'expense';

            String displayName = name;
            String category = 'รายจ่าย';
            String msgType = 'expense';

            if (name.startsWith('[ออม] หยอดกระปุก: ')) {
              displayName = name.replaceAll('[ออม] หยอดกระปุก: ', '');
              category = 'เงินออม';
              msgType = 'dream';
            } else if (name.startsWith('[รายจ่ายประจำ] ')) {
              displayName = name.replaceAll('[รายจ่ายประจำ] ', '');
              category = 'รายจ่าย';
              msgType = 'expense';
            } else if (name.startsWith('[รายรับประจำ] ')) {
              displayName = name.replaceAll('[รายรับประจำ] ', '');
              category = 'รายรับ';
              msgType = 'income';
            } else if (type == 'income') {
              category = 'รายรับ';
              msgType = 'income';
            } else {
              category = 'รายจ่าย';
              msgType = 'expense';
            }

            final cleanName = displayName.trim().toLowerCase();
            double budget = 0.0;
            bool hasBudget = false;

            // ค้นหาข้อแนะนำที่ตรงกันโดยใช้ ID
            Map<String, dynamic>? matchedSugg;
            final txFixedExpenseId = tx['fixed_expense_id']?.toString();
            final txIncomeSourceId = tx['income_source_id']?.toString();

            if (txFixedExpenseId != null || txIncomeSourceId != null) {
              for (var sugg in _rawSuggestions) {
                final suggId = sugg['id']?.toString();
                if (msgType == 'expense' && suggId == txFixedExpenseId) {
                  matchedSugg = sugg;
                  break;
                } else if (msgType == 'income' && suggId == txIncomeSourceId) {
                  matchedSugg = sugg;
                  break;
                }
              }
            }

            if (matchedSugg == null) {
              for (var sugg in _rawSuggestions) {
                final suggName =
                    (sugg['bot_type'] == 'dream' ? sugg['title'] : sugg['name'])
                        ?.toString()
                        .toLowerCase();
                if (suggName == cleanName && sugg['bot_type'] == msgType) {
                  matchedSugg = sugg;
                  break;
                }
              }
            }

            // Fallback
            if (matchedSugg == null && msgType == 'expense') {
              for (var sugg in _rawSuggestions) {
                final suggName = sugg['name']?.toString().trim().toLowerCase();
                if (suggName == 'ค่าใช้จ่ายรายเดือน' &&
                    sugg['bot_type'] == 'expense') {
                  matchedSugg = sugg;
                  break;
                }
              }
            }

            if (matchedSugg != null) {
              hasBudget = true;
              if (msgType == 'expense' || msgType == 'income') {
                budget = (matchedSugg['amount'] as num?)?.toDouble() ?? 0.0;
              } else if (msgType == 'dream') {
                budget =
                    (matchedSugg['target_amount'] as num?)?.toDouble() ?? 0.0;
              }
            }

            final String? matchedId = matchedSugg?['id']?.toString();
            double totalAccumulated = amount;
            if (matchedId != null) {
              if (msgType == 'expense') {
                totalAccumulated =
                    accumulatedMap['expense_id_$matchedId'] ??
                    accumulatedMap[cleanName] ??
                    amount;
              } else if (msgType == 'income') {
                totalAccumulated =
                    accumulatedMap['income_id_$matchedId'] ??
                    accumulatedMap[cleanName] ??
                    amount;
              }
            } else {
              totalAccumulated = accumulatedMap[cleanName] ?? amount;
            }

            _messages.add(
              Message(
                text: '$displayName ${amount.toStringAsFixed(0)}',
                isUser: true,
                timestamp: timestamp,
              ),
            );
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
                  'msgType': msgType,
                },
              ),
            );
          }
        });
        _scrollToBottom();
      } else {
        // fail silently
      }
    } catch (e) {
      // fail silently
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _handleUserScroll(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.idle) return false;

    final shouldShow = notification.direction == ScrollDirection.reverse;
    if (_showQuickSuggestions != shouldShow) {
      setState(() {
        _showQuickSuggestions = shouldShow;
      });
    }
    return false;
  }

  List<Map<String, dynamic>> _parseInput(String input) {
    final RegExp regex = RegExp(r'([+*-]?[^\d\s]+)\s*(\d+)');
    final matches = regex.allMatches(input);
    List<Map<String, dynamic>> results = [];

    // กรณีพิมพ์แบบปกติ เช่น "อาหาร 50" ไม่มีเครื่องหมายนำหน้า
    if (matches.isEmpty) {
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
          String msgType = _inputType;

          if (msgType == 'income') {
            type = 'income';
            category = 'รายรับ';
          } else if (msgType == 'dream') {
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
            'msgType': msgType,
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
        String msgType = _inputType;

        if (name.startsWith('+')) {
          type = 'income';
          category = 'รายรับ';
          note = name.substring(1).trim();
          msgType = 'income';
        } else if (name.startsWith('*')) {
          type = 'expense';
          category = 'เงินออม';
          final dreamTitle = name.substring(1).trim();
          note = '[ออม] หยอดกระปุก: $dreamTitle';
          msgType = 'dream';
        } else if (name.startsWith('-')) {
          type = 'expense';
          category = 'รายจ่าย';
          note = name.substring(1).trim();
          msgType = 'expense';
        } else {
          // หากไม่มีเครื่องหมายนำหน้า ให้เลือกประเภทตาม Tab ที่เลือก
          if (msgType == 'income') {
            type = 'income';
            category = 'รายรับ';
          } else if (msgType == 'dream') {
            type = 'expense';
            category = 'เงินออม';
            note = '[ออม] หยอดกระปุก: $name';
          } else {
            msgType = 'expense';
          }
        }

        results.add({
          'name': name.replaceAll(RegExp(r'^[+*-]'), '').trim(),
          'note': note,
          'amount': amount,
          'type': type,
          'category': category,
          'msgType': msgType,
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
        Message(text: text, isUser: true, timestamp: DateTime.now()),
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

    Future.delayed(const Duration(milliseconds: 1000), () async {
      final parsedItems = _parseInput(text);

      setState(() {
        _messages.remove(thinkingMessage);
      });

      if (parsedItems.isEmpty) {
        setState(() {
          _messages.add(
            Message(
              text:
                  'ไม่พบข้อมูลที่ระบุ กรุณาระบุในรูปแบบ [รายการ] [จำนวนเงิน] เช่น "ข้าวผัด 60" หรือ "+เงินเดือน 20000"',
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
            ),
          );
        });
        _scrollToBottom();
        _playAiReplySound();
        return;
      }

      for (var item in parsedItems) {
        final name = item['name'] as String;
        final note = item['note'] as String;
        final amount = item['amount'] as double;
        final type = item['type'] as String;
        final category = item['category'] as String;
        final msgType = item['msgType'] as String; // expense, income, dream

        try {
          String? fixedExpenseId;
          String? incomeSourceId;
          String finalNote = note;

          Map<String, dynamic>? matchedSuggestion;
          for (var sugg in _rawSuggestions) {
            final suggName =
                (sugg['bot_type'] == 'dream' ? sugg['title'] : sugg['name'])
                    ?.toString()
                    .toLowerCase();
            if (suggName == name.toLowerCase() && sugg['bot_type'] == msgType) {
              matchedSuggestion = sugg;
              break;
            }
          }

          // Fallback ไปยัง "ค่าใช้จ่ายรายเดือน" ถ้ายังไม่เจอ และเป็นรายจ่าย
          if (matchedSuggestion == null && msgType == 'expense') {
            for (var sugg in _rawSuggestions) {
              final suggName = sugg['name']?.toString().trim().toLowerCase();
              if (suggName == 'ค่าใช้จ่ายรายเดือน' &&
                  sugg['bot_type'] == 'expense') {
                matchedSuggestion = sugg;
                break;
              }
            }

            // สร้างอัตโนมัติ
            if (matchedSuggestion == null) {
              try {
                final createResp = await _apiClient.post(
                  '/recurring/expenses',
                  headers: {'Prefer': 'return=representation'},
                  body: {
                    'user_id': _activeUserId,
                    'name': 'ค่าใช้จ่ายรายเดือน',
                    'amount': 0.0,
                    'category': 'อื่นๆ',
                    'due_day': 1,
                  },
                );
                if (createResp.statusCode == 200 ||
                    createResp.statusCode == 201) {
                  final List<dynamic> createdList = jsonDecode(createResp.body);
                  if (createdList.isNotEmpty) {
                    final Map<String, dynamic> newSuggestion =
                        createdList.first as Map<String, dynamic>;
                    newSuggestion['bot_type'] = 'expense';
                    matchedSuggestion = newSuggestion;
                    _rawSuggestions.add(newSuggestion);
                  }
                }
              } catch (e) {
                // Fallback query
                try {
                  final queryResp = await _apiClient.get(
                    '/recurring/expenses?user_id=eq.$_activeUserId&name=eq.ค่าใช้จ่ายรายเดือน',
                  );
                  if (queryResp.statusCode == 200) {
                    final List<dynamic> queriedList = jsonDecode(
                      queryResp.body,
                    );
                    if (queriedList.isNotEmpty) {
                      final Map<String, dynamic> newSuggestion =
                          queriedList.first as Map<String, dynamic>;
                      newSuggestion['bot_type'] = 'expense';
                      matchedSuggestion = newSuggestion;
                      _rawSuggestions.add(newSuggestion);
                    }
                  }
                } catch (_) {}
              }
            }
          }

          if (matchedSuggestion != null) {
            final suggestionId = matchedSuggestion['id']?.toString();
            if (msgType == 'expense') {
              fixedExpenseId = suggestionId;
              finalNote = '[รายจ่ายประจำ] $name';
            } else if (msgType == 'income') {
              incomeSourceId = suggestionId;
              finalNote = '[รายรับประจำ] $name';
            } else if (msgType == 'dream') {
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
            // Update dream amount
            if (note.startsWith('[ออม] หยอดกระปุก: ')) {
              final dreamTitle = note
                  .replaceAll('[ออม] หยอดกระปุก: ', '')
                  .trim();
              final dreamsResp = await _apiClient.get(
                '/dreams?user_id=eq.$_activeUserId&title=eq.$dreamTitle',
              );
              if (dreamsResp.statusCode == 200) {
                final List<dynamic> matchingDreams = jsonDecode(
                  dreamsResp.body,
                );
                if (matchingDreams.isNotEmpty) {
                  final dream = matchingDreams.first;
                  final double newSaved =
                      (dream['current_amount'] as num).toDouble() + amount;
                  await _apiClient.patch(
                    '/dreams?id=eq.${dream['id']}',
                    body: {'current_amount': newSaved},
                  );
                }
              }
            }

            double budget = 0.0;
            bool hasBudget = false;
            if (matchedSuggestion != null) {
              hasBudget = true;
              if (msgType == 'expense' || msgType == 'income') {
                budget =
                    (matchedSuggestion['amount'] as num?)?.toDouble() ?? 0.0;
              } else if (msgType == 'dream') {
                budget =
                    (matchedSuggestion['target_amount'] as num?)?.toDouble() ??
                    0.0;
              }
            }

            double totalAccumulated = 0.0;
            try {
              final txResponseForSum = await _apiClient.get(
                '/transactions?user_id=eq.$_activeUserId',
              );
              if (txResponseForSum.statusCode == 200) {
                final List<dynamic> txList = jsonDecode(txResponseForSum.body);
                final now = DateTime.now();
                final String? matchedId = matchedSuggestion?['id']?.toString();

                for (var tx in txList) {
                  final dateStr = tx['transaction_date'] ?? '';
                  final date = DateTime.tryParse(dateStr);
                  final noteText = tx['note']?.toString() ?? '';
                  final txAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                  final txFixedExpenseId = tx['fixed_expense_id']?.toString();
                  final txIncomeSourceId = tx['income_source_id']?.toString();

                  if (date != null &&
                      date.year == now.year &&
                      date.month == now.month) {
                    bool isTxMatch = false;
                    if (matchedId != null) {
                      if (msgType == 'expense' &&
                          txFixedExpenseId == matchedId) {
                        isTxMatch = true;
                      } else if (msgType == 'income' &&
                          txIncomeSourceId == matchedId) {
                        isTxMatch = true;
                      }
                    }
                    if (!isTxMatch) {
                      final cleanNote = noteText
                          .replaceAll('[รายจ่ายประจำ]', '')
                          .replaceAll('[รายรับประจำ]', '')
                          .replaceAll('[ออม] หยอดกระปุก:', '')
                          .trim()
                          .toLowerCase();
                      final cleanName = name.trim().toLowerCase();
                      if (cleanNote == cleanName ||
                          (cleanNote.isNotEmpty &&
                              cleanName.isNotEmpty &&
                              (cleanNote.contains(cleanName) ||
                                  cleanName.contains(cleanNote)))) {
                        isTxMatch = true;
                      }
                    }
                    if (isTxMatch) {
                      totalAccumulated += txAmount;
                    }
                  }
                }
              }
            } catch (e) {
              totalAccumulated = amount;
            }

            final String replyText = hasBudget
                ? _successMessage(msgType)
                : 'ไม่พบแผนงบประมาณที่ตรงกับรายการนี้ ยอดเงินถูกบันทึกสำเร็จแล้ว';

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
                    'msgType': msgType,
                    'icon': _getIconForTransaction(name, category, msgType, matchedSuggestion),
                  },
                ),
              );
            });
            _loadQuickSuggestions();
          } else {
            _addLocalFallbackMessage(name, amount, category, msgType);
          }
        } catch (e) {
          _addLocalFallbackMessage(name, amount, category, msgType);
        }
      }
      _scrollToBottom();
      _playAiReplySound();
    });
  }

  void _addLocalFallbackMessage(
    String name,
    double amount,
    String category,
    String msgType,
  ) {
    setState(() {
      _messages.add(
        Message(
          text: 'บันทึกสำเร็จชั่วคราวในเครื่อง (ขัดข้องด้านการเชื่อมต่อ)',
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
            'msgType': msgType,
            'icon': _getIconForTransaction(name, category, msgType, null),
          },
        ),
      );
    });
  }

  Widget _buildMessageBubble(Message message) {
    final compactAiWidth = MediaQuery.sizeOf(context).width * 0.55;

    if (message.cardData != null) {
      final card = message.cardData!;
      final name = card['name'] ?? '';
      final amount = (card['amount'] as num?)?.toDouble() ?? 0.0;
      final category = card['category'] ?? 'รายจ่าย';
      final msgType = card['msgType'] as String? ?? 'expense';

      final bool hasBudget = card['hasBudget'] as bool? ?? false;
      final double budget = (card['budget'] as num?)?.toDouble() ?? 0.0;
      final double totalAccumulated =
          (card['totalAccumulated'] as num?)?.toDouble() ?? amount;

      Color categoryColor = const Color(0xFF10B981);
      Color headerBgColor = const Color(0xFFE6F4F1);
      IconData headerIcon = Icons.account_balance_wallet_outlined;

      if (msgType == 'expense' || category == 'รายจ่าย') {
        categoryColor = const Color(0xFFEF4444);
        headerBgColor = const Color(0xFFFEE2E2);
        headerIcon = Icons.receipt_long_outlined;
      } else if (msgType == 'dream' || category == 'เงินออม') {
        categoryColor = const Color(0xFFF59E0B);
        headerBgColor = const Color(0xFFFEF3C7);
        headerIcon = Icons.auto_awesome;
      }

      final double progress = budget > 0
          ? (totalAccumulated / budget).clamp(0.0, 1.0)
          : 0.0;

      final style = AppSettings.themeStyle.value;
      BorderRadius cardRadius = BorderRadius.circular(16);
      Border cardBorder = Border.all(color: context.borderColor);
      
      switch (style) {
        case ThemeStyle.emerald:
          cardRadius = BorderRadius.circular(16);
          cardBorder = Border.all(color: context.borderColor, width: 1);
          break;
        case ThemeStyle.cartoon:
          cardRadius = BorderRadius.circular(20);
          cardBorder = Border.all(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFFDF5) : const Color(0xFF2B1A0E),
            width: 2.0,
          );
          break;
        case ThemeStyle.sakura:
          cardRadius = BorderRadius.circular(24);
          cardBorder = Border.all(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4C2731) : const Color(0xFFFFE3E7),
            width: 1.2,
          );
          break;
        case ThemeStyle.cyberpunk:
          cardRadius = BorderRadius.circular(12);
          cardBorder = Border.all(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF00FFF0) : const Color(0xFFFF007F),
            width: 1.5,
          );
          break;
        case ThemeStyle.luxury:
          cardRadius = BorderRadius.circular(16);
          cardBorder = Border.all(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4A3E20) : const Color(0xFFE5D5A1),
            width: 1.2,
          );
          break;
      }

      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compactAiWidth),
          child: Container(
            margin: const EdgeInsets.only(right: 16, top: 4, bottom: 8),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: cardRadius,
              border: cardBorder,
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
                _buildCardHeader(
                  style,
                  category,
                  msgType,
                  card['icon'] ?? headerIcon,
                  categoryColor,
                  headerBgColor,
                  hasBudget,
                ),
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
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: context.primaryTextColor,
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
                            style: TextStyle(
                              fontSize: 10,
                              color: context.secondaryTextColor,
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
        ),
      );
    }

    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isUser ? 300 : compactAiWidth),
        child: Container(
          margin: EdgeInsets.only(
            left: isUser ? 48 : 0,
            right: isUser ? 0 : 32,
            top: 4,
            bottom: 4,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isUser ? 16 : 12,
            vertical: isUser ? 12 : 9,
          ),
          decoration: BoxDecoration(
            color: isUser
                ? Theme.of(context).primaryColor
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9)),
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
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              : Text(
                  message.text,
                  style: TextStyle(
                    color: isUser
                        ? Colors.white
                        : (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF1E293B)),
                    fontSize: isUser ? 14 : 13,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final inputBarHeight = bottomInset > 0 ? bottomInset + 68 : 72.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: ThemePatternPainter(
                style: AppSettings.themeStyle.value,
                brightness: Theme.of(context).brightness,
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: NotificationListener<UserScrollNotification>(
                  onNotification: _handleUserScroll,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      widget.topPadding,
                      16,
                      _quickSuggestions.isNotEmpty ? 58 : 16,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: bottomInset > 0 ? bottomInset + 6 : 10,
                ),
                child: Container(
                  key: widget.inputKey,
                  height: 54,
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: context.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'รายการทางลัด',
                        onPressed: _quickSuggestions.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _showQuickSuggestions =
                                      !_showQuickSuggestions;
                                });
                              },
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            _showQuickSuggestions
                                ? Icons.grid_view_rounded
                                : Icons.add_rounded,
                            key: ValueKey(_showQuickSuggestions),
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.send,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'พิมพ์รายการและจำนวนเงิน…',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: (_) {
                            if (_canSend) _handleSendMessage();
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _canSend
                              ? Theme.of(context).primaryColor
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _canSend
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context).primaryColor.withValues(
                                      alpha: 0.24,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _canSend ? _handleSendMessage : null,
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              color: _canSend
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                              size: 21,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_quickSuggestions.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: inputBarHeight + 4,
              child: IgnorePointer(
                ignoring: !_showQuickSuggestions,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: _showQuickSuggestions
                      ? Offset.zero
                      : const Offset(0, 0.65),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _showQuickSuggestions ? 1 : 0,
                    child: _buildQuickSuggestions(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    return SizedBox(
      height: 47,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        scrollDirection: Axis.horizontal,
        itemCount: _quickSuggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final suggestion = _quickSuggestions[index];
          final color = _typeColor(suggestion.type);
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _onSuggestionTap(suggestion),
              child: Container(
                constraints: const BoxConstraints(minWidth: 41, maxWidth: 66),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    suggestion.icon is Widget
                        ? suggestion.icon
                        : Icon(suggestion.icon as IconData, size: 13, color: color),
                    Text(
                      suggestion.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.05,
                        color: color,
                        fontWeight: FontWeight.w600,
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

  Color _typeColor(String type) {
    switch (type) {
      case 'income':
        return const Color(0xFF10B981);
      case 'dream':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFFEF4444);
    }
  }

  String _successMessage(String type) {
    switch (type) {
      case 'income':
        return 'บันทึกยอดรายรับเข้าระบบสำเร็จเรียบร้อยแล้ว';
      case 'dream':
        return 'บันทึกยอดเงินออมเข้าระบบสำเร็จเรียบร้อยแล้ว';
      default:
        return 'บันทึกยอดรายจ่ายเข้าระบบสำเร็จเรียบร้อยแล้ว';
    }
  }

  Widget _buildCardHeader(
    ThemeStyle style,
    String category,
    String msgType,
    dynamic itemIcon,
    Color categoryColor,
    Color headerBgColor,
    bool hasBudget,
  ) {
    final isExpense = msgType == 'expense' || category == 'รายจ่าย';
    final isDream = msgType == 'dream' || category == 'เงินออม';
    final title = isExpense 
        ? context.tr('บันทึกรายจ่าย', 'EXPENSE RECORD') 
        : (isDream ? context.tr('หยอดเป้าหมาย', 'SAVINGS GOAL') : context.tr('รายการใหม่', 'NEW ENTRY'));

    final badge = !hasBudget
        ? Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
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
          )
        : const SizedBox.shrink();

    switch (style) {
      case ThemeStyle.cartoon:
        return Container(
          height: 100,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFFFE3CC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CardCheckeredPainter(color: const Color(0xFFFFC08D).withValues(alpha: 0.3)),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9233),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2B1A0E), width: 1.8),
                      ),
                      child: itemIcon is Widget
                          ? SizedBox(width: 24, height: 24, child: itemIcon)
                          : Icon(
                              itemIcon as IconData,
                              size: 24,
                              color: const Color(0xFF2B1A0E),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF2B1A0E),
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              badge,
            ],
          ),
        );

      case ThemeStyle.sakura:
        return Container(
          height: 100,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFD1DC), Color(0xFFFFB5C2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Stack(
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: itemIcon is Widget
                      ? itemIcon
                      : Icon(
                          itemIcon as IconData,
                          size: 34,
                          color: const Color(0xFFFF6B8B),
                        ),
                ),
              ),
              badge,
            ],
          ),
        );

      case ThemeStyle.cyberpunk:
        return Container(
          height: 100,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF140D24),
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CardCyberGridPainter(color: const Color(0xFFFF007F).withValues(alpha: 0.15)),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F0D3D),
                        border: Border.all(color: const Color(0xFF00FFF0), width: 1.5),
                        shape: BoxShape.circle,
                      ),
                      child: itemIcon is Widget
                          ? SizedBox(width: 24, height: 24, child: itemIcon)
                          : Icon(
                              itemIcon as IconData,
                              size: 24,
                              color: const Color(0xFF00FFF0),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '[ $title ]',
                      style: const TextStyle(
                        color: Color(0xFF00FFF0),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              badge,
            ],
          ),
        );

      case ThemeStyle.luxury:
        return Container(
          height: 100,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF121824), Color(0xFF080B11)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    itemIcon is Widget
                        ? SizedBox(width: 28, height: 28, child: itemIcon)
                        : Icon(
                            itemIcon as IconData,
                            size: 28,
                            color: const Color(0xFFD4AF37),
                          ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1.5,
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                ),
              ),
              badge,
            ],
          ),
        );

      case ThemeStyle.emerald:
      default:
        return Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: headerBgColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: itemIcon is Widget
                    ? itemIcon
                    : Icon(
                        itemIcon as IconData,
                        size: 40,
                        color: categoryColor.withValues(alpha: 0.8),
                      ),
              ),
              badge,
            ],
          ),
        );
    }
  }

  dynamic _getIconForTransaction(
    String name,
    String category,
    String msgType,
    Map<String, dynamic>? matchedSuggestion,
  ) {
    if (matchedSuggestion != null) {
      if (msgType == 'dream') {
        final iconKey = matchedSuggestion['icon']?.toString();
        return _getIconForDreamKey(iconKey);
      } else if (msgType == 'income') {
        final cat = matchedSuggestion['category']?.toString() ?? '';
        return _getIconForIncomeCategory(cat);
      } else {
        final cat = matchedSuggestion['category']?.toString() ?? '';
        return _getIconForExpenseCategory(cat);
      }
    }

    final nameLower = name.toLowerCase();
    if (msgType == 'dream' || category == 'เงินออม') {
      return Icons.savings_outlined;
    } else if (msgType == 'income' || category == 'รายรับ') {
      if (nameLower.contains('เดือน')) return Icons.work_outline;
      if (nameLower.contains('ลงทุน') || nameLower.contains('หุ้น')) return Icons.trending_up_outlined;
      if (nameLower.contains('ขาย')) return Icons.shopping_cart_outlined;
      return Icons.account_balance_wallet_outlined;
    } else {
      if (nameLower.contains('ไฟ')) return Icons.flash_on_outlined;
      if (nameLower.contains('น้ำ')) return Icons.water_drop_outlined;
      if (nameLower.contains('ห้อง') || nameLower.contains('บ้าน') || nameLower.contains('เช่า')) return Icons.home_outlined;
      if (nameLower.contains('เน็ต') || nameLower.contains('wifi')) return Icons.wifi;
      if (nameLower.contains('โทร') || nameLower.contains('มือถือ')) return Icons.phone_android_outlined;
      if (nameLower.contains('กิน') || nameLower.contains('ข้าว') || nameLower.contains('อาหาร') || nameLower.contains('คาเฟ่')) return Icons.local_cafe_outlined;
      if (nameLower.contains('รถ') || nameLower.contains('เดินทาง')) return Icons.directions_car_outlined;
      if (nameLower.contains('ยา') || nameLower.contains('หมอ') || nameLower.contains('โรงพยาบาล') || nameLower.contains('รักษา')) return Icons.favorite_border_outlined;
      return Icons.receipt_long_outlined;
    }
  }
}

class ThemePatternPainter extends CustomPainter {
  final ThemeStyle style;
  final Brightness brightness;

  ThemePatternPainter({required this.style, required this.brightness});

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = brightness == Brightness.dark;

    switch (style) {
      case ThemeStyle.emerald:
        final paint = Paint()
          ..color = isDark ? Colors.white.withValues(alpha: 0.015) : Colors.black.withValues(alpha: 0.015)
          ..strokeWidth = 1.0;
        const double step = 32.0;
        for (double x = 0; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = 0; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;

      case ThemeStyle.cartoon:
        final paint = Paint()
          ..color = isDark ? const Color(0xFFFFF3E6).withValues(alpha: 0.03) : const Color(0xFFFF9233).withValues(alpha: 0.04)
          ..strokeWidth = 2.0;
        const double step = 28.0;
        for (double x = 0; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = 0; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;

      case ThemeStyle.sakura:
        final paint = Paint()
          ..color = isDark ? const Color(0xFFFF8FA3).withValues(alpha: 0.03) : const Color(0xFFFF8FA3).withValues(alpha: 0.05)
          ..strokeWidth = 3.0;
        const double step = 40.0;
        for (double i = -size.height; i < size.width; i += step) {
          canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
        }
        break;

      case ThemeStyle.cyberpunk:
        final gridPaint = Paint()
          ..color = const Color(0xFF00FFF0).withValues(alpha: 0.06)
          ..strokeWidth = 1.5;
        
        final horizonY = size.height * 0.15;
        
        const int numLines = 16;
        for (int i = 0; i <= numLines; i++) {
          final xBottom = size.width * (i / numLines);
          final xTop = size.width * 0.5 + (xBottom - size.width * 0.5) * 0.1;
          canvas.drawLine(Offset(xBottom, size.height), Offset(xTop, horizonY), gridPaint);
        }

        double currentY = size.height;
        double spacing = 45.0;
        while (currentY > horizonY) {
          final ratio = (currentY - horizonY) / (size.height - horizonY);
          gridPaint.color = const Color(0xFFFF007F).withValues(alpha: 0.04 + (0.06 * ratio));
          canvas.drawLine(Offset(0, currentY), Offset(size.width, currentY), gridPaint);
          currentY -= spacing;
          spacing *= 0.85;
          if (spacing < 4.0) break;
        }
        break;

      case ThemeStyle.luxury:
        final paint = Paint()
          ..color = const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.03 : 0.05)
          ..strokeWidth = 1.0;
        const double step = 45.0;
        for (double i = -size.height; i < size.width; i += step) {
          canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
        }
        for (double i = 0; i < size.width + size.height; i += step) {
          canvas.drawLine(Offset(i, 0), Offset(i - size.height, size.height), paint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CardCheckeredPainter extends CustomPainter {
  final Color color;
  _CardCheckeredPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const double step = 20.0;
    for (double x = 0; x < size.width; x += step * 2) {
      for (double y = 0; y < size.height; y += step * 2) {
        canvas.drawRect(Rect.fromLTWH(x, y, step, step), paint);
        canvas.drawRect(Rect.fromLTWH(x + step, y + step, step, step), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardCyberGridPainter extends CustomPainter {
  final Color color;
  _CardCyberGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    const double step = 15.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
