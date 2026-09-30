import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/api_repository.dart';
import '../widgets/in_app_notification_banner.dart';
import 'notifications_store.dart';

/// Must be a top-level function (not a class method) — FCM runs this in a
/// separate background isolate when a message arrives while the app is
/// backgrounded/terminated, so it can't close over any app state.
/// Notification-type messages are already shown by the system tray
/// automatically in that state, so there's nothing else to do here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Wires the app up to Firebase Cloud Messaging: asks for the notification
/// permission, and keeps [NotificationsStore] updated with whatever arrives
/// so the in-app Notifications screen has something real to show instead of
/// relying only on the system tray.
class PushNotificationService {
  PushNotificationService(this._store);

  final NotificationsStore _store;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'rezolv_alerts',
    'Rezolv Alerts',
    description: 'Hotel sold out and stop-sell alerts',
    importance: Importance.high,
  );

  Future<void> init() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _localNotifications.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );

    // firebase_messaging's own requestPermission() is a no-op on Android —
    // it just reads the current authorization state rather than triggering
    // the system dialog. The actual Android 13+ POST_NOTIFICATIONS runtime
    // prompt has to go through flutter_local_notifications instead.
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await FirebaseMessaging.instance.requestPermission();

    // App already open when a message arrives — FCM does NOT auto-show a
    // system notification in this state, so show an in-app banner instead
    // (a system-tray popup competing with whatever's on screen while
    // someone is actively using the app is the wrong call here).
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App was backgrounded (not terminated) and the user tapped the system
    // notification to bring it back to front.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // App was fully closed and got launched BY tapping the notification.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleMessage(initial);

    // FCM can rotate this device's token at any time (not just around
    // login) — re-register whenever that happens so we never end up
    // pushing to a stale one.
    FirebaseMessaging.instance.onTokenRefresh.listen((token) => ApiRepository().saveFcmToken(token));
  }

  /// Tells the backend which device to push to — call this once someone is
  /// known to be signed in (right after login, and again on app startup if
  /// a session already exists). Safe to call opportunistically: failures
  /// (no network, not logged in yet) are swallowed by saveFcmToken itself.
  Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await ApiRepository().saveFcmToken(token);
    } catch (e) {
      debugPrint('[PushNotificationService] could not register push token: $e');
    }
  }

  void _handleMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'Rezolv';
    final body = message.notification?.body ?? '';
    if (body.isEmpty) return;

    _store.add(title: title, body: body, externalId: message.messageId);

    if (message.notification != null) {
      _localNotifications.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(android: AndroidNotificationDetails(_channel.id, _channel.name)),
      );
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'Rezolv';
    final body = message.notification?.body ?? '';
    if (body.isEmpty) return;

    _store.add(title: title, body: body, externalId: message.messageId);
    InAppNotificationBanner.show(title: title, body: body);
  }
}
