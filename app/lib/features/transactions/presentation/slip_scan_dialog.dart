import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/core/localization/app_material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/slip_scanner_bridge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bank_logo_icon.dart';
import '../../auth/domain/auth_session.dart';
import 'slip_scan_date_sheet.dart';

class SlipScanDialog extends StatefulWidget {
  final List<ParsedSlip> slips;
  final VoidCallback? onTransactionsSaved;

  const SlipScanDialog({
    super.key,
    required this.slips,
    this.onTransactionsSaved,
  });

  /// แสดงผลเป็นการ์ดสลิปธนาคารทรงสี่เหลี่ยมกะทัดรัด ลอย 3D กลางจอ สไตล์การ์ตูน
  static Future<void> show(
    BuildContext context, {
    required List<ParsedSlip> slips,
    VoidCallback? onTransactionsSaved,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.60),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SlipScanDialog(
          slips: slips,
          onTransactionsSaved: onTransactionsSaved,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<SlipScanDialog> createState() => _SlipScanDialogState();
}

class _SlipScanDialogState extends State<SlipScanDialog>
    with TickerProviderStateMixin {
  late List<ParsedSlip> _slips;
  bool _isSaving = false;
  final ApiClient _apiClient = ApiClient();

  late PageController _pageController;
  int _currentIndex = 0;

  // Animation controller สำหรับสร้างเอฟเฟกต์การ์ดลอยดุ๊กดิ๊ก (Floating Bobbing)
  AnimationController? _floatController;
  Animation<double>? _floatAnimation;

  // Animation controller สำหรับลำแสงเลเซอร์สแกน (Laser Beam Scanner)
  late AnimationController _beamController;
  late Animation<double> _beamAnimation;

  // สถานะการนับสลิปทีละใบระหว่างสแกน
  bool _isScanning = true;
  int _scannedCount = 1;

  void _initAnimation() {
    if (_floatController != null) return;
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _floatController!, curve: Curves.easeInOutSine),
    );

    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    _beamAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _beamController, curve: Curves.easeInOut),
    );
  }

  void _startScanningSequence() async {
    if (_slips.isEmpty) {
      if (mounted) setState(() => _isScanning = false);
      return;
    }

    final summaryIndex = _slips.length;

    if (_slips.length == 1) {
      if (mounted) {
        setState(() {
          _isScanning = true;
          _scannedCount = 1;
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted || !_isScanning) return;

      // เลื่อนไปใบสุดท้าย (ใบสรุปยอดรวม)
      if (_pageController.hasClients && _pageController.positions.length == 1) {
        _pageController.animateToPage(
          summaryIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
      setState(() {
        _currentIndex = summaryIndex;
        _isScanning = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isScanning = true;
        _scannedCount = 1;
        _currentIndex = 0;
      });
    }

    // หยุดดูใบแรก 400ms
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted || !_isScanning) return;

    // เลื่อนเปลี่ยนการ์ดทีละใบ พร้อมนับตัวเลขตามที่นายสั่ง
    for (int i = 1; i < _slips.length; i++) {
      if (!mounted || !_isScanning) return;

      if (_pageController.hasClients && _pageController.positions.length == 1) {
        _pageController.animateToPage(
          i,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
        );
      }

      setState(() {
        _currentIndex = i;
        _scannedCount = i + 1;
      });

      await Future<void>.delayed(const Duration(milliseconds: 320));
    }

    if (!mounted || !_isScanning) return;

    // ค้างแสดงผลสลิปใบสุดท้ายก่อนหน้าเล็กน้อย 300ms
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || !_isScanning) return;

    // พอสแกนเสร็จ เลื่อนไปยัง "ใบสุดท้าย (ใบสรุปยอดรวมทั้งหมด)" อัตโนมัติทันที
    if (_pageController.hasClients && _pageController.positions.length == 1) {
      _pageController.animateToPage(
        summaryIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }

    setState(() {
      _currentIndex = summaryIndex;
      _isScanning = false;
      _scannedCount = _slips.length;
    });
  }

  void _skipScanning() {
    if (!_isScanning) return;
    final summaryIndex = _slips.length;
    if (_pageController.hasClients && _pageController.positions.length == 1) {
      _pageController.jumpToPage(summaryIndex);
    }
    setState(() {
      _currentIndex = summaryIndex;
      _isScanning = false;
      _scannedCount = _slips.length;
    });
  }



  Future<void> _pickSingleSlip() async {
    HapticFeedback.lightImpact();
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      final parsed = await SlipScannerBridge.instance.scanSingleImage(picked.path);
      if (!mounted) return;
      if (parsed != null) {
        setState(() {
          _slips.insert(0, parsed);
          _currentIndex = 0;
        });
        try {
          if (_pageController.hasClients && _pageController.positions.length == 1) {
            _pageController.jumpToPage(0);
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              context.tr('เพิ่มสลิปจากรูปภาพสำเร็จ!', 'Slip added from image!'),
            ),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              context.tr('ไม่พบข้อมูลสลิปในรูปที่เลือกครับ', 'No slip found in selected image'),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking slip image: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _slips = widget.slips;
    _pageController = PageController(
      viewportFraction: 0.72,
      initialPage: 0,
    );
    _initAnimation();
    _startScanningSequence();

    final userId = AuthSession.userId;
    if (userId != null) {
      SlipScannerBridge.instance.syncSavedSlipsFromServer(
        userId: userId,
        apiClient: _apiClient,
      );
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    try {
      _pageController.dispose();
    } catch (_) {}
    _pageController = PageController(
      viewportFraction: 0.72,
      initialPage: _currentIndex,
    );
  }

  @override
  void dispose() {
    _beamController.dispose();
    try {
      _pageController.dispose();
    } catch (_) {}
    _floatController?.dispose();
    super.dispose();
  }

  double get _totalSelectedAmount {
    return _slips
        .where((s) => s.isSelected)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  int get _selectedCount {
    return _slips.where((s) => s.isSelected).length;
  }


  Future<void> _saveSelectedTransactions() async {
    final selected = _slips.where((s) => s.isSelected).toList();
    if (selected.isEmpty) return;

    final userId = AuthSession.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('กรุณาเข้าสู่ระบบก่อนบันทึกรายการ', 'Please login first'),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    int savedSuccessCount = 0;
    final List<ParsedSlip> successfulSlips = [];

    for (final slip in selected) {
      try {
        final isTransfer = slip.isTransfer;
        final titleText = slip.finalFormattedNoteTitle;
        final refTag = (slip.referenceNo != null && slip.referenceNo!.trim().isNotEmpty)
            ? ' [Ref:${slip.referenceNo!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}]'
            : '';
        final note = isTransfer
            ? '[ย้ายเงิน] $titleText$refTag'
            : '[สลิป ${slip.bank.displayName}] $titleText$refTag';
        final cleanRef = (slip.referenceNo != null && slip.referenceNo!.trim().isNotEmpty)
            ? slip.referenceNo!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
            : null;
        final bodyWithNormalized = {
          'user_id': userId,
          'amount': slip.amount,
          'type': isTransfer ? 'transfer' : 'expense',
          'note': note,
          'bank': slip.bank.name,
          if (isTransfer && slip.destinationBank != null) 'destination_bank': slip.destinationBank!.name,
          if (cleanRef != null) 'reference_no': cleanRef,
          'source': isTransfer ? 'transfer' : 'slip',
          'transaction_date': slip.date.toUtc().toIso8601String(),
          'metadata': {
            if (slip.recipient.isNotEmpty) 'recipient': slip.recipient,
            'bank_display': slip.bank.displayName,
            if (isTransfer && slip.destinationBank != null) 'destination_bank_display': slip.destinationBank!.displayName,
            if (isTransfer) 'transfer_type': 'own_account',
            if (slip.imagePath != null && slip.imagePath!.isNotEmpty) 'image_path': slip.imagePath,
            'asset_id': slip.id,
            if (slip.albumName != null && slip.albumName!.isNotEmpty) 'album_name': slip.albumName,
          },
        };

        var response = await _apiClient.post('/transactions', body: bodyWithNormalized);
        // Fallback gracefully if database constraint or schema does not accept 'transfer' type
        if (response.statusCode >= 400) {
          debugPrint('Slip save initial attempt failed (${response.statusCode}): ${response.body}');
          final fallbackBody = Map<String, dynamic>.from(bodyWithNormalized);
          // If check constraint failed on type = 'transfer', save with type = 'expense' and source = 'transfer'
          if (isTransfer) {
            fallbackBody['type'] = 'expense';
            fallbackBody['source'] = 'transfer';
            fallbackBody['note'] = note.startsWith('[ย้ายเงิน') ? note : '[ย้ายเงิน] $note';
            response = await _apiClient.post('/transactions', body: fallbackBody);
          }
          if (response.statusCode >= 400 && response.body.contains('column')) {
            fallbackBody.remove('destination_bank');
            response = await _apiClient.post('/transactions', body: fallbackBody);
            if (response.statusCode >= 400 && response.body.contains('column')) {
              response = await _apiClient.post(
                '/transactions',
                body: {
                  'user_id': userId,
                  'amount': slip.amount,
                  'type': isTransfer ? 'expense' : 'expense',
                  'note': isTransfer && !note.startsWith('[ย้ายเงิน') ? '[ย้ายเงิน] $note' : note,
                  'transaction_date': slip.date.toUtc().toIso8601String(),
                },
              );
            }
          }
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          savedSuccessCount++;
          successfulSlips.add(slip);
          if (isTransfer) {
            SlipParserService.learnOwnAccount(
              name: slip.recipient,
              accountNumber: slip.recipientAccount,
            );
            if (slip.sender != null && slip.sender!.isNotEmpty) {
              SlipParserService.learnOwnAccount(
                name: slip.sender,
                accountNumber: slip.senderAccount,
              );
            }
          } else {
            // Self-healing: หากผู้ใช้บันทึกเป็นรายจ่าย ป้องกันไม่ให้ระบบเข้าใจผิดว่าเป็นบัญชีตนเองในอนาคต
            SlipParserService.forgetOwnAccount(
              name: slip.recipient,
              accountNumber: slip.recipientAccount,
            );
          }
        } else {
          debugPrint('Slip save failed: status=${response.statusCode}, body=${response.body}');
        }
      } catch (e) {
        debugPrint('Error saving slip transaction: $e');
      }
    }

    if (successfulSlips.isNotEmpty) {
      await SlipScannerBridge.instance.markSlipsAsSaved(successfulSlips);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop();

    if (savedSuccessCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(
                    'ไม่สามารถบันทึกรายการได้ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่ครับ',
                    'Could not save slips. Please check connection and try again.',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                context.tr(
                  'บันทึกสลิปสำเร็จ $savedSuccessCount รายการเรียบร้อยครับ!',
                  'Successfully saved $savedSuccessCount slips!',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    widget.onTransactionsSaved?.call();
  }
  // โทนสี Gradient ประจำแต่ละธนาคาร (โทนสีสว่าง ละมุนตา ไม่เข้มทึบ สบายตา)
  List<Color> _getBankGradient(BankType bank) {
    switch (bank) {
      case BankType.kbank:
        // กสิกรไทย (K PLUS): สีเขียวสว่างนุ่มนวล พาสเทลมรกต จางลงสบายตา ไม่เข้มทึบ
        return const [
          Color(0xFF269D64),
          Color(0xFF38B97C),
          Color(0xFF6EDFA8),
        ];
      case BankType.scb:
        // ไทยพาณิชย์ (SCB EASY): ม่วงสว่างพาสเทล ละมุนตา
        return const [
          Color(0xFF7346C9),
          Color(0xFF8F5FE0),
          Color(0xFFB188F3),
        ];
      case BankType.krungsri:
        // กรุงศรี (Krungsri): เหลืองทองสว่างละมุน
        return const [
          Color(0xFFD4A325),
          Color(0xFFE5B53C),
          Color(0xFFF7D472),
        ];
      case BankType.truemoney:
        // ทรูมันนี่ (TrueMoney): ส้มสว่างละมุนสดใส
        return const [
          Color(0xFFF07038),
          Color(0xFFFA8752),
          Color(0xFFFFB085),
        ];
      case BankType.ktb:
        // กรุงไทย (KTB NEXT): ฟ้าสว่างละมุน
        return const [
          Color(0xFF0EA5E9),
          Color(0xFF38BDF8),
          Color(0xFF7DD3FC),
        ];
      case BankType.bbl:
        // กรุงเทพ (BBL): น้ำเงินสว่างสดใส
        return const [
          Color(0xFF3B82F6),
          Color(0xFF60A5FA),
          Color(0xFF93C5FD),
        ];
      case BankType.ttb:
        // ทีทีบี (ttb): น้ำเงินสว่างสดใส
        return const [
          Color(0xFF2563EB),
          Color(0xFF3B82F6),
          Color(0xFF60A5FA),
        ];
      case BankType.gsb:
        // ออมสิน (GSB): ชมพูสว่างสดใส
        return const [
          Color(0xFFDB2777),
          Color(0xFFF43F5E),
          Color(0xFFFB7185),
        ];
      case BankType.other:
        return const [
          Color(0xFF269D64),
          Color(0xFF38B97C),
          Color(0xFF6EDFA8),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.currentPalette;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = math.min(screenWidth * 0.78, 295.0);
    const cardHeight = 315.0;
    final bool isSummaryPage = _currentIndex == _slips.length;
    final currentSlip = _slips[_currentIndex.clamp(0, _slips.length - 1)];
    final gradientColors = isSummaryPage
        ? [palette.primary, palette.strong]
        : _getBankGradient(currentSlip.bank);
    final anim = _floatAnimation ?? const AlwaysStoppedAnimation(0.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              // แถบเครื่องมือด้านบน: ล้างประวัติ & สแกนใหม่, เลือกภาพเดี่ยว, ปุ่มปิด
              SizedBox(
                width: cardWidth + 30,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [

                        Tooltip(
                          message: context.tr('เลือกรูปสลิปจากเครื่อง', 'Pick slip from photos'),
                          child: GestureDetector(
                            onTap: _isScanning ? null : _pickSingleSlip,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE4DAC7),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.photo_library_outlined,
                                size: 16,
                                color: Color(0xFF3F3624),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: context.tr('เลือกช่วงวันย้อนหลัง (สูงสุด 30 วัน)', 'Select date range (max 30 days)'),
                          child: GestureDetector(
                            onTap: _isScanning
                                ? null
                                : () {
                                    final navContext = context;
                                    Navigator.of(navContext).pop();
                                    SlipScanDateSheet.show(
                                      navContext,
                                      onTransactionsSaved: widget.onTransactionsSaved,
                                    );
                                  },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE4DAC7),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.calendar_month_rounded,
                                size: 16,
                                color: Color(0xFF3F3624),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Tooltip(
                      message: context.tr('ปิด', 'Close'),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE4DAC7),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF3F3624),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 2. CoverFlow Carousel: ใบซ้าย-ขวาจะย่อขนาดเล็กลง (Scale down) ลอยสวยงาม
              // ใบสุดท้ายคือ ใบสรุปยอดรวมทั้งหมด
              SizedBox(
                height: cardHeight + 15,
                width: screenWidth,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slips.length + 1,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final bool isSummary = index == _slips.length;
                    return AnimatedBuilder(
                      animation: Listenable.merge([
                        _pageController,
                        ?_floatController,
                      ]),
                      builder: (context, child) {
                        double diff = (_currentIndex - index).toDouble();
                        try {
                          if (_pageController.hasClients &&
                              _pageController.positions.length == 1 &&
                              _pageController.position.haveDimensions) {
                            diff = (_pageController.page ?? _currentIndex.toDouble()) - index;
                          }
                        } catch (_) {
                          diff = (_currentIndex - index).toDouble();
                        }
                        final dist = diff.abs().clamp(0.0, 1.0);
                        // centerWeight: 1.0 เมื่ออยู่กึ่งกลางเต็มใบ, 0.0 เมื่อเป็นการ์ดข้างๆ
                        final centerWeight = (1.0 - dist).clamp(0.0, 1.0);

                        // การ์ดที่อยู่ข้างๆ จะเล็กลง (scale: 0.84) และจางลง เพื่อให้การ์ดตรงกลางเด่นชัด
                        final scale = 1.0 - (dist * 0.16);
                        final opacity = 1.0 - (dist * 0.45);
                        final translateY = dist * 8.0;

                        // การ์ดตรงกลาง: ลอยขึ้น-ลงอย่างมีชีวิตชีวา (Living Float) และเอียงเบาๆ อย่างเป็นธรรมชาติ
                        // การ์ดข้างๆ (ซ้าย-ขวา): นิ่งสงบ มั่นคง สวยงาม
                        final floatY = anim.value * centerWeight;
                        final floatAngle = (_floatController != null
                            ? math.sin(_floatController!.value * 2 * math.pi) * 0.012 * centerWeight
                            : 0.0);

                        return Center(
                          child: SizedBox(
                            width: cardWidth,
                            height: cardHeight,
                            child: Transform.translate(
                              offset: Offset(0, translateY + floatY),
                              child: Transform.rotate(
                                angle: floatAngle,
                                child: Transform.scale(
                                  scale: scale,
                                  child: Opacity(
                                    opacity: opacity.clamp(0.45, 1.0),
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: isSummary
                          ? _buildSummaryTotalCard(
                              context,
                              isActive: index == _currentIndex,
                            )
                          : _buildCompactRectangularCard(
                              context,
                              _slips[index],
                              isActive: index == _currentIndex,
                              index: index,
                            ),
                    );
                  },
                ),
              ),

              // จุดหรือแถบบอกตำแหน่งสลิป (Progress Pill & Dots Indicator)
              const SizedBox(height: 8),
              if (_slips.length <= 10)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slips.length + 1, (idx) {
                    final isCurrent = idx == _currentIndex;
                    final isSummaryDot = idx == _slips.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: isCurrent ? (isSummaryDot ? 18 : 14) : (isSummaryDot ? 7 : 5),
                      height: 5,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? (isSummaryDot ? const Color(0xFFFBBF24) : Colors.white)
                            : (isSummaryDot
                                ? const Color(0xFFFBBF24).withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSummaryPage ? Icons.receipt_long_rounded : Icons.photo_library_outlined,
                        size: 13,
                        color: isSummaryPage ? const Color(0xFFFBBF24) : Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSummaryPage
                            ? context.tr('สรุปยอดรวม (${_slips.length} ใบ)', 'Summary Total (${_slips.length} slips)')
                            : context.tr('ใบที่ ${_currentIndex + 1} / ${_slips.length}', 'Slip ${_currentIndex + 1} / ${_slips.length}'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSummaryPage ? const Color(0xFFFDE68A) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),

              // 3. แถบควบคุมด้านล่าง: สถานะกำลังสแกน หรือ ปุ่มบันทึกสลิป 3D
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: _isScanning
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2D17).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF7FA858).withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF7FA858),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'กำลังนับสลิปใบที่ $_scannedCount จาก ${_slips.length} ใบ...',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _skipScanning,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ข้าม',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.skip_next_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                secondChild: SizedBox(
                  width: cardWidth,
                  child: GestureDetector(
                    onTap: _isSaving || _selectedCount == 0
                        ? null
                        : _saveSelectedTransactions,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _selectedCount > 0
                              ? (isSummaryPage
                                  ? [palette.primary, palette.strong]
                                  : [gradientColors[0], gradientColors[1]])
                              : const [Color(0xFF475569), Color(0xFF334155)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedCount > 0
                              ? (isSummaryPage
                                  ? palette.secondary.withValues(alpha: 0.85)
                                  : Colors.white.withValues(alpha: 0.85))
                              : const Color(0xFF64748B),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _selectedCount > 0
                                ? (isSummaryPage
                                    ? palette.strong.withValues(alpha: 0.45)
                                    : gradientColors[0].withValues(alpha: 0.40))
                                : Colors.black.withValues(alpha: 0.2),
                            offset: const Offset(0, 3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isSummaryPage
                                          ? Icons.save_rounded
                                          : Icons.check_circle_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isSummaryPage
                                          ? context.tr(
                                              'บันทึกทั้งหมด ($_selectedCount ใบ • ฿${_totalSelectedAmount.toStringAsFixed(2)})',
                                              'Save All ($_selectedCount • ฿${_totalSelectedAmount.toStringAsFixed(2)})',
                                            )
                                          : (_slips.length > 1
                                              ? context.tr(
                                                  'บันทึกทั้งหมด ($_selectedCount ใบ • ฿${_totalSelectedAmount.toStringAsFixed(2)})',
                                                  'Save All ($_selectedCount • ฿${_totalSelectedAmount.toStringAsFixed(2)})',
                                                )
                                              : context.tr(
                                                  'บันทึกสลิป (฿${_totalSelectedAmount.toStringAsFixed(2)})',
                                                  'Save Slip (฿${_totalSelectedAmount.toStringAsFixed(2)})',
                                                )),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // การ์ดใบสุดท้าย: สรุปยอดรวมทั้งหมด พร้อมปุ่มบันทึกทีเดียวจบ
  Widget _buildSummaryTotalCard(
    BuildContext context, {
    required bool isActive,
  }) {
    final Map<BankType, int> bankCounts = {};
    for (final s in _slips) {
      bankCounts[s.bank] = (bankCounts[s.bank] ?? 0) + 1;
    }

    return GestureDetector(
      onTap: () {
        if (_currentIndex != _slips.length) {
          if (_pageController.hasClients && _pageController.positions.length == 1) {
            _pageController.animateToPage(
              _slips.length,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            );
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFFDF6), // Soft pale ivory
              Color(0xFFFAF4DC), // Pale eggshell cream (สีครีมไข่ไก่ จางๆ ละมุนตา)
              Color(0xFFF5EAC6), // Warm soft custard paper tint
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFEADBBE), // Delicate egg-cream border
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5E4E2C).withValues(alpha: isActive ? 0.13 : 0.05),
              offset: const Offset(0, 8),
              blurRadius: 20,
            ),
            BoxShadow(
              color: const Color(0xFFFDF0CC).withValues(alpha: isActive ? 0.40 : 0.15),
              offset: const Offset(0, 2),
              blurRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              // Decorative background shapes - soft pale egg-yolk & meadow tints
              Positioned(
                right: -25,
                top: -25,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFDE7A8).withValues(alpha: 0.55), // Warm egg yolk halo
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -20,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE2EFCD).withValues(alpha: 0.50), // Soft meadow leaf
                  ),
                ),
              ),

              // Content inside summary card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top: Prominent App Logo + Brand Title + Count Badge
                    Row(
                      children: [
                        // Large & Clearly Visible App Logo (46x46)
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: const Color(0xFFEADBBE),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.asset(
                              'assets/images/logo_blue.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'SaveFor',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF243F1A),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 13,
                                        color: const Color(0xFFE5A922).withValues(alpha: 0.90),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        final allSelected = _selectedCount == _slips.length;
                                        for (final s in _slips) {
                                          s.isSelected = !allSelected;
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF0CD), // Soft egg-custard badge
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFF3DD9C),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '$_selectedCount/${_slips.length} ใบ',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF6F4A04), // Warm caramel egg text
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'สรุปยอดสแกนทั้งหมด',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B8353),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Amount Section (Large Grand Total)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ยอดเงินรวมทั้งสิ้น',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6D8555),
                          ),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '฿${_totalSelectedAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E3816),
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Bank Breakdown Chips: เอาแค่ไอคอน x2 ตามคำสั่งนาย เพื่อความประหยัดเนื้อที่
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6EFE0), // Pale egg-milk tint
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFE5D7BD),
                          width: 1,
                        ),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: bankCounts.entries.map((entry) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFDFD2B8),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  BankLogoIcon(bank: entry.key, size: 20, showShadow: false),
                                  const SizedBox(width: 5),
                                  Text(
                                    'x${entry.value}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF233E1A),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Status Badge / Summary Verification
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF6E5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFCEE3BA),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Color(0xFF5A8E38),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.tr(
                              'พร้อมบันทึกสลิปทั้งหมด $_selectedCount รายการ',
                              'Ready to save all $_selectedCount slips',
                            ),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF233E1A),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Hint at bottom: ไอคอนปัดเลื่อนซ้าย
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.swipe_left_rounded,
                          size: 13,
                          color: Color(0xFF7A8C6B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ปัดซ้ายเพื่อดูสลิปทีละใบ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7A8C6B).withValues(alpha: 0.9),
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
      ),
    );
  }

  void _showDestinationBankPicker(BuildContext context, ParsedSlip slip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'เลือกธนาคารปลายทางที่ย้ายเงินไป',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BankType.values.map((bank) {
                    final isSel = slip.destinationBank == bank;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          slip.destinationBank = bank;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BankLogoIcon(bank: bank, size: 20, showShadow: false),
                            const SizedBox(width: 6),
                            Text(
                              bank.displayName.split(' ').first,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                color: isSel ? const Color(0xFF4F46E5) : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditSlipNoteDialog(ParsedSlip slip) {
    final textController = TextEditingController(text: slip.customNote ?? '');
    bool includeRecipient = slip.includeRecipientInNote;
    bool isTransfer = slip.isTransfer;
    BankType? destinationBank = slip.destinationBank ??
        (slip.bank == BankType.kbank ? BankType.scb : BankType.kbank);

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
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                    const SizedBox(height: 16),

                    // Bank Header & Identity
                    Row(
                      children: [
                        isTransfer && destinationBank != null
                            ? DualBankLogoIcon(
                                fromBank: slip.bank,
                                toBank: destinationBank!,
                                size: 30,
                                showShadow: true,
                              )
                            : BankLogoIcon(
                                bank: slip.bank,
                                size: 34,
                                showShadow: true,
                              ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      isTransfer ? 'ย้ายเงินระหว่างบัญชี' : slip.bank.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isTransfer ? const Color(0xFFEEF2FF) : const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isTransfer ? 'ย้ายเงิน' : 'สลิปธนาคาร',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: isTransfer ? const Color(0xFF4F46E5) : const Color(0xFF0284C7),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ผู้รับเดิม: ${slip.recipient}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          isTransfer ? '฿${slip.amount.toStringAsFixed(2)}' : '-฿${slip.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isTransfer ? const Color(0xFF6366F1) : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),

                    // Toggle: รายจ่ายปกติ vs ย้ายเงินระหว่างบัญชี
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  isTransfer = false;
                                });
                              },
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !isTransfer ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: !isTransfer
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.06),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_rounded,
                                      size: 15,
                                      color: !isTransfer ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'รายจ่าย',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: !isTransfer ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  isTransfer = true;
                                });
                              },
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isTransfer ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: isTransfer
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.06),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.swap_horiz_rounded,
                                      size: 16,
                                      color: isTransfer ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'ย้ายเงิน',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isTransfer ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isTransfer) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: Row(
                          children: [
                            BankLogoIcon(bank: slip.bank, size: 20, showShadow: false),
                            const SizedBox(width: 6),
                            Text(
                              slip.bank.displayName.split(' ').first,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF3730A3)),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF6366F1)),
                            ),
                            const Text('ไปยัง: ', style: TextStyle(fontSize: 11.5, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<BankType>(
                                  value: destinationBank,
                                  isDense: true,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF4F46E5)),
                                  items: BankType.values.map((b) {
                                    return DropdownMenuItem<BankType>(
                                      value: b,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          BankLogoIcon(bank: b, size: 18, showShadow: false),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              b.displayName.split(' ').first,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() {
                                        destinationBank = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Field Title
                    const Text(
                      'ระบุชื่อรายการ (เช่น ค่าข้าว, ค่าน้ำมัน, ของใช้)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // TextField
                    TextField(
                      controller: textController,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'เช่น ค่าข้าวเที่ยง, ค่าน้ำมัน, ช้อปปิ้ง...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
                        ),
                        prefixIcon: Icon(
                          Icons.edit_note_rounded,
                          color: AppTheme.primaryColor,
                        ),
                        suffixIcon: textController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setModalState(() {
                                    textController.clear();
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
                    const SizedBox(height: 12),

                    // Quick Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: quickChips.map((chip) {
                        final label = chip['label'] as String;
                        final icon = chip['icon'] as IconData;
                        final isSelected = textController.text.trim() == label;
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              textController.text = label;
                              textController.selection = TextSelection.fromPosition(
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
                    const SizedBox(height: 12),

                    // Checkbox include original recipient
                    InkWell(
                      onTap: () {
                        setModalState(() {
                          includeRecipient = !includeRecipient;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: includeRecipient,
                                activeColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                onChanged: (val) {
                                  setModalState(() {
                                    includeRecipient = val ?? true;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'แนบชื่อผู้รับ (${slip.recipient}) ต่อท้ายในประวัติ',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      children: [
                        if (slip.customNote != null && slip.customNote!.isNotEmpty) ...[
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  slip.customNote = null;
                                  slip.includeRecipientInNote = true;
                                  slip.isTransfer = false;
                                });
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(color: Color(0xFFFECACA)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'ล้างชื่อที่แก้',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final text = textController.text.trim();
                              setState(() {
                                slip.customNote = text.isNotEmpty ? text : null;
                                slip.includeRecipientInNote = includeRecipient;
                                slip.isTransfer = isTransfer;
                                if (isTransfer) {
                                  slip.destinationBank = destinationBank;
                                }
                              });
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'บันทึกชื่อรายการ',
                              style: TextStyle(
                                fontSize: 13.5,
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
            );
          },
        );
      },
    );
  }

  void _showFullImagePreview(BuildContext context, ParsedSlip slip) {
    if (slip.imagePath == null) return;
    final file = File(slip.imagePath!);
    if (!file.existsSync()) return;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
              maxWidth: 400,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF6),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFEADBBE),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ส่วนหัว Header ธีมแอปสมุดโน้ตครีมไข่ พร้อมโลโก้ SaveFor ตามคำสั่งนาย
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFFFDF6),
                        Color(0xFFFAF4DC),
                        Color(0xFFF5EAC6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      // โลโก้แอป SaveFor สุดน่ารัก (แทนที่ไอคอนเดิม)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFEADBBE),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.5),
                          child: Image.asset(
                            'assets/images/logo_blue.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  context.tr('รูปภาพสลิปต้นฉบับ', 'Original Slip Image'),
                                  style: const TextStyle(
                                    color: Color(0xFF243F1A),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDF6E5),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: const Color(0xFFCEE3BA),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    slip.bank.displayName,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF3B6B22),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'จากโฟลเดอร์: ${slip.albumName ?? "แกลเลอรี"}',
                              style: const TextStyle(
                                color: Color(0xFF6B8353),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ปุ่มปิด X กลมมนสไตล์ครีมมินิมอล
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.90),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE4DAC7),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Color(0xFF3F3624),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFEADBBE)),

                // พื้นที่แสดงภาพสลิปต้นฉบับ ซูมเข้า-ออกได้ บนพื้นหลังมืดสบายตา
                Flexible(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    child: Container(
                      color: const Color(0xFF0F172A),
                      width: double.infinity,
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Image.file(file),
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

  // ตัวสลิปธนาคารแนวตั้ง สะอาดตา ไม่รก มินิมอล พร้อมแอนิเมชันเลือกและแตะสลับ
  Widget _buildCompactRectangularCard(
    BuildContext context,
    ParsedSlip slip, {
    required bool isActive,
    required int index,
  }) {
    final gradientColors = _getBankGradient(slip.bank);
    final isSelected = slip.isSelected;
    final hasImage = slip.imagePath != null && File(slip.imagePath!).existsSync();

    return GestureDetector(
      onTap: () {
        if (index != _currentIndex) {
          if (_pageController.hasClients && _pageController.positions.length == 1) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            );
          }
        } else {
          setState(() {
            slip.isSelected = !slip.isSelected;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.35),
            width: isSelected ? 2.2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[1].withValues(alpha: isActive ? 0.45 : 0.15),
              offset: const Offset(0, 8),
              blurRadius: 18,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              offset: const Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            children: [
              // Background cartoon circle wave
              Positioned(
                right: -25,
                top: -25,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),

              // ลำแสงเลเซอร์สแกนเนอร์เคลื่อนที่ขณะสแกน
              if (_isScanning && isActive)
                AnimatedBuilder(
                  animation: _beamAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: _beamAnimation.value * 270,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 3.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              const Color(0xFF6EE7B7),
                              Colors.white,
                              const Color(0xFF6EE7B7),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF34D399).withValues(alpha: 0.95),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // Content inside clean minimal card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top: Bank Logo + Name + Checkbox
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: slip.isTransfer && slip.destinationBank != null
                              ? DualBankLogoIcon(
                                  fromBank: slip.bank,
                                  toBank: slip.destinationBank!,
                                  size: 19,
                                  showShadow: false,
                                )
                              : BankLogoIcon(
                                  bank: slip.bank,
                                  size: 22,
                                  showShadow: false,
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slip.isTransfer ? 'ย้ายเงิน' : slip.bank.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    slip.isTransfer ? 'ย้ายเงินระหว่างบัญชี ➔' : 'โอนเงินสำเร็จ ✓',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.88),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.20),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'ใบที่ ${index + 1}/${_slips.length}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Checkbox
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              width: 1.8,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: gradientColors[1],
                                )
                              : null,
                        ),
                      ],
                    ),

                    // Amount section + Slip Image Thumbnail Preview
                    Row(
                      mainAxisAlignment: hasImage ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: hasImage ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  slip.isTransfer ? context.tr('ยอดที่ย้าย', 'Transfer Amount') : context.tr('จำนวนเงิน', 'Amount'),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                if (slip.albumName != null && slip.albumName!.isNotEmpty) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    constraints: const BoxConstraints(maxWidth: 110),
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '📷 ${slip.albumName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                slip.isTransfer
                                    ? '฿${slip.amount.toStringAsFixed(2)}'
                                    : '-฿${slip.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: hasImage ? 25 : 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.6,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (hasImage)
                          GestureDetector(
                            onTap: () => _showFullImagePreview(context, slip),
                            child: Tooltip(
                              message: context.tr('แตะดูรูปสลิปต้นฉบับ', 'Tap to view original slip'),
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6.5),
                                      child: Image.file(
                                        File(slip.imagePath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.broken_image,
                                          size: 18,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(5),
                                        bottomRight: Radius.circular(6),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.zoom_in_rounded,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Quick Toggle: ค่าใช้จ่าย vs ย้ายเงิน
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 6),
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (slip.isTransfer) {
                                  setState(() {
                                    slip.isTransfer = false;
                                  });
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: !slip.isTransfer ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: !slip.isTransfer
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '💸 ค่าใช้จ่าย',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: !slip.isTransfer ? FontWeight.w800 : FontWeight.w600,
                                      color: !slip.isTransfer ? const Color(0xFFEF4444) : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (!slip.isTransfer) {
                                  setState(() {
                                    slip.isTransfer = true;
                                    slip.destinationBank ??= (slip.bank == BankType.kbank ? BankType.scb : BankType.kbank);
                                  });
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: slip.isTransfer ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: slip.isTransfer
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '⇄ ย้ายเงิน',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: slip.isTransfer ? FontWeight.w800 : FontWeight.w600,
                                      color: slip.isTransfer ? const Color(0xFF4F46E5) : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (slip.isTransfer) ...[
                      GestureDetector(
                        onTap: () => _showDestinationBankPicker(context, slip),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                          ),
                          child: Row(
                            children: [
                              BankLogoIcon(bank: slip.bank, size: 18, showShadow: false),
                              const SizedBox(width: 4),
                              Text(
                                slip.bank.displayName.split(' ').first,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white70),
                              ),
                              if (slip.destinationBank != null) ...[
                                BankLogoIcon(bank: slip.destinationBank!, size: 18, showShadow: false),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    slip.destinationBank!.displayName.split(' ').first,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ] else ...[
                                const Expanded(
                                  child: Text(
                                    'เลือกธนาคารปลายทาง',
                                    style: TextStyle(fontSize: 11, color: Colors.white70),
                                  ),
                                ),
                              ],
                              const Icon(Icons.expand_more_rounded, size: 16, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Recipient / Custom Note (Editable on tap)
                    GestureDetector(
                      onTap: () => _showEditSlipNoteDialog(slip),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: slip.customNote != null && slip.customNote!.isNotEmpty
                                ? 0.25
                                : 0.16,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: slip.customNote != null && slip.customNote!.isNotEmpty
                                ? Colors.white.withValues(alpha: 0.65)
                                : Colors.white.withValues(alpha: 0.25),
                            width: 1.1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              slip.customNote != null && slip.customNote!.isNotEmpty
                                  ? Icons.edit_note_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (slip.customNote != null && slip.customNote!.isNotEmpty) ...[
                                    Text(
                                      slip.customNote!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (slip.includeRecipientInNote)
                                      Text(
                                        'โอนให้: ${slip.recipient}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.82),
                                        ),
                                      ),
                                  ] else
                                    Text(
                                      'ถึง: ${slip.recipient}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.edit_rounded,
                                    size: 9.5,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 2.5),
                                  Text(
                                    slip.customNote != null && slip.customNote!.isNotEmpty
                                        ? 'แก้แล้ว'
                                        : 'แก้ชื่อ',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Footer: Date & Ref
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${slip.date.day.toString().padLeft(2, '0')}/${slip.date.month.toString().padLeft(2, '0')}/${slip.date.year} ${slip.date.hour.toString().padLeft(2, '0')}:${slip.date.minute.toString().padLeft(2, '0')} น.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        if (slip.referenceNo != null && slip.referenceNo!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Ref: ${slip.referenceNo!.length > 10 ? '...${slip.referenceNo!.substring(slip.referenceNo!.length - 8)}' : slip.referenceNo!}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ],
                      ],
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
}
