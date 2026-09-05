import 'package:app/core/localization/app_material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/slip_parser_service.dart';
import '../../../core/services/slip_scanner_bridge.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/auth_session.dart';

class SlipScanDialog extends StatefulWidget {
  final List<ParsedSlip> slips;
  final VoidCallback? onTransactionsSaved;

  const SlipScanDialog({
    super.key,
    required this.slips,
    this.onTransactionsSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ParsedSlip> slips,
    VoidCallback? onTransactionsSaved,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SlipScanDialog(
        slips: slips,
        onTransactionsSaved: onTransactionsSaved,
      ),
    );
  }

  @override
  State<SlipScanDialog> createState() => _SlipScanDialogState();
}

class _SlipScanDialogState extends State<SlipScanDialog> {
  late List<ParsedSlip> _slips;
  bool _isSaving = false;
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _slips = widget.slips;
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
        final note = '[สลิป ${slip.bank.displayName}] ${slip.recipient}';
        final response = await _apiClient.post(
          '/transactions',
          body: {
            'user_id': userId,
            'amount': slip.amount,
            'type': 'expense',
            'note': note,
            'transaction_date': slip.date.toIso8601String(),
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          savedSuccessCount++;
          successfulSlips.add(slip);
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.primaryColor,
        content: Text(
          context.tr(
            'บันทึกสลิปสำเร็จ $savedSuccessCount รายการ',
            'Successfully saved $savedSuccessCount slips',
          ),
        ),
      ),
    );

    widget.onTransactionsSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('ตรวจพบสลิปใหม่', 'New Bank Slips Found'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr(
                            'พบ ${_slips.length} รายการจากอัลบั้มรูปภาพ',
                            'Found ${_slips.length} slips from your photo library',
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: subColor,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),

            // Slips List
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shrinkWrap: true,
                itemCount: _slips.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final slip = _slips[index];
                  final bankColor = Color(slip.bank.brandColorValue);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        slip.isSelected = !slip.isSelected;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: slip.isSelected
                            ? (isDark
                                ? const Color(0xFF0F2327)
                                : const Color(0xFFF0FDF9))
                            : (isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: slip.isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.4)
                              : (isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFE2E8F0)),
                          width: slip.isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: slip.isSelected,
                            activeColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            onChanged: (val) {
                              setState(() {
                                slip.isSelected = val ?? false;
                              });
                            },
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: bankColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        slip.bank.displayName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: bankColor,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '-฿${slip.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  slip.recipient,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${slip.date.day.toString().padLeft(2, '0')}/${slip.date.month.toString().padLeft(2, '0')}/${slip.date.year} ${slip.date.hour.toString().padLeft(2, '0')}:${slip.date.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('รวมที่เลือก', 'Total Selected'),
                          style: TextStyle(fontSize: 12, color: subColor),
                        ),
                        Text(
                          '฿${_totalSelectedAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isSaving || _selectedCount == 0
                        ? null
                        : _saveSelectedTransactions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            context.tr(
                              'บันทึก ($_selectedCount รายการ)',
                              'Save ($_selectedCount items)',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
