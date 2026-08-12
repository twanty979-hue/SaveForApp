import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:app/core/localization/app_material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../auth/domain/auth_session.dart';
import '../../profile/presentation/profile_settings_screen.dart';
import '../../planning/presentation/planning_hub_screen.dart';
import '../../transactions/presentation/transactions_screen.dart';
import 'notification_inbox_sheet.dart';
import 'compact_calendar_sheet.dart';
import 'finance_dashboard_screen.dart';
import 'package:app/icon_selector_demo.dart';
import 'package:app/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiClient _apiClient = ApiClient();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _balanceKey = GlobalKey();
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _notificationKey = GlobalKey();
  final GlobalKey _homeMenuKey = GlobalKey();
  final GlobalKey _inputKey = GlobalKey();
  int _tutorialStep = -1;
  final String _activeUserId =
      AuthSession.userId ?? '5b2d488d-75a0-4ea4-8f14-43047d256c8d';

  double _todaySpent = 0.0;
  double _monthSpent = 0.0;
  String? _avatarUrl = AuthSession.avatarUrl;
  final ValueNotifier<DateTime?> _chatDateFilter = ValueNotifier<DateTime?>(null);

  @override
  void initState() {
    super.initState();
    AppSettings.hideBalances.addListener(_onHideBalancesChanged);
    unawaited(_apiClient.preloadCoreData(_activeUserId));
    _fetchHeaderTotals();
    _fetchHeaderAvatar();
    NotificationService.instance.registerDevice();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndForceMonthlyExpense();
    });
  }

  void _onHideBalancesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSettings.hideBalances.removeListener(_onHideBalancesChanged);
    _chatDateFilter.dispose();
    super.dispose();
  }

  String _obfuscate(double amount) {
    return AppSettings.hideBalances.value ? '***' : amount.toStringAsFixed(0);
  }

  Future<void> _fetchHeaderAvatar() async {
    if (AuthSession.accessToken?.isNotEmpty != true) return;
    try {
      final response = await _apiClient.get('/profile/avatar');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final avatarPath = data['avatar_url']?.toString();
        final avatarUrl = avatarPath == null
            ? null
            : _apiClient.absoluteUrl(avatarPath);
        await AuthSession.setAvatarUrl(avatarUrl);
        if (mounted) setState(() => _avatarUrl = avatarUrl);
      }
    } catch (_) {
      // ใช้รูปที่บันทึกไว้ในเครื่องเมื่อเครือข่ายไม่พร้อม
    }
  }

  Future<void> _fetchHeaderTotals() async {
    try {
      final response = await _apiClient.get(
        '/transactions?user_id=eq.$_activeUserId',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final now = DateTime.now();

        double todaySum = 0.0;
        double monthSum = 0.0;

        for (var tx in data) {
          if (tx['type'] == 'expense') {
            final dateStr = tx['transaction_date'] ?? '';
            final date = DateTime.tryParse(dateStr)?.toLocal();
            if (date == null) continue;
            final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
            if (date.year == now.year && date.month == now.month) {
              monthSum += amount;
            }
            if (date.year == now.year &&
                date.month == now.month &&
                date.day == now.day) {
              todaySum += amount;
            }
          }
        }

        setState(() {
          _todaySpent = todaySum;
          _monthSpent = monthSum;
        });
      }
    } catch (e) {
      // ดำเนินการเงียบ
    }
  }

  void _showCalendarBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CompactCalendarSheet(
          onDateSelected: (date) {
            _chatDateFilter.value = date;
            Navigator.pop(context); // Close calendar sheet immediately
          },
        );
      },
    );
  }

  void _showNotificationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationInboxSheet(),
    ).then((_) => NotificationService.instance.refreshUnreadCount());
  }

  Future<void> _openProfileSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
    );
    if (mounted) {
      setState(() {});
      _fetchHeaderTotals();
      _fetchHeaderAvatar();
    }
  }

  void _openSettingsPage(String destination) {
    final Widget page;
    switch (destination) {
      case 'summary':
        page = FinanceDashboardScreen(onRefreshHeader: _fetchHeaderTotals);
      case 'dream':
        page = const PlanningHubScreen(initialSection: PlanningSection.dream);
      case 'expense':
        page = const PlanningHubScreen(initialSection: PlanningSection.expense);
      case 'plans':
        page = const PlanningHubScreen();
      case 'icon_picker':
        page = const IconSelectorDemo();
      default:
        page = const PlanningHubScreen(initialSection: PlanningSection.income);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) => _fetchHeaderTotals());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageColor,
      body: Stack(
        children: [
          const Positioned.fill(child: FloatingBackground()),
          SafeArea(
            child: ResponsiveLayout(
              maxWidth: 800,
              child: Stack(
                children: [
                Positioned.fill(
                  child: TransactionsScreen(
                    topPadding: 86,
                    inputKey: _inputKey,
                    dateFilter: _chatDateFilter,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Tooltip(
                          message: context.tr(
                            'ตั้งค่าโปรไฟล์',
                            'Profile settings',
                          ),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _openProfileSettings,
                            child: Container(
                              key: _profileKey,
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _avatarUrl?.isNotEmpty == true
                                  ? SafeNetworkImage(
                                      url: _avatarUrl!,
                                      fit: BoxFit.cover,
                                      isCircle: true,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.person_outline_rounded,
                                        color: AppTheme.primaryColor,
                                        size: 21,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_outline_rounded,
                                      color: AppTheme.primaryColor,
                                      size: 21,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            key: _balanceKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AuthSession.displayName ??
                                    context.tr('บัญชีของฉัน', 'My account'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    '${context.tr('วันนี้', 'Today')} ฿${_obfuscate(_todaySpent)}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: SizedBox(
                                      width: 3,
                                      height: 3,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Color(0xFFCBD5E1),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      '${context.tr('เดือนนี้', 'This month')} ฿${_obfuscate(_monthSpent)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: context.tr('ปฏิทิน', 'Calendar'),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13),
                            onTap: _showCalendarBottomSheet,
                            child: SizedBox(
                              key: _calendarKey,
                              child: const _HeaderIcon(
                                icon: Icons.calendar_today_outlined,
                                color: Color(0xFF64748B),
                                backgroundColor: Color(0xFFF1F5F9),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ValueListenableBuilder<int>(
                          valueListenable:
                              NotificationService.instance.unreadCount,
                          builder: (context, unreadCount, _) => Tooltip(
                            message: context.tr(
                              'การแจ้งเตือน',
                              'Notifications',
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(13),
                              onTap: _showNotificationBottomSheet,
                              child: SizedBox(
                                key: _notificationKey,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                  const _HeaderIcon(
                                    icon: Icons.notifications_none_rounded,
                                    color: Color(0xFF64748B),
                                    backgroundColor: Color(0xFFF1F5F9),
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      top: -2,
                                      right: -2,
                                      child: Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                        const SizedBox(width: 6),
                        PopupMenuButton<String>(
                          tooltip: context.tr('เมนูหน้าหลัก', 'Home menu'),
                          onSelected: _openSettingsPage,
                          offset: const Offset(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'summary',
                              child: _HomeMenuItem(
                                icon: Icons.bar_chart_outlined,
                                color: Color(0xFF1E293B),
                                label: context.tr('สรุปยอด', 'Dashboard'),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'plans',
                              child: _HomeMenuItem(
                                icon: Icons.dashboard_customize_outlined,
                                color: AppTheme.primaryColor,
                                label: context.tr('รายการที่ตั้งไว้', 'Plans'),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'icon_picker',
                              child: _HomeMenuItem(
                                icon: Icons.emoji_emotions_outlined,
                                color: Colors.purple,
                                label: context.tr('เทสไอคอน', 'Test Icon'),
                              ),
                            ),
                          ],
                          child: SizedBox(
                            key: _homeMenuKey,
                            child: const _HeaderAssetIcon(
                              assetPath: 'assets/images/home_menu_icon.png',
                              color: AppTheme.primaryColor,
                              backgroundColor: Color(0xFFE6F4F1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildTutorialOverlay(),
      ],
      ),
    );
  }

  void _finishMainTutorial() {
    setState(() {
      _tutorialStep = -1;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlanningHubScreen(
          initialSection: PlanningSection.income,
          startTutorial: true,
        ),
      ),
    ).then((_) => _fetchHeaderTotals());
  }

  Rect? _getWidgetRect(GlobalKey key) {
    try {
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final offset = renderBox.localToGlobal(Offset.zero);
        return Rect.fromLTWH(
          offset.dx,
          offset.dy,
          renderBox.size.width,
          renderBox.size.height,
        );
      }
    } catch (_) {}
    return null;
  }

  Widget _buildTutorialOverlay() {
    if (_tutorialStep < 0) return const SizedBox.shrink();

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double screenHeight = MediaQuery.sizeOf(context).height;

    Rect targetRectVal = Rect.fromCenter(
      center: Offset(screenWidth / 2, screenHeight / 2),
      width: 0,
      height: 0,
    );
    double targetRadiusVal = 0.0;
    
    switch (_tutorialStep) {
      case 1:
        final rect = _getWidgetRect(_profileKey);
        if (rect != null) {
          targetRectVal = rect;
          targetRadiusVal = rect.width / 2;
        }
        break;
      case 2:
        final rect = _getWidgetRect(_balanceKey);
        if (rect != null) {
          targetRectVal = rect;
          targetRadiusVal = 12.0;
        }
        break;
      case 3:
        final rect = _getWidgetRect(_calendarKey);
        if (rect != null) {
          targetRectVal = rect;
          targetRadiusVal = rect.width / 2;
        }
        break;
      case 4:
        final rect = _getWidgetRect(_notificationKey);
        if (rect != null) {
          targetRectVal = rect;
          targetRadiusVal = rect.width / 2;
        }
        break;
      case 5:
        final rect = _getWidgetRect(_homeMenuKey);
        if (rect != null) {
          targetRectVal = rect;
          targetRadiusVal = rect.width / 2;
        }
        break;
      case 6:
        final rect = _getWidgetRect(_inputKey);
        if (rect != null) {
          targetRectVal = rect;
          targetRadiusVal = 22.0;
        }
        break;
    }

    final titles = [
      context.tr('ยินดีต้อนรับสู่ SaveFor', 'Welcome to SaveFor'),
      context.tr('โปรไฟล์และการตั้งค่า', 'Profile & Settings'),
      context.tr('สรุปยอดเงินวันนี้', 'Today\'s Summary'),
      context.tr('ปฏิทินบันทึกย้อนหลัง', 'Daily Calendar'),
      context.tr('ศูนย์แจ้งเตือน', 'Notification Center'),
      context.tr('เมนูทางเลือกหลัก', 'Main Home Menu'),
      context.tr('พิมพ์บันทึกธุรกรรมด่วน', 'AI Fast Recording'),
    ];

    final descriptions = [
      context.tr('ขอแนะนำฟีเจอร์การใช้งานหลักที่จะช่วยให้คุณออมเงินและบันทึกรายรับรายจ่ายได้อย่างชาญฉลาดและรวดเร็ว', 'Let\'s take a quick tour to learn the main features that help you save and track transactions smartly.'),
      context.tr('แตะรูปโปรไฟล์ที่นี่เพื่อเข้าสู่การตั้งค่าบัญชี เปลี่ยนรหัสผ่าน จัดการความเป็นส่วนตัว หรือเลือกเปลี่ยนธีมลวดลายสวยงามที่คุณชอบ', 'Tap your profile here to access settings, change password, manage privacy, or customize your app themes.'),
      context.tr('ส่วนนี้จะแสดงยอดสรุปรายจ่ายของวันนี้ และรายจ่ายทั้งหมดในเดือนนี้ เพื่อช่วยให้คุณควบคุมการเงินได้ทันท่วงที', 'This section displays your total expenses for today and this month to help you stay on track instantly.'),
      context.tr('แตะไอคอนนี้เพื่อเปิดดูรายการย้อนหลังในแต่ละวัน แก้ไขรายการที่บันทึกไปแล้ว หรือคลิกบันทึกรายการย้อนหลัง', 'Tap this icon to view daily history, edit past transactions, or manually log retroactive entries.'),
      context.tr('รับข้อมูลอัปเดต ข่าวสาร หรือข้อความสำคัญเกี่ยวกับบัญชีและการออมเงินของคุณได้จากหน้าต่างนี้', 'Get updates, announcements, or warning alerts regarding your budget and savings plan here.'),
      context.tr('เข้าสู่แดชบอร์ดดูสรุปแผนภูมิการเงิน วิเคราะห์รายจ่าย หรือจัดการรายการวางแผนรายรับ-รายจ่ายประจำเดือน', 'Switch to the dashboard to view charts, analyze expenses, or manage monthly recurring plans.'),
      context.tr('พิมพ์ข้อความบันทึกง่าย ๆ เช่น "ค่าข้าว 50" หรือ "+เงินเดือน 20000" เพื่อบันทึกทันที หรือคลิกไอคอนบวกเพื่อเลือกรายการแนะนำด่วน', 'Type quick statements like "Food 60" or "+Salary 20000" to log instantly, or tap the plus icon for shortcuts.'),
    ];

    final totalSteps = titles.length;

    Widget cardChild = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_tutorialStep + 1} / $totalSteps',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _tutorialStep = -1;
                  });
                },
                child: Text(
                  context.tr('ข้ามการแนะนำ', 'Skip'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            titles[_tutorialStep],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            descriptions[_tutorialStep],
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: context.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_tutorialStep > 0) ...[
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _tutorialStep--;
                    });
                  },
                  child: Text(context.tr('ย้อนกลับ', 'Back')),
                ),
                const SizedBox(width: 10),
              ],
              FilledButton(
                onPressed: () {
                  if (_tutorialStep < totalSteps - 1) {
                    setState(() {
                      _tutorialStep++;
                    });
                  } else {
                    _finishMainTutorial();
                  }
                },
                child: Text(
                  _tutorialStep == totalSteps - 1
                      ? context.tr('เข้าใจแล้ว', 'Finish')
                      : context.tr('ถัดไป', 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Determine layout coordinates dynamically for smooth sliding animation
    final double cardHeight = 220.0;
    double animTop = (screenHeight - cardHeight) / 2;
    if (_tutorialStep == 6) {
      animTop = 160.0;
    } else if (_tutorialStep > 0) {
      animTop = screenHeight - cardHeight - 110;
    }

    return Positioned.fill(
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: false,
            child: GestureDetector(
              onTap: () {
                if (_tutorialStep < totalSteps - 1) {
                  setState(() {
                    _tutorialStep++;
                  });
                } else {
                  _finishMainTutorial();
                }
              },
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: targetRectVal),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                builder: (context, animRect, _) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: targetRadiusVal),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeInOutCubic,
                    builder: (context, animRadius, _) {
                      return CustomPaint(
                        size: Size.infinite,
                        painter: TutorialBackdropPainter(
                          targetRect: animRect,
                          borderRadius: animRadius,
                          isWelcomeStep: _tutorialStep == 0,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            top: animTop,
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _tutorialStep >= 0 ? 1.0 : 0.0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 400),
                scale: _tutorialStep >= 0 ? 1.0 : 0.95,
                curve: Curves.easeOutBack,
                child: cardChild,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShownTutorial = prefs.getBool('has_shown_dashboard_tutorial') ?? false;
    
    if (hasShownTutorial) return;

    Future.delayed(const Duration(milliseconds: 600), () async {
      if (mounted && _tutorialStep < 0) {
        setState(() {
          _tutorialStep = 0;
        });
        await prefs.setBool('has_shown_dashboard_tutorial', true);
      }
    });
  }

  Future<void> _checkAndForceMonthlyExpense() async {
    if (!mounted) return;
    try {
      final response = await _apiClient.get(
        '/recurring/expenses?user_id=eq.$_activeUserId',
      );
      if (response.statusCode == 200) {
        final List<dynamic> expenses = jsonDecode(response.body);
        Map<String, dynamic>? monthlyExpense;
        for (var item in expenses) {
          if (item['name']?.toString().trim() == 'ค่าใช้จ่ายรายเดือน') {
            monthlyExpense = item;
            break;
          }
        }

        final double amount = monthlyExpense != null
            ? (monthlyExpense['amount'] as num?)?.toDouble() ?? 0.0
            : 0.0;

        if (monthlyExpense == null || amount <= 0.0) {
          if (mounted) {
            _showForceMonthlyExpenseBottomSheet(monthlyExpense);
          }
        } else {
          _startTutorial();
        }
      } else {
        _startTutorial();
      }
    } catch (e) {
      debugPrint('Error checking monthly expense: $e');
      _startTutorial();
    }
  }

  void _showForceMonthlyExpenseBottomSheet(Map<String, dynamic>? existingExpense) {
    final TextEditingController amountController = TextEditingController();
    String? errorMsg;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final style = AppSettings.themeStyle.value;
            Color primaryColor = AppTheme.primaryColor;
            BorderRadius cardRadius = BorderRadius.circular(24);

            switch (style) {
              case ThemeStyle.cartoon:
                primaryColor = const Color(0xFFFF9233);
                cardRadius = BorderRadius.circular(20);
                break;
              case ThemeStyle.sakura:
                primaryColor = const Color(0xFFFF8FA3);
                cardRadius = BorderRadius.circular(24);
                break;
              case ThemeStyle.cyberpunk:
                primaryColor = const Color(0xFFFF007F);
                cardRadius = BorderRadius.circular(12);
                break;
              case ThemeStyle.luxury:
                primaryColor = const Color(0xFFD4AF37);
                cardRadius = BorderRadius.circular(16);
                break;
              default:
                primaryColor = const Color(0xFF00A88F);
                cardRadius = BorderRadius.circular(24);
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
            final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
            final subTextCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

            return PopScope(
              canPop: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.vertical(top: cardRadius.topRight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.settings_suggest_rounded,
                            color: primaryColor,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'ตั้งค่าประมาณการรายจ่ายประจำเดือน',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ยินดีต้อนรับสู่ SaveFor! กรุณาระบุยอดประมาณการค่าใช้จ่ายรายเดือนของคุณก่อนเริ่มต้น เพื่อใช้เป็นข้อมูลเปรียบเทียบในระบบควบคุมงบประมาณและการออม',
                        style: TextStyle(
                          fontSize: 13,
                          color: subTextCol,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (errorMsg != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMsg!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'จำนวนเงินประมาณการ (บาท/เดือน)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                        decoration: InputDecoration(
                          hintText: 'กรอกจำนวนเงิน เช่น 15000',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: subTextCol.withOpacity(0.7),
                          ),
                          prefixText: '฿ ',
                          prefixStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final inputStr = amountController.text.trim().replaceAll(',', '');
                                  final double? val = double.tryParse(inputStr);

                                  if (inputStr.isEmpty) {
                                    setSheetState(() {
                                      errorMsg = 'กรุณากรอกประมาณการค่าใช้จ่ายรายเดือน';
                                    });
                                    return;
                                  }
                                  if (val == null || val <= 0) {
                                    setSheetState(() {
                                      errorMsg = 'กรุณากรอกจำนวนเงินมากกว่า 0 บาท';
                                    });
                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                    errorMsg = null;
                                  });

                                  try {
                                    final body = {
                                      'user_id': _activeUserId,
                                      'name': 'ค่าใช้จ่ายรายเดือน',
                                      'amount': val,
                                      'category': 'อื่นๆ',
                                      'due_day': 1,
                                    };

                                    final response = existingExpense != null
                                        ? await _apiClient.patch(
                                            '/recurring/expenses?id=eq.${existingExpense['id']}',
                                            body: body,
                                          )
                                        : await _apiClient.post(
                                            '/recurring/expenses',
                                            body: body,
                                          );

                                    if (response.statusCode == 200 ||
                                        response.statusCode == 201 ||
                                        response.statusCode == 204) {
                                      ApiClient.clearCache();
                                      if (sheetContext.mounted) {
                                        Navigator.pop(sheetContext);
                                      }
                                      _fetchHeaderTotals();
                                      _startTutorial();
                                    } else {
                                      setSheetState(() {
                                        isSaving = false;
                                        errorMsg = 'ไม่สามารถบันทึกข้อมูลได้ กรุณาลองใหม่อีกครั้ง';
                                      });
                                    }
                                  } catch (e) {
                                    setSheetState(() {
                                      isSaving = false;
                                      errorMsg = 'เกิดข้อผิดพลาดในการเชื่อมต่อเครือข่าย';
                                    });
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'บันทึกและเริ่มใช้งาน',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          },
        );
      },
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _HeaderIcon({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class _HeaderAssetIcon extends StatelessWidget {
  final String assetPath;
  final Color color;
  final Color backgroundColor;

  const _HeaderAssetIcon({
    required this.assetPath,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Image.asset(
        assetPath,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _HomeMenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _HomeMenuItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

class _CalendarCell {
  final int day;
  final int month;
  final int year;
  final bool isCurrentMonth;

  _CalendarCell({
    required this.day,
    required this.month,
    required this.year,
    required this.isCurrentMonth,
  });
}

class _CalendarBottomSheet extends StatefulWidget {
  const _CalendarBottomSheet();

  @override
  State<_CalendarBottomSheet> createState() => _CalendarBottomSheetState();
}

class _CalendarBottomSheetState extends State<_CalendarBottomSheet> {
  final ApiClient _apiClient = ApiClient();
  final String _activeUserId =
      AuthSession.userId ?? '5b2d488d-75a0-4ea4-8f14-43047d256c8d';

  bool _isLoading = true;
  List<dynamic> _transactions = [];
  final double _grandTotal = 0.0;

  String _obfuscate(double amount) {
    return AppSettings.hideBalances.value ? '***' : amount.toStringAsFixed(0);
  }

  late int _currentYear;
  late int _currentMonth;
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentYear = now.year;
    _currentMonth = now.month;
    _selectedDay = now.day;
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    try {
      final response = await _apiClient.get(
        '/transactions?user_id=eq.$_activeUserId',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _transactions = data;
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

  List<_CalendarCell> _generateCells() {
    List<_CalendarCell> cells = [];
    DateTime firstDay = DateTime(_currentYear, _currentMonth, 1);
    DateTime prevMonthEnd = DateTime(_currentYear, _currentMonth, 0);
    DateTime currentMonthEnd = DateTime(_currentYear, _currentMonth + 1, 0);

    int firstWeekday = firstDay.weekday;
    int startOffset = firstWeekday == 7 ? 0 : firstWeekday;

    int prevMonthDays = prevMonthEnd.day;
    for (int i = startOffset - 1; i >= 0; i--) {
      cells.add(
        _CalendarCell(
          day: prevMonthDays - i,
          month: _currentMonth == 1 ? 12 : _currentMonth - 1,
          year: _currentMonth == 1 ? _currentYear - 1 : _currentYear,
          isCurrentMonth: false,
        ),
      );
    }

    for (int i = 1; i <= currentMonthEnd.day; i++) {
      cells.add(
        _CalendarCell(
          day: i,
          month: _currentMonth,
          year: _currentYear,
          isCurrentMonth: true,
        ),
      );
    }

    int remaining = 42 - cells.length;
    for (int i = 1; i <= remaining; i++) {
      cells.add(
        _CalendarCell(
          day: i,
          month: _currentMonth == 12 ? 1 : _currentMonth + 1,
          year: _currentMonth == 12 ? _currentYear + 1 : _currentYear,
          isCurrentMonth: false,
        ),
      );
    }

    return cells;
  }

  String _getMonthName(int month) {
    const names = [
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
    ];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final cells = _generateCells();
    final thYear = _currentYear + 543;

    final monthlyExpenses = _transactions.where((tx) {
      final dateStr = tx['transaction_date'] ?? '';
      final date = DateTime.tryParse(dateStr);
      return date != null &&
          date.year == _currentYear &&
          date.month == _currentMonth &&
          tx['type'] == 'expense';
    }).toList();

    double monthlyTotal = monthlyExpenses.fold(0.0, (sum, item) {
      return sum + (item['amount'] as num).toDouble();
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F4F1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'ปฏิทินรายจ่าย',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'ดูรายจ่ายแยกตามวัน',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_getMonthName(_currentMonth)} $thYear',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: () {
                            setState(() {
                              if (_currentMonth == 1) {
                                _currentMonth = 12;
                                _currentYear--;
                              } else {
                                _currentMonth--;
                              }
                              _selectedDay = 1;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: () {
                            setState(() {
                              if (_currentMonth == 12) {
                                _currentMonth = 1;
                                _currentYear++;
                              } else {
                                _currentMonth++;
                              }
                              _selectedDay = 1;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    Text(
                      'อา.',
                      style: TextStyle(
                        color: Color(0xFF00A88F),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'จ.',
                      style: TextStyle(
                        color: Color(0xFF00A88F),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'อ.',
                      style: TextStyle(
                        color: Color(0xFF00A88F),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'พ.',
                      style: TextStyle(
                        color: Color(0xFF00A88F),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'พฤ.',
                      style: TextStyle(
                        color: Color(0xFF00A88F),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'ศ.',
                      style: TextStyle(
                        color: Color(0xFF00A88F),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'ส.',
                      style: TextStyle(
                        color: Color(0xFF00A88F),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _isLoading
                    ? const SizedBox(
                        height: 280,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.95,
                            ),
                        itemCount: 42,
                        itemBuilder: (context, index) {
                          final cell = cells[index];
                          final date = DateTime(
                            cell.year,
                            cell.month,
                            cell.day,
                          );

                          double spent = 0.0;
                          for (var tx in _transactions) {
                            final txDateStr = tx['transaction_date'] ?? '';
                            final txDate = DateTime.tryParse(txDateStr);
                            if (txDate != null &&
                                txDate.year == date.year &&
                                txDate.month == date.month &&
                                txDate.day == date.day &&
                                tx['type'] == 'expense') {
                              spent += (tx['amount'] as num).toDouble();
                            }
                          }

                          final isSelected =
                              cell.isCurrentMonth && _selectedDay == cell.day;

                          return GestureDetector(
                            onTap: () {
                              if (cell.isCurrentMonth) {
                                setState(() {
                                  _selectedDay = cell.day;
                                });
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE6F4F1)
                                    : (cell.isCurrentMonth
                                          ? const Color(0xFFF8FAFC)
                                          : Colors.transparent),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : (cell.isCurrentMonth
                                            ? const Color(0xFFF1F5F9)
                                            : Colors.transparent),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${cell.day}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: cell.isCurrentMonth
                                          ? (isSelected
                                                ? AppTheme.primaryColor
                                                : const Color(0xFF1E293B))
                                          : const Color(0xFFCBD5E1),
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (spent > 0) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '฿${_obfuscate(spent)}',
                                      style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'รายการเดือน${_getMonthName(_currentMonth)} $thYear',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Text(
                      'รวม ฿${_obfuscate(monthlyTotal)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: monthlyExpenses.isEmpty
                      ? Center(
                          child: Text(
                            'ไม่มีรายจ่ายในเดือนนี้',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: monthlyExpenses.length,
                          itemBuilder: (context, index) {
                            final tx = monthlyExpenses[index];
                            final amount = (tx['amount'] as num).toDouble();
                            return Card(
                              elevation: 0,
                              color: const Color(0xFFF8FAFC),
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  tx['note'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'หมวดหมู่: ค่าใช้จ่ายรายวัน',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                                trailing: Text(
                                  '-฿${_obfuscate(amount)}',
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF475569),
                        ),
                        children: [
                          const TextSpan(text: 'รายจ่ายรวมทุกวัน: '),
                          TextSpan(
                            text: '฿${_obfuscate(_grandTotal)}',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'ปิดหน้าต่าง',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


class TutorialBackdropPainter extends CustomPainter {
  final Rect? targetRect;
  final double borderRadius;
  final bool isWelcomeStep;

  TutorialBackdropPainter({
    this.targetRect,
    required this.borderRadius,
    required this.isWelcomeStep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.75);
    
    if (isWelcomeStep || targetRect == null || targetRect!.width == 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      return;
    }

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    final maskPaint = Paint()
      ..color = Colors.white
      ..blendMode = BlendMode.clear;
      
    final rrect = RRect.fromRectAndRadius(
      targetRect!.inflate(8),
      Radius.circular(borderRadius + 8),
    );
    canvas.drawRRect(rrect, maskPaint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TutorialBackdropPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect || 
           oldDelegate.borderRadius != borderRadius ||
           oldDelegate.isWelcomeStep != isWelcomeStep;
  }
}
