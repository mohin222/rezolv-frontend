import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/api_repository.dart';
import '../services/notifications_store.dart';
import '../services/push_notification_service.dart' show NotificationStyle;

/// One row on the bell screen — from the backend's history when online,
/// or from this phone's own received list as an offline fallback.
class _Item {
  final String title;
  final String body;
  final String? type;
  final DateTime time;
  const _Item(this.title, this.body, this.type, this.time);
}

/// The bell screen: every alert the backend sent in the last few days
/// (kept server-side, so it's the same for every user and survives a
/// reinstall), 20 at a time with a Load more button.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiRepository();
  final List<_Item> _items = [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final (rows, hasMore) = await _api.fetchNotifications(page: 1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(rows.map(_fromServer));
        _page = 1;
        _hasMore = hasMore;
        _offline = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Server unreachable — show what this phone itself received instead
      // of an empty screen.
      final local = context.read<NotificationsStore>().items;
      setState(() {
        _items
          ..clear()
          ..addAll(local.map((n) => _Item(n.title, n.body, null, n.receivedAt)));
        _hasMore = false;
        _offline = true;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final (rows, hasMore) = await _api.fetchNotifications(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(rows.map(_fromServer));
        _page += 1;
        _hasMore = hasMore;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load more — check your connection')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  static _Item _fromServer(Map<String, dynamic> json) => _Item(
        json['title'] as String? ?? '',
        json['body'] as String? ?? '',
        json['type'] as String?,
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(children: [
          const SizedBox(height: 160),
          _EmptyNotifications(textSecondary: textSecondary),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length + 2,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Text(
                _offline ? 'Offline — showing alerts received on this phone' : 'Alerts from the last 3 days',
                style: TextStyle(fontSize: 11.5, color: textSecondary),
              );
            }
            if (i == _items.length + 1) {
              if (!_hasMore) return const SizedBox.shrink();
              return Center(
                child: _loadingMore
                    ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
                    : OutlinedButton(onPressed: _loadMore, child: const Text('Load more')),
              );
            }
            return _NotificationTile(
              item: _items[i - 1],
              cardBg: theme.cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
      ),
      body: body,
    );
  }
}

/// Shown when there have been no alerts in the retention window — honest
/// empty state rather than placeholder/fake content.
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
            "You'll see sold-out, stop-sell and flights-at-risk alerts here as they come in.",
            style: TextStyle(fontSize: 12.5, color: textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final _Item item;
  final Color cardBg, textPrimary, textSecondary;
  const _NotificationTile({required this.item, required this.cardBg, required this.textPrimary, required this.textSecondary});

  static const _navy = Color(0xFF0D2B4E);

  @override
  Widget build(BuildContext context) {
    final style = NotificationStyle.forType(item.type);
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
          decoration: BoxDecoration(color: style.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(style.icon, color: style.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 2),
          Text(item.body, style: TextStyle(fontSize: 12.5, color: textPrimary)),
          const SizedBox(height: 4),
          Text(DateFormat('d MMM, HH:mm').format(item.time), style: TextStyle(fontSize: 10.5, color: textSecondary)),
        ])),
      ]),
    );
  }
}
