import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/services/app_version_service.dart';

class AppUpdateRequiredPage extends StatefulWidget {
  final VersionCheckResult checkResult;
  final VoidCallback onRetry;

  const AppUpdateRequiredPage({
    super.key,
    required this.checkResult,
    required this.onRetry,
  });

  @override
  State<AppUpdateRequiredPage> createState() => _AppUpdateRequiredPageState();
}

class _AppUpdateRequiredPageState extends State<AppUpdateRequiredPage> {
  bool _isChecking = false;

  Future<void> _handleRefresh() async {
    setState(() => _isChecking = true);
    final result = await AppVersionService.checkVersion();
    if (mounted) {
      setState(() => _isChecking = false);
      if (result.isSupported) {
        widget.onRetry();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Still requires update to v${result.minRequiredVersion} (Installed: v${result.installedVersion})',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedGradientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Warning Shield Icon
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 2),
                  ),
                  child: const Icon(
                    Icons.system_security_update_warning_rounded,
                    color: Colors.redAccent,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'App Update Required',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                Text(
                  'This version of AssetPulse Pro is out of date and cannot connect to plant services.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                GlassContainer(
                  width: double.infinity,
                  borderRadius: 18,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Installed Version:',
                                style: TextStyle(color: Colors.white70, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'v${widget.checkResult.installedVersion}',
                                style: const TextStyle(
                                    color: Colors.redAccent, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Minimum Required:',
                                style: TextStyle(color: Colors.white70, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'v${widget.checkResult.minRequiredVersion}',
                                style: const TextStyle(
                                    color: Colors.greenAccent, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 28, color: Colors.white12),
                        Text(
                          widget.checkResult.message.isNotEmpty
                              ? widget.checkResult.message
                              : (kIsWeb
                                  ? 'Please reload or clear your browser cache (Ctrl+Shift+R or Ctrl+F5) to load the latest web build (v${widget.checkResult.minRequiredVersion}).'
                                  : 'Please download and install the latest APK (v${widget.checkResult.minRequiredVersion}) from your plant electrical engineering supervisor or administrator.'),
                          style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Refresh Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh, size: 20),
                    label: Text(
                      _isChecking ? 'Checking Version...' : (kIsWeb ? 'Reload & Check Again' : 'Check Again'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: _isChecking ? null : _handleRefresh,
                  ),
                ),
                const SizedBox(height: 12),

                // Exit / Sign out button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(kIsWeb ? Icons.refresh : Icons.power_settings_new, color: Colors.white70, size: 18),
                    label: Text(kIsWeb ? 'Reload Web App' : 'Quit App / Exit',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    onPressed: () {
                      if (kIsWeb) {
                        _handleRefresh();
                      } else {
                        SystemNavigator.pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
