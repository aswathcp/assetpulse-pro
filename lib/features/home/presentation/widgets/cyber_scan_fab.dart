import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

class CyberScanFab extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;
  final double size;

  const CyberScanFab({
    super.key,
    required this.isOpen,
    required this.onTap,
    this.size = 64.0,
  });

  @override
  State<CyberScanFab> createState() => _CyberScanFabState();
}

class _CyberScanFabState extends State<CyberScanFab>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _pulseController;
  late AnimationController _morphController;

  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;
  late Animation<double> _morphAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Continuous 5s linear infinite spin for the 3px conic gradient ring
    _spinController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();

    // 2. 2.6s ease-in-out breathing radial glow loop (scale 1.0 -> 1.08, opacity 0.55 -> 1.0)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3. Morph animation between Viewfinder icon and X icon (280ms cubic-bezier(0.34, 1.56, 0.64, 1))
    _morphController = AnimationController(
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: const Cubic(0.34, 1.56, 0.64, 1.0),
      reverseCurve: Curves.easeIn,
    );

    if (widget.isOpen) {
      _morphController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(CyberScanFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _morphController.forward();
      } else {
        _morphController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pulseController.dispose();
    _morphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double buttonSize = widget.size;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color iconColor = isDark ? const Color(0xFF34D3EE) : const Color(0xFF0284C7);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1. Soft Breathing Radial Cyan / Sky Glow (Optimized Custom Painter)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(buttonSize, buttonSize),
                    painter: _RadialGlowPainter(
                      scale: _pulseScale.value,
                      opacity: _pulseOpacity.value,
                      isDark: isDark,
                    ),
                  );
                },
              ),

              // 2. High-Performance Unified Circular Button Painter (Conic Ring + Gradient Body + Inner Border)
              AnimatedBuilder(
                animation: _spinController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(buttonSize, buttonSize),
                    painter: _CyberButtonPainter(
                      angle: _spinController.value * 2 * math.pi,
                      strokeWidth: 3.0,
                      isDark: isDark,
                    ),
                  );
                },
              ),

              // 3. Morphing Center Icon (Viewfinder <-> X)
              Center(
                child: AnimatedBuilder(
                  animation: _morphAnimation,
                  builder: (context, child) {
                    final double progress = _morphAnimation.value;

                    return SizedBox(
                      width: 26,
                      height: 26,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Viewfinder Icon: Rotates 0 -> -45deg, Fades 1.0 -> 0.0
                          Transform.rotate(
                            angle: -progress * (math.pi / 4), // -45 deg
                            child: Opacity(
                              opacity: (1.0 - progress * 1.4).clamp(0.0, 1.0),
                              child: _ViewfinderIcon(
                                size: 26,
                                color: iconColor,
                              ),
                            ),
                          ),

                          // Close "X" Icon: Rotates +45deg -> 0deg, Fades 0.0 -> 1.0
                          Transform.rotate(
                            angle: (1.0 - progress) * (math.pi / 4), // +45 deg to 0
                            child: Opacity(
                              opacity: ((progress - 0.2) / 0.8).clamp(0.0, 1.0),
                              child: Icon(
                                Icons.close_rounded,
                                size: 26,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom Viewfinder / Scan-Frame Icon (26px)
class _ViewfinderIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _ViewfinderIcon({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ViewfinderPainter(color: color),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  final Color color;

  _ViewfinderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double w = size.width;
    final double h = size.height;
    const double pad = 2.0;
    const double arm = 6.5; // Corner bracket length
    const double r = 3.0; // Corner radius

    // Top-Left bracket
    final pathTL = Path()
      ..moveTo(pad, pad + arm)
      ..lineTo(pad, pad + r)
      ..arcToPoint(Offset(pad + r, pad), radius: const Radius.circular(r))
      ..lineTo(pad + arm, pad);
    canvas.drawPath(pathTL, paint);

    // Top-Right bracket
    final pathTR = Path()
      ..moveTo(w - pad - arm, pad)
      ..lineTo(w - pad - r, pad)
      ..arcToPoint(Offset(w - pad, pad + r), radius: const Radius.circular(r))
      ..lineTo(w - pad, pad + arm);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left bracket
    final pathBL = Path()
      ..moveTo(pad, h - pad - arm)
      ..lineTo(pad, h - pad - r)
      ..arcToPoint(Offset(pad + r, h - pad), radius: const Radius.circular(r))
      ..lineTo(pad + arm, h - pad);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right bracket
    final pathBR = Path()
      ..moveTo(w - pad - arm, h - pad)
      ..lineTo(w - pad - r, h - pad)
      ..arcToPoint(Offset(w - pad, h - pad - r), radius: const Radius.circular(r))
      ..lineTo(w - pad, h - pad - arm);
    canvas.drawPath(pathBR, paint);

    // Center subtle laser dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h / 2), 1.8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Unified Single-Pass Painter for the Button:
/// 1. Solid dark / light base disc + shadow
/// 2. Body linear gradient
/// 3. Inner 1px border
/// 4. Outer 3px conic gradient rotating ring
class _CyberButtonPainter extends CustomPainter {
  final double angle;
  final double strokeWidth;
  final bool isDark;

  _CyberButtonPainter({
    required this.angle,
    required this.strokeWidth,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final ringRadius = outerRadius - (strokeWidth / 2);
    final innerRadius = outerRadius - strokeWidth;

    // 1. Soft drop shadow
    final shadowPaint = Paint()
      ..color = isDark ? const Color(0x8003050A) : const Color(0x280F172A)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? 12 : 10);
    canvas.drawCircle(center + const Offset(0, 4), innerRadius, shadowPaint);

    // 2. Solid inner body fill with Linear Gradient
    final bodyPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: const Alignment(-0.6, -0.9),
        end: const Alignment(0.6, 0.9),
        colors: isDark
            ? const [
                Color(0xFF182238),
                Color(0xFF0F1626),
              ]
            : const [
                Color(0xFFFFFFFF),
                Color(0xFFF1F5F9),
              ],
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.drawCircle(center, innerRadius, bodyPaint);

    // 3. 1px Subtle Inner Border
    final innerBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0);
    canvas.drawCircle(center, innerRadius - 0.5, innerBorderPaint);

    // 4. 3px Conic Gradient Rotating Ring
    final List<Color> ringColors = isDark
        ? const [
            Color(0xFF34D3EE),
            Color(0xFF39D98A),
            Color(0xFFA78BFA),
            Color(0xFF34D3EE),
          ]
        : const [
            Color(0xFF0284C7),
            Color(0xFF059669),
            Color(0xFF7C3AED),
            Color(0xFF0284C7),
          ];

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        startAngle: angle + math.pi / 2,
        endAngle: angle + math.pi / 2 + 2 * math.pi,
        colors: ringColors,
        stops: const [0.0, 0.33, 0.66, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: ringRadius));
    canvas.drawCircle(center, ringRadius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _CyberButtonPainter oldDelegate) =>
      oldDelegate.angle != angle ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.isDark != isDark;
}

/// Soft Radial Cyan / Sky Glow Painter
class _RadialGlowPainter extends CustomPainter {
  final double scale;
  final double opacity;
  final bool isDark;

  _RadialGlowPainter({
    required this.scale,
    required this.opacity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2 + 10.0) * scale;
    final glowColor = isDark ? const Color(0xFF34D3EE) : const Color(0xFF0284C7);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withValues(alpha: (isDark ? 0.35 : 0.22) * opacity),
          glowColor.withValues(alpha: (isDark ? 0.12 : 0.08) * opacity),
          glowColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RadialGlowPainter oldDelegate) =>
      oldDelegate.scale != scale ||
      oldDelegate.opacity != opacity ||
      oldDelegate.isDark != isDark;
}
