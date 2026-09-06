import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/auth/domain/auth_session.dart';
import '../network/api_client.dart';
import '../settings/app_settings.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const String channelId = 'savefor_reminders_v2';

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final ApiClient _apiClient = ApiClient();

  final ValueNotifier<int> inboxRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  bool _initialized = false;
  bool _firebaseReady = false;
  String? _token;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseReady = true;
    } catch (error) {
      debugPrint('Firebase is not ready: $error');
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );

    const channel = AndroidNotificationChannel(
      channelId,
      'การแจ้งเตือน SaveFor',
      description: 'แจ้งเตือนรายรับ รายจ่าย และเป้าหมายการออม',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        'alert_positive_marimba_swoop',
      ),
      enableVibration: true,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((_) => inboxRevision.value++);
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      _token = token;
      await _sendToken(enabled: AppSettings.notificationsEnabled);
    });

    if (AppSettings.notificationsEnabled) await registerDevice();
  }

  String? get currentToken => _token;

  Future<void> registerDevice() async {
    if (!_firebaseReady || !AppSettings.notificationsEnabled) return;

    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Notification permission was denied by user');
      return;
    }

    if (!kIsWeb && Platform.isIOS) {
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      int retries = 0;
      while (apnsToken == null && retries < 6) {
        await Future.delayed(const Duration(milliseconds: 500));
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        retries++;
      }
      if (apnsToken != null) {
        debugPrint('[FCM] APNs Token ready: $apnsToken');
      } else {
        debugPrint('[FCM] APNs token not available yet (normal on Simulator)');
      }
    }

    try {
      _token = await FirebaseMessaging.instance.getToken();
      debugPrint('\n======================================================');
      debugPrint('[FCM DEVICE TOKEN] $_token');
      debugPrint('======================================================\n');
    } catch (e) {
      debugPrint('[FCM] Error fetching device token: $e');
    }

    if (AuthSession.accessToken?.isNotEmpty == true) {
      await _sendToken(enabled: true);
      await refreshUnreadCount();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (!_firebaseReady) return;
    if (enabled) {
      await registerDevice();
      return;
    }

    _token ??= await FirebaseMessaging.instance.getToken();
    await _sendToken(enabled: false);
    unreadCount.value = 0;
  }

  Future<void> _sendToken({required bool enabled}) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    if (AuthSession.accessToken?.isNotEmpty != true) return;

    try {
      await _apiClient.post(
        '/notifications/device-token',
        body: {
          'token': token,
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
          'enabled': enabled,
        },
      );
    } catch (error) {
      debugPrint('Unable to register notification token: $error');
    }
  }

  Future<void> refreshUnreadCount() async {
    if (AuthSession.accessToken?.isNotEmpty != true) return;
    try {
      final response = await _apiClient.get('/notifications/unread-count');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        unreadCount.value = (body['count'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {
      // Keep the previous badge count while offline.
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    inboxRevision.value++;
    unreadCount.value++;
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    await _local.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'การแจ้งเตือน SaveFor',
          channelDescription: 'แจ้งเตือนรายรับ รายจ่าย และเป้าหมายการออม',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          sound: RawResourceAndroidNotificationSound(
            'alert_positive_marimba_swoop',
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
