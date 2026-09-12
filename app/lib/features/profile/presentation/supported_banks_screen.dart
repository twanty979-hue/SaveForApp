import 'package:app/core/localization/app_material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/bank_rule_model.dart';
import '../../../core/services/bank_rules_service.dart';
import '../../../core/services/slip_scanner_bridge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bank_logo_icon.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../transactions/presentation/slip_scan_dialog.dart';

class SupportedBanksScreen extends StatefulWidget {
  const SupportedBanksScreen({super.key});

  @override
  State<SupportedBanksScreen> createState() => _SupportedBanksScreenState();
}

class _SupportedBanksScreenState extends State<SupportedBanksScreen> {

  List<Map<String, dynamic>> _detectedAlbums = [];
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceAlbums();
    BankRulesService.init();
    // Auto-fetch latest rules from Cloud silently without requiring manual button press
    BankRulesService.syncFromCloud().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadDeviceAlbums() async {
    try {
      final albums = await SlipScannerBridge.instance.getAvailableBankAlbums();
      if (mounted) {
        setState(() {
          _detectedAlbums = albums;
        });
      }
    } catch (_) {}
  }

  int _getCountForBank(List<String> keywords) {
    int total = 0;
    bool found = false;
    for (final alb in _detectedAlbums) {
      final title = (alb['title']?.toString() ?? '').toLowerCase();
      final tag = (alb['bankTag']?.toString() ?? '').toLowerCase();
      for (final kw in keywords) {
        final lowerKw = kw.toLowerCase();
        if (title.contains(lowerKw) || tag.contains(lowerKw)) {
          total += (alb['count'] as num?)?.toInt() ?? 0;
          found = true;
          break;
        }
      }
    }
    return found ? total : -1;
  }

