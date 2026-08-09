import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget child;
  final double borderRadius;
  final double blur; // Kept for API compatibility, but unused
  final double border;

  const GlassContainer({
    super.key,
    this.width,
    this.height,
    required this.child,
    this.borderRadius = 20,
    this.blur = 20,
    this.border = 2,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Optimized: Simulating glass with just opacity and gradients.
    // Removed BackdropFilter/Blur for performance.
    
    final backgroundColor = isDark 
        ? const Color(0xFF1E293B).withValues(alpha: 0.7)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.9);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.2);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor,
          width: border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Material ancestor is required for ListTile/InkWell/DataTable to paint
      // ink splashes and backgrounds correctly on dark decorated surfaces.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}

