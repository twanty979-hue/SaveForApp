import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';

class ContactAdminScreen extends StatefulWidget {
  const ContactAdminScreen({super.key});

  @override
  State<ContactAdminScreen> createState() => _ContactAdminScreenState();
}

class _ContactAdminScreenState extends State<ContactAdminScreen> {
  final _apiClient = ApiClient();
  List<_SupportChannel> _channels = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    final response = await _apiClient.get('/support/channels');
    if (!mounted) return;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _channels = data
              .whereType<Map<String, dynamic>>()
              .map(_SupportChannel.fromJson)
              .toList();
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      } catch (_) {
        // Fall through to the same visible error state as an API failure.
      }
    }
    setState(() {
      _isLoading = false;
      _errorMessage = context.tr(
        'ไม่สามารถโหลดช่องทางติดต่อได้',
        'Unable to load contact channels.',
      );
    });
  }

  Future<void> _openChannel(_SupportChannel channel) async {
    final launched = await launchUrl(
      Uri.parse(channel.url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'ไม่สามารถเปิดช่องทางนี้ได้',
              'Unable to open this contact channel.',
            ),
          ),
        ),
      );
    }
  }

  IconData _iconFor(String iconKey) {
    switch (iconKey) {
      case 'facebook':
        return Icons.facebook_rounded;
      case 'email':
        return Icons.email_rounded;
      default:
        return Icons.chat_bubble_rounded;
    }
  }

  Color _colorFor(String iconKey) {
    switch (iconKey) {
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'email':
        return const Color(0xFFEA4335);
      default:
        return const Color(0xFF00B900);
    }
  }

  Widget _buildContactCard(BuildContext context, _SupportChannel channel) {
    final color = _colorFor(channel.iconKey);
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
          child: Icon(_iconFor(channel.iconKey), color: color),
        ),
        title: Text(
          channel.label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          channel.address,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: () => _openChannel(channel),
      ),
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
                            context.tr('ติดต่อแอดมิน', 'Contact Admin'),
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
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                            children: [
                              if (_errorMessage != null)
                                Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: context.secondaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                        onPressed: () {
                                          setState(() => _isLoading = true);
                                          _loadChannels();
                                        },
                                        child: Text(context.tr('ลองใหม่', 'Retry')),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ..._channels.map(
                                  (channel) => _buildContactCard(context, channel),
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

class _SupportChannel {
  final String label;
  final String address;
  final String url;
  final String iconKey;

  const _SupportChannel({
    required this.label,
    required this.address,
    required this.url,
    required this.iconKey,
  });

  factory _SupportChannel.fromJson(Map<String, dynamic> json) {
    return _SupportChannel(
      label: json['label']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      iconKey: json['icon_key']?.toString() ?? 'chat',
    );
  }
}
