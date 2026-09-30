import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushNotification {
  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;

  const PushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'receivedAt': receivedAt.toIso8601String(),
      };

  factory PushNotification.fromJson(Map<String, dynamic> json) => PushNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        receivedAt: DateTime.parse(json['receivedAt'] as String),
      );
}

/// Every push notification the app has actually received, newest first —
/// persisted locally so they survive an app restart, since FCM itself keeps
/// no history once a message has been delivered.
class NotificationsStore extends ChangeNotifier {
  static const _key = 'push_notifications';
  static const _maxStored = 50;

  List<PushNotification> _items = [];
  List<PushNotification> get items => List.unmodifiable(_items);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _items = list.map(PushNotification.fromJson).toList();
    notifyListeners();
  }

  /// [externalId] is FCM's own message id, when available — used to skip a
  /// duplicate add if the same message reaches us twice (e.g. a background
  /// tap racing the foreground listener on app resume).
  Future<void> add({required String title, required String body, String? externalId}) async {
    if (externalId != null && _items.any((e) => e.id == externalId)) return;
    final entry = PushNotification(
      id: externalId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      receivedAt: DateTime.now(),
    );
    _items = [entry, ..._items].take(_maxStored).toList();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }
}
