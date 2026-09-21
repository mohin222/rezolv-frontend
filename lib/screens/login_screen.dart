import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../data/api_config.dart';
import '../data/api_repository.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  Future<void> _login() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter username and password');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiRepository().login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );
      await ApiConfig.saveToken(result['token']!);
      await ApiConfig.saveUserInfo(
        username: result['username'] ?? '',
        email:    result['email']    ?? '',
        phone:    result['phone']    ?? '',
      );

      // Get FCM token and save to Django
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        
        if (fcmToken != null) {
          await ApiRepository().saveFcmToken(fcmToken);
          
        }
      } catch (e) {
        
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } on SocketException {
      setState(() => _error = 'No internet connection');
    } on http.ClientException {
      setState(() => _error = 'No internet connection');
    } on TimeoutException {
      setState(() => _error = 'No internet connection');
    } catch (e) {
      setState(() => _error = 'Invalid username or password');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.business, color: Colors.black, size: 36),
                ),
                const SizedBox(height: 24),
                Text('Rezolv Inventory',
                    style: GoogleFonts.fraunces(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Sign in to your account',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white38, fontSize: 14)),
                const SizedBox(height: 40),

                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _inputDecoration('Username', Icons.person_outline),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _inputDecoration('Password', Icons.lock_outline,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white38,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      )),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _loading
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2))
                        : Text('Login',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 32),
                Text('Rezolv Hospitality LLP',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white24, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5)),
      );
}