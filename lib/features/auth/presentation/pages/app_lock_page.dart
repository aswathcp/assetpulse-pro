import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/services/auth_service.dart';

class AppLockPage extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockPage({super.key, required this.onUnlocked});

  @override
  State<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends State<AppLockPage> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  bool _biometricEnabled = false;
  String? _savedPin;
  bool _isLoading = false;
  String _message = 'Enter PIN or Use Biometrics to Unlock';
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _checkLockSettings();
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .animate(CurvedAnimation(parent: _shakeController, curve: ShakeCurve()))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reset();
        }
      });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkLockSettings() async {
    final bioEnabled = await BiometricService.isAppLockBiometricsEnabled();
    final pinActive = await BiometricService.isAppLockPinEnabled();
    final pin = await BiometricService.getAppLockPin();

    setState(() {
      _biometricEnabled = bioEnabled;
      _savedPin = pin;
      
      if (!bioEnabled && !pinActive) {
        // Fallback: If neither is enabled but AppLock is somehow showing, unlock directly
        widget.onUnlocked();
      }
    });

    if (bioEnabled) {
      _authenticateBiometrics();
    }
  }

  Future<void> _authenticateBiometrics() async {
    final success = await BiometricService.authenticate();
    if (success) {
      widget.onUnlocked();
    } else {
      setState(() {
        _message = 'Biometric unlock failed. Please use PIN.';
      });
    }
  }

  Future<void> _triggerFailureFeedback() async {
    HapticFeedback.vibrate();
    _shakeController.forward();
    setState(() {
      _enteredPin = '';
      _message = 'Incorrect PIN. Please try again.';
    });
  }

  void _onKeyPress(String value) {
    final targetLength = _savedPin?.length ?? 4;
    if (_enteredPin.length < targetLength) {
      setState(() {
        _enteredPin += value;
        _message = 'Enter PIN or Use Biometrics to Unlock';
      });

      // Auto-validate
      if (_enteredPin.length == targetLength) {
        if (_savedPin != null && _enteredPin == _savedPin) {
          widget.onUnlocked();
        } else {
          _triggerFailureFeedback();
        }
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _onClear() {
    setState(() {
      _enteredPin = '';
    });
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    try {
      await BiometricService.clearCredentials();
      await AuthService().signOut();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPinDot(int index, bool isDark) {
    final filled = index < _enteredPin.length;
    final emptyColor = isDark ? Colors.white24 : Colors.black12;
    final borderColor = isDark ? Colors.white38 : Colors.black26;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.accent : emptyColor,
        border: Border.all(
          color: filled ? AppColors.accent : borderColor,
          width: 2,
        ),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
    );
  }

  Widget _buildKeypadButton(
    String label, {
    VoidCallback? onTap,
    IconData? icon,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.all(10),
      child: InkWell(
        onTap: onTap ?? () => _onKeyPress(label),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: textColor, size: 28)
                : Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;
    final keyBgColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);
    final keyBorderColor = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1);

    return Scaffold(
      body: AnimatedGradientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: GlassContainer(
                width: double.infinity,
                borderRadius: 28,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      color: AppColors.accent,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'App Locked',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: subtitleColor, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    
                    // Pin dots indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _savedPin?.length ?? 4,
                        (index) => _buildPinDot(index, isDark),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Custom key pad
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildKeypadButton('1', bgColor: keyBgColor, borderColor: keyBorderColor, textColor: textColor),
                            _buildKeypadButton('2', bgColor: keyBgColor, borderColor: keyBorderColor, textColor: textColor),
                            _buildKeypadButton('3', bgColor: keyBgColor, borderColor: keyBorderColor, textColor: textColor),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildKeypadButton('4', bgColor: keyBgColor, borderColor: keyBorderColor, textColor: textColor),
                            _buildKeypadButton('5', bgColor: keyBgColor, borderColor: keyBorderColor, textColor: textColor),
                            _buildKeypadButton('6', bgColor: keyBgColor, borderColor: keyBorderColor, textColor: textColor),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildKeypadButton('7', bgColor: keyBgColor, borderColor: keyBorderColor, textColor: textColor),
                            _buildKeypadButton('8', bgColor: keyBgColor, borderColor: keyBorderColor, textColor: textColor),
                            _buildKeypadButton('9', bgColor: keyBgColor, borderColor: keyBorderColor, textColor: textColor),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _biometricEnabled
                                ? _buildKeypadButton(
                                    '',
                                    icon: Icons.fingerprint,
                                    onTap: _authenticateBiometrics,
                                    bgColor: keyBgColor,
                                    borderColor: keyBorderColor,
                                    textColor: textColor,
                                  )
                                : _buildKeypadButton(
                                    '',
                                    icon: Icons.clear,
                                    onTap: _onClear,
                                    bgColor: keyBgColor,
                                    borderColor: keyBorderColor,
                                    textColor: textColor,
                                  ),
                            _buildKeypadButton('0', bgColor: keyBgColor, borderColor: keyBorderColor, textColor: textColor),
                            _buildKeypadButton(
                              '',
                              icon: Icons.backspace_outlined,
                              onTap: _onBackspace,
                              bgColor: keyBgColor,
                              borderColor: keyBorderColor,
                              textColor: textColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    TextButton.icon(
                      onPressed: _isLoading ? null : _handleLogout,
                      icon: const Icon(Icons.logout, color: AppColors.error, size: 18),
                      label: const Text(
                        'Sign Out of Account',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShakeCurve extends Curve {
  @override
  double transform(double t) {
    return sin(t * pi * 3);
  }
}
