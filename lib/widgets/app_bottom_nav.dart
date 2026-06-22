import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderTertiary)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navIcon(Icons.home_rounded, 0),
          _navIcon(Icons.bar_chart_rounded, 1),
          _navIcon(Icons.calendar_month_rounded, 2),
          _navIcon(Icons.person_rounded, 3),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, int index) {
    final active = index == currentIndex;
    return IconButton(
      onPressed: () => onTap(index),
      icon: Icon(
        icon,
        color: active ? AppColors.info : AppColors.textSecondary,
      ),
    );
  }
}
