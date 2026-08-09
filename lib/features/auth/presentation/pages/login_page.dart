import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/biometric_service.dart';

import '../../../../core/widgets/responsive_layout.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  bool _hasSavedCredentials = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.isBiometricAvailable();
    final hasCreds = await BiometricService.hasSavedCredentials();
    if (mounted) {
      setState(() {
        _isBiometricAvailable = available;
        _hasSavedCredentials = hasCreds;
      });
    }
  }

  Future<void> _handleBiometricLogin() async {
    final success = await BiometricService.authenticate();
    if (success) {
      final creds = await BiometricService.getSavedCredentials();
      if (creds != null) {
        _emailController.text = creds['email']!;
        _passwordController.text = creds['password']!;
        _handleLogin(isBiometric: true);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({bool isBiometric = false}) async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final cred = await AuthService().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Check Approval Status
      if (cred?.user != null) {
        final profile = await FirestoreService().getUserProfile(cred!.user!.uid, fromServer: true);
        if (profile != null && profile['isValidated'] == false) {
           await AuthService().signOut();
           throw Exception("Account pending approval. Please contact Admin.");
        }

        // Save credentials if this was normal email/password login
        if (!isBiometric) {
          await BiometricService.saveCredentials(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
        }
      }
      // Auth State Stream in main.dart will handle navigation if we didn't sign out
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AnimatedGradientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.precision_manufacturing_outlined,
                  size: 80,
                  color: AppColors.accent,
                ).animate().fadeIn(duration: 600.ms).scale(),
                const SizedBox(height: 24),
                Text(
                  'AssetPulse Pro',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
                const SizedBox(height: 48),
                ResponsiveContentWrapper(
                  maxWidth: 460,
                  child: GlassContainer(
                    width: double.infinity,
                    height: null,
                    borderRadius: 24,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Welcome Back',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _emailController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Email ID',
                            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                            prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24))),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                            prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24))),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _handleLogin(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const PulseLoading(size: 24, color: Colors.white)
                                : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        if (_isBiometricAvailable && _hasSavedCredentials) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _handleBiometricLogin,
                            icon: const Icon(Icons.fingerprint, color: AppColors.accent),
                            label: const Text('Login with Biometrics', style: TextStyle(color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.accent),
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () async {
                             // Password Reset Trigger
                             if (_emailController.text.isEmpty) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(content: Text('Please enter your Email ID to reset password.'), backgroundColor: AppColors.warning),
                               );
                               return;
                             }
                             try {
                               await AuthService().sendPasswordResetEmail(_emailController.text.trim());
                               if (context.mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   const SnackBar(content: Text('Password Reset Email Sent! Check your inbox or spam folder.'), backgroundColor: AppColors.success),
                                 );
                               }
                             } catch (e) {
                               if (context.mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                                 );
                               }
                             }
                          },
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: const Text(
                            'Create an Account',
                            style: TextStyle(color: AppColors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
