import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'main_shell.dart';
import '../data/api_config.dart';
import '../data/api_repository.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack)),
    );
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    );
    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.6, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.35, 0.6, curve: Curves.easeOut)),
    );
    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.75, curve: Curves.easeOut),
    );
    _loaderFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 0.9, curve: Curves.easeOut),
    );

    _controller.forward();

    // Request notification permission immediately
    // TODO: enable on iOS once Firebase iOS config is added.
    if (defaultTargetPlatform == TargetPlatform.android) {
      FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    Timer(const Duration(milliseconds: 2600), () async {
      if (!mounted) return;
      final token = await ApiConfig.getToken();
      if (!mounted) return;

      Widget nextScreen = const LoginScreen();

      if (token != null) {
        try {
          final userInfo = await ApiRepository().verifyToken();
          await ApiConfig.saveUserInfo(
            username: userInfo['username'] ?? '',
            email:    userInfo['email']    ?? '',
            phone:    userInfo['phone']    ?? '',
          );

          // Get FCM token and save to Django
          // TODO: enable on iOS once Firebase iOS config is added.
          if (defaultTargetPlatform == TargetPlatform.android) {
            final fcmToken = await FirebaseMessaging.instance.getToken();
            if (fcmToken != null) {
              await ApiRepository().saveFcmToken(fcmToken);
            }
          }

          nextScreen = const MainShell();
        } catch (_) {
          await ApiConfig.clearToken();
          nextScreen = const LoginScreen();
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: nextScreen,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2B4E), Color(0xFF091E38)],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: _logoFade.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Transform.rotate(
                          angle: -0.35,
                          child: const Icon(
                            Icons.flight_rounded,
                            color: Color(0xFF0D2B4E),
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  SlideTransition(
                    position: _titleSlide,
                    child: Opacity(
                      opacity: _titleFade.value.clamp(0.0, 1.0),
                      child: const Text(
                        'Rezolv',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Opacity(
                    opacity: _taglineFade.value.clamp(0.0, 1.0),
                    child: Text(
                      'INVENTORY CONTROL',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Opacity(
                    opacity: _loaderFade.value.clamp(0.0, 1.0),
                    child: const _PulsingDots(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value - (i * 0.2)) % 1.0;
            final opacity = (0.3 + 0.7 * (1 - (t - 0.5).abs() * 2)).clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}