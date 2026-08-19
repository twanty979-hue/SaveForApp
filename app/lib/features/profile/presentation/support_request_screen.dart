import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';

class SupportRequestScreen extends StatefulWidget {
  final String ticketType;

  const SupportRequestScreen({super.key, required this.ticketType});

  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _apiClient = ApiClient();
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isBugReport => widget.ticketType == 'bug';

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.length < 3 || message.isEmpty) {
      setState(() {
        _errorMessage = context.tr(
          'กรุณากรอกหัวข้ออย่างน้อย 3 ตัวอักษรและรายละเอียดให้ครบถ้วน',
          'Please enter a subject of at least 3 characters and a message.',
        );
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final response = await _apiClient.post(
      '/support/tickets',
      body: {
        'ticket_type': widget.ticketType,
        'subject': subject,
        'message': message,
      },
    );

    if (!mounted) return;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'ส่งข้อมูลเรียบร้อยแล้ว ทีมงานจะตรวจสอบให้ครับ',
              'Submitted successfully. Our team will review it.',
            ),
          ),
        ),
      );
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _errorMessage = context.tr(
        'ไม่สามารถส่งข้อมูลได้ กรุณาลองใหม่อีกครั้ง',
        'Unable to submit. Please try again.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _isBugReport
        ? context.tr('รายงานปัญหา', 'Report a Bug')
        : context.tr('ติดต่อแอดมิน', 'Contact Us');
    final description = _isBugReport
        ? context.tr(
            'อธิบายปัญหาและขั้นตอนที่ทำให้เกิดปัญหา',
            'Tell us what happened and how we can reproduce it.',
          )
        : context.tr(
            'ส่งข้อความถึงทีมงาน SaveFor โดยตรง',
            'Send a message directly to the SaveFor team.',
          );

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
                            title,
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
                        Text(
                          description,
                          style: TextStyle(
                            color: context.secondaryTextColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _subjectController,
                          maxLength: 160,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: context.tr('หัวข้อ', 'Subject'),
                            hintText: _isBugReport
                                ? context.tr('เช่น ปุ่มบันทึกกดไม่ได้', 'e.g. Save button does not work')
                                : context.tr('เช่น ขอเพิ่มการสแกนใบเสร็จ', 'e.g. Add receipt scanning'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _messageController,
                          minLines: 5,
                          maxLines: 9,
                          maxLength: 10000,
                          decoration: InputDecoration(
                            alignLabelWithHint: true,
                            labelText: _isBugReport
                                ? context.tr('รายละเอียดปัญหา', 'Problem details')
                                : context.tr('รายละเอียดข้อเสนอ', 'Request details'),
                            hintText: context.tr(
                              'พิมพ์รายละเอียดที่นี่...',
                              'Type the details here...',
                            ),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(context.tr('ส่งข้อมูล', 'Submit')),
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                          ),
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
