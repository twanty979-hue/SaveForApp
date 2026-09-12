import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/bank_rule_model.dart';
import '../../../core/services/bank_rules_service.dart';
import '../../../core/services/slip_scanner_bridge.dart';
import '../../../core/widgets/bank_logo_icon.dart';
import 'slip_scan_dialog.dart';
import 'no_slips_found_sheet.dart';

/// Modal Sheet สำหรับเลือกช่วงวันที่ต้องการอ่านสลิปย้อนหลังจากอัลบั้ม (สูงสุด 30 วัน)
/// พร้อมปฏิทินที่ออกแบบเข้ากับระบบธีมของ SaveForApp อย่างสมบูรณ์แบบ
class SlipScanDateSheet extends StatefulWidget {
  final VoidCallback? onTransactionsSaved;
  final int initialDaysBack;

  const SlipScanDateSheet({
    super.key,
    this.onTransactionsSaved,
    this.initialDaysBack = 30,
  });

  static const String _prefDaysBackKey = 'pref_slip_scan_selected_days_back';

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onTransactionsSaved,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedDays = prefs.getInt(_prefDaysBackKey) ?? 30;

    if (!context.mounted) return;

    final result = await showModalBottomSheet<List<ParsedSlip>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SlipScanDateSheet(
        onTransactionsSaved: onTransactionsSaved,
        initialDaysBack: savedDays.clamp(1, 30),
      ),
    );

    if (!context.mounted) return;
    if (result == null) return;

    if (result.isNotEmpty) {
      SlipScanDialog.show(
        context,
        slips: result,
        onTransactionsSaved: onTransactionsSaved,
      );
    } else {
      NoSlipsFoundSheet.show(
        context,
        onPickImage: () async {
          final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
          if (picked == null || !context.mounted) return;
          final slip = await SlipScannerBridge.instance.scanSingleImage(picked.path);
          if (!context.mounted) return;
          if (slip != null) {
            SlipScanDialog.show(
              context,
              slips: [slip],
              onTransactionsSaved: onTransactionsSaved,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.tr('ไม่พบข้อมูลสลิปในรูปที่เลือกครับ', 'No slip found in selected image'),
                ),
              ),
            );
          }
        },
      );
    }
  }

  @override
  State<SlipScanDateSheet> createState() => _SlipScanDateSheetState();
}

class _SlipCalendarCell {
  final DateTime date;
  final bool inCurrentMonth;

  const _SlipCalendarCell({
    required this.date,
    required this.inCurrentMonth,
  });
}

class _SlipScanDateSheetState extends State<SlipScanDateSheet> {
  late int _daysBack;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isScanning = false;
  bool _isCalendarExpanded = true;
  late int _calendarYear;
  late int _calendarMonth;


  final List<int> _presetDays = [1, 3, 7, 15, 30];

