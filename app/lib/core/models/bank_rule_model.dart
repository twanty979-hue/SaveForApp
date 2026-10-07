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
      albumKeywords: ['krungthai', 'ktb', 'สลิปกรุงไทย', 'กรุงไทย', 'เป๋าตัง'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#00AEEF',
      priority: 5,
    ),
    const BankRuleConfig(
      id: 'ttb',
      name: 'ทีเอ็มบีธนชาต',
      appName: 'ttb touch',
      bankType: BankType.ttb,
      logoUrl: '/images/banks/ttb.png',
      albumKeywords: ['ttb', 'ttb touch', 'ธนชาต', 'tmb', 'thanachart', 'ทีเอ็มบี'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#002D62',
      priority: 6,
    ),
    const BankRuleConfig(
      id: 'bbl',
      name: 'กรุงเทพ',
      appName: 'Bangkok Bank • Bualuang mBanking',
      bankType: BankType.bbl,
      logoUrl: '/images/banks/bbl.png',
      albumKeywords: ['bualuang', 'bbl', 'bangkok bank', 'บัวหลวง', 'กรุงเทพ'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#1E3A8A',
      priority: 7,
    ),
    const BankRuleConfig(
      id: 'gsb',
      name: 'ออมสิน',
      appName: 'MyMo by GSB',
      bankType: BankType.gsb,
      logoUrl: '/images/banks/gsb.png',
      albumKeywords: ['mymo', 'gsb', 'ออมสิน'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#E91E63',
      priority: 8,
    ),
    const BankRuleConfig(
      id: 'kkp',
      name: 'เกียรตินาคินภัทร',
      appName: 'Dime! • KKP Mobile',
      bankType: BankType.kkp,
      logoUrl: '/images/banks/kkp.png',
      albumKeywords: ['dime', 'kkp', 'เกียรตินาคิน', 'kiatnakin', 'phatra', 'ไดม์'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#652D86',
      priority: 9,
    ),
    const BankRuleConfig(
      id: 'baac',
      name: 'ธ.ก.ส.',
      appName: 'BAAC Mobile • A-Mobile Plus',
      bankType: BankType.baac,
      logoUrl: '/images/banks/baac.png',
      albumKeywords: ['baac', 'ธกส', 'ธ.ก.ส.', 'a-mobile'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#006837',
      priority: 10,
    ),
    const BankRuleConfig(
      id: 'uob',
      name: 'ยูโอบี',
      appName: 'UOB TMRW Thailand',
      bankType: BankType.uob,
      logoUrl: '/images/banks/uob.png',
      albumKeywords: ['uob', 'tmrw', 'ยูโอบี'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#0B2265',
      priority: 11,
    ),
    const BankRuleConfig(
      id: 'cimb',
      name: 'ซีไอเอ็มบี ไทย',
      appName: 'CIMB THAI Digital Banking',
      bankType: BankType.cimb,
      logoUrl: '/images/banks/cimb.png',
      albumKeywords: ['cimb', 'ซีไอเอ็มบี', 'cimb thai'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#7E1518',
      priority: 12,
    ),
    const BankRuleConfig(
      id: 'lhb',
      name: 'แลนด์ แอนด์ เฮ้าส์',
      appName: 'LHB You • LH Bank',
      bankType: BankType.lhb,
      logoUrl: '/images/banks/lhb.png',
      albumKeywords: ['lhb', 'lh bank', 'lhbank', 'แลนด์ แอนด์ เฮ้าส์'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#009688',
      priority: 13,
    ),
    const BankRuleConfig(
      id: 'tisco',
      name: 'ทิสโก้',
      appName: 'TISCO My Car / Mobile',
      bankType: BankType.tisco,
      logoUrl: '/images/banks/tisco.png',
      albumKeywords: ['tisco', 'ทิสโก้'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#1A5276',
      priority: 14,
    ),
    const BankRuleConfig(
      id: 'thaicredit',
      name: 'ไทยเครดิต',
      appName: 'Thai Credit Alpha',
      bankType: BankType.thaicredit,
      logoUrl: '/images/banks/thaicredit.png',
      albumKeywords: ['thai credit', 'thaicredit', 'ไทยเครดิต', 'alpha by thai credit'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#0288D1',
      priority: 15,
    ),
    const BankRuleConfig(
      id: 'shopeepay',
      name: 'ช้อปปี้เพย์',
      appName: 'ShopeePay • SeaMoney',
      bankType: BankType.shopeepay,
      logoUrl: '/images/banks/shopeepay.png',
      albumKeywords: ['shopeepay', 'shopee pay', 'airpay', 'ช้อปปี้เพย์'],
      isEnabled: true,
      isCustom: false,
      colorHex: '#EE4D2D',
      priority: 16,
    ),
  ];
}
