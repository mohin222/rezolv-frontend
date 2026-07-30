import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'utils/app_version.dart';

// Local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> _initLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
  InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);
}

void _setupForegroundNotifications() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'rezolv_alerts',
            'Rezolv Alerts',
            channelDescription: 'Hotel sold out and stop-sell alerts',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _initLocalNotifications();
  _setupForegroundNotifications();
  await AppVersion.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const RezolvApp(),
    ),
  );
}

class RezolvApp extends StatelessWidget {
  const RezolvApp({super.key});
  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Rezolv Inventory',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardColor: Colors.white,
        dividerColor: const Color(0xFFE9EAED),
        colorScheme: const ColorScheme.light(
          primary: _navy,
          secondary: _gold,
          surface: Colors.white,
          background: Color(0xFFF5F7FA),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? _gold : Colors.grey.shade400),
          trackColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? _gold.withOpacity(0.4) : Colors.grey.shade300),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        dividerColor: const Color(0xFF2C2C2C),
        colorScheme: const ColorScheme.dark(
          primary: _navy,
          secondary: _gold,
          surface: Color(0xFF1E1E1E),
          background: Color(0xFF121212),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? _gold : Colors.grey.shade600),
          trackColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? _gold.withOpacity(0.4) : Colors.grey.shade800),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}