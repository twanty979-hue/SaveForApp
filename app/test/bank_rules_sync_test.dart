import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/models/bank_rule_model.dart';
import 'package:app/core/services/bank_rules_service.dart';
import 'package:app/core/settings/app_settings.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSettings.enabledAutoScanBanks.value = {
      'kbank',
      'scb',
      'krungsri',
      'truemoney',
    };
  });

  test('BankRulesService parses and activates new banks from Cloud (e.g. Krungthai)', () async {
    final sampleJson = jsonEncode({
      'rules': [
        {
          'id': 'kbank',
          'name': 'กสิกรไทย',
          'appName': 'K PLUS • Kasikornbank',
          'bankType': 'kbank',
          'albumKeywords': ['k plus', 'กสิกร'],
          'isEnabled': true,
        },
        {
          'id': 'custom_ktb',
          'name': 'กรุงไทย',
          'appName': 'Krungthai NEXT',
          'bankType': 'ktb',
          'logoUrl': '/images/banks/ktb.png',
          'albumKeywords': ['krungthai', 'ktb', 'สลิปกรุงไทย'],
          'isEnabled': true,
          'isCustom': true,
        }
      ]
    });

    final decoded = jsonDecode(sampleJson);
    final rawList = decoded['rules'] as List;
    final cloudRules = rawList
        .map((e) => BankRuleConfig.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    expect(cloudRules.length, 2);
    expect(cloudRules[1].name, 'กรุงไทย');
    expect(cloudRules[1].albumKeywords, contains('สลิปกรุงไทย'));
    expect(cloudRules[1].isEnabled, isTrue);

    // Apply to service notifier
    BankRulesService.rulesNotifier.value = cloudRules;
    expect(BankRulesService.rulesNotifier.value.any((r) => r.name == 'กรุงไทย'), isTrue);
  });
}
