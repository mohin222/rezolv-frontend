import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart' show navigatorKey;

/// WhatsApp-style top banner shown while the app is in the foreground — FCM
/// does not auto-show a system notification in that state, so without this
/// a push arriving while someone is looking at the app produces no visible
/// alert at all. Inserted directly into the root Overlay (via [navigatorKey])
/// so it can appear over whatever screen is on screen.
class InAppNotificationBanner {
  static OverlayEntry? _entry;

  static void show({required String title, required String body, VoidCallback? onTap}) {
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _entry?.remove();

    late OverlayEntry entry;
    void removeSelf() {
      if (identical(_entry, entry)) _entry = null;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (context) => _BannerWidget(
        title: title,
        body: body,
        onTap: () {
          onTap?.call();
          removeSelf();
        },
        onDismiss: removeSelf,
      ),
    );

    _entry = entry;
    overlayState.insert(entry);
  }
}

class _BannerWidget extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _BannerWidget({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget> with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, -1.3),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  double _dragDy = 0;
  bool _dismissing = false;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _autoDismissTimer = Timer(const Duration(seconds: 5), _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _autoDismissTimer?.cancel();
    if (mounted) await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _offset,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: GestureDetector(
              onTap: () {
                _autoDismissTimer?.cancel();
                widget.onTap();
              },
              onVerticalDragUpdate: (details) {
                if (details.delta.dy < 0) setState(() => _dragDy += details.delta.dy);
              },
              onVerticalDragEnd: (details) {
                if (_dragDy < -18) {
                  _dismiss();
                } else {
                  setState(() => _dragDy = 0);
                }
              },
              child: Transform.translate(
                offset: Offset(0, _dragDy),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(color: _navy, shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_active_rounded, color: _gold, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy),
                              ),
                              if (widget.body.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  widget.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Colors.black87),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
