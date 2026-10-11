import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/domain/auth_session.dart';
import '../network/api_client.dart';

enum SubscriptionTier {
  free,
  monthly,
  yearly,
}

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const String entitlementId = 'pro';
  static const String monthlyProductId = 'savefor_pro_monthly';
  static const String yearlyProductId = 'savefor_pro_yearly';
  static const String _prefIsProKey = 'pref_savefor_is_pro_active';
  static const String _prefTierKey = 'pref_savefor_pro_tier';
  static const String _prefExpiryKey = 'pref_savefor_pro_expiry';

  bool _initialized = false;
  bool _isPro = false;
  SubscriptionTier _activeTier = SubscriptionTier.free;
  DateTime? _expiryDate;
  Offerings? _offerings;

  final ValueNotifier<bool> isProNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<SubscriptionTier> tierNotifier =
      ValueNotifier<SubscriptionTier>(SubscriptionTier.free);

  bool get isPro => _isPro;
  SubscriptionTier get activeTier => _activeTier;
  DateTime? get expiryDate => _expiryDate;
  Offerings? get offerings => _offerings;

  /// Call during app initialization or login
  Future<void> initialize({String? userId}) async {
    // 1. Load locally cached status immediately for instant UI response
    await _loadCachedStatus();

    // Skip native RevenueCat initialization on web
    if (kIsWeb) return;

    final appleKey = dotenv.env['REVENUECAT_APPLE_API_KEY'] ?? '';
    final googleKey = dotenv.env['REVENUECAT_GOOGLE_API_KEY'] ?? '';
    final apiKey = Platform.isIOS ? appleKey : googleKey;

    if (apiKey.isEmpty || apiKey.startsWith('appl_placeholder') || apiKey.startsWith('goog_placeholder')) {
      debugPrint('[SubscriptionService] RevenueCat API Key is empty or placeholder. Running in test/mock mode.');
      return;
    }

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      final configuration = PurchasesConfiguration(apiKey)
        ..appUserID = userId;
      await Purchases.configure(configuration);

      _initialized = true;

      // Listen to customer info changes in real-time
      Purchases.addCustomerInfoUpdateListener(_updateCustomerInfo);

      // Fetch latest customer info and offerings
      final customerInfo = await Purchases.getCustomerInfo();
      _updateCustomerInfo(customerInfo);
      await fetchOfferings();
    } catch (e) {
      debugPrint('[SubscriptionService] Failed to initialize RevenueCat: $e');
    }
  }

  /// Call when user logs into Supabase
  Future<void> logIn(String userId) async {
    if (!_initialized || kIsWeb) return;
    try {
      final result = await Purchases.logIn(userId);
      _updateCustomerInfo(result.customerInfo);
      await fetchOfferings();
    } catch (e) {
      debugPrint('[SubscriptionService] Error logging in to RevenueCat: $e');
    }
  }

  /// Call when user logs out
  Future<void> logOut() async {
    if (!_initialized || kIsWeb) return;
    try {
      final customerInfo = await Purchases.logOut();
      _updateCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('[SubscriptionService] Error logging out of RevenueCat: $e');
    }
  }

  Future<void> _loadCachedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_prefIsProKey) ?? false;
    final tierStr = prefs.getString(_prefTierKey) ?? 'free';
    _activeTier = tierStr == 'yearly'
        ? SubscriptionTier.yearly
        : tierStr == 'monthly'
        ? SubscriptionTier.monthly
        : SubscriptionTier.free;
    final expiryMillis = prefs.getInt(_prefExpiryKey);
    if (expiryMillis != null) {
      _expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      if (_expiryDate != null && DateTime.now().isAfter(_expiryDate!)) {
        _isPro = false;
        _activeTier = SubscriptionTier.free;
      }
    }
    isProNotifier.value = _isPro;
    tierNotifier.value = _activeTier;
  }

  Future<void> _saveCachedStatus({
    required bool isPro,
    required SubscriptionTier tier,
    DateTime? expiry,
  }) async {
    _isPro = isPro;
    _activeTier = tier;
    _expiryDate = expiry;
    isProNotifier.value = isPro;
    tierNotifier.value = tier;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefIsProKey, isPro);
    await prefs.setString(_prefTierKey, tier == SubscriptionTier.yearly ? 'yearly' : tier == SubscriptionTier.monthly ? 'monthly' : 'free');
    if (expiry != null) {
      await prefs.setInt(_prefExpiryKey, expiry.millisecondsSinceEpoch);
    } else {
      await prefs.remove(_prefExpiryKey);
    }

    // Sync to Supabase Database profile table
    _syncToDatabase(isPro);
  }

  void _syncToDatabase(bool isPro) {
    final userId = AuthSession.userId;
    if (userId == null || userId.isEmpty) return;

    final tierStr = isPro ? 'pro' : 'free';
    ApiClient().patch(
      '/profile?id=eq.$userId',
      body: {'tier': tierStr},
    ).then((response) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[SubscriptionService] Successfully synced tier=$tierStr to database');
      } else {
        debugPrint('[SubscriptionService] Failed to sync tier to database: ${response.statusCode} ${response.body}');
      }
    }).catchError((e) {
      debugPrint('[SubscriptionService] Error syncing tier to database: $e');
    });
  }

  void _updateCustomerInfo(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.all[entitlementId];
    final active = entitlement?.isActive ?? false;

    SubscriptionTier tier = SubscriptionTier.free;
    DateTime? expiry;

    if (active) {
      final pid = entitlement?.productIdentifier.toLowerCase() ?? '';
      if (pid.contains('year') || pid.contains('annual')) {
        tier = SubscriptionTier.yearly;
      } else {
        tier = SubscriptionTier.monthly;
      }
      final expString = entitlement?.expirationDate;
      if (expString != null) {
        expiry = DateTime.tryParse(expString);
      }
    }

    _saveCachedStatus(isPro: active, tier: tier, expiry: expiry);
  }

  Future<Offerings?> fetchOfferings() async {
    if (!_initialized) return null;
    try {
      _offerings = await Purchases.getOfferings();
      return _offerings;
    } catch (e) {
      debugPrint('[SubscriptionService] Error fetching offerings: $e');
      return null;
    }
  }

  /// Purchase Monthly Package
  Future<bool> purchaseMonthly() async {
    return _purchase(isYearly: false);
  }

  /// Purchase Yearly Package
  Future<bool> purchaseYearly() async {
    return _purchase(isYearly: true);
  }

  Future<bool> _purchase({required bool isYearly}) async {
    if (!_initialized) {
      throw Exception('ระบบ RevenueCat ยังไม่ได้เริ่มต้นเชื่อมต่อ (กรุณาตรวจสอบการตั้งค่า API Key หรืออินเทอร์เน็ต)');
    }

    final currentOfferings = _offerings ?? await fetchOfferings();
    final currentOffering = currentOfferings?.current ??
        currentOfferings?.all['default'] ??
        (currentOfferings?.all.isNotEmpty == true ? currentOfferings?.all.values.first : null);

    Package? targetPackage;
    if (currentOffering != null) {
      if (isYearly) {
        targetPackage = currentOffering.annual;
        if (targetPackage == null) {
          for (final p in currentOffering.availablePackages) {
            if (p.packageType == PackageType.annual ||
                p.identifier == '\$rc_annual' ||
                p.identifier.toLowerCase().contains('annual') ||
                p.identifier.toLowerCase().contains('year') ||
                p.storeProduct.identifier.toLowerCase().contains('year') ||
                p.storeProduct.identifier.toLowerCase().contains('annual')) {
              targetPackage = p;
              break;
            }
          }
        }
      } else {
        targetPackage = currentOffering.monthly;
        if (targetPackage == null) {
          for (final p in currentOffering.availablePackages) {
            if (p.packageType == PackageType.monthly ||
                p.identifier == '\$rc_monthly' ||
                p.identifier.toLowerCase().contains('monthly') ||
                p.identifier.toLowerCase().contains('month') ||
                p.storeProduct.identifier.toLowerCase().contains('month')) {
              targetPackage = p;
              break;
            }
          }
        }
      }
    }

    if (targetPackage == null) {
      throw Exception('ยังไม่พบแพ็กเกจใน RevenueCat (กรุณาตรวจสอบ Offering และ Package บน RevenueCat Dashboard ให้เรียบร้อย)');
    }

    try {
      final result = await Purchases.purchase(PurchaseParams.package(targetPackage));
      _updateCustomerInfo(result.customerInfo);
      return _isPro;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('[SubscriptionService] User cancelled purchase');
        return false;
      }
      rethrow;
    }
  }

  /// Restore purchases (Required by App Store Review Guideline 3.1.2)
  Future<bool> restorePurchases() async {
    if (!_initialized) {
      throw Exception('ระบบ RevenueCat ยังไม่ได้เริ่มต้นเชื่อมต่อ');
    }

    final customerInfo = await Purchases.restorePurchases();
    _updateCustomerInfo(customerInfo);
    return _isPro;
  }
}
