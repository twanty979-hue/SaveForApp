import 'dart:convert';
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

  static const String entitlementId = 'savefor_pro';
  static const String monthlyProductId = 'savefor_pro_monthly';
  static const String yearlyProductId = 'savefor_pro_yearly';

  // Legacy local keys kept solely to purge any old cache from device
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

  /// คำนวณข้อความระยะเวลาที่เหลือ (เช่น 'เหลืออีก 28 วัน', 'เหลืออีก 2 ชั่วโมง', 'ตลอดชีพ')
  String getRemainingTimeText({bool isThai = true}) {
    if (!_isPro) return '';
    if (_expiryDate == null) {
      return isThai ? 'ตลอดชีพ (Lifetime)' : 'Lifetime';
    }

    final now = DateTime.now();
    final difference = _expiryDate!.difference(now);

    if (difference.isNegative) {
      return isThai ? 'หมดอายุแล้ว' : 'Expired';
    }

    final days = difference.inDays;
    final hours = difference.inHours;
    final minutes = difference.inMinutes;

    if (days >= 1) {
      return isThai ? 'เหลืออีก $days วัน' : '$days days left';
    } else if (hours >= 1) {
      return isThai ? 'เหลืออีก $hours ชั่วโมง' : '$hours hours left';
    } else if (minutes >= 1) {
      return isThai ? 'เหลืออีก $minutes นาที' : '$minutes mins left';
    } else {
      return isThai ? 'กำลังจะหมดอายุเร็วๆ นี้' : 'Expiring soon';
    }
  }

  /// แสดงวันที่หมดอายุ (เช่น '12/10/2026')
  String getFormattedExpiryDate() {
    if (_expiryDate == null) return '';
    final local = _expiryDate!.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day/$month/$year';
  }

  /// Call during app initialization or login
  Future<void> initialize({String? userId}) async {
    // 1. Purge any legacy local storage cache completely (Online-Only requirement)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefIsProKey);
      await prefs.remove(_prefTierKey);
      await prefs.remove(_prefExpiryKey);
    } catch (_) {}

    // 2. Fetch real-time online status from Supabase
    if (userId != null && userId.isNotEmpty) {
      await syncFromOnline();
    }

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

      // Fetch latest customer info online from RevenueCat
      final customerInfo = await Purchases.getCustomerInfo();
      _updateCustomerInfo(customerInfo);
      await fetchOfferings();
    } catch (e) {
      debugPrint('[SubscriptionService] Failed to initialize RevenueCat: $e');
    }
  }

  /// Call when user logs into Supabase
  Future<void> logIn(String userId) async {
    await syncFromOnline();
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
    _isPro = false;
    _activeTier = SubscriptionTier.free;
    _expiryDate = null;
    isProNotifier.value = false;
    tierNotifier.value = SubscriptionTier.free;

    if (!_initialized || kIsWeb) return;
    try {
      final customerInfo = await Purchases.logOut();
      _updateCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('[SubscriptionService] Error logging out of RevenueCat: $e');
    }
  }

  /// Fetch subscription status directly from Supabase Database online
  Future<void> syncFromOnline() async {
    final userId = AuthSession.userId;
    if (userId == null || userId.isEmpty) return;

    try {
      final response = await ApiClient().get(
        '/profile?id=eq.$userId&select=tier,subscription_expires_at,subscription_plan,subscription_store',
        forceRefresh: true,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> list = decoded is List ? decoded : [];
        if (list.isNotEmpty) {
          final profile = list[0] as Map<String, dynamic>;
          final tierStr = (profile['tier'] ?? 'free').toString().toLowerCase();
          final expiresAtStr = profile['subscription_expires_at']?.toString();
          final planStr = (profile['subscription_plan'] ?? 'free').toString().toLowerCase();

          DateTime? expiresAt;
          if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
            expiresAt = DateTime.tryParse(expiresAtStr);
          }

          // Verify if expired by timestamp
          bool activePro = tierStr == 'pro';
          if (activePro && expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt.toUtc())) {
            activePro = false;
          }

          _isPro = activePro;
          _expiryDate = expiresAt;
          _activeTier = activePro
              ? (planStr == 'yearly' ? SubscriptionTier.yearly : SubscriptionTier.monthly)
              : SubscriptionTier.free;

          isProNotifier.value = _isPro;
          tierNotifier.value = _activeTier;
          debugPrint('[SubscriptionService] Online status loaded: isPro=$_isPro, expiresAt=$_expiryDate, tier=$_activeTier');
        }
      }
    } catch (e) {
      debugPrint('[SubscriptionService] Error syncing subscription online from database: $e');
    }
  }

  /// Update in-memory state and sync directly to online database (No local storage)
  void _updateMemoryAndSyncOnline({
    required bool isPro,
    required SubscriptionTier tier,
    DateTime? expiry,
    String? store,
  }) {
    _isPro = isPro;
    _activeTier = tier;
    _expiryDate = expiry;
    isProNotifier.value = isPro;
    tierNotifier.value = tier;

    // Persist strictly online in Supabase Database
    _syncToDatabase(
      isPro: isPro,
      tier: tier,
      expiry: expiry,
      store: store,
    );
  }

  /// Sync subscription details online to Supabase Database (profiles table)
  void _syncToDatabase({
    required bool isPro,
    required SubscriptionTier tier,
    DateTime? expiry,
    String? store,
  }) {
    final userId = AuthSession.userId;
    if (userId == null || userId.isEmpty) return;

    final tierStr = isPro ? 'pro' : 'free';
    final planStr = isPro
        ? (tier == SubscriptionTier.yearly ? 'yearly' : 'monthly')
        : 'free';

    ApiClient().patch(
      '/profile?id=eq.$userId',
      body: {
        'tier': tierStr,
        'subscription_expires_at': expiry?.toUtc().toIso8601String(),
        'subscription_plan': planStr,
        'subscription_store': isPro ? (store ?? (Platform.isIOS ? 'app_store' : 'play_store')) : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    ).then((response) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[SubscriptionService] Successfully synced online to Supabase: tier=$tierStr, expires=$expiry, plan=$planStr');
      } else {
        debugPrint('[SubscriptionService] Failed to sync to Supabase: ${response.statusCode} ${response.body}');
      }
    }).catchError((e) {
      debugPrint('[SubscriptionService] Error syncing subscription to Supabase: $e');
    });
  }

  void _updateCustomerInfo(CustomerInfo customerInfo, {bool isExplicitAction = false}) {
    // Official RevenueCat standard: Entitlement is the single source of truth
    final entitlement = customerInfo.entitlements.all[entitlementId] ??
        customerInfo.entitlements.all['pro'] ??
        (customerInfo.entitlements.active.isNotEmpty ? customerInfo.entitlements.active.values.first : null);
    final active = entitlement?.isActive ?? false;

    SubscriptionTier tier = SubscriptionTier.free;
    DateTime? expiry;
    String? store;

    if (active && entitlement != null) {
      final pid = entitlement.productIdentifier.toLowerCase();
      if (pid.contains('year') || pid.contains('annual')) {
        tier = SubscriptionTier.yearly;
      } else {
        tier = SubscriptionTier.monthly;
      }

      final expString = entitlement.expirationDate;
      if (expString != null) {
        expiry = DateTime.tryParse(expString);
      }
      store = entitlement.store.name;
    }

    // หากเป็นการเช็กเบื้องหลังตอนเปิดแอป (Passive check) และสถานะใน Supabase ถูกตั้งเป็น Free (เช่น กดล้างใน Test Plan Studio)
    // จะไม่ให้ StoreKit passive check แอบเขียนทับ Supabase ให้กลับเป็น PRO อัตโนมัติ
    // ผู้ใช้ต้องกด "กู้คืนการซื้อ (Restore)" หรือ "ซื้อใหม่" ด้วยตนเองเท่านั้น
    if (!isExplicitAction && !_isPro && active) {
      debugPrint('[SubscriptionService] User is Free in Supabase. Ignoring passive StoreKit entitlement. User must tap Restore Purchases to re-link.');
      return;
    }

    _updateMemoryAndSyncOnline(
      isPro: active,
      tier: tier,
      expiry: expiry,
      store: store,
    );
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
      _updateCustomerInfo(result.customerInfo, isExplicitAction: true);
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
    _updateCustomerInfo(customerInfo, isExplicitAction: true);
    return _isPro;
  }
}
