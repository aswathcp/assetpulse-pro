import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';

class UserUnderReviewPage extends StatefulWidget {
  final User user;
  final Map<String, dynamic> userProfile;
  final VoidCallback onApproved;

  const UserUnderReviewPage({
    super.key,
    required this.user,
    required this.userProfile,
    required this.onApproved,
  });

  @override
  State<UserUnderReviewPage> createState() => _UserUnderReviewPageState();
}

class _UserUnderReviewPageState extends State<UserUnderReviewPage> {
  bool _isChecking = false;
  late Map<String, dynamic> _profile;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _profile = widget.userProfile;
    _listenForRealtimeApproval();
  }

  void _listenForRealtimeApproval() {
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null && mounted) {
        final updatedProfile = snapshot.data()!;
        setState(() => _profile = updatedProfile);

        if (updatedProfile['isValidated'] == true && updatedProfile['isRejected'] != true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account approved! Welcome to AssetPulse Pro.'),
              backgroundColor: AppColors.success,
            ),
          );
          widget.onApproved();
        } else if (updatedProfile['isRejected'] == true) {
          widget.onApproved(); // Triggers AuthWrapper to switch to RequestRejectedPage
        }
      }
    }, onError: (e) {
      debugPrint("Error listening to user review status: $e");
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkApprovalStatus() async {
    setState(() => _isChecking = true);
    try {
      final updatedProfile = await FirestoreService().getUserProfile(widget.user.uid, fromServer: true);

      if (updatedProfile != null) {
        setState(() => _profile = updatedProfile);

        if (updatedProfile['isValidated'] == true && updatedProfile['isRejected'] != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account approved! Welcome to AssetPulse Pro.'),
                backgroundColor: AppColors.success,
              ),
            );
            widget.onApproved();
          }
          return;
        } else if (updatedProfile['isRejected'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your account registration request has been rejected. Please contact administrator.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration is still under review. Please wait for administrator approval.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking status: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile['name'] ?? _profile['displayName'] ?? widget.user.displayName ?? 'New User';
    final email = _profile['email'] ?? widget.user.email ?? '';
    final employeeId = _profile['employeeId'] ?? 'N/A';
    final department = _profile['department'] ?? 'Operations';
    final plant = _profile['plantId'] ?? _profile['plant'] ?? 'All';
    final unit = _profile['unitId'] ?? _profile['unit'] ?? 'All';
    final role = _profile['role'] ?? 'Guest';

    return Scaffold(
      body: AnimatedGradientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Amber Review Badge Icon
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 2),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: Colors.amber,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Registration Under Review',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  'Please wait for administrator approval before accessing the plant system.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // User details card
                GlassContainer(
                  width: double.infinity,
                  borderRadius: 18,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildDetailRow('Account Name', name, Icons.person_outline),
                        const Divider(height: 20, color: Colors.white12),
                        _buildDetailRow('Email Address', email, Icons.email_outlined),
                        const Divider(height: 20, color: Colors.white12),
                        _buildDetailRow('Employee ID', employeeId, Icons.badge_outlined),
                        const Divider(height: 20, color: Colors.white12),
                        _buildDetailRow('Department', department, Icons.business_outlined),
                        const Divider(height: 20, color: Colors.white12),
                        _buildDetailRow('Plant / Unit', '$plant • $unit', Icons.factory_outlined),
                        const Divider(height: 20, color: Colors.white12),
                        _buildDetailRow('Requested Role', role, Icons.admin_panel_settings_outlined),
                        const Divider(height: 20, color: Colors.white12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Status:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.pending_actions, color: Colors.amber, size: 14),
                                  SizedBox(width: 5),
                                  Text(
                                    'Pending Approval',
                                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                      elevation: 2,
                    ),
                    icon: _isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh, size: 20),
                    label: Text(
                      _isChecking ? 'Checking Approval...' : 'Refresh Status',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: _isChecking ? null : _checkApprovalStatus,
                  ),
                ),
                const SizedBox(height: 12),

                // Quit App / Sign Out button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.exit_to_app, color: Colors.white70, size: 18),
                    label: const Text('Quit App / Log Out',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    onPressed: () async {
                      await AuthService().signOut();
                      SystemNavigator.pop();
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
