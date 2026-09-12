import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bank_rule_model.dart';
import '../network/api_client.dart';
import '../settings/app_settings.dart';
import 'slip_scanner_bridge.dart';

import 'package:http/http.dart' as http;

/// Service for managing Bank Album Rules (Read-only on Mobile, synchronized from Cloud)
class BankRulesService {
  static const String _prefRulesKey = 'cached_bank_album_rules';
  static const String _prefDisabledKey = 'disabled_auto_scan_banks';

  static final ValueNotifier<List<BankRuleConfig>> rulesNotifier =
      ValueNotifier<List<BankRuleConfig>>(BankRuleConfig.defaultRules);

  static bool _initialized = false;

  /// Initialize and load cached rules, then sync from Cloud in background
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Load from local cache
    await loadFromLocal();

    // 2. Sync to Native scanner immediately
    await syncToNative();

    // 3. Sync from Cloud in background
    syncFromCloud();
  }

  /// Load rules from SharedPreferences
  static Future<void> loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefRulesKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final loaded = decoded
              .map((e) => BankRuleConfig.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (loaded.isNotEmpty) {
            rulesNotifier.value = loaded;
            _applyToAppSettings(loaded);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[BankRulesService] Failed to load local cache: $e');
    }

    // Default fallback
    rulesNotifier.value = BankRuleConfig.defaultRules;
    _applyToAppSettings(BankRuleConfig.defaultRules);
  }

  /// Fetch latest rules from Cloud API (Read-only fetch)
  static Future<bool> syncFromCloud() async {
    List<dynamic>? rawList;

    // 1. Try Supabase Public Cloud Storage directly (Global CDN, no auth needed), or local dev portal
    final candidateUrls = [
      'https://nqgmimfkxgkkofaoddre.supabase.co/storage/v1/object/public/app_config/bank_rules.json?t=${DateTime.now().millisecondsSinceEpoch}',
      'http://127.0.0.1:3000/api/bank-rules',
      'http://localhost:3000/api/bank-rules',
      'http://10.0.2.2:3000/api/bank-rules',
    ];

    for (final url in candidateUrls) {
      try {
        final client = http.Client();
        final res = await client.get(
          Uri.parse(url),
          headers: const {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(milliseconds: 3000));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          final list = decoded['rules'] ?? decoded;
          if (list is List && list.isNotEmpty) {
            rawList = list;
            debugPrint('[BankRulesService] Loaded rules from: $url');
            break;
          }
        }
      } catch (_) {}
    }

    // 2. If not found locally, try ApiClient (Production Cloud API)
    if (rawList == null || rawList.isEmpty) {
      try {
        final apiClient = ApiClient();
        final response = await apiClient.get('/bank-rules');
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final list = decoded['rules'] ?? decoded;
          if (list is List && list.isNotEmpty) {
            rawList = list;
          }
        }
      } catch (e) {
        debugPrint('[BankRulesService] ApiClient sync skipped/failed: $e');
      }
    }

    if (rawList is List && rawList.isNotEmpty) {
      try {
        final cloudRules = rawList
            .map((e) => BankRuleConfig.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        // Check local disabled preferences
        final prefs = await SharedPreferences.getInstance();
        final disabledBanks = (prefs.getStringList(_prefDisabledKey) ?? []).toSet();

        final updatedRules = cloudRules.map((r) {
          final bankId = r.id.toLowerCase();
          final bankType = r.bankType.name.toLowerCase();
          // Only disable if user explicitly turned it off on this device
          final isExplicitlyDisabled = disabledBanks.contains(bankId) || disabledBanks.contains(bankType);
          final isEnabled = isExplicitlyDisabled ? false : r.isEnabled;
          return r.copyWith(isEnabled: isEnabled);
        }).toList();

        rulesNotifier.value = updatedRules;
        _applyToAppSettings(updatedRules);

        // Save to local cache
        final encoded = jsonEncode(updatedRules.map((e) => e.toJson()).toList());
        await prefs.setString(_prefRulesKey, encoded);

        // Update Native Scanner Bridge
        await syncToNative();
        return true;
      } catch (e) {
        debugPrint('[BankRulesService] Error parsing rules: $e');
      }
    }
    return false;
  }

  /// Toggle bank enabled/disabled state on this device
  static Future<void> toggleBank(String bankId, bool isEnabled) async {
    final updated = rulesNotifier.value.map((r) {
      if (r.id.toLowerCase() == bankId.toLowerCase() ||
          r.bankType.name.toLowerCase() == bankId.toLowerCase()) {
        return r.copyWith(isEnabled: isEnabled);
      }
      return r;
    }).toList();

    rulesNotifier.value = updated;

    // Track explicit disabled preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final disabled = (prefs.getStringList(_prefDisabledKey) ?? []).toSet();
      if (!isEnabled) {
        disabled.add(bankId.toLowerCase());
      } else {
        disabled.remove(bankId.toLowerCase());
      }
      await prefs.setStringList(_prefDisabledKey, disabled.toList());

      final encoded = jsonEncode(updated.map((e) => e.toJson()).toList());
      await prefs.setString(_prefRulesKey, encoded);
    } catch (_) {}

    // Update AppSettings
    await AppSettings.setAutoScanBankEnabled(bankId, isEnabled);

    // Update Native Scanner Bridge
    await syncToNative();
  }

  /// Toggle all banks on or off
  static Future<void> toggleAll(bool isEnabled) async {
    final updated = rulesNotifier.value.map((r) => r.copyWith(isEnabled: isEnabled)).toList();
    rulesNotifier.value = updated;

    await AppSettings.setAllAutoScanBanksEnabled(isEnabled);

    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(updated.map((e) => e.toJson()).toList());
      await prefs.setString(_prefRulesKey, encoded);
    } catch (_) {}

    await syncToNative();
  }

  /// Send active bank rules and their album keywords to Native (iOS & Android)
  static Future<void> syncToNative() async {
    try {
      final activeRules = rulesNotifier.value.where((r) => r.isEnabled).toList();
      await SlipScannerBridge.instance.updateBankRules(activeRules);
    } catch (e) {
      debugPrint('[BankRulesService] Failed to sync to native: $e');
    }
  }

  static void _applyToAppSettings(List<BankRuleConfig> rules) {
    final activeKeys = rules.where((r) => r.isEnabled).map((r) => r.id.toLowerCase()).toSet();
    if (activeKeys.isNotEmpty) {
      AppSettings.enabledAutoScanBanks.value = activeKeys;
    }
  }
}
