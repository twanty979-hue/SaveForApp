import 'dart:convert';

import 'package:app/core/localization/app_material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';

class NotificationInboxSheet extends StatefulWidget {
  const NotificationInboxSheet({super.key});

  @override
  State<NotificationInboxSheet> createState() => _NotificationInboxSheetState();
}

class _NotificationInboxSheetState extends State<NotificationInboxSheet> {
  final ApiClient _apiClient = ApiClient();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await _apiClient.get('/notifications?limit=50');
      if (response.statusCode != 200) throw Exception(response.body);
      final decoded = jsonDecode(response.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _items = decoded.cast<Map<String, dynamic>>();
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'ยังโหลดการแจ้งเตือนไม่ได้ กรุณาลองอีกครั้ง';
      });
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['read_at'] != null) return;
    final id = item['id']?.toString();
    if (id == null) return;
    final response = await _apiClient.patch('/notifications/$id/read');
    if (response.statusCode >= 200 && response.statusCode < 300 && mounted) {
      setState(() => item['read_at'] = DateTime.now().toIso8601String());
      await NotificationService.instance.refreshUnreadCount();
    }
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'expense':
        return Icons.south_west_rounded;
      case 'income':
        return Icons.north_east_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'expense':
        return const Color(0xFFEF4444);
      case 'income':
        return const Color(0xFF16A085);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  String _timeLabel(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}/${date.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      decoration: BoxDecoration(
        color: context.pageColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'การแจ้งเตือน',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'รีเฟรช',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 42,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 10),
            Text(
              'ยังไม่มีการแจ้งเตือน',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final item = _items[index];
        final type = item['type']?.toString();
        final color = _colorFor(type);
        final unread = item['read_at'] == null;
        return Material(
          color: Theme.of(context).brightness == Brightness.dark
              ? (unread ? const Color(0xFF1E293B) : const Color(0xFF162033))
              : (unread ? Colors.white : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _markRead(item),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.11),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_iconFor(type), color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['title']?.toString() ?? 'SaveFor',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: unread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Text(
                              _timeLabel(item['sent_at']),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['body']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unread) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
