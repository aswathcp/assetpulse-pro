import 'package:flutter/material.dart';

/// Reusable Responsive Breakpoint Utility & Layout Builder for AssetPulse-Pro Multiplatform Architecture
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static const double mobileMaxBreakPoint = 768.0;
  static const double tabletMaxBreakPoint = 1100.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileMaxBreakPoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileMaxBreakPoint &&
      MediaQuery.of(context).size.width < tabletMaxBreakPoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletMaxBreakPoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= tabletMaxBreakPoint) {
          return desktop;
        } else if (constraints.maxWidth >= mobileMaxBreakPoint) {
          return tablet ?? desktop;
        } else {
          return mobile;
        }
      },
    );
  }
}

/// Centered Content Wrapper for Desktop / Web Landscape Screens (Prevents Ultra-Wide Stretching)
class ResponsiveContentWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveContentWrapper({
    super.key,
    required this.child,
    this.maxWidth = 1320.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < ResponsiveLayout.mobileMaxBreakPoint;
    if (isMobile) return child;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
