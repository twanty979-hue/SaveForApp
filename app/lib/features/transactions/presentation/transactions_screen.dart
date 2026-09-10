import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:app/core/localization/app_material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/slip_scanner_bridge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bank_logo_icon.dart';
import '../../../core/widgets/shared_icon_selector.dart';
import '../../auth/domain/auth_session.dart';
import '../../../core/settings/app_settings.dart';
import 'slip_scan_date_sheet.dart';

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
  final ValueNotifier<DateTime?>? dateFilter;
  final Future<void> Function()? onTransactionSaved;
  final ValueNotifier<int>? refreshNotifier;

  const TransactionsScreen({
    super.key,
    this.topPadding = 16,
    this.inputKey,
    this.dateFilter,
    this.onTransactionSaved,
    this.refreshNotifier,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with WidgetsBindingObserver {
  List<Message> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late ValueNotifier<DateTime?> _effectiveDateFilter;
  final ApiClient _apiClient = ApiClient();
  final AudioPlayer _aiReplyPlayer = AudioPlayer();
  bool _isLoading = false;
  bool _canSend = false;
  bool _showQuickSuggestions = true;

  List<Map<String, dynamic>> _rawSuggestions = [];
  List<QuickSuggestion> _quickSuggestions = [];
  String _inputType = 'expense';

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
    _effectiveDateFilter = widget.dateFilter ?? ValueNotifier<DateTime?>(null);
    _effectiveDateFilter.addListener(_handleDateFilterChanged);
    widget.refreshNotifier?.addListener(_handleExternalRefresh);
    _focusNode.addListener(_handleInputFocusChange);
    _inputController.addListener(_handleInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
  }

  void _handleExternalRefresh() {
    if (mounted) {
      _loadPastTransactions(preserveScroll: true);
    }
  }

  Future<void> _initData() async {
    SlipParserService.loadLearnedOwnData();
    _addIntroMessage();
    await _loadQuickSuggestions();
    await _loadPastTransactions(forceScrollToBottom: true);
  }

  void _handleDateFilterChanged() {
    if (mounted) {
      _loadPastTransactions(forceScrollToBottom: true);
    }
  }

  String _monthName(int month) {
    return const [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ][month - 1];
  }

  String _formatTinyDate(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
    final isSameYear = dt.year == now.year;
    final isThai = Localizations.localeOf(context).languageCode == 'th';

    final hourStr = dt.hour.toString().padLeft(2, '0');
    final minStr = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$hourStr:$minStr';

    if (isThai) {
      final monthStr = _monthName(dt.month);
      final yearStr = ((dt.year + 543) % 100).toString().padLeft(2, '0');
      if (isToday) {
        return 'วันนี้ (${dt.day} $monthStr) • $timeStr';
      } else if (isYesterday) {
        return 'เมื่อวาน (${dt.day} $monthStr) • $timeStr';
      } else if (isSameYear) {
        return '${dt.day} $monthStr • $timeStr';
      } else {
        return '${dt.day} $monthStr $yearStr • $timeStr';
      }
    } else {
      const enMonths = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final monthStr = enMonths[dt.month - 1];
      final yearStr = (dt.year % 100).toString().padLeft(2, '0');
      if (isToday) {
        return 'Today (${dt.day} $monthStr) • $timeStr';
      } else if (isYesterday) {
        return 'Yesterday (${dt.day} $monthStr) • $timeStr';
      } else if (isSameYear) {
        return '${dt.day} $monthStr • $timeStr';
      } else {
        return '${dt.day} $monthStr $yearStr • $timeStr';
      }
    }
  }

  void _addIntroMessage() {
    final intro = context.tr(
      'พิมพ์เพื่อบันทึกได้เลยครับ เช่น "ข้าว 50"',
      'Type to record, e.g., "Food 50"',
    );
    setState(() {
      _messages.add(
        Message(text: intro, isUser: false, timestamp: DateTime.now()),
      );
    });
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNotifier != widget.refreshNotifier) {
      oldWidget.refreshNotifier?.removeListener(_handleExternalRefresh);
      widget.refreshNotifier?.addListener(_handleExternalRefresh);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _effectiveDateFilter.removeListener(_handleDateFilterChanged);
    widget.refreshNotifier?.removeListener(_handleExternalRefresh);
    if (widget.dateFilter == null) {
      _effectiveDateFilter.dispose();
    }
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
    } catch (e, stackTrace) {
      debugPrint('Error loading quick suggestions: $e\n$stackTrace');
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

  Future<void> _loadPastTransactions({
    bool preserveScroll = false,
    bool forceScrollToBottom = false,
  }) async {
    final double? previousScrollOffset =
        _scrollController.hasClients ? _scrollController.offset : null;
    final bool wasNearBottom = _scrollController.hasClients &&
        (_scrollController.position.maxScrollExtent - _scrollController.offset).abs() < 150;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final response = await _apiClient.get(
        '/transactions?user_id=eq.$_activeUserId&order=transaction_date.asc',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        // ซิงก์ประวัติสลิปจากเซิร์ฟเวอร์แบบเบื้องหลัง (รองรับกรณีย้ายเครื่อง/ลบแอพ)
        if (_activeUserId.isNotEmpty) {
          SlipScannerBridge.instance.syncSavedSlipsFromServer(
            userId: _activeUserId,
            apiClient: _apiClient,
          );
        }

        // ติดตามยอดสะสมแบบทีละรายการตามลำดับเวลา (Running Total Step-by-Step)
        // เพื่อให้การ์ดแสดงยอดบวกเพิ่มขึ้นเรื่อยๆ ตามลำดับ ไม่เท่ากันหมดทุกการ์ด
        final Map<String, double> monthlyExpenseRunningTotal = {};
        final Map<String, double> monthlyIncomeRunningTotal = {};
        final Map<String, double> categoryRunningTotal = {};
        final Map<String, double> categoryNameRunningTotal = {};
        final Map<String, double> dreamRunningTotal = {};

        // เรียงลำดับรายการตามเวลา (เก่าไปใหม่) เพื่อคำนวณ running total ให้ถูกต้อง
        data.sort((a, b) {
          final dateA = DateTime.tryParse(a['transaction_date']?.toString() ?? '') ?? DateTime(1970);
          final dateB = DateTime.tryParse(b['transaction_date']?.toString() ?? '') ?? DateTime(1970);
          return dateA.compareTo(dateB);
        });

        if (!mounted) return;
        // Build new messages list locally to avoid intermediate layout glitches
        final introMsg = _messages.isNotEmpty
            ? _messages.first
            : Message(
                text: context.tr(
                  'พิมพ์เพื่อบันทึกได้เลยครับ เช่น "ข้าว 50"',
                  'Type to record, e.g., "Food 50"',
                ),
                isUser: false,
                timestamp: DateTime.now(),
              );
        final List<Message> newMessages = [introMsg];

        for (var tx in data) {
            try {
              final name = tx['note']?.toString() ?? '';
              final amount =
                  num.tryParse(tx['amount']?.toString() ?? '')?.toDouble() ??
                  0.0;
              final dateStr = tx['transaction_date']?.toString() ?? '';
              final timestamp = DateTime.tryParse(dateStr) ?? DateTime.now();
              final type = tx['type']?.toString() ?? 'expense';

              String displayName = name;
              String category = 'รายจ่าย';
              String msgType = 'expense';
              BankType? detectedBank;
              BankType? detectedDestinationBank;

              final source = tx['source']?.toString();
              final bankStr = tx['bank']?.toString();
              final destinationBankStr = tx['destination_bank']?.toString();
              final dreamId = tx['dream_id']?.toString();
              final fixedId = tx['fixed_expense_id']?.toString();
              final incomeId = tx['income_source_id']?.toString();

              if (bankStr != null && bankStr.isNotEmpty) {
                detectedBank = BankType.values.cast<BankType?>().firstWhere(
                  (b) => b?.name == bankStr,
                  orElse: () => null,
                );
              }
              if (destinationBankStr != null && destinationBankStr.isNotEmpty) {
                detectedDestinationBank = BankType.values.cast<BankType?>().firstWhere(
                  (b) => b?.name == destinationBankStr,
                  orElse: () => null,
                );
              }
              if (detectedDestinationBank == null && tx['metadata'] is Map) {
                final toBankStr = tx['metadata']['to_bank']?.toString() ??
                    tx['metadata']['destination_bank']?.toString();
                if (toBankStr != null && toBankStr.isNotEmpty) {
                  detectedDestinationBank = BankType.values.cast<BankType?>().firstWhere(
                    (b) => b?.name == toBankStr,
                    orElse: () => null,
                  );
                }
              }
              if (detectedBank == null && (name.startsWith('[สลิป') || name.contains('[สลิป'))) {
                detectedBank = BankType.detectFromText(name);
              }

              final bool isTransfer = type == 'transfer' ||
                  source == 'transfer' ||
                  name.startsWith('[ย้ายเงิน') ||
                  name.contains('[ย้ายเงิน') ||
                  (tx['metadata'] is Map && tx['metadata']['transfer_type'] == 'own_account');

              if (isTransfer) {
                category = 'ย้ายเงิน';
                msgType = 'transfer';
                displayName = name
                    .replaceAll(RegExp(r'\[ย้ายเงิน\s+[^\]]+\]'), '')
                    .replaceAll('[ย้ายเงิน]', '')
                    .replaceAll(RegExp(r'\[Ref:[^\]]+\]'), '')
                    .trim();
                if (displayName.isEmpty) {
                  displayName = 'ย้ายเงินระหว่างบัญชี';
                }
              } else if (detectedBank != null || source == 'slip' || name.startsWith('[สลิป') || name.contains('[สลิป')) {
                final closeBracket = name.indexOf(']');
                if (closeBracket != -1) {
                  displayName = name.substring(closeBracket + 1).trim();
                }
                displayName = displayName.replaceAll(RegExp(r'\[Ref:[^\]]+\]'), '').trim();
                category = 'รายจ่าย';
                msgType = 'expense';
              } else if (source == 'dream_saving' || dreamId != null || name.startsWith('[ออม]')) {
                displayName = name
                    .replaceAll('[ออม] หยอดกระปุก: ', '')
                    .replaceAll('[ออม] ', '')
                    .replaceAll('[ออม]', '')
                    .trim();
                category = 'เงินออม';
                msgType = 'dream';
              } else if (source == 'recurring_expense' || fixedId != null || name.startsWith('[รายจ่ายประจำ]')) {
                displayName = name.replaceAll('[รายจ่ายประจำ] ', '').replaceAll('[รายจ่ายประจำ]', '').trim();
                category = 'รายจ่าย';
                msgType = 'expense';
              } else if (source == 'recurring_income' || incomeId != null || name.startsWith('[รายรับประจำ]')) {
                displayName = name.replaceAll('[รายรับประจำ] ', '').replaceAll('[รายรับประจำ]', '').trim();
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
                  } else if (msgType == 'income' &&
                      suggId == txIncomeSourceId) {
                    matchedSugg = sugg;
                    break;
                  }
                }
              }

              if (matchedSugg == null) {
                for (var sugg in _rawSuggestions) {
                  final suggName =
                      (sugg['bot_type'] == 'dream'
                              ? sugg['title']
                              : sugg['name'])
                          ?.toString()
                          .toLowerCase();
                  if (suggName == cleanName && sugg['bot_type'] == msgType) {
                    matchedSugg = sugg;
                    break;
                  }
                }
              }

              // Fallback ไปยัง "ค่าใช้จ่ายรายเดือน" ถ้ายังไม่เจองบเฉพาะ และเป็นรายจ่าย
              if (matchedSugg == null && msgType == 'expense') {
                for (var sugg in _rawSuggestions) {
                  final suggName = sugg['name']
                      ?.toString()
                      .trim()
                      .toLowerCase();
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
                  budget =
                      num.tryParse(
                        matchedSugg['amount']?.toString() ?? '',
                      )?.toDouble() ??
                      0.0;
                } else if (msgType == 'dream') {
                  budget =
                      num.tryParse(
                        matchedSugg['target_amount']?.toString() ?? '',
                      )?.toDouble() ??
                      0.0;
                }
              }

              final bool isGenericMonthlyBudget = matchedSugg != null &&
                  matchedSugg['name']?.toString().trim() == 'ค่าใช้จ่ายรายเดือน';
              final String? matchedId = matchedSugg?['id']?.toString();
              final monthKey = '${timestamp.year}_${timestamp.month}';
              double totalAccumulated = amount;

              if (msgType == 'expense') {
                // อัปเดต running total ของรายจ่ายรวมทั้งเดือน
                monthlyExpenseRunningTotal[monthKey] =
                    (monthlyExpenseRunningTotal[monthKey] ?? 0.0) + amount;

                if (matchedId != null && !isGenericMonthlyBudget) {
                  categoryRunningTotal['${monthKey}_$matchedId'] =
                      (categoryRunningTotal['${monthKey}_$matchedId'] ?? 0.0) + amount;
                }
                categoryNameRunningTotal['${monthKey}_$cleanName'] =
                    (categoryNameRunningTotal['${monthKey}_$cleanName'] ?? 0.0) + amount;

                if (isGenericMonthlyBudget) {
                  // เทียบกับงบรวมค่าใช้จ่ายรายเดือน -> แสดงยอดใช้จ่ายรวมสะสมจนถึงรายการนี้
                  totalAccumulated = monthlyExpenseRunningTotal[monthKey] ?? amount;
                } else if (matchedId != null) {
                  totalAccumulated =
                      categoryRunningTotal['${monthKey}_$matchedId'] ??
                      categoryNameRunningTotal['${monthKey}_$cleanName'] ??
                      amount;
                } else {
                  totalAccumulated = categoryNameRunningTotal['${monthKey}_$cleanName'] ?? amount;
                }
              } else if (msgType == 'income') {
                monthlyIncomeRunningTotal[monthKey] =
                    (monthlyIncomeRunningTotal[monthKey] ?? 0.0) + amount;
                if (matchedId != null) {
                  categoryRunningTotal['${monthKey}_$matchedId'] =
                      (categoryRunningTotal['${monthKey}_$matchedId'] ?? 0.0) + amount;
                  totalAccumulated = categoryRunningTotal['${monthKey}_$matchedId'] ?? amount;
                } else {
                  totalAccumulated = monthlyIncomeRunningTotal[monthKey] ?? amount;
                }
              } else if (msgType == 'dream') {
                final dreamKey = dreamId ?? matchedId ?? cleanName;
                dreamRunningTotal[dreamKey] =
                    (dreamRunningTotal[dreamKey] ?? 0.0) + amount;
                totalAccumulated = dreamRunningTotal[dreamKey] ?? amount;
              }

              // Apply date filter if active (คัดกรองการแสดงผลหลังอัปเดต running total แล้ว)
              if (_effectiveDateFilter.value != null) {
                final filter = _effectiveDateFilter.value!;
                final txLocalDate = timestamp.toLocal();
                if (txLocalDate.year != filter.year ||
                    txLocalDate.month != filter.month ||
                    txLocalDate.day != filter.day) {
                  continue; // Skip items that don't match the active date filter
                }
              }

              newMessages.add(
                Message(
                  text: '$displayName ${amount.toStringAsFixed(0)}',
                  isUser: true,
                  timestamp: timestamp,
                ),
              );
              final bool isSlipTx = name.startsWith('[สลิป') || name.contains('[สลิป');
              final txMetadata = tx['metadata'] is Map ? Map<String, dynamic>.from(tx['metadata'] as Map) : null;
              final rawImagePath = txMetadata?['image_path']?.toString() ?? tx['image_path']?.toString();
              final assetId = txMetadata?['asset_id']?.toString();
              final recipientName = txMetadata?['recipient']?.toString();

              newMessages.add(
                Message(
                  text: '',
                  isUser: false,
                  timestamp: timestamp,
                  cardData: {
                    'id': tx['id'],
                    'rawNote': name,
                    'isSlip': isSlipTx,
                    'isTransfer': isTransfer,
                    'bank': bankStr ?? detectedBank?.name,
                    'destination_bank': destinationBankStr ?? detectedDestinationBank?.name,
                    'reference_no': tx['reference_no'],
                    'image_path': rawImagePath,
                    'asset_id': assetId,
                    'recipient': recipientName,
                    'metadata': txMetadata,
                    'source': source ?? (isTransfer ? 'transfer' : (detectedBank != null ? 'slip' : 'manual')),
                    'dream_id': dreamId,
                    'transaction_date': dateStr,
                    'name': displayName,
                    'amount': amount,
                    'category': category,
                    'hasBudget': isTransfer ? false : hasBudget,
                    'budget': budget,
                    'totalAccumulated': totalAccumulated,
                    'msgType': msgType,
                    'bankType': detectedBank,
                    'destinationBankType': detectedDestinationBank,
                    'icon': isTransfer && detectedBank != null && detectedDestinationBank != null
                        ? DualBankLogoIcon(
                            fromBank: detectedBank,
                            toBank: detectedDestinationBank,
                            size: 38,
                            showShadow: true,
                          )
                        : (detectedBank != null
                            ? BankLogoIcon(
                                bank: detectedBank,
                                size: 44,
                                showShadow: true,
                              )
                            : null),
                  },
                ),
              );
            } catch (innerEx) {
              debugPrint('Error parsing transaction item: $innerEx');
            }
          }

        if (!mounted) return;
        setState(() {
          _messages = newMessages;
        });
        if (forceScrollToBottom || (!preserveScroll && wasNearBottom)) {
          _scrollToBottom(force: forceScrollToBottom);
        } else if (preserveScroll && previousScrollOffset != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollController.hasClients) {
              _scrollController.jumpTo(
                previousScrollOffset.clamp(
                  0.0,
                  _scrollController.position.maxScrollExtent,
                ),
              );
            }
          });
        }
      } else {
        debugPrint('Failed to load transactions: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading past transactions: $e\n$stackTrace');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _unfocusKeyboard() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _scrollToBottom({bool force = false}) {
    void scrollAction() {
      if (!mounted || !_scrollController.hasClients) return;
      if (!force) {
        final max = _scrollController.position.maxScrollExtent;
        final current = _scrollController.offset;
        if ((max - current) > 150) {
          // User has scrolled up to review or edit history; don't auto-scroll down
          return;
        }
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollAction();
      // Ensure layout and image/card rendering settles (especially after keyboard dismisses)
      Future.delayed(const Duration(milliseconds: 80), scrollAction);
      if (force) {
        Future.delayed(const Duration(milliseconds: 200), scrollAction);
        Future.delayed(const Duration(milliseconds: 350), scrollAction);
      }
    });
  }

  bool _isScanningSlips = false;

  Future<void> _openSlipScanner() async {
    HapticFeedback.lightImpact();
    SlipScanDateSheet.show(
      context,
      onTransactionsSaved: () {
        if (!mounted) return;
        _loadPastTransactions(forceScrollToBottom: true);
        widget.onTransactionSaved?.call();
        SlipScannerBridge.instance.refreshUnscannedCount();
      },
    );
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

    _inputController.clear();
    // Do not dismiss keyboard on send so user can type subsequent entries seamlessly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });

    final parsedItems = _parseInput(text);

    if (parsedItems.isEmpty) {
      setState(() {
        _messages.add(
          Message(text: text, isUser: true, timestamp: DateTime.now()),
        );
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
      _scrollToBottom(force: true);
      _playAiReplySound();
      return;
    }

    // 1. ตอบสนองทันที 0ms (Optimistic UI):
    // สรุปข้อมูลการ์ดและคำตอบ AI แสดงขึ้นหน้าจอทันที ไม่ต้องรอเน็ตเวิร์ก
    final now = DateTime.now();
    final List<Message> optimisticMessages = [
      Message(text: text, isUser: true, timestamp: now),
    ];
    final List<Map<String, dynamic>> itemsToSync = [];

    for (var item in parsedItems) {
      final name = item['name']?.toString() ?? '';
      final note = item['note']?.toString() ?? '';
      final amount =
          num.tryParse(item['amount']?.toString() ?? '')?.toDouble() ?? 0.0;
      final type = item['type']?.toString() ?? 'expense';
      final category = item['category']?.toString() ?? 'รายจ่าย';
      final msgType = item['msgType']?.toString() ?? 'expense';

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
      }

      double budget = 0.0;
      bool hasBudget = false;
      if (matchedSuggestion != null) {
        hasBudget = true;
        if (msgType == 'expense' || msgType == 'income') {
          budget =
              num.tryParse(matchedSuggestion['amount']?.toString() ?? '')
                  ?.toDouble() ??
              0.0;
        } else if (msgType == 'dream') {
          budget =
              num.tryParse(matchedSuggestion['target_amount']?.toString() ?? '')
                  ?.toDouble() ??
              0.0;
        }
      }

      // คำนวณ totalAccumulated สะสมของเดือนปัจจุบันทันทีในหน่วยความจำ (0ms)
      double totalAccumulated = amount;
      final cleanName = name.trim().toLowerCase();
      final String? matchedId = matchedSuggestion?['id']?.toString();
      final bool isGenericMonthlyBudget = matchedSuggestion != null &&
          matchedSuggestion['name']?.toString().trim() == 'ค่าใช้จ่ายรายเดือน';

      for (final m in _messages) {
        final card = m.cardData;
        if (card == null) continue;
        final date =
            DateTime.tryParse(card['transaction_date']?.toString() ?? '') ??
            m.timestamp;
        if (date.year != now.year || date.month != now.month) continue;

        final cardAmount =
            num.tryParse(card['amount']?.toString() ?? '')?.toDouble() ?? 0.0;
        final cardMsgType = card['msgType']?.toString() ?? 'expense';
        final cardName = card['name']?.toString().trim().toLowerCase() ?? '';

        if (msgType == 'expense' && cardMsgType == 'expense') {
          if (isGenericMonthlyBudget) {
            totalAccumulated += cardAmount;
          } else {
            final cardFixedId =
                card['fixed_expense_id']?.toString() ?? card['id']?.toString();
            if ((matchedId != null && cardFixedId == matchedId) ||
                cardName == cleanName) {
              totalAccumulated += cardAmount;
            }
          }
        } else if (msgType == 'income' && cardMsgType == 'income') {
          final cardIncomeId = card['income_source_id']?.toString();
          if ((matchedId != null && cardIncomeId == matchedId) ||
              cardName == cleanName) {
            totalAccumulated += cardAmount;
          }
        }
      }

      final String replyText = hasBudget
          ? _successMessage(msgType)
          : 'ไม่พบแผนงบประมาณที่ตรงกับรายการนี้ ยอดเงินถูกบันทึกสำเร็จแล้ว';

      final matchedBank = BankType.detectFromText(name);
      final tempId =
          'temp_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';

      final transactionDateStr = () {
        if (_effectiveDateFilter.value != null) {
          final filter = _effectiveDateFilter.value!;
          final merged = DateTime(
            filter.year,
            filter.month,
            filter.day,
            now.hour,
            now.minute,
            now.second,
          );
          return merged.toUtc().toIso8601String();
        }
        return now.toUtc().toIso8601String();
      }();

      final cardData = <String, dynamic>{
        'id': tempId,
        'rawNote': note,
        'isSlip': false,
        'bank': matchedBank?.name,
        'source': msgType == 'dream'
            ? 'dream_saving'
            : (msgType == 'expense' ? 'recurring_expense' : 'recurring_income'),
        'transaction_date': transactionDateStr,
        'name': name,
        'type': type,
        'amount': amount,
        'category': category,
        'hasBudget': hasBudget,
        'budget': budget,
        'totalAccumulated': totalAccumulated,
        'msgType': msgType,
        'bankType': matchedBank,
        'icon': matchedBank != null
            ? BankLogoIcon(
                bank: matchedBank,
                size: 44,
                showShadow: true,
              )
            : _getIconForTransaction(
                name,
                category,
                msgType,
                matchedSuggestion,
              ),
      };

      optimisticMessages.add(
        Message(text: replyText, isUser: false, timestamp: now),
      );
      optimisticMessages.add(
        Message(text: '', isUser: false, timestamp: now, cardData: cardData),
      );

      itemsToSync.add({
        'item': item,
        'cardData': cardData,
        'matchedSuggestion': matchedSuggestion,
      });
    }

    // อัปเดตขึ้นหน้าจอทันที 0ms!
    setState(() {
      _messages.addAll(optimisticMessages);
    });
    _scrollToBottom(force: true);
    _playAiReplySound();
    _loadQuickSuggestions();

    // 2. ทำงานเบื้องหลัง (Background Sync) ส่งขึ้นเซิร์ฟเวอร์เงียบๆ
    _syncOptimisticTransactionsInBackground(itemsToSync);
  }

  Future<void> _syncOptimisticTransactionsInBackground(
    List<Map<String, dynamic>> syncItems,
  ) async {
    var savedAny = false;
    for (final syncItem in syncItems) {
      final item = syncItem['item'] as Map<String, dynamic>;
      final cardData = syncItem['cardData'] as Map<String, dynamic>;
      var matchedSuggestion =
          syncItem['matchedSuggestion'] as Map<String, dynamic>?;

      final name = item['name']?.toString() ?? '';
      final note = item['note']?.toString() ?? '';
      final amount =
          num.tryParse(item['amount']?.toString() ?? '')?.toDouble() ?? 0.0;
      final type = item['type']?.toString() ?? 'expense';
      final msgType = item['msgType']?.toString() ?? 'expense';

      try {
        String? fixedExpenseId;
        String? incomeSourceId;
        String finalNote = note;

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
                      Map<String, dynamic>.from(createdList.first as Map);
                  newSuggestion['bot_type'] = 'expense';
                  matchedSuggestion = newSuggestion;
                  _rawSuggestions.add(newSuggestion);
                }
              }
            } catch (_) {}
          }
        }

        if (matchedSuggestion != null) {
          final suggestionId = matchedSuggestion['id']?.toString();
          if (msgType == 'expense') {
            fixedExpenseId = suggestionId;
            finalNote = name;
          } else if (msgType == 'income') {
            incomeSourceId = suggestionId;
            finalNote = name;
          } else if (msgType == 'dream') {
            finalNote = name;
          }
        }

        final detectedBank = BankType.detectFromText(name);
        final String source = msgType == 'dream'
            ? 'dream_saving'
            : (fixedExpenseId != null
                ? 'recurring_expense'
                : (incomeSourceId != null ? 'recurring_income' : 'ai_chat'));

        final Map<String, dynamic> body = {
          'user_id': _activeUserId,
          'type': type,
          'amount': amount,
          'note': finalNote,
          'source': source,
          if (detectedBank != null) 'bank': detectedBank.name,
          'transaction_date': cardData['transaction_date'] ??
              DateTime.now().toUtc().toIso8601String(),
        };
        if (fixedExpenseId != null) {
          body['fixed_expense_id'] = fixedExpenseId;
        }
        if (incomeSourceId != null) {
          body['income_source_id'] = incomeSourceId;
        }
        if (msgType == 'dream' && matchedSuggestion != null) {
          final dreamId = matchedSuggestion['id']?.toString();
          if (dreamId != null) {
            body['dream_id'] = dreamId;
          }
        }

        var response = await _apiClient.post('/transactions', body: body);
        if (response.statusCode >= 400 && response.body.contains('column')) {
          final fallbackBody = Map<String, dynamic>.from(body)
            ..remove('source')
            ..remove('bank')
            ..remove('dream_id');
          response = await _apiClient.post('/transactions', body: fallbackBody);
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          savedAny = true;
          dynamic createdId;
          try {
            final parsed = jsonDecode(response.body);
            if (parsed is List && parsed.isNotEmpty) {
              createdId = parsed[0]['id'];
            } else if (parsed is Map) {
              createdId = parsed['id'];
            }
          } catch (_) {}

          if (createdId != null) {
            cardData['id'] = createdId;
          }

          // Update dream amount asynchronously in background
          if (note.startsWith('[ออม] หยอดกระปุก: ')) {
            final dreamTitle = note.replaceAll('[ออม] หยอดกระปุก: ', '').trim();
            _apiClient.get(
              '/dreams?user_id=eq.$_activeUserId&title=eq.$dreamTitle',
            ).then((dreamsResp) {
              if (dreamsResp.statusCode == 200) {
                final List<dynamic> matchingDreams =
                    jsonDecode(dreamsResp.body);
                if (matchingDreams.isNotEmpty) {
                  final dream = matchingDreams.first;
                  final double currentSaved =
                      num.tryParse(dream['current_amount']?.toString() ?? '')
                          ?.toDouble() ??
                      0.0;
                  final double newSaved = currentSaved + amount;
                  _apiClient.patch(
                    '/dreams?id=eq.${dream['id']}',
                    body: {'current_amount': newSaved},
                  );
                }
              }
            }).catchError((_) {});
          }
        }
      } catch (_) {
        // ออฟไลน์หรือมีปัญหาเครือข่าย: การ์ดยังคงแสดงผลอยู่ในเครื่องอย่างราบรื่น
      }
    }

    if (savedAny) {
      widget.onTransactionSaved?.call();
    }
  }

  void _showEditTransactionModal(Map<String, dynamic> card) {
    final String currentDisplayName = card['name']?.toString() ?? '';
    final String rawNote = card['rawNote']?.toString() ?? currentDisplayName;
    final double currentAmount =
        num.tryParse(card['amount']?.toString() ?? '')?.toDouble() ?? 0.0;
    final BankType? bank = card['bankType'] as BankType?;
    final BankType? destBank = card['destinationBankType'] as BankType?;
    final bool isTransfer = card['isTransfer'] == true || card['category'] == 'ย้ายเงิน';
    final bool isSlip = (card['isSlip'] == true) ||
        rawNote.startsWith('[สลิป') ||
        rawNote.contains('[สลิป') ||
        card['source'] == 'slip' ||
        card['reference_no'] != null ||
        card['image_path'] != null;
    String? txId = card['id']?.toString();
    String? currentImagePath = card['image_path']?.toString();
    final String? assetId = card['asset_id']?.toString();
    final String? refNo = card['reference_no']?.toString() ??
        RegExp(r'\[Ref:([^\]]+)\]').firstMatch(rawNote)?.group(1);
    final String? recipient = card['recipient']?.toString() ??
        (card['metadata'] is Map ? card['metadata']['recipient']?.toString() : null);
    final String? txDateStr = card['transaction_date']?.toString();
    final DateTime? txDate = txDateStr != null ? DateTime.tryParse(txDateStr)?.toLocal() : null;
    bool hasTriedResolving = false;

    final titleController = TextEditingController(text: currentDisplayName);
    final amountController = TextEditingController(
      text: currentAmount.toStringAsFixed(
        currentAmount.truncateToDouble() == currentAmount ? 0 : 2,
      ),
    );

    final quickChips = [
      {'label': 'ค่าข้าว', 'icon': Icons.restaurant_rounded},
      {'label': 'ชากาแฟ', 'icon': Icons.local_cafe_rounded},
      {'label': 'ของใช้ 7-11', 'icon': Icons.storefront_rounded},
      {'label': 'ค่าน้ำมัน', 'icon': Icons.local_gas_station_rounded},
      {'label': 'ช้อปปิ้ง', 'icon': Icons.shopping_bag_rounded},
      {'label': 'ค่าเดินทาง', 'icon': Icons.directions_car_rounded},
      {'label': 'จ่ายบิล / ค่าห้อง', 'icon': Icons.home_work_rounded},
      {'label': 'ค่าขนม', 'icon': Icons.cake_rounded},
      {'label': 'ยา / สุขภาพ', 'icon': Icons.medication_rounded},
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            if (!hasTriedResolving && (currentImagePath == null || !File(currentImagePath!).existsSync())) {
              hasTriedResolving = true;
              SlipScannerBridge.instance.getSlipImagePath(
                path: currentImagePath,
                assetId: assetId,
                cleanId: refNo,
              ).then((resolved) {
                if (resolved != null && File(resolved).existsSync() && modalContext.mounted) {
                  setModalState(() {
                    currentImagePath = resolved;
                    card['image_path'] = resolved;
                  });
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalContext).size.height * 0.88,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                    // Header row
                    Row(
                      children: [
                        if (bank != null)
                          BankLogoIcon(bank: bank, size: 36, showShadow: true)
                        else
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              size: 22,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSlip
                                    ? 'รายการสลิป (${bank?.displayName ?? 'ธนาคาร'})'
                                    : 'ข้อมูลรายการธุรกรรม',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isSlip
                                    ? 'ระบบล็อคยอดเงินตามสลิปจริง แก้ไขได้เฉพาะชื่อรายการ'
                                    : 'แก้ไขชื่อรายการและจำนวนเงินได้ตามต้องการ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (txId?.isNotEmpty == true)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFEF4444),
                            ),
                            tooltip: 'ลบรายการ',
                            onPressed: () async {
                              final currentId = (card['id']?.toString() != null &&
                                      !card['id'].toString().startsWith('temp_'))
                                  ? card['id'].toString()
                                  : txId;
                              if (currentId == null || currentId.isEmpty) return;

                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Text('ยืนยันการลบรายการ'),
                                  content: const Text(
                                    'คุณต้องการลบรายการนี้ใช่หรือไม่? ข้อมูลจะถูกลบออกจากระบบอย่างถาวร',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('ยกเลิก'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEF4444),
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('ลบรายการ'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                try {
                                  await _apiClient.delete('/transactions?id=eq.$currentId');
                                  await SlipScannerBridge.instance.unmarkSlipSaved(
                                    referenceNo: refNo,
                                    assetId: assetId,
                                    imagePath: currentImagePath,
                                    bank: bank,
                                    amount: currentAmount,
                                    date: txDate,
                                  );
                                  if (_activeUserId.isNotEmpty) {
                                    SlipScannerBridge.instance.syncSavedSlipsFromServer(
                                      userId: _activeUserId,
                                      apiClient: _apiClient,
                                      overwrite: true,
                                    );
                                  }
                                  if (ctx.mounted && Navigator.canPop(ctx)) {
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    await _loadPastTransactions(preserveScroll: true);
                                    await widget.onTransactionSaved?.call();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Colors.white,
                                          elevation: 6,
                                          behavior: SnackBarBehavior.floating,
                                          width: 190,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                            side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                                          ),
                                          content: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color: Color(0xFFEF4444),
                                                size: 16,
                                              ),
                                              SizedBox(width: 7),
                                              Text(
                                                'ลบรายการแล้ว',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('Error deleting transaction: $e');
                                }
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 14),

                    // Slip Preview Card (แสดงรูปสลิปและรายละเอียดสลิป)
                    if (isSlip || (currentImagePath != null && currentImagePath!.isNotEmpty) || refNo != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (currentImagePath != null && File(currentImagePath!).existsSync())
                              GestureDetector(
                                onTap: () => _showFullSlipImagePreview(
                                  modalContext,
                                  currentImagePath!,
                                  bank: bank,
                                  destBank: destBank,
                                  refNo: refNo,
                                  recipient: recipient,
                                  amount: currentAmount,
                                  date: txDate,
                                  isTransfer: isTransfer,
                                ),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      width: 66,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(9),
                                        child: Image.file(
                                          File(currentImagePath!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            color: const Color(0xFFE2E8F0),
                                            child: const Icon(Icons.broken_image, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(6),
                                          bottomRight: Radius.circular(9),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.zoom_in_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                width: 66,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (bank != null)
                                      BankLogoIcon(bank: bank, size: 28, showShadow: false)
                                    else
                                      const Icon(Icons.receipt_long_rounded, size: 28, color: Color(0xFF64748B)),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'สลิป',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        isTransfer ? 'สลิปย้ายเงิน' : 'สลิปธนาคาร',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (bank != null) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0F2FE),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            bank.displayName,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0369A1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (refNo != null && refNo.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Ref: $refNo',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (recipient != null && recipient.isNotEmpty) ...[
                                    const SizedBox(height: 2.5),
                                    Text(
                                      'ผู้รับ: $recipient',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (currentImagePath != null && File(currentImagePath!).existsSync())
                                        InkWell(
                                          onTap: () => _showFullSlipImagePreview(
                                            modalContext,
                                            currentImagePath!,
                                            bank: bank,
                                            destBank: destBank,
                                            refNo: refNo,
                                            recipient: recipient,
                                            amount: currentAmount,
                                            date: txDate,
                                            isTransfer: isTransfer,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppTheme.primaryColor.withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.zoom_in_rounded,
                                                  size: 13,
                                                  color: AppTheme.primaryColor,
                                                ),
                                                const SizedBox(width: 3.5),
                                                Text(
                                                  'ดูสลิปเต็มใบ',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.primaryColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      InkWell(
                                        onTap: () async {
                                          final picker = ImagePicker();
                                          final picked = await picker.pickImage(source: ImageSource.gallery);
                                          if (picked != null) {
                                            setModalState(() {
                                              currentImagePath = picked.path;
                                              card['image_path'] = picked.path;
                                            });
                                            if (txId != null && txId.isNotEmpty) {
                                              final newMeta = Map<String, dynamic>.from(
                                                card['metadata'] is Map ? card['metadata'] as Map : {},
                                              );
                                              newMeta['image_path'] = picked.path;
                                              card['metadata'] = newMeta;
                                              try {
                                                await _apiClient.patch('/transactions?id=eq.$txId', body: {
                                                  'metadata': newMeta,
                                                });
                                              } catch (e) {
                                                debugPrint('Error updating transaction slip image: $e');
                                              }
                                            }
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                currentImagePath != null && File(currentImagePath!).existsSync()
                                                    ? Icons.sync_rounded
                                                    : Icons.add_photo_alternate_rounded,
                                                size: 13,
                                                color: const Color(0xFF475569),
                                              ),
                                              const SizedBox(width: 3.5),
                                              Text(
                                                currentImagePath != null && File(currentImagePath!).existsSync()
                                                    ? 'เปลี่ยนรูป'
                                                    : 'แนบรูปสลิป',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
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
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Label: ชื่อรายการ
                    const Text(
                      'ชื่อรายการ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'เช่น ค่าข้าว, ค่าน้ำมัน, ช้อปปิ้ง...',
                        prefixIcon: Icon(
                          Icons.edit_note_rounded,
                          color: AppTheme.primaryColor,
                        ),
                        suffixIcon: titleController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setModalState(() {
                                    titleController.clear();
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppTheme.primaryColor,
                            width: 1.6,
                          ),
                        ),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 10),

                    // Quick Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: quickChips.map((chip) {
                        final label = chip['label'] as String;
                        final icon = chip['icon'] as IconData;
                        final isSelected = titleController.text.trim() == label;
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              titleController.text = label;
                              titleController.selection = TextSelection.fromPosition(
                                TextPosition(offset: label.length),
                              );
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  size: 13.5,
                                  color: isSelected ? Colors.white : AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 4.5),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Label: จำนวนเงิน
                    Row(
                      children: [
                        const Text(
                          'จำนวนเงิน (บาท)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        if (isSlip) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  size: 11,
                                  color: Color(0xFF64748B),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'ล็อคตามสลิปธนาคาร',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      readOnly: isSlip,
                      keyboardType: isSlip
                          ? TextInputType.none
                          : const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isSlip
                            ? const Color(0xFF64748B)
                            : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Text(
                            '฿',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSlip
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        suffixIcon: isSlip
                            ? const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(
                                  Icons.lock_outline_rounded,
                                  size: 18,
                                  color: Color(0xFF94A3B8),
                                ),
                              )
                            : null,
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                        filled: true,
                        fillColor: isSlip
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isSlip
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.primaryColor,
                            width: isSlip ? 1.0 : 1.6,
                          ),
                        ),
                      ),
                    ),
                    if (isSlip) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'ยอดเงินอ้างอิงจากสลิปธนาคารจริง เพื่อความถูกต้องทางบัญชีจึงไม่สามารถแก้ไขยอดเงินได้ครับ',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              if (ctx.mounted && Navigator.canPop(ctx)) {
                                Navigator.pop(ctx);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'ยกเลิก',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              final newTitle = titleController.text.trim();
                              final newAmount = isSlip
                                  ? currentAmount
                                  : (double.tryParse(amountController.text.trim()) ?? currentAmount);
                              if (newTitle.isEmpty || newAmount <= 0) return;

                              // สร้าง note ใหม่: ถ้าเป็นสลิป ให้คง [สลิป ...] และ [Ref:...] เอาไว้
                              String updatedNote;
                              if (isSlip) {
                                final refMatch = RegExp(r'\[Ref:[^\]]+\]').firstMatch(rawNote);
                                final refTag = refMatch != null ? ' ${refMatch.group(0)}' : '';
                                final bankName = bank?.displayName ?? (BankType.detectFromText(rawNote)?.displayName ?? 'ธนาคาร');
                                updatedNote = '[สลิป $bankName] $newTitle$refTag';
                              } else {
                                updatedNote = newTitle;
                              }

                              // 1. ปิดหน้าต่าง Modal ทันที (0ms ไม่ต้องรอเน็ตเวิร์ก)
                              if (ctx.mounted && Navigator.canPop(ctx)) {
                                Navigator.pop(ctx);
                              }

                              // 2. อัปเดตการ์ดบนหน้าจอทันที ไม่ให้ผู้ใช้ต้องรอ
                              card['name'] = newTitle;
                              card['amount'] = newAmount;
                              card['rawNote'] = updatedNote;
                              card['isSlip'] = isSlip;

                              // อัปเดตข้อความบับเบิลของผู้ใช้ที่อยู่ก่อนหน้าการ์ดนี้ด้วย (ถ้ามี)
                              final cardIndex = _messages.indexWhere((m) => identical(m.cardData, card));
                              if (cardIndex > 0) {
                                for (int i = cardIndex - 1; i >= 0 && i >= cardIndex - 2; i--) {
                                  if (_messages[i].isUser) {
                                    _messages[i] = Message(
                                      text: '$newTitle ${newAmount.toStringAsFixed(0)}',
                                      isUser: true,
                                      timestamp: _messages[i].timestamp,
                                    );
                                    break;
                                  }
                                }
                              }

                              setState(() {});
                              widget.onTransactionSaved?.call();

                              // 3. แสดงแถบแจ้งเตือน เล็กๆ ขาวๆ ทันที
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.white,
                                  elevation: 6,
                                  behavior: SnackBarBehavior.floating,
                                  width: 210,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                                  ),
                                  content: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: AppTheme.primaryColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 7),
                                      const Text(
                                        'บันทึกเรียบร้อยแล้ว',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              // 4. ซิงค์ข้อมูลขึ้นเซิร์ฟเวอร์แบบ Background Asynchronous ทันทีโดยไม่บล็อกหน้าจอ
                              _syncTransactionUpdate(
                                card: card,
                                txId: txId,
                                rawNote: rawNote,
                                currentDisplayName: currentDisplayName,
                                updatedNote: updatedNote,
                                newAmount: newAmount,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'บันทึก',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  void _showFullSlipImagePreview(
    BuildContext context,
    String imagePath, {
    BankType? bank,
    BankType? destBank,
    String? refNo,
    String? recipient,
    double? amount,
    DateTime? date,
    bool isTransfer = false,
  }) {
    final file = File(imagePath);
    if (!file.existsSync()) return;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
              maxWidth: 420,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ส่วนหัว Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
                  ),
                  child: Row(
                    children: [
                      if (bank != null)
                        BankLogoIcon(bank: bank, size: 30, showShadow: false)
                      else
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 24,
                          color: Colors.white70,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTransfer
                                  ? 'สลิปย้ายเงิน'
                                  : (bank != null ? 'สลิป ${bank.displayName}' : 'รูปภาพสลิป'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (refNo != null && refNo.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Ref: $refNo',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFF334155)),

                // ส่วนรูปภาพสลิป InteractiveViewer ซูมได้
                Flexible(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(21)),
                    child: Container(
                      color: const Color(0xFF0F172A),
                      width: double.infinity,
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.5,
                        child: Image.file(
                          file,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _syncTransactionUpdate({
    required Map<String, dynamic> card,
    required String? txId,
    required String rawNote,
    required String currentDisplayName,
    required String updatedNote,
    required double newAmount,
  }) async {
    try {
      String? currentTxId = (card['id']?.toString() != null &&
              !card['id'].toString().startsWith('temp_'))
          ? card['id'].toString()
          : txId;
      if (currentTxId == null ||
          currentTxId.isEmpty ||
          currentTxId.startsWith('temp_')) {
        final q = await _apiClient.get(
          '/transactions?user_id=eq.$_activeUserId&order=transaction_date.desc&limit=15',
        );
        if (q.statusCode == 200) {
          final list = jsonDecode(q.body);
          if (list is List) {
            for (var item in list) {
              if (item is Map) {
                final itemNote = item['note']?.toString() ?? '';
                if (itemNote == rawNote ||
                    (rawNote.contains('[Ref:') &&
                        itemNote.contains(rawNote.substring(rawNote.indexOf('[Ref:')))) ||
                    itemNote.contains(currentDisplayName)) {
                  currentTxId = item['id']?.toString();
                  card['id'] = currentTxId;
                  break;
                }
              }
            }
          }
        }
      }

      if (currentTxId != null && currentTxId.isNotEmpty) {
        final patchBody = {
          'note': updatedNote,
          'amount': newAmount,
          if (card['bank'] != null) 'bank': card['bank'],
          if (card['reference_no'] != null) 'reference_no': card['reference_no'],
          if (card['source'] != null) 'source': card['source'],
          if (card['metadata'] != null) 'metadata': card['metadata'],
        };
        var patchResp = await _apiClient.patch(
          '/transactions?id=eq.$currentTxId',
          body: patchBody,
        );
        if (patchResp.statusCode >= 400 && patchResp.body.contains('column')) {
          patchResp = await _apiClient.patch(
            '/transactions?id=eq.$currentTxId',
            body: {
              'note': updatedNote,
              'amount': newAmount,
            },
          );
        }

        if (patchResp.statusCode >= 400) {
          await _apiClient.delete('/transactions?id=eq.$currentTxId');
          final postBody = {
            'user_id': _activeUserId,
            'amount': newAmount,
            'type': card['msgType'] == 'income' ? 'income' : 'expense',
            'note': updatedNote,
            if (card['bank'] != null) 'bank': card['bank'],
            if (card['reference_no'] != null) 'reference_no': card['reference_no'],
            if (card['source'] != null) 'source': card['source'],
            if (card['transaction_date'] != null)
              'transaction_date': card['transaction_date'],
          };
          var postResp = await _apiClient.post('/transactions', body: postBody);
          if (postResp.statusCode >= 400 && postResp.body.contains('column')) {
            postResp = await _apiClient.post(
              '/transactions',
              body: {
                'user_id': _activeUserId,
                'amount': newAmount,
                'type': card['msgType'] == 'income' ? 'income' : 'expense',
                'note': updatedNote,
                if (card['transaction_date'] != null)
                  'transaction_date': card['transaction_date'],
              },
            );
          }
          try {
            final parsed = jsonDecode(postResp.body);
            if (parsed is List && parsed.isNotEmpty) {
              card['id'] = parsed[0]['id'];
            } else if (parsed is Map) {
              card['id'] = parsed['id'];
            }
          } catch (_) {}
        }
      } else {
        final postBody = {
          'user_id': _activeUserId,
          'amount': newAmount,
          'type': card['msgType'] == 'income' ? 'income' : 'expense',
          'note': updatedNote,
          if (card['bank'] != null) 'bank': card['bank'],
          if (card['reference_no'] != null) 'reference_no': card['reference_no'],
          if (card['source'] != null) 'source': card['source'],
          if (card['transaction_date'] != null)
            'transaction_date': card['transaction_date'],
        };
        var postResp = await _apiClient.post('/transactions', body: postBody);
        if (postResp.statusCode >= 400 && postResp.body.contains('column')) {
          postResp = await _apiClient.post(
            '/transactions',
            body: {
              'user_id': _activeUserId,
              'amount': newAmount,
              'type': card['msgType'] == 'income' ? 'income' : 'expense',
              'note': updatedNote,
              if (card['transaction_date'] != null)
                'transaction_date': card['transaction_date'],
            },
          );
        }
        try {
          final parsed = jsonDecode(postResp.body);
          if (parsed is List && parsed.isNotEmpty) {
            card['id'] = parsed[0]['id'];
          } else if (parsed is Map) {
            card['id'] = parsed['id'];
          }
        } catch (_) {}
      }

      widget.onTransactionSaved?.call();
    } catch (e) {
      debugPrint('Background transaction sync error: $e');
    }
  }

  Widget _buildMessageBubble(Message message) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compactAiWidth = math.min(screenWidth * 0.60, 225.0);
    final userBubbleMaxWidth = math.min(screenWidth * 0.60, 210.0);

    if (message.cardData != null) {
      final card = message.cardData!;
      final name = card['name'] ?? '';
      final amount = num.tryParse(card['amount']?.toString() ?? '')?.toDouble() ?? 0.0;
      final category = card['category'] ?? 'รายจ่าย';
      final msgType = card['msgType'] as String? ?? 'expense';
      final cardDate = DateTime.tryParse(card['transaction_date']?.toString() ?? '')?.toLocal() ?? message.timestamp;

      final bool hasBudget = card['hasBudget'] as bool? ?? false;
      final double budget = num.tryParse(card['budget']?.toString() ?? '')?.toDouble() ?? 0.0;
      final double totalAccumulated =
          num.tryParse(card['totalAccumulated']?.toString() ?? '')?.toDouble() ?? amount;

      final BankType? bank = card['bankType'] as BankType?;
      final BankType? destinationBank = card['destinationBankType'] as BankType?;

      Color categoryColor = const Color(0xFF10B981);
      Color headerBgColor = const Color(0xFFE6F4F1);
      IconData headerIcon = Icons.account_balance_wallet_outlined;

      if (bank != null) {
        categoryColor = Color(bank.brandColorValue);
        headerBgColor = Color(bank.brandColorValue).withValues(alpha: 0.12);
        headerIcon = Icons.account_balance_rounded;
      } else if (msgType == 'expense' || category == 'รายจ่าย') {
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
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFDF5)
                : const Color(0xFF2B1A0E),
            width: 2.0,
          );
          break;
        case ThemeStyle.sakura:
          cardRadius = BorderRadius.circular(24);
          cardBorder = Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF4C2731)
                : const Color(0xFFFFE3E7),
            width: 1.2,
          );
          break;
        case ThemeStyle.cyberpunk:
          cardRadius = BorderRadius.circular(12);
          cardBorder = Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF00FFF0)
                : const Color(0xFFFF007F),
            width: 1.5,
          );
          break;
        case ThemeStyle.luxury:
          cardRadius = BorderRadius.circular(16);
          cardBorder = Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF4A3E20)
                : const Color(0xFFE5D5A1),
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
                  card['icon'] ?? (bank != null ? BankLogoIcon(bank: bank, size: 48, showShadow: true) : headerIcon),
                  categoryColor,
                  headerBgColor,
                  hasBudget,
                  bank: bank,
                  destinationBank: destinationBank,
                  onEdit: () => _showEditTransactionModal(card),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (bank != null)
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  BankLogoIcon(
                                    bank: bank,
                                    size: 16,
                                    showShadow: false,
                                    showBorder: false,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      bank.displayName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(bank.brandColorValue),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            const Spacer(),
                          const SizedBox(width: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 10,
                                color: context.secondaryTextColor.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatTinyDate(cardDate),
                                style: TextStyle(
                                  fontFamily: 'SukhumvitSet',
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w600,
                                  color: context.secondaryTextColor.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
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
                      if (msgType == 'transfer') ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFF6366F1)),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'ย้ายเงินระหว่างบัญชี',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
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
        constraints: BoxConstraints(
          maxWidth: isUser ? userBubbleMaxWidth : compactAiWidth,
        ),
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
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              message.isThinking
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
              if (!message.isThinking) ...[
                const SizedBox(height: 3),
                Text(
                  _formatTinyDate(message.timestamp),
                  style: TextStyle(
                    fontFamily: 'SukhumvitSet',
                    fontSize: 9.0,
                    fontWeight: FontWeight.w500,
                    color: isUser
                        ? Colors.white.withValues(alpha: 0.70)
                        : (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ],
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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _unfocusKeyboard,
        child: Stack(
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
                ValueListenableBuilder<DateTime?>(
                  valueListenable: _effectiveDateFilter,
                  builder: (context, dateFilterVal, _) {
                    if (dateFilterVal == null) return const SizedBox.shrink();
                    final formattedDate =
                        '${dateFilterVal.day} ${_monthName(dateFilterVal.month)} ${dateFilterVal.year + 543}';
                    return Container(
                      margin: EdgeInsets.fromLTRB(
                        16,
                        widget.topPadding + 8,
                        16,
                        0,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.tr(
                                'จดบันทึกของวันที่: $formattedDate',
                                'Recording for: $formattedDate',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _effectiveDateFilter.value = null;
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Expanded(
                  child: NotificationListener<UserScrollNotification>(
                    onNotification: _handleUserScroll,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _unfocusKeyboard,
                      child: ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          _effectiveDateFilter.value != null
                              ? 8
                              : widget.topPadding,
                          16,
                          _quickSuggestions.isNotEmpty ? 58 : 16,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _unfocusKeyboard,
                            child: _buildMessageBubble(_messages[index]),
                          );
                        },
                      ),
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
                      ValueListenableBuilder<int>(
                        valueListenable:
                            SlipScannerBridge.instance.unscannedCount,
                        builder: (context, count, _) => Tooltip(
                          message: count > 0
                              ? context.tr(
                                  'พบสลิป $count รายการ กดเพื่อสแกน',
                                  'Found $count slips, tap to scan',
                                )
                              : context.tr(
                                  'สแกนสลิปธนาคาร',
                                  'Scan Bank Slip',
                                ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              IconButton(
                                onPressed:
                                    _isScanningSlips ? null : _openSlipScanner,
                                icon: _isScanningSlips
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      )
                                    : Icon(
                                        Icons.receipt_long_rounded,
                                        color: Theme.of(context).primaryColor,
                                        size: 21,
                                      ),
                              ),
                              if (count > 0 && !_isScanningSlips)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Center(
                                      child: Text(
                                        count > 9 ? '9+' : '$count',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
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
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.24),
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
                        : Icon(
                            suggestion.icon as IconData,
                            size: 13,
                            color: color,
                          ),
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
      case 'transfer':
        return const Color(0xFF6366F1);
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
      case 'transfer':
        return 'บันทึกการย้ายเงินระหว่างบัญชีเรียบร้อยแล้ว';
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
    bool hasBudget, {
    BankType? bank,
    BankType? destinationBank,
    VoidCallback? onEdit,
  }) {
    final isTransfer = msgType == 'transfer' || category == 'ย้ายเงิน';
    final isExpense = !isTransfer && (msgType == 'expense' || category == 'รายจ่าย');
    final isDream = !isTransfer && (msgType == 'dream' || category == 'เงินออม');
    final title = isTransfer
        ? 'ย้ายเงินระหว่างบัญชี'
        : (bank != null
            ? (destinationBank != null
                ? 'โอนออก (${bank.displayName} ➔ ${destinationBank.displayName})'
                : 'สลิป ${bank.displayName}')
            : (isExpense
                ? context.tr('บันทึกรายจ่าย', 'EXPENSE RECORD')
                : (isDream
                    ? context.tr('หยอดเป้าหมาย', 'SAVINGS GOAL')
                    : context.tr('รายการใหม่', 'NEW ENTRY'))));

    final editButton = onEdit != null
        ? Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 13,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    final badge = !hasBudget
        ? Positioned(
            top: 10,
            left: 10,
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
                  painter: _CardCheckeredPainter(
                    color: const Color(0xFFFFC08D).withValues(alpha: 0.3),
                  ),
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
                        border: Border.all(
                          color: const Color(0xFF2B1A0E),
                          width: 1.8,
                        ),
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
              editButton,
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
              editButton,
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
                  painter: _CardCyberGridPainter(
                    color: const Color(0xFFFF007F).withValues(alpha: 0.15),
                  ),
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
                        border: Border.all(
                          color: const Color(0xFF00FFF0),
                          width: 1.5,
                        ),
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
              editButton,
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
              editButton,
            ],
          ),
        );

      case ThemeStyle.emerald:
        return Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: headerBgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              editButton,
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
    final detectedBank = BankType.detectFromText(name);
    if (detectedBank != null) {
      return BankLogoIcon(bank: detectedBank, size: 44, showShadow: true);
    }

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
      if (nameLower.contains('ลงทุน') || nameLower.contains('หุ้น'))
        return Icons.trending_up_outlined;
      if (nameLower.contains('ขาย')) return Icons.shopping_cart_outlined;
      return Icons.account_balance_wallet_outlined;
    } else {
      if (nameLower.contains('ไฟ')) return Icons.flash_on_outlined;
      if (nameLower.contains('น้ำ')) return Icons.water_drop_outlined;
      if (nameLower.contains('ห้อง') ||
          nameLower.contains('บ้าน') ||
          nameLower.contains('เช่า'))
        return Icons.home_outlined;
      if (nameLower.contains('เน็ต') || nameLower.contains('wifi'))
        return Icons.wifi;
      if (nameLower.contains('โทร') || nameLower.contains('มือถือ'))
        return Icons.phone_android_outlined;
      if (nameLower.contains('กิน') ||
          nameLower.contains('ข้าว') ||
          nameLower.contains('อาหาร') ||
          nameLower.contains('คาเฟ่'))
        return Icons.local_cafe_outlined;
      if (nameLower.contains('รถ') || nameLower.contains('เดินทาง'))
        return Icons.directions_car_outlined;
      if (nameLower.contains('ยา') ||
          nameLower.contains('หมอ') ||
          nameLower.contains('โรงพยาบาล') ||
          nameLower.contains('รักษา'))
        return Icons.favorite_border_outlined;
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
          ..color = isDark
              ? Colors.white.withValues(alpha: 0.015)
              : Colors.black.withValues(alpha: 0.015)
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
          ..color = isDark
              ? const Color(0xFFFFF3E6).withValues(alpha: 0.03)
              : const Color(0xFFFF9233).withValues(alpha: 0.04)
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
          ..color = isDark
              ? const Color(0xFFFF8FA3).withValues(alpha: 0.03)
              : const Color(0xFFFF8FA3).withValues(alpha: 0.05)
          ..strokeWidth = 3.0;
        const double step = 40.0;
        for (double i = -size.height; i < size.width; i += step) {
          canvas.drawLine(
            Offset(i, 0),
            Offset(i + size.height, size.height),
            paint,
          );
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
          canvas.drawLine(
            Offset(xBottom, size.height),
            Offset(xTop, horizonY),
            gridPaint,
          );
        }

        double currentY = size.height;
        double spacing = 45.0;
        while (currentY > horizonY) {
          final ratio = (currentY - horizonY) / (size.height - horizonY);
          gridPaint.color = const Color(
            0xFFFF007F,
          ).withValues(alpha: 0.04 + (0.06 * ratio));
          canvas.drawLine(
            Offset(0, currentY),
            Offset(size.width, currentY),
            gridPaint,
          );
          currentY -= spacing;
          spacing *= 0.85;
          if (spacing < 4.0) break;
        }
        break;

      case ThemeStyle.luxury:
        final paint = Paint()
          ..color = const Color(
            0xFFD4AF37,
          ).withValues(alpha: isDark ? 0.03 : 0.05)
          ..strokeWidth = 1.0;
        const double step = 45.0;
        for (double i = -size.height; i < size.width; i += step) {
          canvas.drawLine(
            Offset(i, 0),
            Offset(i + size.height, size.height),
            paint,
          );
        }
        for (double i = 0; i < size.width + size.height; i += step) {
          canvas.drawLine(
            Offset(i, 0),
            Offset(i - size.height, size.height),
            paint,
          );
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
