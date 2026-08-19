import 'package:app/core/localization/app_material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': context.tr('แอป SaveFor คืออะไร?', 'What is SaveFor app?'),
        'a': context.tr(
          'SaveFor เป็นแอปพลิเคชันช่วยจัดการการออมเงิน ตั้งเป้าหมาย และติดตามค่าใช้จ่ายต่างๆ เพื่อให้คุณถึงเป้าหมายได้เร็วขึ้น',
          'SaveFor is an app that helps you manage savings, set goals, and track expenses to reach your financial goals faster.'
        ),
      },
      {
        'q': context.tr('วิธีตั้งเป้าหมายการออมทำอย่างไร?', 'How to set a savings goal?'),
        'a': context.tr(
          'ไปที่หน้าเป้าหมาย (Dreams) กดปุ่ม + ด้านขวาล่าง เลือกลักษณะไอคอน และกรอกจำนวนเงินที่คุณต้องการออม',
          'Go to the Dreams page, tap the + button at the bottom right, select an icon, and enter the amount you want to save.'
        ),
      },
      {
        'q': context.tr('ข้อมูลของฉันปลอดภัยหรือไม่?', 'Is my data safe?'),
        'a': context.tr(
          'ข้อมูลของคุณถูกจัดเก็บอย่างปลอดภัยบนคลาวด์ พร้อมระบบเข้ารหัสข้อมูล และเราไม่มีนโยบายส่งต่อข้อมูลให้บุคคลที่สาม',
          'Your data is securely stored in the cloud with encryption. We do not share your data with third parties.'
        ),
      },
    ];

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
                            context.tr('คำถามที่พบบ่อย (FAQ)', 'FAQ'),
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
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: faqs.length,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          elevation: 0,
                          color: Colors.white.withValues(alpha: 0.9),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              title: Text(
                                faqs[index]['q']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Text(
                                    faqs[index]['a']!,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
