import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/notifications_store.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final notifications = context.watch<NotificationsStore>().items;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
      ),
      body: notifications.isEmpty
          ? _EmptyNotifications(textSecondary: textSecondary)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _NotificationTile(
                notification: notifications[i],
                cardBg: theme.cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
    );
  }
}

/// Shown until the first real push notification arrives — honest empty
/// state rather than placeholder/fake content.
class _EmptyNotifications extends StatelessWidget {
  final Color textSecondary;
  const _EmptyNotifications({required this.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.notifications_none_rounded, size: 48, color: textSecondary),
        const SizedBox(height: 14),
        Text('No notifications yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textSecondary)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            "You'll see sold-out and stop-sell alerts here as they come in.",
            style: TextStyle(fontSize: 12.5, color: textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final PushNotification notification;
  final Color cardBg, textPrimary, textSecondary;
  const _NotificationTile({required this.notification, required this.cardBg, required this.textPrimary, required this.textSecondary});

  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: _gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.notifications_rounded, color: _navy, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(notification.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 2),
          Text(notification.body, style: TextStyle(fontSize: 12.5, color: textPrimary)),
          const SizedBox(height: 4),
          Text(DateFormat('MMM d, h:mm a').format(notification.receivedAt), style: TextStyle(fontSize: 10.5, color: textSecondary)),
        ])),
      ]),
    );
  }
}
