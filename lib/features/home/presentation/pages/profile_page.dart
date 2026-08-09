import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/admin_database_page.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/biometric_service.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../admin/presentation/pages/user_management_page.dart';
import '../../../admin/presentation/pages/hierarchy_config_page.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  bool _pinEnabled = false;
  String? _currentPin;

  @override
  void initState() {
    super.initState();
    _loadAppLockSettings();
  }

  Future<void> _loadAppLockSettings() async {
    final available = await BiometricService.isBiometricAvailable();
    final bioEnabled = await BiometricService.isAppLockBiometricsEnabled();
    final pinEnabled = await BiometricService.isAppLockPinEnabled();
    final pin = await BiometricService.getAppLockPin();
    if (mounted) {
      setState(() {
        _bioAvailable = available;
        _bioEnabled = bioEnabled;
        _pinEnabled = pinEnabled;
        _currentPin = pin;
      });
    }
  }

  Future<void> _showSetPinDialog() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Set App Lock PIN'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Enter PIN (4-6 digits)'),
                validator: (val) {
                  if (val == null || val.length < 4) {
                    return 'PIN must be 4 to 6 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
                validator: (val) {
                  if (val != pinController.text) {
                    return 'PINs do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await BiometricService.setAppLockPin(pinController.text);
                await BiometricService.setAppLockPinEnabled(true);
                nav.pop();
                _loadAppLockSettings();
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('PIN App Lock enabled!'), backgroundColor: AppColors.success),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Save PIN', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Profile & Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        centerTitle: true,
      ),
      body: AnimatedGradientBackground(
        child: user == null
          ? const Center(child: PulseLoading(size: 60))
          : FutureBuilder<Map<String, dynamic>?>(
            future: FirestoreService().getUserProfile(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: PulseLoading(size: 60));
              }
              final userData = snapshot.data ?? {};
              final role = userData['role'] ?? 'Guest';
              final department = userData['department'] ?? 'Other';
              final employeeId = userData['employeeId'] ?? 'N/A';

              final isDark = Theme.of(context).brightness == Brightness.dark;
              final textColor = isDark ? Colors.white : Colors.black87;
              final subtitleColor = isDark ? Colors.white54 : Colors.black54;
              final dividerColor = isDark ? Colors.white12 : Colors.black12;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Profile Header Card
                    GlassContainer(
                      width: double.infinity,
                      height: null,
                      borderRadius: 24,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                              child: const Icon(Icons.person, size: 40, color: AppColors.accent),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              userData['displayName'] ?? 'Unknown User',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: textColor, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              role,
                              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: dividerColor),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text('Employee ID', style: TextStyle(color: subtitleColor, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(employeeId, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('Department', style: TextStyle(color: subtitleColor, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(department, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Menu Options
                    GlassContainer(
                      width: double.infinity,
                      height: null,
                      borderRadius: 24,
                      child: Column(
                        children: [
                          _buildThemeToggle(context, themeProvider),
                          Divider(color: dividerColor, height: 1),
                          
                          // Biometrics Settings (Mobile Only)
                          if (!kIsWeb && _bioAvailable) ...[
                            ListTile(
                              leading: Icon(Icons.fingerprint, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                              title: Text('Biometric App Lock', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                              trailing: Switch(
                                value: _bioEnabled,
                                activeThumbColor: AppColors.accent,
                                onChanged: (val) async {
                                  await BiometricService.setAppLockBiometricsEnabled(val);
                                  _loadAppLockSettings();
                                },
                              ),
                            ),
                            Divider(color: dividerColor, height: 1),
                          ],
                          
                          // PIN Lock Settings (Mobile Only)
                          if (!kIsWeb) ...[
                            ListTile(
                              leading: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                              title: Text('PIN Code App Lock', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                              subtitle: _currentPin != null
                                  ? Text('PIN Configured', style: TextStyle(color: subtitleColor, fontSize: 12))
                                  : null,
                              trailing: Switch(
                                value: _pinEnabled,
                                activeThumbColor: AppColors.accent,
                                onChanged: (val) async {
                                  if (val) {
                                    _showSetPinDialog();
                                  } else {
                                    await BiometricService.setAppLockPinEnabled(false);
                                    _loadAppLockSettings();
                                  }
                                },
                              ),
                              onTap: _pinEnabled ? _showSetPinDialog : null,
                            ),
                            Divider(color: dividerColor, height: 1),
                          ],

                          if (role == AppRoles.developer || userData['isAdmin'] == true) 
                            _buildMenuItem(
                              context,
                              Icons.manage_accounts,
                              'User Management',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserManagementPage(currentUserProfile: userData),
                                ),
                              ),
                            ),
                          if (role == AppRoles.developer || userData['isAdmin'] == true)
                            _buildMenuItem(
                              context,
                              Icons.account_tree,
                              'Site Hierarchy Config',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const HierarchyConfigPage(),
                                ),
                              ),
                            ),
                           _buildMenuItem(context, Icons.person_outline, 'Edit Profile'),
                          _buildMenuItem(context, Icons.history, 'Activity Log'),
                          _buildMenuItem(context, Icons.help_outline, 'Help & Support'),
                          if (role == AppRoles.developer)
                            _buildMenuItem(
                              context,
                              Icons.sync_alt,
                              'Data Migration',
                              onTap: () => Navigator.pushNamed(context, '/migration'),
                            ),
                           _buildMenuItem(
                             context,
                             Icons.logout, 
                             'Log Out', 
                             isDestructive: true,
                             onTap: () async {
                               final nav = Navigator.of(context);
                               await BiometricService.clearCredentials();
                               await AuthService().signOut();
                               nav.popUntil((route) => route.isFirst);
                             },
                           ),
                        ],
                      ),
                    ),
                    
                    if (role == AppRoles.developer || userData['isAdmin'] == true) ...[
                       const SizedBox(height: 16),
                       GlassContainer(
                          width: double.infinity,
                          borderRadius: 24,
                          child: _buildMenuItem(
                           context, 
                           Icons.dataset, 
                           'Database Management',
                           onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDatabasePage())),
                          ),
                       ),
                    ],
                    
                    const SizedBox(height: 24),
                    const Text(
                      'Version 1.0.0 (Build 2024.1)',
                      style: TextStyle(color: Colors.white30, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, {bool isDestructive = false, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? AppColors.error : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? AppColors.error : Theme.of(context).colorScheme.onSurface,
          fontWeight: isDestructive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24), size: 16),
      onTap: onTap ?? () {},
    );
  }

  Widget _buildThemeToggle(BuildContext context, ThemeProvider themeProvider) {
    return ListTile(
      leading: Icon(
        themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      title: Text(
        'Dark Mode',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      trailing: Switch(
        value: themeProvider.isDarkMode,
        onChanged: (value) {
          themeProvider.toggleTheme(value);
        },
        activeThumbColor: AppColors.accent,
      ),
    );
  }
}
