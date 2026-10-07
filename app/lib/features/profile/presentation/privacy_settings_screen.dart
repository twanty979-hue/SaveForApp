import 'package:app/core/localization/app_material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/settings/app_settings.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../../core/services/bank_rules_service.dart';
import '../../../core/models/bank_rule_model.dart';
import 'supported_banks_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final ApiClient _apiClient = ApiClient();

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: BoxDecoration(
            color: ctx.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF10B981),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ctx.tr('นโยบายความเป็นส่วนตัว', 'Privacy Policy'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ctx.primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ctx.tr(
                              'การคุ้มครองข้อมูลส่วนบุคคลและสิทธิ์การเข้าถึงรูปภาพ',
                              'Personal Data Protection & Photo Access Rights',
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: ctx.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: ctx.secondaryTextColor),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content Body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // Badge Notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.3 : 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ctx.tr(
                                'SaveFor ปฏิบัติตามมาตรฐาน PDPA อย่างเคร่งครัด ข้อมูลของคุณเป็นสิทธิ์ของคุณแต่เพียงผู้เดียว',
                                'SaveFor strictly adheres to PDPA standards. Your financial data strictly belongs to you.',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    _buildPolicyCard(
                      ctx,
                      icon: Icons.folder_special_rounded,
                      title: ctx.tr(
                        '1. สิทธิ์การเข้าถึงเฉพาะอัลบั้มธนาคาร (Strict Whitelist)',
                        '1. Whitelisted Bank Folders Only',
                      ),
                      body: ctx.tr(
                        '• แอปขอสิทธิ์เข้าถึงคลังภาพเพื่อตรวจหาเฉพาะโฟลเดอร์สลิปของธนาคารที่คุณเปิดใช้งานเท่านั้น (เช่น โฟลเดอร์ K PLUS, SCB EASY, ttb touch ฯลฯ)\n'
                        '• ❌ ไม่มีการเข้าถึงรูปถ่ายส่วนตัวเด็ดขาด: แอปไม่แตะต้องและไม่อ่านรูปถ่ายจากกล้อง (Camera, DCIM), ภาพหน้าจอ (Screenshots), หรือโฟลเดอร์ดาวน์โหลดส่วนตัวใดๆ ของคุณทั้งสิ้น',
                        '• The app requests photo access ONLY to search for designated bank slip albums you have enabled (e.g., K PLUS, SCB EASY, ttb touch, etc.)\n'
                        '• ❌ Never accesses personal photos: The app never touches Camera (DCIM), Screenshots, or personal downloads.',
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildPolicyCard(
                      ctx,
                      icon: Icons.memory_rounded,
                      title: ctx.tr(
                        '2. ประมวลผลบนเครื่อง (On-Device Local Processing)',
                        '2. On-Device Local Processing',
                      ),
                      body: ctx.tr(
                        '• การตรวจจับตัวอักษร วันที่ และยอดเงิน ทำงานด้วยระบบ Machine Learning (Local OCR) บนอุปกรณ์ของคุณเองโดยตรง\n'
                        '• ❌ ไม่ส่งภาพสลิปออกภายนอก: รูปภาพสลิปจะไม่ถูกอัปโหลดหรือส่งต่อไปยังเซิร์ฟเวอร์ภายนอก รูปและข้อมูลจึงปลอดภัยอยู่กับเครื่องเสมอ',
                        '• Slip recognition (amount, date, recipient) is processed locally on your device via on-device ML/OCR.\n'
                        '• ❌ Slips are never sent externally: Images are never uploaded to 3rd-party servers.',
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildPolicyCard(
                      ctx,
                      icon: Icons.tune_rounded,
                      title: ctx.tr(
                        '3. ผู้ใช้มีสิทธิ์ควบคุม 100% (Full User Control)',
                        '3. Full User Control',
                      ),
                      body: ctx.tr(
                        '• คุณสามารถเลือกเปิด-ปิดการสแกนของแต่ละธนาคารได้อย่างอิสระ หรือกด "ปิดทั้งหมด" ได้ตลอดเวลาในหน้า "ธนาคารที่รองรับ"\n'
                        '• สามารถเลือกนำเข้าสลิปแบบระบุรูปเองเป็นรายครั้งได้โดยไม่ต้องเปิดระบบตรวจหาอัตโนมัติ',
                        '• You have full control to toggle individual banks or disable all auto-scanning at any time in "Supported Banks".\n'
                        '• Manual single-photo picking is always available without enabling auto-scan.',
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildPolicyCard(
                      ctx,
                      icon: Icons.lock_outline_rounded,
                      title: ctx.tr(
                        '4. การจัดเก็บข้อมูลและการเข้ารหัส (Data Security)',
                        '4. Data Security & Storage',
                      ),
                      body: ctx.tr(
                        '• บันทึกธุรกรรมและประวัติการเงินได้รับการเข้ารหัสปลอดภัยตามมาตรฐานความปลอดภัยระดับสูง\n'
                        '• รองรับระบบล็อกแอปด้วย PIN หรือสแกนใบหน้า (Biometrics) ก่อนเข้าใช้งาน',
                        '• Transaction records are securely encrypted with modern security standards.\n'
                        '• Supports PIN and Biometric App Lock before entering the app.',
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildPolicyCard(
                      ctx,
                      icon: Icons.block_rounded,
                      title: ctx.tr(
                        '5. ไม่ขายข้อมูล และไม่ยิงโฆษณา (Zero Data Brokerage)',
                        '5. No Data Selling or Ads',
                      ),
                      body: ctx.tr(
                        '• SaveFor ไม่มีนโยบายนำข้อมูลทางการเงิน หรือพฤติกรรมการใช้จ่ายของคุณไปจำหน่าย แลกเปลี่ยน หรือใช้ในการยิงโฆษณาแก่บุคคลภายนอกโดยเด็ดขาด',
                        '• SaveFor never sells, rents, or exchanges your financial data for commercial marketing or advertising.',
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildPolicyCard(
                      ctx,
                      icon: Icons.delete_forever_rounded,
                      title: ctx.tr(
                        '6. สิทธิ์ในการลบข้อมูลทั้งหมดอย่างถาวร (Right to Erasure)',
                        '6. Right to Erasure / Account Deletion',
                      ),
                      body: ctx.tr(
                        '• คุณสามารถใช้สิทธิ์ลบประวัติการเงินและบัญชีทั้งหมดอย่างถาวรได้ตลอดเวลาผ่านปุ่ม "ลบบัญชี" โดยระบบจะทำลายข้อมูลทั้งหมดทันที',
                        '• You may permanently delete your account and all associated financial history at any time via "Delete Account".',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Confirm Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          ctx.tr('เข้าใจและรับทราบแล้ว', 'Understood'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTermsOfService() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: BoxDecoration(
            color: ctx.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.description_rounded,
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
                            ctx.tr('ข้อตกลงการใช้งาน', 'Terms of Service'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ctx.primaryTextColor,
                            ),
                          ),
                          Text(
                            ctx.tr('เงื่อนไขและข้อกำหนดในการใช้งานแอปพลิเคชัน', 'Terms and conditions for using SaveFor'),
                            style: TextStyle(
                              fontSize: 12,
                              color: ctx.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: ctx.secondaryTextColor),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    _buildPolicyCard(
                      ctx,
                      icon: Icons.savings_rounded,
                      title: ctx.tr('1. วัตถุประสงค์การใช้งาน', '1. Purpose of Service'),
                      body: ctx.tr(
                        'SaveFor เป็นแอปพลิเคชันบันทึกและวางแผนการเงินส่วนบุคคล ออกแบบมาเพื่อช่วยบันทึกรายรับ-รายจ่าย วิเคราะห์การเงิน และติดตามเป้าหมายการออมเงิน',
                        'SaveFor is a personal financial tracking tool designed to log income, expenses, and savings goals.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPolicyCard(
                      ctx,
                      icon: Icons.verified_user_outlined,
                      title: ctx.tr('2. ความรับผิดชอบในการตัดสินใจทางการเงิน', '2. Financial Decisions'),
                      body: ctx.tr(
                        'ข้อมูลสรุปและคำแนะนำในแอปเป็นเพียงเครื่องมือช่วยอำนวยความสะดวก การตัดสินใจในการลงทุนหรือการใช้จ่ายใดๆ เป็นการตัดสินใจและดุลยพินิจของผู้ใช้ทั้งสิ้น',
                        'Analytics and summaries are for reference. All financial decisions are made at user discretion.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPolicyCard(
                      ctx,
                      icon: Icons.cloud_done_rounded,
                      title: ctx.tr('3. ความต่อเนื่องและความปลอดภัยของระบบ', '3. Service Reliability'),
                      body: ctx.tr(
                        'ทีมงานมุ่งมั่นพัฒนาระบบให้มีความปลอดภัย เสถียร และมีประสิทธิภาพอย่างต่อเนื่องเพื่อมอบประสบการณ์ที่ดีที่สุดแก่ผู้ใช้ทุกท่าน',
                        'We strive to maintain high service availability, stability, and data security.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          ctx.tr('ตกลง', 'OK'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPolicyCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.pageColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: context.primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 12,
              color: context.secondaryTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.tr('ลบบัญชีผู้ใช้?', 'Delete Account?'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.tr(
            'ข้อมูลทั้งหมด รวมถึงธุรกรรม เป้าหมายความฝัน และการตั้งค่าต่าง ๆ จะถูกลบอย่างถาวรและไม่สามารถเรียกคืนได้ คุณต้องการดำเนินการต่อหรือไม่?',
            'All your data, including transactions, dreams, and settings, will be permanently deleted and cannot be recovered. Do you wish to proceed?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('ยกเลิก', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('ลบบัญชี', 'Delete Account')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final userId = AuthSession.userId;
      if (userId != null) {
        // Cascade delete user data
        await _apiClient.delete('/transactions?user_id=eq.$userId');
        await _apiClient.delete('/dreams?user_id=eq.$userId');
        await _apiClient.delete('/recurring/expenses?user_id=eq.$userId');
        await _apiClient.delete('/recurring/sources?user_id=eq.$userId');
        await _apiClient.delete('/users?id=eq.$userId');
      }
    } catch (_) {}

    // Dismiss loading and logout
    if (mounted) {
      Navigator.pop(context); // Dismiss loading spinner
      await AuthSession.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    }
  }

  Widget _buildPrivacyCommitmentCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF13231B),
                  const Color(0xFF0F1A15),
                ]
              : [
                  const Color(0xFFECFDF5),
                  const Color(0xFFF0FDF4),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('คำมั่นสัญญาด้านความเป็นส่วนตัว', 'Our Privacy Commitment'),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: context.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('ปลอดภัยสูงสุดระดับธนาคาร (PDPA Compliant)', 'Bank-Grade Privacy & PDPA Compliant'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildCommitmentItem(
            context,
            icon: Icons.folder_special_rounded,
            title: context.tr('สแกนเฉพาะอัลบั้มธนาคาร', 'Whitelisted Bank Albums Only'),
            desc: context.tr('ไม่แตะต้องรูปกล้อง (DCIM) หรือรูปส่วนตัวเด็ดขาด', 'Never touches Camera (DCIM) or personal photos'),
          ),
          const SizedBox(height: 9),
          _buildCommitmentItem(
            context,
            icon: Icons.memory_rounded,
            title: context.tr('ประมวลผลบนเครื่อง (On-Device)', 'On-Device Processing'),
            desc: context.tr('อ่านสลิปในโทรศัพท์ของคุณ ไม่ส่งรูปออกภายนอก', 'OCR runs locally, slips are never sent to 3rd-party servers'),
          ),
          const SizedBox(height: 9),
          _buildCommitmentItem(
            context,
            icon: Icons.shield_moon_rounded,
            title: context.tr('ไม่ขายข้อมูล ไม่ยิงโฆษณา', 'No Data Selling or Ads'),
            desc: context.tr('ข้อมูลการเงินเป็นของคุณแต่เพียงผู้เดียว 100%', 'Your financial data strictly belongs to you alone'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitmentItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF10B981)),
        const SizedBox(width: 9),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 11.5,
                color: context.secondaryTextColor,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.primaryTextColor,
                  ),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
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
              maxWidth: 600,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                          child: Text(
                            context.tr('ความเป็นส่วนตัว', 'Privacy'),
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
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      children: [
                        // Privacy & Security Commitment Hero Card
                        _buildPrivacyCommitmentCard(context),

                        _SectionLabel(context.tr('ความปลอดภัย', 'Security')),
                        const SizedBox(height: 8),

                        _SettingsTile(
                          icon: Icons.fingerprint_rounded,
                          title: context.tr('ล็อกแอปก่อนเข้าใช้งาน', 'App Lock'),
                          subtitle: context.tr(
                            'ใช้รหัส PIN หรือสแกนใบหน้า',
                            'Use PIN or Face ID',
                          ),
                          trailing: Switch(
                            value: AppSettings.appLockEnabled,
                            activeThumbColor: AppTheme.primaryColor,
                            onChanged: (val) async {
                              await AppSettings.setAppLockEnabled(val);
                              if (mounted) setState(() {});
                            },
                          ),
                          onTap: () async {
                            await AppSettings.setAppLockEnabled(!AppSettings.appLockEnabled);
                            if (mounted) setState(() {});
                          },
                        ),
                        _SettingsTile(
                          icon: Icons.visibility_off_rounded,
                          title: context.tr('ซ่อนยอดเงินในหน้าแรก', 'Hide Balances'),
                          subtitle: context.tr(
                            'เบลอยอดเงินอัตโนมัติ',
                            'Automatically blur balances',
                          ),
                          trailing: Switch(
                            value: AppSettings.hideBalances.value,
                            activeThumbColor: AppTheme.primaryColor,
                            onChanged: (val) async {
                              await AppSettings.setHideBalances(val);
                              if (mounted) setState(() {});
                            },
                          ),
                          onTap: () async {
                            await AppSettings.setHideBalances(!AppSettings.hideBalances.value);
                            if (mounted) setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),

                        _SectionLabel(context.tr('การเข้าถึงรูปภาพสลิป', 'Slip Photo Access')),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<List<BankRuleConfig>>(
                          valueListenable: BankRulesService.rulesNotifier,
                          builder: (context, rules, _) {
                            final activeCount = rules.where((r) => r.isEnabled).length;
                            final totalCount = rules.length;
                            return _SettingsTile(
                              icon: Icons.account_balance_rounded,
                              title: context.tr('ธนาคารที่ให้อ่านสลิป', 'Bank Slip Permissions'),
                              subtitle: context.tr(
                                'สแกนเฉพาะ $activeCount/$totalCount อัลบั้มธนาคารที่เปิดใช้งาน',
                                'Only scans $activeCount/$totalCount enabled bank albums',
                              ),
                              trailingText: '$activeCount/$totalCount',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SupportedBanksScreen(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        _SectionLabel(context.tr('ข้อมูลและข้อตกลง', 'Data & Agreements')),
                        const SizedBox(height: 8),
                        _SettingsTile(
                          icon: Icons.policy_rounded,
                          title: context.tr('นโยบายความเป็นส่วนตัว', 'Privacy Policy'),
                          subtitle: context.tr(
                            'อ่านรายละเอียดการจัดการข้อมูลส่วนบุคคล (PDPA)',
                            'Read details about personal data management (PDPA)',
                          ),
                          onTap: _showPrivacyPolicy,
                        ),
                        _SettingsTile(
                          icon: Icons.description_rounded,
                          title: context.tr('ข้อตกลงการใช้งาน', 'Terms of Service'),
                          subtitle: context.tr(
                            'ข้อกำหนดและเงื่อนไขการใช้แอป',
                            'Terms and conditions of app usage',
                          ),
                          onTap: _showTermsOfService,
                        ),
                        _SettingsTile(
                          icon: Icons.analytics_rounded,
                          title: context.tr('การเก็บข้อมูลพฤติกรรม', 'Analytics Consent'),
                          subtitle: context.tr(
                            'ช่วยเราพัฒนาแอปให้ดีขึ้น',
                            'Help us improve the app',
                          ),
                          trailing: Switch(
                            value: AppSettings.analyticsEnabled,
                            activeThumbColor: AppTheme.primaryColor,
                            onChanged: (val) async {
                              await AppSettings.setAnalyticsEnabled(val);
                              if (mounted) setState(() {});
                            },
                          ),
                          onTap: () async {
                            await AppSettings.setAnalyticsEnabled(!AppSettings.analyticsEnabled);
                            if (mounted) setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),

                        _SectionLabel(context.tr('จัดการบัญชี', 'Account Management')),
                        const SizedBox(height: 8),
                        _SettingsTile(
                          icon: Icons.delete_forever_rounded,
                          title: context.tr('ลบบัญชี', 'Delete Account'),
                          subtitle: context.tr(
                            'ลบข้อมูลทั้งหมดอย่างถาวร',
                            'Permanently delete all data',
                          ),
                          danger: true,
                          onTap: _confirmDeleteAccount,
                        ),
                      ],
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
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: context.primaryTextColor,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? trailing;
  final bool danger;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFEF4444) : AppTheme.primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: danger
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF271A1C)
                      : const Color(0xFFFFF7F7))
                  : context.surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: danger
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF7F1D1D)
                        : const Color(0xFFFECACA))
                    : context.borderColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: danger
                              ? const Color(0xFFDC2626)
                              : context.primaryTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.secondaryTextColor,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else ...[
                  if (trailingText != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Text(
                        trailingText!,
                        style: TextStyle(
                          color: context.secondaryTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: danger
                        ? const Color(0xFFFCA5A5)
                        : context.secondaryTextColor,
                    size: 21,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
