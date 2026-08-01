import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../auth/domain/auth_session.dart';

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final bool isThinking;
  final Map<String, dynamic>? cardData;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.isThinking = false,
    this.cardData,
  });
}

class TransactionItem {
  final String name;
  final double amount;
  final DateTime date;

  TransactionItem({
    required this.name,
    required this.amount,
    required this.date,
  });
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final List<Message> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final ApiClient _apiClient = ApiClient();
  String get _activeUserId {
    if (AuthSession.userId == null) {
      throw Exception('เข้าถึงข้อมูลโดยไม่ได้รับอนุญาต กรุณาเข้าสู่ระบบก่อน');
    }
    return AuthSession.userId!;
  }
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPastTransactions();
  }

  Future<void> _loadPastTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.get(
        '/transactions?user_id=eq.$_activeUserId&order=transaction_date.asc',
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _messages.clear();
          _messages.add(
            Message(
              text: 'สวัสดีครับ ยินดีต้อนรับกลับมาครับ! ด้านล่างนี้คือประวัติรายการของคุณที่บันทึกไว้ใน Supabase ครับ',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );

          for (var tx in data) {
            final name = tx['note'] ?? '';
            final amount = (tx['amount'] as num).toDouble();
            final dateStr = tx['transaction_date'] ?? '';
            final timestamp = DateTime.tryParse(dateStr) ?? DateTime.now();
            final type = tx['type'] ?? 'expense';

            String displayName = name;
            String category = 'รายจ่าย';

            if (name.startsWith('[ออม] หยอดกระปุก: ')) {
              displayName = name.replaceAll('[ออม] หยอดกระปุก: ', '');
              category = 'เงินออม';
            } else if (name.startsWith('[รายจ่ายประจำ] ')) {
              displayName = name.replaceAll('[รายจ่ายประจำ] ', '');
              category = 'รายจ่าย';
            } else if (name.startsWith('[รายรับประจำ] ')) {
              displayName = name.replaceAll('[รายรับประจำ] ', '');
              category = 'รายรับ';
            } else if (type == 'income') {
              category = 'รายรับ';
            }

            _messages.add(
              Message(
                text: '',
                isUser: false,
                timestamp: timestamp,
                cardData: {
                  'name': displayName,
                  'amount': amount,
                  'category': category,
                },
              ),
            );
          }
        });
        _scrollToBottom();
      } else {
        _showErrorPlaceholder();
      }
    } catch (e) {
      _showErrorPlaceholder();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorPlaceholder() {
    setState(() {
      _messages.clear();
      _messages.add(
        Message(
          text: 'สวัสดีครับ พิมพ์รายการได้เลย เช่น "กาแฟ 50" หรือใช้เครื่องหมายระบุประเภท "+รายรับ", "*เงินออม" ครับ (เปิดโหมดสำรองชั่วคราวเนื่องจากติดต่อเซิร์ฟเวอร์ไม่ได้)',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ระบบประมวลผลคำออกแบบวิธีเดียวเป็นเอกภาพ (Unified Symbol-Based Parser) ตามความต้องการของผู้ใช้
  // เครื่องหมายนำหน้าคำ:
  // '+' = รายรับ (Income)
  // '*' = เงินออม / ความฝัน (Savings/Dreams)
  // '-' หรือไม่มีเครื่องหมาย = รายจ่าย (Expense)
  List<Map<String, dynamic>> _parseInput(String input) {
    final RegExp regex = RegExp(r'([+*-]?[^\d\s]+)\s*(\d+)');
    final matches = regex.allMatches(input);
    List<Map<String, dynamic>> results = [];
    for (var match in matches) {
      final name = match.group(1)?.trim() ?? '';
      final amountStr = match.group(2) ?? '0';
      final amount = double.tryParse(amountStr) ?? 0.0;
      if (name.isNotEmpty && amount > 0) {
        String type = 'expense';
        String note = name;
        String category = 'รายจ่าย';

        if (name.startsWith('+')) {
          type = 'income';
          category = 'รายรับ';
          note = name.substring(1).trim();
        } else if (name.startsWith('*')) {
          type = 'expense';
          category = 'เงินออม';
          final dreamTitle = name.substring(1).trim();
          note = '[ออม] หยอดกระปุก: $dreamTitle';
        } else {
          type = 'expense';
          category = 'รายจ่าย';
          note = name.startsWith('-') ? name.substring(1).trim() : name;
        }

        results.add({
          'name': name.replaceAll(RegExp(r'^[+*-]'), '').trim(),
          'note': note,
          'amount': amount,
          'type': type,
          'category': category,
        });
      }
    }
    return results;
  }

  void _handleSendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        Message(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
    });
    _inputController.clear();
    _scrollToBottom();

    final thinkingMessage = Message(
      text: 'กำลังคิด . . .',
      isUser: false,
      timestamp: DateTime.now(),
      isThinking: true,
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _messages.add(thinkingMessage);
      });
      _scrollToBottom();
    });

    Future.delayed(const Duration(milliseconds: 1200), () async {
      final parsedItems = _parseInput(text);

      setState(() {
        _messages.remove(thinkingMessage);
      });

      if (parsedItems.isEmpty) {
        setState(() {
          _messages.add(
            Message(
              text: 'เกิดข้อผิดพลาดในการบันทึกข้อมูลครับ',
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
            ),
          );
        });
        _scrollToBottom();
        return;
      }

      for (var item in parsedItems) {
        final name = item['name'] as String;
        final note = item['note'] as String;
        final amount = item['amount'] as double;
        final type = item['type'] as String;
        final category = item['category'] as String;

        try {
          final body = {
            'user_id': _activeUserId,
            'type': type,
            'amount': amount,
            'note': note,
            'transaction_date': DateTime.now().toUtc().toIso8601String(),
          };

          final response = await _apiClient.post('/transactions', body: body);

          if (response.statusCode == 200 || response.statusCode == 201) {
            if (note.startsWith('[ออม] หยอดกระปุก: ')) {
              final dreamTitle = note.replaceAll('[ออม] หยอดกระปุก: ', '').trim();
              
              final dreamsResp = await _apiClient.get('/dreams?user_id=eq.$_activeUserId&title=eq.$dreamTitle');
              if (dreamsResp.statusCode == 200) {
                final List<dynamic> matchingDreams = jsonDecode(dreamsResp.body);
                if (matchingDreams.isNotEmpty) {
                  final dream = matchingDreams.first;
                  final double newSaved = (dream['current_amount'] as num).toDouble() + amount;
                  
                  await _apiClient.post('/dreams?id=eq.${dream['id']}', body: {
                    'current_amount': newSaved,
                  });
                }
              }
            }

            setState(() {
              _messages.add(
                Message(
                  text: '',
                  isUser: false,
                  timestamp: DateTime.now(),
                  cardData: {
                    'name': name,
                    'amount': amount,
                    'category': category,
                  },
                ),
              );
            });
          } else {
            _addLocalFallbackMessage(name, amount, category);
          }
        } catch (e) {
          _addLocalFallbackMessage(name, amount, category);
        }
      }
      _scrollToBottom();
    });
  }

  void _addLocalFallbackMessage(String name, double amount, String category) {
    setState(() {
      _messages.add(
        Message(
          text: 'บันทึกสำเร็จชั่วคราวในเครื่อง (ไม่สามารถเชื่อมโยงระบบเน็ตได้ชั่วคราว)',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      _messages.add(
        Message(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          cardData: {
            'name': name,
            'amount': amount,
            'category': category,
          },
        ),
      );
    });
  }

  Widget _buildBotAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF00A88F), Color(0xFF00C2A5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00A88F).withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    if (message.cardData != null) {
      final card = message.cardData!;
      final name = card['name'] ?? '';
      final amount = (card['amount'] as num?)?.toDouble() ?? 0.0;
      final category = card['category'] ?? 'รายจ่าย';

      Color categoryColor = const Color(0xFF10B981); 
      if (category == 'รายจ่าย') {
        categoryColor = const Color(0xFFEF4444); 
      } else if (category == 'เงินออม') {
        categoryColor = const Color(0xFFF59E0B); 
      }

      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(left: 48, right: 48, top: 4, bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '฿${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: categoryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'บันทึกแล้ว',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_circle,
                    size: 12,
                    color: categoryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isUser ? 64 : 16,
          right: isUser ? 16 : 64,
          top: 4,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF00A88F) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: message.isThinking
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
                  ),
                ],
              )
            : Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(
            child: FloatingBackground(),
          ),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isUser = message.isUser;
                    final showAvatar = !isUser && (index == 0 || _messages[index - 1].isUser);

                    if (showAvatar) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBotAvatar(),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMessageBubble(message),
                          ),
                        ],
                      );
                    } else {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser) const SizedBox(width: 40),
                          Expanded(
                            child: _buildMessageBubble(message),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mic_none_outlined, color: Color(0xFF64748B), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _inputController,
                                decoration: const InputDecoration(
                                  hintText: 'พิมพ์รายการของคุณ เช่น ซื้อกาแฟ 50 บาท',
                                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _handleSendMessage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _handleSendMessage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF5ED5A8), 
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
