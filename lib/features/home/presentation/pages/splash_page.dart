import 'package:flutter/material.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../main.dart'; // For AuthWrapper

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 1. Initialize Hierarchy (Fetch & Cache)
    await HierarchyService().init();

    // 2. Artificial delay for smooth UX (optional)
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      // 3. Navigation to Auth Wrapper
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background - Use App Theme Gradient or Fallback
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                   Theme.of(context).colorScheme.primaryContainer,
                   Theme.of(context).colorScheme.surface,
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo or Title
                Icon(Icons.hub, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  "ASSETPULSE PRO",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 40),
                // Use our Pulse Loading widget
                PulseLoading(size: 40, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  "Loading Environment...",
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
