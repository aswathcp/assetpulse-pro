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
                          _buildMenuItem(
                            context,
                            Icons.help_outline,
                            'Help & Support',
                            onTap: () => _showHelpAndSupportModal(context),
                          ),
                          _buildMenuItem(
                            context,
                            Icons.info_outline,
                            'About AssetPulse Pro',
                            onTap: () => _showAboutAppModal(context),
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
                      'AssetPulse Pro v2.4.0 (Build 2026.2) • ISO 55000 Certified',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          ),
      ),
    );
  }

  void _showAboutAppModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.hub, color: AppColors.accent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AssetPulse Pro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Enterprise Industrial Asset & Operations Suite', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: const Column(
                  children: [
                    _AboutRow(label: 'Application Version', value: 'v2.4.0 (Enterprise Production)'),
                    _AboutRow(label: 'Build Number', value: '2026.2.14-PRO'),
                    _AboutRow(label: 'Standard Compliance', value: 'ISO 55000 / IEC 60034 / IEEE 43'),
                    _AboutRow(label: 'Security & Auth', value: 'RBAC Multi-Tier + Biometric/PIN Lock'),
                    _AboutRow(label: 'Telemetry Engine', value: 'Direct NFC/RFID In-Situ Scanning'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Engineered for heavy industrial plants, steel mills, and automated facilities. Provides zero-data-loss field operations, automated motor/gearbox/pump health scoring, LOTO isolation permit workflows, and plant checklist governance.',
                style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHelpAndSupportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.support_agent, color: Colors.cyanAccent, size: 24),
                  SizedBox(width: 10),
                  Text('Help & Support Center', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    // Emergency & Control Room Support
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Emergency Plant Breakdown Support', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13)),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text('• Main Control Room: Ext 4001 / 4002\n• Electrical Maintenance Cell: Ext 5100\n• Safety & LOTO Officer: Ext 3300', style: TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Standard Operating Procedures (SOP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accent)),
                    const SizedBox(height: 8),
                    _buildHelpCard(
                      icon: Icons.monitor_heart_outlined,
                      title: 'Motor & Asset Diagnostic Tests',
                      desc: 'Open any Asset Detail page -> Log Diagnostic Test. Enter Insulation Resistance (IR in MΩ), Winding Resistance (mΩ), No-Load Current, and DE/NDE Vibration. The system automatically computes IEEE 43 compliant health scores.',
                    ),
                    const SizedBox(height: 8),
                    _buildHelpCard(
                      icon: Icons.nfc,
                      title: 'Direct NFC / RFID Tag Scanning',
                      desc: 'Tap the center "SCAN" button on the bottom navigation bar to read asset RFID chips in the field. Tagged equipment opens instantly in Asset Detail.',
                    ),
                    const SizedBox(height: 8),
                    _buildHelpCard(
                      icon: Icons.lock_clock_outlined,
                      title: 'LOTO Isolation Management',
                      desc: 'Under Operations -> Isolation Management. Request, approve, or de-isolate physical panel feeders before commencing mechanical or electrical work.',
                    ),
                    const SizedBox(height: 16),

                    const Text('Frequently Asked Questions (FAQ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accent)),
                    const SizedBox(height: 8),
                    _buildFaqTile('How do I convert a Standby Spare into Active?', 'Go to the active machine\'s Asset Detail page, tap "Replace with Spare", and choose the compatible spare unit. The system automatically shifts the old asset to "Under Maintenance" and activates the spare.'),
                    _buildFaqTile('Can I export maintenance records to Excel / PDF?', 'Yes! On the Asset Inventory page and each Checklist page, tap the "Excel" or "PDF Report" buttons in the top header to generate instant signed reports.'),
                    _buildFaqTile('How does offline data sync work?', 'All checklist submissions and diagnostic logs are cached locally in SQLite/Firestore offline persistence. When network connectivity resumes, all logs sync to the cloud automatically.'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHelpCard({required IconData icon, required String title, required String desc}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(question, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        children: [
          Text(answer, style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.4)),
        ],
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

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
