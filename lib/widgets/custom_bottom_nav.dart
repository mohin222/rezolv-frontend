import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  static const _gold = Color(0xFFC1791C);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outerBg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final navBg   = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final unselectedColor = isDark ? Colors.grey.shade500 : Colors.grey;
    final selectedBg = isDark ? const Color(0xFF2E2010) : const Color(0xFFFCEEDD);

    final items = [
      (icon: Icons.radio_button_checked,  label: 'Overview'),
      (icon: Icons.warning_amber_rounded, label: 'Alerts'),
      (icon: Icons.dashboard_rounded,     label: 'Dashboard'),
      (icon: Icons.bolt_rounded,          label: 'Leaks'),
      (icon: Icons.menu_rounded,          label: 'More'),
    ];

    return Container(
      color: outerBg,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: navBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.08), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          // A single detector handles both a plain tap and a finger sliding
          // across the bar (like iOS's keyboard-switcher / WhatsApp emoji-tab
          // scrubbing) — one recognizer, so there's nothing for a tap and a
          // drag to fight over.
          child: LayoutBuilder(
            builder: (context, constraints) {
              void trackAt(double dx) {
                final itemWidth = constraints.maxWidth / items.length;
                final index = (dx / itemWidth).floor().clamp(0, items.length - 1);
                if (index != selectedIndex) {
                  HapticFeedback.selectionClick();
                  onTap(index);
                }
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => trackAt(details.localPosition.dx),
                onHorizontalDragStart: (details) => trackAt(details.localPosition.dx),
                onHorizontalDragUpdate: (details) => trackAt(details.localPosition.dx),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(items.length, (index) {
                    final isSelected = index == selectedIndex;
                    final item = items[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? selectedBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, size: 20, color: isSelected ? _gold : unselectedColor),
                          const SizedBox(height: 3),
                          Text(item.label, style: TextStyle(
                            fontSize: 10.5,
                            color: isSelected ? _gold : unselectedColor,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          )),
                        ],
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
