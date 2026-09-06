import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class ScanMenuOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<String> onOptionSelected;
  final Offset buttonPosition;

  const ScanMenuOverlay({
    super.key,
    required this.onClose,
    required this.onOptionSelected,
    required this.buttonPosition,
  });

  @override
  State<ScanMenuOverlay> createState() => _ScanMenuOverlayState();
}

class _ScanMenuOverlayState extends State<ScanMenuOverlay>
    with TickerProviderStateMixin {
  late AnimationController _cardController;
  late AnimationController _backdropController;
  late AnimationController _rowController;

  late Animation<double> _cardScale;
  late Animation<double> _cardTranslate;
  late Animation<double> _cardOpacity;
  late Animation<double> _backdropOpacity;

  bool _isClosing = false;
  String? _tappedOption;

  @override
  void initState() {
    super.initState();

    // 1. Backdrop Controller (300ms ease)
    _backdropController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _backdropOpacity = CurvedAnimation(
      parent: _backdropController,
      curve: Curves.easeOut,
    );
    _backdropController.forward();

    // 2. Main Card Entrance (260ms cubic-bezier(0.34, 1.56, 0.64, 1))
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );

    const entranceCurve = Cubic(0.34, 1.56, 0.64, 1.0);

    _cardScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: entranceCurve,
        reverseCurve: Curves.easeIn,
      ),
    );

    _cardTranslate = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: entranceCurve,
        reverseCurve: Curves.easeIn,
      ),
    );

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
        reverseCurve: Curves.easeIn,
      ),
    );

    _cardController.forward();

    // 3. Staggered Rows Controller (Total ~300ms, each row 180ms ease-out with 40ms stagger)
    _rowController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Start row stagger slightly after card starts expanding
    Future.delayed(const Duration(milliseconds: 40), () {
      if (mounted && !_isClosing) {
        _rowController.forward();
      }
    });
  }

  @override
  void dispose() {
    _backdropController.dispose();
    _cardController.dispose();
    _rowController.dispose();
    super.dispose();
  }

  void _close([VoidCallback? onComplete]) {
    if (_isClosing) return;
    _isClosing = true;

    _backdropController.reverse();
    _rowController.reverse();
    _cardController.reverse().then((_) {
      if (mounted) {
        if (onComplete != null) {
          onComplete();
        } else {
          widget.onClose();
        }
      }
    });
  }

  void _handleRowTap(String option) async {
    if (_isClosing) return;
    setState(() => _tappedOption = option);

    // Brief tactile flash & scale feedback (120ms)
    await Future.delayed(const Duration(milliseconds: 120));

    if (!mounted) return;

    _close(() {
      widget.onOptionSelected(option);
    });
  }

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 212.0;
    final Size screenSize = MediaQuery.of(context).size;
    final double centerX = screenSize.width / 2;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Card positioned directly above the original FAB position
    const double cardBottom = 118.0;

    final Color cardBg = isDark ? const Color(0xFF141C30) : const Color(0xFFFFFFFF);
    final Color cardBorder = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0);
    final Color backdropColor = isDark ? const Color(0x9903050A) : const Color(0x4D0F172A);

    return Stack(
      children: [
        // 1. Full-screen backdrop (rgba(3,5,10,0.6) dark or rgba(15,23,42,0.3) light, blur 3px)
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _close(),
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: _backdropOpacity,
              builder: (context, child) {
                return Opacity(
                  opacity: _backdropOpacity.value,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 3.0 * _backdropOpacity.value,
                        sigmaY: 3.0 * _backdropOpacity.value,
                      ),
                      child: Container(
                        color: backdropColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // 2. Animated Popup Menu Card with Bottom Diamond Pointer
        Positioned(
          left: centerX - (cardWidth / 2),
          bottom: cardBottom,
          width: cardWidth,
          child: AnimatedBuilder(
            animation: _cardController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _cardTranslate.value),
                child: Transform.scale(
                  scale: _cardScale.value,
                  alignment: Alignment.bottomCenter,
                  child: Opacity(
                    opacity: _cardOpacity.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Connecting Tail: 12x12px diamond (rotated square) in theme card background
                Positioned(
                  bottom: -5.5,
                  child: Transform.rotate(
                    angle: math.pi / 4, // 45 degrees
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border(
                          right: BorderSide(
                            color: cardBorder,
                            width: 0.5,
                          ),
                          bottom: BorderSide(
                            color: cardBorder,
                            width: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Main Rounded Card: width ~210px, border-radius 18px
                Container(
                  width: cardWidth,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: cardBorder,
                      width: isDark ? 0.5 : 0.8,
                    ),
                    boxShadow: isDark
                        ? const [
                            BoxShadow(
                              color: Color(0x99000000),
                              blurRadius: 28,
                              spreadRadius: 2,
                              offset: Offset(0, 12),
                            ),
                            BoxShadow(
                              color: Color(0x2634D3EE),
                              blurRadius: 20,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : const [
                            BoxShadow(
                              color: Color(0x1F0F172A),
                              blurRadius: 24,
                              spreadRadius: 1,
                              offset: Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Color(0x120284C7),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row 1: QR scan
                        _buildAnimatedRow(
                          index: 0,
                          option: 'QR',
                          label: 'QR scan',
                          icon: Icons.qr_code_scanner_rounded,
                          accentColor: isDark ? const Color(0xFF34D3EE) : const Color(0xFF0284C7),
                          isDark: isDark,
                        ),

                        // Hairline divider: 0.5px, inset 14px
                        _buildHairlineDivider(isDark),

                        // Row 2: NFC scan
                        _buildAnimatedRow(
                          index: 1,
                          option: 'NFC',
                          label: 'NFC scan',
                          icon: Icons.nfc_rounded,
                          accentColor: isDark ? const Color(0xFF39D98A) : const Color(0xFF059669),
                          isDark: isDark,
                        ),

                        // Hairline divider: 0.5px, inset 14px
                        _buildHairlineDivider(isDark),

                        // Row 3: RFID reader
                        _buildAnimatedRow(
                          index: 2,
                          option: 'RFID',
                          label: 'RFID reader',
                          icon: Icons.sensors_rounded,
                          accentColor: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Hairline divider (0.5px, inset 14px from both sides)
  Widget _buildHairlineDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      child: Divider(
        height: 0.5,
        thickness: 0.5,
        color: isDark ? const Color(0x12FFFFFF) : const Color(0xFFF1F5F9),
      ),
    );
  }

  /// Staggered Animated Row with 40ms interval delay, 15px -> 0 slide up, 180ms ease-out
  Widget _buildAnimatedRow({
    required int index,
    required String option,
    required String label,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    // 40ms delay per row (0ms, 40ms, 80ms over 300ms total timeline)
    final double start = (index * 40) / 300.0;
    final double end = (start + (180 / 300.0)).clamp(0.0, 1.0);

    final rowAnimation = CurvedAnimation(
      parent: _rowController,
      curve: Interval(start, end, curve: Curves.easeOut),
    );

    final bool isTapped = _tappedOption == option;
    final Color textColor = isDark ? const Color(0xFFEAF0FA) : const Color(0xFF0F172A);
    final Color chevronColor = isDark ? const Color(0xFF57647F) : const Color(0xFF94A3B8);

    return AnimatedBuilder(
      animation: rowAnimation,
      builder: (context, child) {
        final double progress = rowAnimation.value;
        final double translateY = (1.0 - progress) * 15.0; // 15px -> 0

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Opacity(
            opacity: progress.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleRowTap(option),
          splashColor: Colors.transparent,
          highlightColor: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          child: AnimatedScale(
            scale: isTapped ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeInOut,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              child: Row(
                children: [
                  // Left: 38x38px rounded-11px icon chip
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isTapped ? 0.24 : (isDark ? 0.14 : 0.12)),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 20,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Middle: label text, 13px, weight 500
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  // Right: chevron-right icon, 16px
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: chevronColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
