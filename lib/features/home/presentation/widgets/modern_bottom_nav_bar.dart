import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';

class ModernBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const ModernBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SizedBox(
          height: 85, // Taller to accommodate the floating button
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none, // Allow center button to overflow if needed
            children: [
              // Glass Background
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
                    const SizedBox(width: 60), // Space for center button
                    _buildNavItem(context, 3, Icons.assignment_outlined, Icons.assignment, 'Operations'), // Was Shifts
                    _buildNavItem(context, 4, Icons.analytics_outlined, Icons.analytics, 'Analytics'),
                  ],
                ),
              ),

              // Floating Center Button (Scan)
              Positioned(
                top: 0,
                child: GestureDetector(
                  onTap: () => onTap(2),
                  child: Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF63B5F6), Color(0xFF1976D2)], // Bright Blue Gradient
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64B5F6).withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                        Text(
                          'SCAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      ],
                    ),
                  ),
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
              color: isSelected ? AppColors.accent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              size: 26,
            ),
            const SizedBox(height: 4),
            // Text
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            // Bottom Glow/Indicator for selected item
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 4),
              width: isSelected ? 20 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF63B5F6),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF63B5F6).withValues(alpha: 0.8),
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
