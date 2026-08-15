import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import 'contact_admin_screen.dart';
import 'faq_screen.dart';
import 'support_request_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  void _showUserManual(BuildContext parentContext) {
    showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: parentContext.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(),
              Text(
                parentContext.tr('คู่มือการใช้งาน', 'User Manual'),
                style: TextStyle(
                  color: parentContext.primaryTextColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                parentContext.tr(
                  '1. บันทึกรายการ: พิมพ์รายการในช่องแชท เช่น "อาหาร 60" หรือ "+เงินเดือน 20000"\n\n'
                  '2. วางแผนรายรับรายจ่าย: เพิ่มรายการประจำเดือนในแท็บรายการประจำ\n\n'
                  '3. ตั้งเป้าหมายการออม: สร้างเป้าหมายในแท็บ Dreams และติดตามความคืบหน้า',
                  '1. Fast Recording: Type transactions in the chat box, such as "Lunch 60" or "+Salary 20000".\n\n'
                  '2. Recurring Plans: Add monthly income and expenses in the Recurring tabs.\n\n'
                  '3. Savings Goals: Create a goal in the Dreams tab and track your progress.',
                ),
                style: TextStyle(
                  color: parentContext.secondaryTextColor,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeatureSuggestion(BuildContext parentContext) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final apiClient = ApiClient();
    var isSubmitting = false;

    showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: parentContext.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                Text(
                  parentContext.tr('เสนอฟีเจอร์', 'Suggest a Feature'),
                  style: TextStyle(
                    color: parentContext.primaryTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  maxLength: 160,
                  decoration: InputDecoration(
                    labelText: parentContext.tr('ชื่อฟีเจอร์', 'Feature title'),
                    hintText: parentContext.tr(
                      'เช่น เพิ่มการสแกนใบเสร็จ',
                      'e.g. Add receipt scanning',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 10000,
                  decoration: InputDecoration(
                    alignLabelWithHint: true,
                    labelText: parentContext.tr('รายละเอียด', 'Description'),
                    hintText: parentContext.tr(
                      'อธิบายว่าฟีเจอร์นี้จะช่วยอะไร',
                      'Explain how this feature would help.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final title = titleController.text.trim();
                            final description = descriptionController.text.trim();
                            if (title.length < 3 || description.isEmpty) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    parentContext.tr(
                                      'กรุณากรอกชื่อและรายละเอียดฟีเจอร์',
                                      'Please enter a feature title and description.',
                                    ),
                                  ),
                                ),
                              );
                              return;
                            }

                            setSheetState(() => isSubmitting = true);
                            final response = await apiClient.post(
                              '/feature-requests',
                              body: {
                                'title': title,
                                'description': description,
                              },
                            );
                            if (!sheetContext.mounted) return;

                            if (response.statusCode >= 200 && response.statusCode < 300) {
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    parentContext.tr(
                                      'ส่งข้อเสนอเรียบร้อยแล้ว ทีมงานได้รับข้อมูลแล้ว',
                                      'Thank you. Your feature request has been submitted.',
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              setSheetState(() => isSubmitting = false);
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    parentContext.tr(
                                      'ส่งข้อเสนอไม่สำเร็จ กรุณาลองใหม่',
                                      'Unable to submit the feature request. Please try again.',
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(parentContext.tr('ส่งข้อเสนอ', 'Submit Suggestion')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      titleController.dispose();
      descriptionController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageColor,
      appBar: AppBar(
        title: Text(context.tr('ช่วยเหลือและสนับสนุน', 'Help & Support')),
        foregroundColor: context.primaryTextColor,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: FloatingBackground()),
          SafeArea(
            top: false,
            child: ResponsiveLayout(
              maxWidth: 600,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _SectionLabel(context.tr('ศูนย์ช่วยเหลือ', 'Help Center')),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.question_answer_rounded,
                    title: context.tr('คำถามที่พบบ่อย (FAQ)', 'FAQ'),
                    subtitle: context.tr(
                      'รวมคำตอบสำหรับปัญหาที่พบบ่อย',
                      'Common questions and answers',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FaqScreen()),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.menu_book_rounded,
                    title: context.tr('คู่มือการใช้งาน', 'User Manual'),
                    subtitle: context.tr(
                      'เรียนรู้วิธีใช้แอปพลิเคชัน',
                      'Learn how to use the app',
                    ),
                    onTap: () => _showUserManual(context),
                  ),
                  const SizedBox(height: 16),
                  _SectionLabel(context.tr('ติดต่อและรายงาน', 'Contact & Feedback')),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.support_agent_rounded,
                    title: context.tr('ติดต่อแอดมิน', 'Contact Us'),
                    subtitle: context.tr(
                      'ติดต่อผ่าน LINE, Facebook หรือ Email',
                      'Chat via LINE, Facebook, or email',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactAdminScreen()),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.bug_report_rounded,
                    title: context.tr('รายงานปัญหา', 'Report a Bug'),
                    subtitle: context.tr(
                      'แจ้งปัญหาการใช้งานหรือแอปขัดข้อง',
                      'Report a bug or crash',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupportRequestScreen(ticketType: 'bug'),
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.lightbulb_rounded,
                    title: context.tr('เสนอฟีเจอร์', 'Suggest a Feature'),
                    subtitle: context.tr(
                      'บอกเราว่าอยากให้เพิ่มอะไร',
                      'Tell us what features you want',
                    ),
                    onTap: () => _showFeatureSuggestion(context),
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
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
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
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
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderColor),
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
                    color: AppTheme.primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 20),
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
                          color: context.primaryTextColor,
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.secondaryTextColor,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
