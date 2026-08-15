import 'package:app/core/localization/app_material.dart';
import 'dart:math' as math;

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../dreams/presentation/dreams_screen.dart';
import '../../recurring/presentation/recurring_expense_screen.dart';
import '../../recurring/presentation/recurring_income_screen.dart';

enum PlanningSection { income, dream, expense }

class PlanningHubScreen extends StatefulWidget {
  final PlanningSection initialSection;
  final bool startTutorial;

  const PlanningHubScreen({
    super.key,
    this.initialSection = PlanningSection.dream,
    this.startTutorial = false,
  });

  @override
  State<PlanningHubScreen> createState() => _PlanningHubScreenState();
}

class _PlanningHubScreenState extends State<PlanningHubScreen> {
  late PlanningSection _section;
  final GlobalKey _tabIncomeKey = GlobalKey();
  final GlobalKey _tabDreamKey = GlobalKey();
  final GlobalKey _tabExpenseKey = GlobalKey();
  final GlobalKey _editButtonKey = GlobalKey();
  int _tutorialStep = -1;
  final ValueNotifier<int> _incomeAddRequest = ValueNotifier(0);
  final ValueNotifier<int> _dreamAddRequest = ValueNotifier(0);
  final ValueNotifier<int> _expenseAddRequest = ValueNotifier(0);

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _pageController = PageController(initialPage: _section.index);
    if (widget.startTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _changeTutorialStep(0);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _incomeAddRequest.dispose();
    _dreamAddRequest.dispose();
    _expenseAddRequest.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indicatorColor = switch (_section) {
      PlanningSection.income => const Color(0xFFBFEFDD),
      PlanningSection.dream => const Color(0xFFE4D7FF),
      PlanningSection.expense => const Color(0xFFFFB9C1),
    };
    final indicatorAlignment = switch (_section) {
      PlanningSection.income => Alignment.centerLeft,
      PlanningSection.dream => Alignment.center,
      PlanningSection.expense => Alignment.centerRight,
    };

    return Scaffold(
      backgroundColor: context.pageColor,
      body: Stack(
        children: [
          const Positioned.fill(child: FloatingBackground()),
          SafeArea(
            child: ResponsiveLayout(
              maxWidth: 800,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 5),
                    child: Row(
                      children: [
                        Material(
                          color: context.surfaceColor.withValues(alpha: 0.92),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.pop(context),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 17,
                                color: context.primaryTextColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.tr('รายการที่ตั้งไว้', 'Plans'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.primaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 220,
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: context.surfaceColor,
                                  borderRadius: BorderRadius.circular(19),
                                  border: Border.all(
                                    color: context.borderColor,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0F172A,
                                      ).withValues(alpha: 0.07),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    AnimatedAlign(
                                      duration: const Duration(
                                        milliseconds: 280,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      alignment: indicatorAlignment,
                                      child: FractionallySizedBox(
                                        widthFactor: 1 / 3,
                                        heightFactor: 1,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 1,
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 220,
                                            ),
                                            decoration: BoxDecoration(
                                              color: indicatorColor,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: indicatorColor
                                                      .withValues(alpha: 0.55),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        _SegmentButton(
                                          key: _tabIncomeKey,
                                          label: context.tr('รายรับ', 'Income'),
                                          selected:
                                              _section ==
                                              PlanningSection.income,
                                          onTap: () =>
                                              _select(PlanningSection.income),
                                        ),
                                        _SegmentButton(
                                          key: _tabDreamKey,
                                          label: context.tr(
                                            'เงินออม',
                                            'Savings',
                                          ),
                                          selected:
                                              _section == PlanningSection.dream,
                                          onTap: () =>
                                              _select(PlanningSection.dream),
                                        ),
                                        _SegmentButton(
                                          key: _tabExpenseKey,
                                          label: context.tr(
                                            'รายจ่าย',
                                            'Expenses',
                                          ),
                                          selected:
                                              _section ==
                                              PlanningSection.expense,
                                          onTap: () =>
                                              _select(PlanningSection.expense),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          key: _editButtonKey,
                          width: 38,
                          height: 38,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _requestAdd,
                              child: Center(
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111111),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.22,
                                        ),
                                        blurRadius: 7,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _section = PlanningSection.values[index];
                          });
                        },
                        children: [
                          RecurringIncomeScreen(
                            embedded: true,
                            addRequest: _incomeAddRequest,
                          ),
                          DreamsScreen(
                            embedded: true,
                            addRequest: _dreamAddRequest,
                          ),
                          RecurringExpenseScreen(
                            embedded: true,
                            addRequest: _expenseAddRequest,
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

  void _select(PlanningSection section) {
    if (_section == section) return;
    _pageController.animateToPage(
      section.index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  void _requestAdd() {
    switch (_section) {
      case PlanningSection.income:
        _incomeAddRequest.value++;
        return;
      case PlanningSection.dream:
        _dreamAddRequest.value++;
        return;
      case PlanningSection.expense:
        _expenseAddRequest.value++;
        return;
    }
  }

  void _changeTutorialStep(int newStep) {
    setState(() {
      _tutorialStep = newStep;
      if (_tutorialStep == 1) {
        _select(PlanningSection.income);
      } else if (_tutorialStep == 2) {
        _select(PlanningSection.dream);
      } else if (_tutorialStep == 3) {
        _select(PlanningSection.expense);
      }
    });
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
        final rect = _getWidgetRect(_tabIncomeKey);
        if (rect != null) {
          targetRectVal = rect;
          targetRadiusVal = 16.0;
        }
        break;
      case 2:
        final rect = _getWidgetRect(_tabDreamKey);
        if (rect != null) {
          targetRectVal = rect;
          targetRadiusVal = 16.0;
        }
        break;
      case 3:
        final rect = _getWidgetRect(_tabExpenseKey);
        if (rect != null) {
          targetRectVal = rect;
          targetRadiusVal = 16.0;
        }
        break;
      case 4:
        final rect = _getWidgetRect(_editButtonKey);
        if (rect != null) {
          targetRectVal = rect;
          targetRadiusVal = rect.width / 2;
        }
        break;
    }

    final titles = [
      context.tr('หน้าวางแผนการเงิน', 'Plans Screen'),
      context.tr('แท็บรายรับประจำ', 'Recurring Income'),
      context.tr('แท็บเป้าหมายเงินออม', 'Savings Goals (Dreams)'),
      context.tr('แท็บรายจ่ายประจำ', 'Recurring Expenses'),
      context.tr('สร้างและแก้ไขรายการ', 'Add & Edit Plans'),
    ];

    final descriptions = [
      context.tr(
        'ยินดีต้อนรับสู่หน้าแผนการเงิน! หน้านี้คือกระเป๋าหลักในการหักออม วางแผนค่าใช้จ่าย และเก็บเงินทำตามความฝันของคุณ',
        'Welcome to the Plans screen! This is your control center to automate savings, schedule fixed bills, and track financial goals.',
      ),
      context.tr(
        'ใช้สำหรับบันทึกช่องทางรายรับคงที่ต่อเดือนของคุณ (เช่น เงินเดือน, ค่าเช่าบ้าน) เพื่อเป็นยอดอ้างอิงในการคำนวณหักออมรายเดือน',
        'Use this to record your fixed monthly income channels (e.g., salary, rent) to use as a baseline for monthly savings calculations.',
      ),
      context.tr(
        'ใช้สำหรับตั้งเป้าหมายความฝันของคุณ (เช่น ซื้อบ้านใหม่, เที่ยวต่างประเทศ) โดยคุณสามารถออมเงินตามเป้าหมายผ่านการพิมพ์แชทคำว่า "ออม" ได้เลยครับ',
        'Use this to set goals for your dreams (e.g., buying a home, traveling). You can save towards goals easily by chatting "save" or "ออม".',
      ),
      context.tr(
        'ใช้สำหรับบันทึกรายการบิลจ่ายคงที่ประจำเดือน (เช่น ค่าหอพัก, ค่าน้ำไฟ, ค่าเน็ต) เพื่อให้ระบบจดจำยอดและส่งการเตือนก่อนถึงกำหนดจ่ายจริง',
        'Use this to record fixed monthly bills (e.g., rent, utility bills, subscription fees) so the system remembers and reminds you before they are due.',
      ),
      context.tr(
        'แตะที่ปุ่มดินสอด้านบนนี้เพื่อสร้างเป้าหมายรายรับ รายจ่าย หรือความฝันออมเงินใหม่ ๆ เพิ่มเติมได้ด้วยตนเองทันที',
        'Tap this pencil button to manually create, edit, or remove your income streams, expense bills, or savings dreams instantly.',
      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_tutorialStep + 1} / $totalSteps',
                  style: TextStyle(
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
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
                  onPressed: () => _changeTutorialStep(_tutorialStep - 1),
                  child: Text(context.tr('ย้อนกลับ', 'Back')),
                ),
                const SizedBox(width: 10),
              ],
              FilledButton(
                onPressed: () {
                  if (_tutorialStep < totalSteps - 1) {
                    _changeTutorialStep(_tutorialStep + 1);
                  } else {
                    setState(() {
                      _tutorialStep = -1;
                    });
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  _tutorialStep == totalSteps - 1
                      ? context.tr('เสร็จสิ้นทัวร์', 'Finish')
                      : context.tr('ถัดไป', 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final double cardHeight = 220.0;
    double animTop = (screenHeight - cardHeight) / 2;
    if (_tutorialStep > 0) {
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
                  _changeTutorialStep(_tutorialStep + 1);
                } else {
                  setState(() {
                    _tutorialStep = -1;
                  });
                  Navigator.pop(context);
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
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.75);

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

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? const Color(0xFF161616)
                    : const Color(0xFF737780),
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
