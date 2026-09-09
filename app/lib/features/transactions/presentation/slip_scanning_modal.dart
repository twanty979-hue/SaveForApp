import 'dart:math' as math;
import 'package:app/core/localization/app_material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/slip_scanner_bridge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bank_logo_icon.dart';
import 'slip_scan_dialog.dart';

enum ScanPhase {
  connecting,
  scanning,
  completed,
  error,
}

class SlipScanningModal extends StatefulWidget {
  final VoidCallback? onTransactionsSaved;

  const SlipScanningModal({
    super.key,
    this.onTransactionsSaved,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onTransactionsSaved,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SlipScanningModal(
          onTransactionsSaved: onTransactionsSaved,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<SlipScanningModal> createState() => _SlipScanningModalState();
}

class _SlipScanningModalState extends State<SlipScanningModal>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _beamController;
  late AnimationController _countController;
  late Animation<double> _countAnimation;

  ScanPhase _phase = ScanPhase.connecting;
  List<ParsedSlip> _detectedSlips = [];
  String _statusMessage = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _countController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _countAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _countController, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanningProcess();
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _beamController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _startScanningProcess() async {
    if (!mounted) return;
    setState(() {
      _phase = ScanPhase.connecting;
      _statusMessage = context.tr(
        'กำลังเชื่อมต่อคลังรูปภาพ...',
        'Connecting to photo library...',
      );
    });

    await Future<void>.delayed(const Duration(milliseconds: 400));

    // ขอสิทธิ์ Photo จริง (ใช้งานระบบสแกนจริง 100%)
    final permission = await SlipScannerBridge.instance.requestPermission();
    if (!mounted) return;

    if (permission == 'denied') {
      setState(() {
        _phase = ScanPhase.error;
        _errorMessage = context.tr(
          'กรุณาเปิดสิทธิ์เข้าถึงรูปภาพในการตั้งค่าโทรศัพท์ เพื่อให้อ่านสลิปอัตโนมัติได้ครับ',
          'Please grant photo permission in Device Settings to scan slips automatically.',
        );
      });
      return;
    }

    setState(() {
      _phase = ScanPhase.scanning;
      _statusMessage = context.tr(
        'กำลังสแกนสลิปจากทุกธนาคารในคลังภาพ...',
        'Scanning slips from all banks in photo library...',
      );
    });

    try {
      final slips = await SlipScannerBridge.instance.scanRecentSlips(
        daysBack: 0,
        limit: 50,
        forceAll: true,
        albumName: 'ALL_BANKS',
      );

      if (!mounted) return;

      setState(() {
        _detectedSlips = slips;
        _phase = ScanPhase.completed;
        _countAnimation = Tween<double>(
          begin: 0,
          end: slips.length.toDouble(),
        ).animate(
          CurvedAnimation(parent: _countController, curve: Curves.easeOutBack),
        );
      });

      _countController.forward(from: 0);

      if (slips.isNotEmpty) {
        // รอให้ผู้ใช้ชม animation สัก 1.2 วินาที แล้วเปิดหน้าสรุปสลิป
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;
        Navigator.of(context).pop();
        SlipScanDialog.show(
          context,
          slips: slips,
          onTransactionsSaved: widget.onTransactionsSaved,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = ScanPhase.error;
        _errorMessage = context.tr(
          'เกิดข้อผิดพลาดในการสแกน: $e',
          'Scan error occurred: $e',
        );
      });
    }
  }

  Future<void> _pickSingleImageFallback() async {
    Navigator.of(context).pop();
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      final slip = await SlipScannerBridge.instance.scanSingleImage(picked.path);
      if (!mounted) return;

      if (slip != null) {
        SlipScanDialog.show(
          context,
          slips: [slip],
          onTransactionsSaved: widget.onTransactionsSaved,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'ไม่พบข้อมูลสลิปในรูปภาพนี้',
                'No slip detected in this image',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking single slip: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryColor;
    final secondary = AppTheme.secondaryColor;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: math.min(MediaQuery.of(context).size.width * 0.88, 380),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D2D) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: primary.withValues(alpha: 0.18),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.18),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // หัวเรื่องด้านบน
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: secondary.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          color: primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.tr('สแกนสลิปธนาคาร', 'Bank Slip Scanner'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.primaryTextColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [

                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ศูนย์กลางอนิเมชั่น Radar + Scanner Beam
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // คลื่นเรดาร์ Pulse Waves
                    AnimatedBuilder(
                      animation: _radarController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(180, 180),
                          painter: _RadarPulsePainter(
                            progress: _radarController.value,
                            color: primary,
                            isActive: _phase == ScanPhase.scanning ||
                                _phase == ScanPhase.connecting,
                          ),
                        );
                      },
                    ),

                    // กล่องไอคอนสลิปตรงกลาง
                    Container(
                      width: 84,
                      height: 104,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primary.withValues(alpha: 0.12),
                            secondary.withValues(alpha: 0.35),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.4),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_phase == ScanPhase.completed && _detectedSlips.isNotEmpty)
                            BankLogoIcon(
                              bank: _detectedSlips.first.bank,
                              size: 48,
                              showShadow: true,
                            )
                          else
                            Icon(
                              _phase == ScanPhase.completed
                                  ? Icons.receipt_outlined
                                  : Icons.receipt_rounded,
                              size: 46,
                              color: primary,
                            ),

                          // เส้นเลเซอร์วิ่งขึ้น-ลง (Laser Scanning Beam)
                          if (_phase == ScanPhase.scanning ||
                              _phase == ScanPhase.connecting)
                            AnimatedBuilder(
                              animation: _beamController,
                              builder: (context, child) {
                                return Positioned(
                                  top: 10 + (_beamController.value * 76),
                                  left: 6,
                                  right: 6,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E5FF),
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00E5FF)
                                              .withValues(alpha: 0.9),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                        BoxShadow(
                                          color: primary.withValues(alpha: 0.8),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                          // วงกลมไอคอนความสำเร็จเมื่อตรวจพบ
                          if (_phase == ScanPhase.completed &&
                              _detectedSlips.isNotEmpty)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ข้อความและตัวเลขสถานะ
              if (_phase == ScanPhase.connecting ||
                  _phase == ScanPhase.scanning) ...[
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'สแกนจากอัลบั้มธนาคารและคลังภาพโดยตรง',
                    'Scanning from bank albums and photo library directly',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ] else if (_phase == ScanPhase.completed) ...[
                if (_detectedSlips.isNotEmpty) ...[
                  AnimatedBuilder(
                    animation: _countAnimation,
                    builder: (context, child) {
                      final count = _countAnimation.value.toInt();
                      return Text(
                        context.tr(
                          'ตรวจพบ $count สลิปใหม่!',
                          'Found $count new slips!',
                        ),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: primary,
                          letterSpacing: -0.3,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'กำลังเปิดหน้ารายการให้ตรวจสอบและบันทึก...',
                      'Opening summary to review & save...',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ] else ...[
                  Text(
                    context.tr(
                      'ไม่พบสลิปธนาคารใหม่',
                      'No new bank slips found',
                    ),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'ไม่มีสลิปใหม่ในช่วง 30 วัน หรือรายการถูกบันทึกไปแล้ว',
                      'No unrecorded slips found in the past 30 days',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 20),


                  const SizedBox(height: 8),
                  // ปุ่มเลือกภาพทดสอบเอง
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickSingleImageFallback,
                      icon: Icon(Icons.photo_library_outlined, size: 16, color: primary),
                      label: Text(
                        context.tr('เลือกรูปสลิปจากอัลบั้มเอง', 'Pick slip manually'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primary.withValues(alpha: 0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      ),
                    ),
                  ),
                ],
              ] else if (_phase == ScanPhase.error) ...[
                Text(
                  context.tr('เกิดข้อผิดพลาด', 'Notice'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(context.tr('เข้าใจแล้ว', 'OK')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomPainter วาดวงแหวนคลื่นเรดาร์ Pulse 3 วง
class _RadarPulsePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isActive;

  _RadarPulsePainter({
    required this.progress,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // วาด 3 วงแหวน โดยกระจาย phase
    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + (i * 0.33)) % 1.0;
      final radius = 46.0 + (ringProgress * (maxRadius - 46.0));
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0) * 0.45;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 - (ringProgress * 1.2);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isActive != isActive;
  }
}
