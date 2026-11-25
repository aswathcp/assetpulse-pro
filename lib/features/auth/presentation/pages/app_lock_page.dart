import 'package:material_ui/material_ui.dart';
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

class _AppLockPageState extends State<AppLockPage> {
  bool _isLoading = false;
  String _message = 'Authenticate with your fingerprint or face recognition to unlock.';

  @override
  void initState() {
    super.initState();
    _triggerBiometricAuth();
  }

  Future<void> _triggerBiometricAuth() async {
    setState(() => _isLoading = true);
    final success = await BiometricService.authenticate();
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        widget.onUnlocked();
      } else {
        setState(() {
          _message = 'Biometric authentication was cancelled or not recognized. Tap below to retry.';
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    try {
      await BiometricService.clearCredentials();
      await AuthService().signOut();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      body: AnimatedGradientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: GlassContainer(
              width: double.infinity,
              borderRadius: 28,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 2),
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.accent,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Biometric App Lock',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: subtitleColor, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 36),

                    // Unlock Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.lock_open_rounded, size: 22),
                        label: Text(
                          _isLoading ? 'Authenticating...' : 'Unlock with Biometrics',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: _isLoading ? null : _triggerBiometricAuth,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Log out button
                    TextButton.icon(
                      onPressed: _isLoading ? null : _handleLogout,
                      icon: const Icon(Icons.logout, size: 18, color: Colors.white60),
                      label: const Text('Log Out of Account', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