  @override
  void initState() {
    super.initState();
    _daysBack = widget.initialDaysBack.clamp(1, 30);
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: _daysBack - 1));
    _calendarYear = _startDate.year;
    _calendarMonth = _startDate.month;
  }

  void _selectPreset(int days) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final clamped = days.clamp(1, 30);
    setState(() {
      _daysBack = clamped;
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      _startDate = today.subtract(Duration(days: clamped - 1));
      _calendarYear = _startDate.year;
      _calendarMonth = _startDate.month;
    });
    _persistDaysBack(clamped);
  }

  Future<void> _persistDaysBack(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SlipScanDateSheet._prefDaysBackKey, days);
  }

  void _prevMonth(DateTime minDate) {
    final canPrev = DateTime(_calendarYear, _calendarMonth, 1)
        .isAfter(DateTime(minDate.year, minDate.month, 1));
    if (!canPrev) return;

    HapticFeedback.selectionClick();
    setState(() {
      if (_calendarMonth == 1) {
        _calendarMonth = 12;
        _calendarYear--;
      } else {
        _calendarMonth--;
      }
    });
  }

  void _nextMonth(DateTime today) {
    final canNext = DateTime(_calendarYear, _calendarMonth, 1)
        .isBefore(DateTime(today.year, today.month, 1));
    if (!canNext) return;

    HapticFeedback.selectionClick();
    setState(() {
      if (_calendarMonth == 12) {
        _calendarMonth = 1;
        _calendarYear++;
      } else {
        _calendarMonth++;
      }
    });
  }

  void _onDateCellTapped(DateTime cellDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = today.subtract(const Duration(days: 30));
    final normalized = DateTime(cellDate.year, cellDate.month, cellDate.day);

    if (normalized.isBefore(minDate) || normalized.isAfter(today)) {
      return;
    }

    HapticFeedback.selectionClick();
    final diff = today.difference(normalized).inDays + 1;
    final clampedDays = diff.clamp(1, 30);

    setState(() {
      _startDate = normalized;
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      _daysBack = clampedDays;
    });

    _persistDaysBack(clampedDays);
  }

  List<_SlipCalendarCell> _generateCalendarCells() {
    final firstDay = DateTime(_calendarYear, _calendarMonth, 1);
    final previousMonthEnd = DateTime(_calendarYear, _calendarMonth, 0);
    final currentMonthEnd = DateTime(_calendarYear, _calendarMonth + 1, 0);
    final sundayBasedOffset = firstDay.weekday == 7 ? 0 : firstDay.weekday;
    final cells = <_SlipCalendarCell>[];

    for (var index = sundayBasedOffset - 1; index >= 0; index--) {
      final date = DateTime(
        previousMonthEnd.year,
        previousMonthEnd.month,
        previousMonthEnd.day - index,
      );
      cells.add(_SlipCalendarCell(date: date, inCurrentMonth: false));
    }

    for (var day = 1; day <= currentMonthEnd.day; day++) {
      cells.add(
        _SlipCalendarCell(
          date: DateTime(_calendarYear, _calendarMonth, day),
          inCurrentMonth: true,
        ),
      );
    }

    var nextDay = 1;
    final totalRows = (cells.length / 7).ceil();
    final targetLength = totalRows * 7;
    while (cells.length < targetLength) {
      cells.add(
        _SlipCalendarCell(
          date: DateTime(_calendarYear, _calendarMonth + 1, nextDay++),
          inCurrentMonth: false,
        ),
      );
    }
    return cells;
  }

  Future<void> _startScan() async {
    HapticFeedback.mediumImpact();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final localTr = context.tr(
      'กรุณาเปิดสิทธิ์เข้าถึงรูปภาพเพื่อสแกนสลิปครับ',
      'Please allow photo library access to scan slips',
    );
    setState(() => _isScanning = true);

    try {
      final isSim = await SlipScannerBridge.instance.isSimulator();
      if (!isSim && SlipScannerBridge.instance.isSupported) {
        final permission = await SlipScannerBridge.instance.requestPermission();
        if (permission == 'denied') {
          if (!mounted) return;
          setState(() => _isScanning = false);
          messenger.showSnackBar(
            SnackBar(content: Text(localTr)),
          );
          return;
        }
      }

      final slips = await SlipScannerBridge.instance.scanRecentSlips(
        daysBack: _daysBack,
        startDate: _startDate,
        endDate: _endDate,
        limit: 50,
        forceAll: true,
        albumName: 'ALL_BANKS',
      );

      if (!mounted) return;
      setState(() => _isScanning = false);

      nav.pop(slips); // ปิด BottomSheet และส่งผลลัพธ์กลับไปยัง show() อย่างปลอดภัย
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      messenger.showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการสแกน: $e')),
      );
    }
  }

  Future<void> _resetAndRescan() async {
    final isThai = Localizations.localeOf(context).languageCode == 'th';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isThai ? 'สแกนสลิปใหม่ทั้งหมด' : 'Re-scan All Slips'),
        content: Text(
          isThai
              ? 'ระบบจะล้างประวัติการจำสลิปเดิม เพื่อค้นหาและสแกนสลิปทั้งหมดในช่วงวันที่เลือกใหม่อีกครั้งครับ'
              : 'Reset slip memory and re-scan all slips in the selected date range?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isThai ? 'ยกเลิก' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isThai ? 'เริ่มสแกนใหม่' : 'Re-scan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SlipScannerBridge.instance.clearAllSavedSlipKeys();
      if (!mounted) return;
      _startScan();
    }
  }

  String _formatDisplayDate(DateTime d, bool isThai) {
    if (isThai) {
      const thaiMonths = [
        '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
        'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
      ];
      final dayStr = d.day.toString().padLeft(2, '0');
      final monthStr = thaiMonths[d.month];
      final yearStr = (d.year + 543).toString();
      return '$dayStr $monthStr $yearStr';
    } else {
      const enMonths = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final dayStr = d.day.toString().padLeft(2, '0');
      final monthStr = enMonths[d.month];
      return '$dayStr $monthStr ${d.year}';
    }
  }

  String _monthNameTh(int month) => const [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
  ][month - 1];

  String _monthNameEn(int month) => const [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ][month - 1];

  @override
  Widget build(BuildContext context) {
    final isThai = Localizations.localeOf(context).languageCode == 'th';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = today.subtract(const Duration(days: 30));
    final cells = _generateCalendarCells();

    final canGoPrev = DateTime(_calendarYear, _calendarMonth, 1)
        .isAfter(DateTime(minDate.year, minDate.month, 1));
    final canGoNext = DateTime(_calendarYear, _calendarMonth, 1)
        .isBefore(DateTime(today.year, today.month, 1));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFBF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 32,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header with App Theme Logo
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE8E0D2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    'assets/images/logo_blue.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.document_scanner_rounded,
                      color: AppTheme.primaryColor,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('สแกนสลิปจากอัลบั้ม', 'Scan Slips from Album'),
                        style: const TextStyle(
                          fontFamily: 'SukhumvitSet',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          'เลือกวันย้อนหลัง (สูงสุด 30 วัน)',
                          'Select date range (max 30 days)',
                        ),
                        style: TextStyle(
                          fontFamily: 'SukhumvitSet',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  tooltip: isThai ? 'รีเซ็ตและสแกนใหม่ทั้งหมด' : 'Reset and re-scan all',
                  onPressed: _isScanning ? null : _resetAndRescan,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.restart_alt_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Quick preset chips
            Row(
              children: _presetDays.map((days) {
                final isSelected = _daysBack == days;
                final label = days == 1
                    ? (isThai ? 'วันนี้' : 'Today')
                    : '$days ${isThai ? 'วัน' : 'days'}';
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectPreset(days),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontFamily: 'SukhumvitSet',
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // Embedded Custom Calendar Card (SaveForApp Luxury Theme)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8E0D2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Range info summary header (Tap to collapse/expand)
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isCalendarExpanded = !_isCalendarExpanded);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              Icons.calendar_month_rounded,
                              color: AppTheme.primaryColor,
                              size: 21,
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
                                      isThai ? 'ช่วงที่สแกนสลิป' : 'Scan window',
                                      style: TextStyle(
                                        fontFamily: 'SukhumvitSet',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${isThai ? 'ย้อนหลัง' : 'Back'} $_daysBack ${isThai ? 'วัน' : 'days'}',
                                        style: const TextStyle(
                                          fontFamily: 'SukhumvitSet',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_formatDisplayDate(_startDate, isThai)}  ➔  ${_formatDisplayDate(now, isThai)}',
                                  style: const TextStyle(
                                    fontFamily: 'SukhumvitSet',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _isCalendarExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF64748B),
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Calendar body
                  if (_isCalendarExpanded) ...[
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        children: [
                          // Month Navigator
                          Row(
                            children: [
                              InkWell(
                                onTap: canGoPrev ? () => _prevMonth(minDate) : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: canGoPrev ? const Color(0xFFF8FAFC) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: canGoPrev ? const Color(0xFFE2E8F0) : Colors.transparent,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.chevron_left_rounded,
                                    size: 20,
                                    color: canGoPrev ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    isThai
                                        ? '${_monthNameTh(_calendarMonth)} ${_calendarYear + 543}'
                                        : '${_monthNameEn(_calendarMonth)} $_calendarYear',
                                    style: const TextStyle(
                                      fontFamily: 'SukhumvitSet',
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: canGoNext ? () => _nextMonth(today) : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: canGoNext ? const Color(0xFFF8FAFC) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: canGoNext ? const Color(0xFFE2E8F0) : Colors.transparent,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: canGoNext ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Weekdays header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                            child: Row(
                              children: (isThai
                                      ? const ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส']
                                      : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
                                  .map(
                                    (day) => Expanded(
                                      child: Center(
                                        child: Text(
                                          day,
                                          style: const TextStyle(
                                            fontFamily: 'SukhumvitSet',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // Month Grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: cells.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 5,
                              crossAxisSpacing: 5,
                              childAspectRatio: 1.15,
                            ),
                            itemBuilder: (context, index) {
                              return _buildCalendarCell(
                                cell: cells[index],
                                today: today,
                                minDate: minDate,
                                isThai: isThai,
                              );
                            },
                          ),

                          const SizedBox(height: 10),

                          // Calendar Legend
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildLegendItem(
                                  color: AppTheme.primaryColor,
                                  label: isThai ? 'วันเริ่มต้น' : 'Start',
                                  isSolid: true,
                                ),
                                _buildLegendItem(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.18),
                                  borderColor: AppTheme.primaryColor.withValues(alpha: 0.35),
                                  label: isThai ? 'ช่วงที่สแกน ($_daysBack วัน)' : 'Scan Range',
                                  isSolid: false,
                                ),
                                _buildLegendItem(
                                  color: AppTheme.primaryColor,
                                  label: isThai ? 'วันนี้' : 'Today',
                                  isDot: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Supported Bank tags row (with official bank logo icons)
            ValueListenableBuilder<List<BankRuleConfig>>(
              valueListenable: BankRulesService.rulesNotifier,
              builder: (context, rules, _) {
                final displayRules = rules.isNotEmpty ? rules : BankRuleConfig.defaultRules;
                final count = displayRules.length;

                return Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4.5,
                  runSpacing: 4,
                  children: [
                    Text(
                      context.tr('รองรับอัลบั้ม $count ธนาคาร:', 'Supports $count bank albums:'),
                      style: TextStyle(
                        fontFamily: 'SukhumvitSet',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    ...displayRules.map((r) => _buildBankLogoChip(r)),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Scan Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isScanning ? null : _startScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: _isScanning
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.tr('กำลังค้นหาสลิปในเครื่อง...', 'Searching slips in photo library...'),
                            style: const TextStyle(
                              fontFamily: 'SukhumvitSet',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${context.tr('เริ่มสแกนสลิป', 'Start Scanning')} (ย้อนหลัง $_daysBack วัน)',
                            style: const TextStyle(
                              fontFamily: 'SukhumvitSet',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),


          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCell({
    required _SlipCalendarCell cell,
    required DateTime today,
    required DateTime minDate,
    required bool isThai,
  }) {
    final date = DateTime(cell.date.year, cell.date.month, cell.date.day);
    final isSelectable = !date.isBefore(minDate) && !date.isAfter(today);
    final isStart = isSelectable &&
        date.year == _startDate.year &&
        date.month == _startDate.month &&
        date.day == _startDate.day;
    final isToday = isSelectable &&
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isInRange = isSelectable &&
        !date.isBefore(_startDate) &&
        !date.isAfter(today);

    if (!cell.inCurrentMonth && !isSelectable) {
      return const SizedBox.shrink();
    }

    Color bgColor = Colors.transparent;
    Border? border;
    Color textColor = const Color(0xFF1E293B);
    FontWeight fontWeight = FontWeight.w600;
    List<BoxShadow>? shadow;

    if (!isSelectable) {
      textColor = const Color(0xFFCBD5E1);
      fontWeight = FontWeight.w400;
    } else if (isStart) {
      bgColor = AppTheme.primaryColor;
      textColor = Colors.white;
      fontWeight = FontWeight.w800;
      shadow = [
        BoxShadow(
          color: AppTheme.primaryColor.withValues(alpha: 0.35),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isInRange) {
      bgColor = AppTheme.primaryColor.withValues(alpha: 0.12);
      border = Border.all(
        color: AppTheme.primaryColor.withValues(alpha: 0.28),
        width: 1.0,
      );
      textColor = AppTheme.primaryColor;
      fontWeight = FontWeight.w700;
    } else {
      bgColor = Colors.white;
      border = Border.all(color: const Color(0xFFE2E8F0));
      textColor = cell.inCurrentMonth ? const Color(0xFF1E293B) : const Color(0xFF94A3B8);
    }

    return InkWell(
      onTap: isSelectable ? () => _onDateCellTapped(date) : null,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: border,
          boxShadow: shadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontFamily: 'SukhumvitSet',
                fontSize: 12.5,
                fontWeight: fontWeight,
                color: textColor,
              ),
            ),
            if (isStart)
              Text(
                isThai ? 'เริ่ม' : 'Start',
                style: const TextStyle(
                  fontFamily: 'SukhumvitSet',
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              )
            else if (isToday)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isStart ? Colors.white : AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    Color? borderColor,
    bool isSolid = false,
    bool isDot = false,
  }) {
    Widget indicator;
    if (isDot) {
      indicator = Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    } else {
      indicator = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: borderColor != null ? Border.all(color: borderColor, width: 1) : null,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'SukhumvitSet',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  String _getBankShortName(BankRuleConfig rule) {
    switch (rule.bankType) {
      case BankType.kbank:
        return 'K PLUS';
      case BankType.scb:
        return 'SCB';
      case BankType.krungsri:
        return 'กรุงศรี';
      case BankType.truemoney:
        return 'TrueMoney';
      case BankType.ktb:
        return 'กรุงไทย';
      default:
        return rule.name;
    }
  }

  Widget _buildBankLogoChip(BankRuleConfig rule) {
    final color = rule.colorHex != null
        ? Color(int.parse(rule.colorHex!.replaceFirst('#', '0xFF')))
        : AppTheme.primaryColor;
    final shortName = _getBankShortName(rule);

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 6, 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BankLogoIcon(
            bank: rule.bankType,
            size: 14,
            isCircle: true,
            showShadow: false,
            showBorder: false,
          ),
          const SizedBox(width: 4),
          Text(
            shortName,
            style: TextStyle(
              fontFamily: 'SukhumvitSet',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