  Future<void> _pickAndScanSlip() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) {
        if (mounted) setState(() => _isPickingImage = false);
        return;
      }

      final slip = await SlipScannerBridge.instance.scanSingleImage(picked.path);
      if (!mounted) return;
      setState(() => _isPickingImage = false);

      if (slip != null) {
        SlipScanDialog.show(context, slips: [slip]);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'ไม่พบข้อมูลสลิปในรูปที่เลือกครับ',
                'No supported bank slip detected in this image',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPickingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.pageColor,
      body: Stack(
        children: [
          const Positioned.fill(child: FloatingBackground()),
          SafeArea(
            child: ResponsiveLayout(
              maxWidth: 600,
              child: ValueListenableBuilder<List<BankRuleConfig>>(
                valueListenable: BankRulesService.rulesNotifier,
                builder: (context, rules, _) {
                  final activeCount = rules.where((r) => r.isEnabled).length;
                  final totalCount = rules.length;
                  final isAll = activeCount == totalCount;
                  final isNone = activeCount == 0;

                  return Column(
                    children: [
                      // App Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            Material(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.pop(context),
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 18,
                                    color: context.primaryTextColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('ธนาคารที่รองรับ', 'Supported Banks'),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: context.primaryTextColor,
                                    ),
                                  ),
                                  Text(
                                    context.tr(
                                      'อ่านสลิปอัตโนมัติจากอัลบั้มรูปภาพ',
                                      'Auto-detect slips from photo albums',
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Count Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isNone
                                    ? Colors.grey.withValues(alpha: 0.12)
                                    : AppTheme.primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isNone
                                      ? Colors.grey.withValues(alpha: 0.25)
                                      : AppTheme.primaryColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: isNone ? Colors.grey : AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isNone
                                        ? context.tr('ปิดทั้งหมด', 'All Off')
                                        : (isAll
                                            ? context.tr('$totalCount ธนาคาร', '$totalCount Banks')
                                            : context.tr('$activeCount/$totalCount ธนาคาร', '$activeCount/$totalCount Banks')),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isNone ? Colors.grey : AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content List
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                          children: [
                            // Hero Status Card
                            _buildHeroBanner(context, isDark, rules),
                            const SizedBox(height: 18),

                            // Section 1 Header
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr(
                                          'อ่านอัตโนมัติจากอัลบั้มในเครื่อง',
                                          'Auto-scanned Bank Albums',
                                        ),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: context.primaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        context.tr(
                                          'ติกเปิด-ปิด หรือเอาออกได้ตามต้องการ',
                                          'Tick to include or remove banks',
                                        ),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: context.secondaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () async {
                                    final allEnabled = activeCount == totalCount;
                                    await BankRulesService.toggleAll(!allEnabled);
                                  },
                                  child: Text(
                                    activeCount == totalCount
                                        ? context.tr('ปิดทั้งหมด', 'Turn off all')
                                        : context.tr('เปิดทั้งหมด', 'Turn on all'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Auto Bank Cards (Dynamic from BankRulesService)
                            ...rules.map((rule) {
                              final count = _getCountForBank(rule.albumKeywords);
                              return _buildAutoBankCard(
                                context,
                                rule,
                                count,
                                isDark,
                              );
                            }),

                            const SizedBox(height: 20),

                            // Bottom Action Button
                            SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            icon: _isPickingImage
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add_photo_alternate_rounded, size: 20),
                            label: Text(
                              _isPickingImage
                                  ? context.tr('กำลังอ่านสลิป...', 'Scanning slip...')
                                  : context.tr('นำเข้ารูปสลิปจากอัลบั้ม', 'Pick a slip photo'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: _isPickingImage ? null : _pickAndScanSlip,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context, bool isDark, List<BankRuleConfig> rules) {
    final activeCount = rules.where((r) => r.isEnabled).length;
    final totalCount = rules.length;
    final allOff = activeCount == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ]
              : [
                  const Color(0xFFF8FAFC),
                  const Color(0xFFF1F5F9),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(
                    'สแกนอัตโนมัติจากอัลบั้มรูปภาพ',
                    'Auto-scan from Photo Albums',
                  ),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: context.primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              'เมื่อเปิดแอป ระบบจะตรวจหาภาพสลิปที่บันทึกไว้ในอัลบั้มของธนาคารที่เปิดใช้งานให้อัตโนมัติ สามารถติกเปิดหรือปิดได้อิสระครับ',
              'The app automatically detects slips from enabled bank albums. You can toggle each bank on or off freely.',
            ),
            style: TextStyle(
              fontSize: 12.5,
              color: context.secondaryTextColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Logos row preview
          Row(
            children: [
              ...rules.take(5).map((r) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildHeroLogo(r.bankType, r.isEnabled),
              )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: allOff
                      ? Colors.grey.withValues(alpha: 0.12)
                      : const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      allOff ? Icons.cancel_outlined : Icons.check_circle_rounded,
                      size: 13,
                      color: allOff ? Colors.grey : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      allOff
                          ? context.tr('ปิดอ่านทั้งหมด', 'All Disabled')
                          : context.tr('เปิดอ่าน $activeCount/$totalCount ธนาคาร', 'Active $activeCount/$totalCount'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: allOff ? Colors.grey : const Color(0xFF10B981),
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

  Widget _buildHeroLogo(BankType bank, bool isEnabled) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled ? 1.0 : 0.35,
      child: BankLogoIcon(bank: bank, size: 32, isCircle: true),
    );
  }

  Widget _buildAutoBankCard(
    BuildContext context,
    BankRuleConfig rule,
    int detectedCount,
    bool isDark,
  ) {
    final isEnabled = rule.isEnabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isEnabled
            ? context.surfaceColor
            : (isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.4)
                : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEnabled
              ? context.borderColor
              : context.borderColor.withValues(alpha: 0.5),
        ),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await BankRulesService.toggleBank(rule.id, !isEnabled);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Bank Logo
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isEnabled ? 1.0 : 0.4,
                  child: BankLogoIcon(
                    bank: rule.bankType,
                    size: 44,
                    isCircle: false,
                    showShadow: isEnabled,
                  ),
                ),
                const SizedBox(width: 14),

                // Bank Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.name,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: isEnabled
                              ? context.primaryTextColor
                              : context.secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rule.appName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.secondaryTextColor,
                        ),
                      ),
                      if (detectedCount > 0) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 12,
                              color: isEnabled
                                  ? AppTheme.primaryColor
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.tr(
                                'พบในเครื่อง $detectedCount รูป',
                                '$detectedCount slips on device',
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isEnabled
                                    ? AppTheme.primaryColor
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Switch and Status Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Switch.adaptive(
                      value: isEnabled,
                      activeTrackColor: AppTheme.primaryColor,
                      onChanged: (val) async {
                        await BankRulesService.toggleBank(rule.id, val);
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isEnabled
                            ? context.tr('เปิดอ่าน', 'Active')
                            : context.tr('ปิดอยู่', 'Off'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isEnabled ? const Color(0xFF10B981) : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
