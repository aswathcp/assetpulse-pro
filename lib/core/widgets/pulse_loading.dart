import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';

class PulseLoading extends StatelessWidget {
  final double size;
  final Color? color;

  const PulseLoading({super.key, this.size = 50, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer Ring
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.withValues(alpha: 0.5), width: 2),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1.seconds)
             .fadeOut(begin: 0.2, curve: Curves.easeInOut),

            // Inner Circle
            Container(
              width: size * 0.4,
              height: size * 0.4,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat())
             .fadeIn(duration: 500.ms)
             .then()
             .fadeOut(duration: 500.ms),
          ],
        ),
      ),
    );
  }
}
