import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'glass_container.dart';

class ShimmerCard extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const ShimmerCard({
    super.key,
    this.height = 100,
    this.width = double.infinity,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        width: width,
        height: height,
        borderRadius: borderRadius,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.15), // Increased contrast
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
          ),
        ).animate(onPlay: (c) => c.repeat())
         .shimmer(duration: 1.2.seconds, color: Colors.white.withValues(alpha: 0.3), angle: 0.8), // Brighter shimmer
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double cardHeight;

  const ShimmerList({super.key, this.itemCount = 5, this.cardHeight = 100});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: itemCount,
      itemBuilder: (context, index) => ShimmerCard(height: cardHeight),
    );
  }
}
