import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/api_repository.dart';
import '../firebase_options.dart';
import '../main.dart' show navigatorKey;
import '../screens/flight_risk_detail_screen.dart';
import '../screens/notifications_screen.dart';
import '../widgets/in_app_notification_banner.dart';
import 'notifications_store.dart';

/// Must be a top-level function (not a class method) — FCM runs this in a
/// separate background isolate when a message arrives while the app is
/// backgrounded/terminated, so it can't close over any app state. The
/// system tray already shows the notification itself in that state; this
/// only records it so the in-app Notifications screen still lists it even
/// if the user never taps it.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final store = NotificationsStore();
  await store.load();
  await PushNotificationService.record(store, message);
}

/// How each alert type the backend sends (data['type'], see the Django
/// rich_sync/notifications.py) looks in the in-app banner.
class NotificationStyle {
  final IconData icon;
  final Color color;
  const NotificationStyle(this.icon, this.color);

  static NotificationStyle forType(String? type) {
    switch (type) {
      case 'sold_out':
        return const NotificationStyle(Icons.hotel_rounded, Color(0xFFD32F2F));
      case 'stop_sell':
        return const NotificationStyle(Icons.block_rounded, Color(0xFFEF6C00));
      case 'airline_risk':
        return const NotificationStyle(Icons.flight_takeoff_rounded, Color(0xFFC1791C));
      default:
        return const NotificationStyle(Icons.notifications_active_rounded, Color(0xFF0D2B4E));
    }
  }
}

/// Wires the app up to Firebase Cloud Messaging on Android and iOS: asks
/// for the notification permission, shows an in-app banner for alerts that
/// arrive while the app is open, opens the right screen when a system
/// notification is tapped, and keeps [NotificationsStore] updated so the
/// in-app Notifications screen has something real to show.
class PushNotificationService {
  PushNotificationService(this._store);

  final NotificationsStore _store;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationChannel(
    'rezolv_alerts',
    'Rezolv Alerts',
    description: 'Hotel sold out, stop-sell and airlines-at-risk alerts',
    importance: Importance.high,
  );

  Future<void> init() async {
    // Listeners below must only be attached once, or every push would
    // show its banner twice.
    if (_initialized) return;
    _initialized = true;

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked once, below, through FirebaseMessaging.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    // firebase_messaging's own requestPermission() is a no-op on Android —
    // it just reads the current authorization state rather than triggering
    // the system dialog. The actual Android 13+ POST_NOTIFICATIONS runtime
    // prompt has to go through flutter_local_notifications instead. On iOS
    // requestPermission() is the real prompt.
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

    // iOS would otherwise also show its own system banner on top of our
    // in-app one while the app is open — keep it to just ours.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    // App already open when a message arrives — FCM does NOT auto-show a
    // system notification in this state, so show an in-app banner instead
    // (a system-tray popup competing with whatever's on screen while
    // someone is actively using the app is the wrong call here).
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App was backgrounded (not terminated) and the user tapped the system
    // notification to bring it back to front.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // App was fully closed and got launched BY tapping the notification —
    // wait for the first frame so there's a Navigator to open a screen on.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTap(initial));
    }

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
    if (!_initialized) return;
    try {
      // iOS hands out an FCM token only once APNs has registered the
      // device; asking before that throws apns-token-not-set.
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await FirebaseMessaging.instance.getAPNSToken() == null) {
        await Future.delayed(const Duration(seconds: 3));
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      if (kDebugMode) debugPrint('[PushNotificationService] FCM token: $token');
      await ApiRepository().saveFcmToken(token);
    } catch (e) {
      debugPrint('[PushNotificationService] could not register push token: $e');
    }
  }

  /// Saves [message] to [store] — shared by the foreground, tap and
  /// background paths. The store skips a message it already has.
  static Future<void> record(NotificationsStore store, RemoteMessage message) async {
    final body = message.notification?.body ?? '';
    if (body.isEmpty) return;
    await store.add(
      title: message.notification?.title ?? 'Rezolv',
      body: body,
      externalId: message.messageId,
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final body = message.notification?.body ?? '';
    if (body.isEmpty) return;

    record(_store, message);
    final style = NotificationStyle.forType(message.data['type']);
    InAppNotificationBanner.show(
      title: message.notification?.title ?? 'Rezolv',
      body: body,
      icon: style.icon,
      color: style.color,
      onTap: () => _openFor(message),
    );
  }

  void _handleTap(RemoteMessage message) {
    record(_store, message);
    _openFor(message);
  }

  /// Airlines-at-risk alerts for one station open that station's Flights
  /// at Risk screen; everything else opens the Notifications list.
  void _openFor(RemoteMessage message) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    final station = message.data['station'];
    if (message.data['type'] == 'airline_risk' && station != null) {
      navigator.push(MaterialPageRoute(
        builder: (_) => FlightRiskDetailScreen(
          stationCode: station,
          stationCity: message.data['city'] ?? station,
        ),
      ));
    } else {
      navigator.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    }
  }
}
