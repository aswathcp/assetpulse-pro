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
import 'core/services/app_version_service.dart';
import 'core/constants/app_version.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/app_update_required_page.dart';
import 'features/auth/presentation/pages/user_under_review_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/home/presentation/pages/splash_page.dart';
import 'core/widgets/pulse_loading.dart';
import 'core/widgets/glass_container.dart';
import 'core/widgets/animated_gradient_background.dart';
import 'core/services/biometric_service.dart';
import 'core/services/hierarchy_service.dart';
import 'features/auth/presentation/pages/app_lock_page.dart';
import 'core/services/memory_optimization_service.dart';
// Note: You must generate this file using `flutterfire configure`
// If it doesn't exist, remove the import and options parameter, but Auth won't work in prod
import 'firebase_options.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MemoryOptimizationService.initialize();
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
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginPage(),
              '/register': (context) => const RegisterPage(),
              '/home': (context) => const HomePage(),
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
  bool _isInitialLoading = true;
  bool _isValidating = false;
  bool _isValidated = false;
  bool _isRejected = false;
  bool _isPendingApproval = false;
  bool _appLockLocked = true;
  VersionCheckResult? _versionCheckResult;
  Map<String, dynamic>? _userProfile;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSubscription;

  @override
  void initState() {
    super.initState();
    _initializeSystem();
  }

  Future<void> _initializeSystem() async {
    final startTime = DateTime.now();

    try {
      // 1. Run Hierarchy init, App version check, and biometric check in parallel
      final results = await Future.wait([
        HierarchyService().init().catchError((e) {
          debugPrint("HierarchyService init error: $e");
          return null;
        }),
        AppVersionService.checkVersion().catchError((e) {
          debugPrint("AppVersionService check error: $e");
          return VersionCheckResult(
            isSupported: true,
            installedVersion: AppVersion.currentVersion,
            minRequiredVersion: AppVersion.currentVersion,
            message: '',
          );
        }),
        BiometricService.isAppLockBiometricsEnabled().catchError((e) => false),
      ]);

      _versionCheckResult = results[1] as VersionCheckResult;
      final bioEnabled = results[2] as bool;

      // 2. Resolve initial user session
      final user = AuthService().currentUser;
      if (user != null) {
        // Developer auto-provision
        if (user.email == 'cpstudio.in@gmail.com') {
          try {
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
          } catch (_) {}
        }

        try {
          final profile = await FirestoreService()
              .getUserProfile(user.uid, fromServer: true)
              .timeout(const Duration(seconds: 4), onTimeout: () => null);
          _applyUserProfile(user, profile, bioEnabled);
        } catch (e) {
          _applyUserProfile(user, null, bioEnabled);
        }
      } else {
        _currentUser = null;
        _isValidated = false;
        _isRejected = false;
        _isPendingApproval = false;
        _userProfile = null;
      }
    } catch (e) {
      debugPrint("Startup initialization error: $e");
    }

    // Ensure a brief minimum 400ms duration so splash renders smoothly without jarring flash
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    if (elapsed < 400) {
      await Future.delayed(Duration(milliseconds: 400 - elapsed));
    }

    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
      _startListeners();
    }
  }

  void _startListeners() {
    // 1. Auth state changes
    _authSubscription?.cancel();
    _authSubscription = AuthService().authStateChanges.listen((user) {
      _handleAuthChange(user);
    });

    // 2. Real-time user doc listener
    if (_currentUser != null) {
      _listenToUserDoc(_currentUser!.uid);
    }
  }

  void _listenToUserDoc(String? uid) {
    _userDocSubscription?.cancel();
    if (uid == null) return;

    _userDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null && mounted) {
        debugPrint("User document snapshot received in real-time.");
        final data = snapshot.data()!;
        _applyUserProfile(_currentUser ?? AuthService().currentUser!, data, _appLockLocked);
        if (mounted) setState(() {});
      }
    }, onError: (e) {
      debugPrint("Error listening to user doc: $e");
    });
  }

  void _applyUserProfile(User user, Map<String, dynamic>? profile, bool bioEnabled) {
    _currentUser = user;
    if (profile != null) {
      _userProfile = profile;
      if (profile['isRejected'] == true) {
        _isRejected = true;
        _isValidated = false;
        _isPendingApproval = false;
      } else if (profile['isValidated'] == true) {
        _isValidated = true;
        _isRejected = false;
        _isPendingApproval = false;
        _appLockLocked = bioEnabled;
      } else {
        // Pending approval
        _isPendingApproval = true;
        _isValidated = false;
        _isRejected = false;
      }
    } else {
      _userProfile = {
        'name': user.displayName ?? user.email,
        'email': user.email,
        'isValidated': false,
        'isRejected': false,
      };
      _isPendingApproval = true;
      _isValidated = false;
      _isRejected = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthChange(User? user) async {
    if (user == null) {
      _userDocSubscription?.cancel();
      if (mounted) {
        setState(() {
          _currentUser = null;
          _isValidating = false;
          _isValidated = false;
          _isRejected = false;
          _isPendingApproval = false;
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
      await _checkAppVersion();
      final bioEnabled = await BiometricService.isAppLockBiometricsEnabled().catchError((_) => false);
      final profile = await FirestoreService().getUserProfile(user.uid, fromServer: true);
      _applyUserProfile(user, profile, bioEnabled);
      _listenToUserDoc(user.uid);
    } catch (e) {
      debugPrint("Auth change error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  Future<void> _checkAppVersion() async {
    final result = await AppVersionService.checkVersion();
    if (mounted) {
      setState(() {
        _versionCheckResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Initial startup splash screen (single loading screen)
    if (_isInitialLoading) {
      return const SplashView(statusText: 'Starting AssetPulse Pro...');
    }

    // 2. Minimum app version gating
    if (_versionCheckResult != null && !_versionCheckResult!.isSupported) {
      return AppUpdateRequiredPage(
        checkResult: _versionCheckResult!,
        onRetry: () => _checkAppVersion(),
      );
    }

    // 3. Subsequent authentication transition loading
    if (_isValidating) {
      return const SplashView(statusText: 'Verifying session...');
    }

    // 4. Authenticated destinations
    if (_currentUser != null) {
      // Rejection state
      if (_isRejected && _userProfile != null) {
        return RequestRejectedPage(
          user: _currentUser!,
          profile: _userProfile!,
          onResubmitted: () {
            _handleAuthChange(_currentUser);
          },
        );
      }

      // Pending admin review state
      if (_isPendingApproval && _userProfile != null) {
        return UserUnderReviewPage(
          user: _currentUser!,
          userProfile: _userProfile!,
          onApproved: () {
            _handleAuthChange(_currentUser);
          },
        );
      }

      // Approved / Validated user state
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

    // 5. Unauthenticated user
    return const LoginPage();
  }
}

class RequestRejectedPage extends StatefulWidget {
  final User user;
  final Map<String, dynamic> profile;
  final VoidCallback? onResubmitted;

  const RequestRejectedPage({
    super.key,
    required this.user,
    required this.profile,
    this.onResubmitted,
  });

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
        'rejectionReason': FieldValue.delete(),
        'resubmittedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request re-submitted! Awaiting administrator review.'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onResubmitted?.call();
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account Data?'),
        content: const Text(
          'This will permanently remove your registration data from the system so you can re-register with fresh details. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

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
          const SnackBar(content: Text('Account data cleared. You can register again.'), backgroundColor: AppColors.info),
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
    final reason = widget.profile['rejectionReason'];

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
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.error.withValues(alpha: 0.15),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.4), width: 2),
                        ),
                        child: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 54),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Registration Rejected',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your registration request for Employee ID ${widget.profile['employeeId'] ?? 'N/A'} was not approved by the administrator.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: subtitleColor, fontSize: 13.5, height: 1.4),
                      ),
                      const SizedBox(height: 18),

                      // Rejection reason note if provided
                      if (reason != null && reason.toString().trim().isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline, color: AppColors.error, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Reason from Administrator:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                reason.toString(),
                                style: TextStyle(fontSize: 13, color: textColor),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      ElevatedButton.icon(
                        onPressed: _resubmitRequest,
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                        label: const Text('Re-submit Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _deleteUserData,
                        icon: const Icon(Icons.delete_forever, color: AppColors.error, size: 18),
                        label: const Text('Delete My Data & Start Over', style: TextStyle(color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => AuthService().signOut(),
                        icon: Icon(Icons.logout, size: 16, color: subtitleColor),
                        label: Text('Sign Out / Use Another Account', style: TextStyle(color: subtitleColor, fontSize: 13)),
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
