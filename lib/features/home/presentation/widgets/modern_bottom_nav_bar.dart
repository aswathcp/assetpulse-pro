import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import 'cyber_scan_fab.dart';

class ModernBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isScanMenuOpen;

  const ModernBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isScanMenuOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SizedBox(
          height: 85, // Original height
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none, // Allow center button to overflow
            children: [
              // Glass Background Nav Bar
              GlassContainer(
                width: double.infinity,
                height: 70,
                borderRadius: 24,
                blur: 25,
                border: 0.5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(context, 0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
                    _buildNavItem(context, 1, Icons.precision_manufacturing_outlined, Icons.precision_manufacturing, 'Assets'),
                    const SizedBox(width: 60), // Original space for center FAB
                    _buildNavItem(context, 3, Icons.assignment_outlined, Icons.assignment, 'Operations'),
                    _buildNavItem(context, 4, Icons.analytics_outlined, Icons.analytics, 'Analytics'),
                  ],
                ),
              ),

              // Floating Cyber Scan Button (Original Position at top: 0)
              Positioned(
                top: 0,
                child: CyberScanFab(
                  isOpen: isScanMenuOpen,
                  size: 64.0,
                  onTap: () => onTap(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.accent : const Color(0xFF0284C7);
    final inactiveColor = isDark
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
        : const Color(0xFF64748B);
    final indicatorColor = isDark ? const Color(0xFF34D3EE) : const Color(0xFF0284C7);

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox( // Fixed width for alignment
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 26,
            ),
            const SizedBox(height: 4),
            // Text
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : (isDark ? FontWeight.w400 : FontWeight.w500),
              ),
            ),
            // Bottom Glow/Indicator for selected item
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 4),
              width: isSelected ? 20 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: indicatorColor.withValues(alpha: isDark ? 0.8 : 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
