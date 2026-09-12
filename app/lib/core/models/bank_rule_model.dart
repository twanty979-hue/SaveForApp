import '../services/slip_parser_service.dart';

class BankRuleConfig {
  final String id;
  final String name;
  final String appName;
  final BankType bankType;
  final String? logoUrl;
  final List<String> albumKeywords;
  final bool isEnabled;
  final bool isCustom;
  final String? colorHex;
  final int? priority;
  final String? updatedAt;

  const BankRuleConfig({
    required this.id,
    required this.name,
    required this.appName,
    required this.bankType,
    this.logoUrl,
    required this.albumKeywords,
    this.isEnabled = true,
    this.isCustom = false,
    this.colorHex,
    this.priority,
    this.updatedAt,
  });

  BankRuleConfig copyWith({
    String? id,
    String? name,
    String? appName,
    BankType? bankType,
    String? logoUrl,
    List<String>? albumKeywords,
    bool? isEnabled,
    bool? isCustom,
    String? colorHex,
    int? priority,
    String? updatedAt,
  }) {
    return BankRuleConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      appName: appName ?? this.appName,
      bankType: bankType ?? this.bankType,
      logoUrl: logoUrl ?? this.logoUrl,
      albumKeywords: albumKeywords ?? this.albumKeywords,
      isEnabled: isEnabled ?? this.isEnabled,
      isCustom: isCustom ?? this.isCustom,
      colorHex: colorHex ?? this.colorHex,
      priority: priority ?? this.priority,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'appName': appName,
      'bankType': bankType.name,
      if (logoUrl != null) 'logoUrl': logoUrl,
      'albumKeywords': albumKeywords,
      'isEnabled': isEnabled,
      'isCustom': isCustom,
      if (colorHex != null) 'colorHex': colorHex,
      if (priority != null) 'priority': priority,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  factory BankRuleConfig.fromJson(Map<String, dynamic> json) {
    final bTypeStr = (json['bankType'] ?? json['bank_type'] ?? 'other').toString().toLowerCase();
    final bankType = BankType.values.firstWhere(
      (e) => e.name == bTypeStr,
      orElse: () => BankType.other,
    );

    final rawKeywords = json['albumKeywords'] ?? json['album_keywords'] ?? [];
    List<String> keywords = [];
    if (rawKeywords is List) {
      keywords = rawKeywords.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    return BankRuleConfig(
      id: (json['id'] ?? json['bank_id'] ?? bTypeStr).toString(),
      name: (json['name'] ?? 'ธนาคาร').toString(),
      appName: (json['appName'] ?? json['app_name'] ?? '').toString(),
      bankType: bankType,
      logoUrl: (json['logoUrl'] ?? json['logo_url']) as String?,
      albumKeywords: keywords,
      isEnabled: json['isEnabled'] ?? json['is_enabled'] ?? true,
      isCustom: json['isCustom'] ?? json['is_custom'] ?? false,
      colorHex: json['colorHex'] ?? json['color_hex'] as String?,
      priority: (json['priority'] as num?)?.toInt(),
      updatedAt: (json['updatedAt'] ?? json['updated_at']) as String?,
    );
  }

  static List<BankRuleConfig> get defaultRules => [
    const BankRuleConfig(
      id: 'kbank',
      name: 'กสิกรไทย',
      appName: 'K PLUS • Kasikornbank',
      bankType: BankType.kbank,
      logoUrl: '/images/banks/kbank.png',
      albumKeywords: ['k plus', 'kplus', 'k-plus', 'kasikorn', 'กสิกร'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#00A950',
      priority: 1,
    ),
    const BankRuleConfig(
      id: 'scb',
      name: 'ไทยพาณิชย์',
      appName: 'SCB EASY • แม่มณี',
      bankType: BankType.scb,
      logoUrl: '/images/banks/scb.png',
      albumKeywords: ['scb easy', 'scbeasy', 'scb', 'แม่มณี', 'ไทยพาณิชย์'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#4E2A84',
      priority: 2,
    ),
    const BankRuleConfig(
      id: 'krungsri',
      name: 'กรุงศรีอยุธยา',
      appName: 'KMA • Bank of Ayudhya',
      bankType: BankType.krungsri,
      logoUrl: '/images/banks/krungsri.png',
      albumKeywords: ['krungsri', 'kma', 'bay', 'กรุงศรี'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#7A6400',
      priority: 3,
    ),
    const BankRuleConfig(
      id: 'truemoney',
      name: 'ทรูมันนี่',
      appName: 'TrueMoney Wallet',
      bankType: BankType.truemoney,
      logoUrl: '/images/banks/truemoney.png',
      albumKeywords: ['truemoney', 'true money', 'ทรูมันนี่', 'tmn'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#FF6600',
      priority: 4,
    ),
    const BankRuleConfig(
      id: 'ktb',
      name: 'กรุงไทย',
      appName: 'Krungthai NEXT',
      bankType: BankType.ktb,
      logoUrl: '/images/banks/ktb.png',
      albumKeywords: ['krungthai', 'ktb', 'สลิปกรุงไทย', 'กรุงไทย'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#00AEEF',
      priority: 5,
    ),
  ];
}
