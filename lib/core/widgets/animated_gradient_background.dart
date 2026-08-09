import 'package:flutter/material.dart';


class AnimatedGradientBackground extends StatelessWidget {
  final Widget child;

  const AnimatedGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Optimized: Removed animated blobs for performance on low-spec units.
    // using system scaffold background for consistent theming.
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}
