import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/auth_service.dart';
import 'core/services/firestore_service.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/home/presentation/pages/splash_page.dart';
import 'features/admin/migration_page.dart';
import 'core/widgets/pulse_loading.dart';
import 'core/widgets/glass_container.dart';
import 'core/widgets/animated_gradient_background.dart';
import 'core/services/biometric_service.dart';
import 'features/auth/presentation/pages/app_lock_page.dart';
// Note: You must generate this file using `flutterfire configure`
// If it doesn't exist, remove the import and options parameter, but Auth won't work in prod
import 'firebase_options.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
    // Fallback if options are not generated yet, will crash on actual usage potentially
    // await Firebase.initializeApp(); 
  }
  runApp(const AssetPulseApp());
}

class AssetPulseApp extends StatelessWidget {
  const AssetPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'AssetPulse Pro',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashPage(),
            routes: {
              '/login': (context) => const LoginPage(),
              '/register': (context) => const RegisterPage(),
              '/home': (context) => const HomePage(),
              '/migration': (context) => const MigrationPage(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _currentUser;
  bool _isValidating = false;
  bool _isValidated = false;
  bool _isRejected = false;
  bool _appLockLocked = true;
  Map<String, dynamic>? _userProfile;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAppLockStatus();
    _authSubscription = AuthService().authStateChanges.listen((user) {
      _handleAuthChange(user);
    });
  }

  Future<void> _checkAppLockStatus() async {
    final bioEnabled = await BiometricService.isAppLockBiometricsEnabled();
    final pinEnabled = await BiometricService.isAppLockPinEnabled();
    if (mounted) {
      setState(() {
        _appLockLocked = bioEnabled || pinEnabled;
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthChange(User? user) async {
    if (user == null) {
      if (mounted) {
        setState(() {
          _currentUser = null;
          _isValidating = false;
          _isValidated = false;
          _isRejected = false;
          _userProfile = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isValidating = true;
      });
    }

    try {
      if (user.email == 'cpstudio.in@gmail.com') {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'role': 'Developer',
            'isValidated': true,
            'isRejected': false,
          });
        } catch (_) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'displayName': 'C P Studio',
            'employeeId': '00000000',
            'role': 'Developer',
            'department': 'Operations',
            'unitId': 'VAB',
            'plantId': 'VAB',
            'isValidated': true,
            'isRejected': false,
            'isRequestingAuth': true,
            'isIsolationAuth': true,
          }, SetOptions(merge: true));
        }
      }

      final profile = await FirestoreService().getUserProfile(user.uid, fromServer: true);
      if (profile != null) {
        if (profile['isRejected'] == true) {
          if (mounted) {
            setState(() {
              _currentUser = user;
              _userProfile = profile;
              _isRejected = true;
              _isValidated = false;
              _isValidating = false;
            });
          }
        } else if (profile['isValidated'] == true) {
          final bioEnabled = await BiometricService.isAppLockBiometricsEnabled();
          final pinEnabled = await BiometricService.isAppLockPinEnabled();
          if (mounted) {
            setState(() {
              _currentUser = user;
              _userProfile = profile;
              _appLockLocked = bioEnabled || pinEnabled;
              _isValidated = true;
              _isRejected = false;
              _isValidating = false;
            });
          }
        } else {
          // Pending approval (isValidated == false)
          await AuthService().signOut();
          if (mounted) {
            setState(() {
              _currentUser = null;
              _isValidated = false;
              _isRejected = false;
              _isValidating = false;
              _userProfile = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account pending approval. Please contact Admin.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } else {
        await AuthService().signOut();
        if (mounted) {
          setState(() {
            _currentUser = null;
            _isValidated = false;
            _isRejected = false;
            _isValidating = false;
            _userProfile = null;
          });
        }
      }
    } catch (e) {
      await AuthService().signOut();
      if (mounted) {
        setState(() {
          _currentUser = null;
          _isValidated = false;
          _isRejected = false;
          _isValidating = false;
          _userProfile = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isValidating) {
      return const Scaffold(
        body: Center(child: PulseLoading(size: 60)),
      );
    }

    if (_currentUser != null) {
      if (_isRejected && _userProfile != null) {
        return RequestRejectedPage(user: _currentUser!, profile: _userProfile!);
      }
      if (_isValidated) {
        if (_appLockLocked) {
          return AppLockPage(
            onUnlocked: () {
              setState(() {
                _appLockLocked = false;
              });
            },
          );
        }
        return const HomePage();
      }
    }

    return const LoginPage();
  }
}

class RequestRejectedPage extends StatefulWidget {
  final User user;
  final Map<String, dynamic> profile;

  const RequestRejectedPage({super.key, required this.user, required this.profile});

  @override
  State<RequestRejectedPage> createState() => _RequestRejectedPageState();
}

class _RequestRejectedPageState extends State<RequestRejectedPage> {
  bool _isLoading = false;

  Future<void> _resubmitRequest() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
        'isRejected': false,
        'isValidated': false,
      });
      await AuthService().signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request re-submitted successfully! Waiting for admin approval.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUserData() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).delete();
      try {
        await widget.user.delete();
      } catch (e) {
        debugPrint("User Auth deletion skipped: $e");
      }
      await AuthService().signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User data deleted. You can register again.'), backgroundColor: AppColors.info),
        );
      }
    } catch (e) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).delete();
      } catch (_) {}
      await AuthService().signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account cleared. Please sign up again. Details: $e'), backgroundColor: AppColors.warning),
        );
      }
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
              borderRadius: 24,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _isLoading 
                ? const Center(child: PulseLoading(size: 60))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cancel, color: AppColors.error, size: 64),
                      const SizedBox(height: 20),
                      Text(
                        'Request Rejected',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your account request for Employee ID ${widget.profile['employeeId']} has been rejected by the administrator.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: subtitleColor, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _resubmitRequest,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text('Re-submit Request', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _deleteUserData,
                        icon: const Icon(Icons.delete_forever, color: AppColors.error),
                        label: const Text('Delete My Data', style: TextStyle(color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => AuthService().signOut(),
                        child: Text('Back to Login', style: TextStyle(color: subtitleColor)),
                      )
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
