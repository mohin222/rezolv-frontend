import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final String? thirdTabLabel;
  final IconData? thirdTabIcon;

  const CustomBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.thirdTabLabel,
    this.thirdTabIcon,
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
      (icon: thirdTabIcon ?? Icons.bolt_rounded, label: thirdTabLabel ?? 'Leaks'),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (index) {
              final isSelected = index == selectedIndex;
              final item = items[index];
              return GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: Container(
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
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}