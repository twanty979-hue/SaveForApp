import 'package:app/core/localization/app_material.dart';

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

  const PlanningHubScreen({
    super.key,
    this.initialSection = PlanningSection.dream,
  });

  @override
  State<PlanningHubScreen> createState() => _PlanningHubScreenState();
}

class _PlanningHubScreenState extends State<PlanningHubScreen> {
  late PlanningSection _section;
  final ValueNotifier<int> _incomeAddRequest = ValueNotifier(0);
  final ValueNotifier<int> _dreamAddRequest = ValueNotifier(0);
  final ValueNotifier<int> _expenseAddRequest = ValueNotifier(0);

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _pageController = PageController(initialPage: _section.index);
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
                                border: Border.all(color: context.borderColor),
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
                                    duration: const Duration(milliseconds: 280),
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
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
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
                                        label: context.tr('รายรับ', 'Income'),
                                        selected:
                                            _section == PlanningSection.income,
                                        onTap: () =>
                                            _select(PlanningSection.income),
                                      ),
                                      _SegmentButton(
                                        label: context.tr('เงินออม', 'Savings'),
                                        selected:
                                            _section == PlanningSection.dream,
                                        onTap: () =>
                                            _select(PlanningSection.dream),
                                      ),
                                      _SegmentButton(
                                        label: context.tr(
                                          'รายจ่าย',
                                          'Expenses',
                                        ),
                                        selected:
                                            _section == PlanningSection.expense,
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
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
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
