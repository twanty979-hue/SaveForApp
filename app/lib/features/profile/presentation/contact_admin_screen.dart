import 'package:app/core/localization/app_material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';

class ContactAdminScreen extends StatelessWidget {
  const ContactAdminScreen({super.key});

  Widget _buildContactCard(BuildContext context, IconData icon, String title, String detail, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.9),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(detail, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('กำลังเปิดลิงก์...', 'Opening link...'))),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageColor,
      appBar: AppBar(
        title: Text(context.tr('ติดต่อแอดมิน', 'Contact Admin')),
        foregroundColor: context.primaryTextColor,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: FloatingBackground()),
          SafeArea(
            child: ResponsiveLayout(
              maxWidth: 600,
              child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildContactCard(
                context,
                Icons.chat_bubble_rounded,
                'LINE Official',
                'bs_boll',
                const Color(0xFF00B900),
              ),
              _buildContactCard(
                context,
                Icons.facebook_rounded,
                'Facebook',
                'https://www.facebook.com/worathon.namthong.2025/',
                const Color(0xFF1877F2),
              ),
              _buildContactCard(
                context,
                Icons.email_rounded,
                'Email Support',
                'support@savefor.app',
                const Color(0xFFEA4335),
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
