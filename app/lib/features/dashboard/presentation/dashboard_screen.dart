import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:app/core/localization/app_material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../auth/domain/auth_session.dart';
import '../../profile/presentation/profile_settings_screen.dart';
import '../../planning/presentation/planning_hub_screen.dart';
import '../../transactions/presentation/transactions_screen.dart';
import 'notification_inbox_sheet.dart';
import 'compact_calendar_sheet.dart';
import 'finance_dashboard_screen.dart';
import 'package:app/icon_selector_demo.dart';
import 'package:app/core/settings/app_settings.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_apiClient.preloadCoreData(_activeUserId));
    _fetchHeaderTotals();
    _fetchHeaderAvatar();
    NotificationService.instance.registerDevice();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndForceMonthlyExpense();
    });
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
        return const CompactCalendarSheet();
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
                  child: TransactionsScreen(topPadding: 86, inputKey: _inputKey),
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
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF16BFA5),
                                    AppTheme.primaryColor,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _avatarUrl?.isNotEmpty == true
                                  ? Image.network(
                                      _avatarUrl!,
                                      fit: BoxFit.cover,
                                      headers: _apiClient.imageHeaders(
                                        _avatarUrl!,
                                      ),
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.person_outline_rounded,
                                        color: Colors.white,
                                        size: 21,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_outline_rounded,
                                      color: Colors.white,
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
                                    '${context.tr('วันนี้', 'Today')} ฿${_todaySpent.toStringAsFixed(0)}',
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
                                      '${context.tr('เดือนนี้', 'This month')} ฿${_monthSpent.toStringAsFixed(0)}',
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
      ],
      ),
    );
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
        }
      }
    } catch (e) {
      debugPrint('Error checking monthly expense: $e');
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
                                      '฿${spent.toStringAsFixed(0)}',
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
                      'รวม ฿${monthlyTotal.toStringAsFixed(0)}',
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
                                  '-฿${amount.toStringAsFixed(0)}',
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
                            text: '฿${_grandTotal.toStringAsFixed(0)}',
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
  final ShapeBorder shape;

  TutorialBackdropPainter({this.targetRect, this.shape = const CircleBorder()});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.75);
    
    if (targetRect == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      return;
    }

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    final maskPaint = Paint()
      ..color = Colors.white
      ..blendMode = BlendMode.clear;
      
    if (shape is CircleBorder) {
      final center = targetRect!.center;
      final radius = math.max(targetRect!.width, targetRect!.height) / 2.0;
      canvas.drawCircle(center, radius + 8, maskPaint);
    } else {
      final rrect = RRect.fromRectAndRadius(
        targetRect!.inflate(8),
        const Radius.circular(16),
      );
      canvas.drawRRect(rrect, maskPaint);
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TutorialBackdropPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect || oldDelegate.shape != shape;
  }
}
