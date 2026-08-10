import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../log_data/presentation/pages/log_fault_page.dart';
import '../../../log_data/presentation/pages/gen_work_log_page.dart';
import '../../../operations/presentation/pages/isolation_management_page.dart';
import '../../../operations/presentation/pages/checklist/checklist_management_dashboard.dart';
import '../../../operations/presentation/pages/checklist/shift_checklists_page.dart';
import '../../../assets/data/models/fault_log_model.dart';
import '../widgets/custom_app_bar.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simulate brief initial load for zero-CLS shimmer transition
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  // Exact Plant Shift Engine (Matches shift_checklists_page.dart)
  String _getCurrentShiftCode() {
    final hour = DateTime.now().hour;
    if (hour >= 7 && hour < 15) return 'AS'; // 07:00 – 15:00
    if (hour >= 15 && hour < 23) return 'BS'; // 15:00 – 23:00
    return 'CS'; // 23:00 – 07:00
  }

  String _getShiftLabel(String code) {
    switch (code) {
      case 'AS':
        return 'A-Shift (07:00–15:00)';
      case 'BS':
        return 'B-Shift (15:00–23:00)';
      case 'CS':
        return 'C-Shift (23:00–07:00)';
      default:
        return code;
    }
  }

  String _getRelativeTime(DateTime? date) {
    if (date == null) return 'Just now';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(title: 'Operations Dashboard'),
        body: Center(child: PulseLoading(size: 40)),
      );
    }

    final currentShift = _getCurrentShiftCode();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Operations Dashboard'),
      body: ResponsiveContentWrapper(
        maxWidth: 1320,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Live Plant Shift & User Duty Header
              _buildShiftHeader(context, currentShift).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05, end: 0),
              const SizedBox(height: 16),

              // 2. Live Asset Fleet Health & Operational Readiness Overview
              _buildLiveFleetOverview(context).animate().fadeIn(duration: 350.ms),
              const SizedBox(height: 16),

              // 3. Quick Action Launchers
              _buildSectionTitle('Operational Actions'),
              const SizedBox(height: 10),
              _buildQuickActionsRow(context).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 18),

              // 4. Live Critical Alerts & Open Faults
              _buildSectionTitle('Active Critical Alerts & Faults'),
              const SizedBox(height: 10),
              _buildLiveFaultsStream(context),
              const SizedBox(height: 18),

              // 5. Live Recent Activity Stream (activity_logs)
              _buildSectionTitle('Recent Plant Activity Log'),
              const SizedBox(height: 10),
              _buildLiveActivityLogStream(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // --- 1. SHIFT HEADER ---
  Widget _buildShiftHeader(BuildContext context, String currentShift) {
    final user = AuthService().currentUser;

    return GlassContainer(
      width: double.infinity,
      borderRadius: 20,
      border: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.access_time_filled, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getShiftLabel(currentShift),
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: user != null ? _firestoreService.getUserProfile(user.uid) : null,
                    builder: (context, snapshot) {
                      final name = snapshot.data?['displayName'] ?? user?.displayName ?? 'Duty Engineer';
                      final dept = snapshot.data?['department'] ?? 'Operations';
                      return Text(
                        '$name • $dept',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.playlist_add_check, color: AppColors.accent, size: 24),
              tooltip: 'Open Shift Checklists',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShiftChecklistsPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. LIVE FLEET OVERVIEW ---
  Widget _buildLiveFleetOverview(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('assets').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final total = docs.length;
        final active = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'active').length;
        final spares = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'spare').length;
        final maintenance = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'underMaintenance').length;
        final critical = docs.where((d) => (d.data() as Map<String, dynamic>)['isCritical'] == true).length;
        final readiness = total == 0 ? 0.0 : ((active + spares) / total) * 100;

        return GlassContainer(
          width: double.infinity,
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.hub_outlined, color: AppColors.accent, size: 18),
                        SizedBox(width: 8),
                        Text('Plant Asset Fleet Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: readiness >= 85 ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: readiness >= 85 ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.orangeAccent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${readiness.toStringAsFixed(0)}% Fleet Ready',
                        style: TextStyle(
                          color: readiness >= 85 ? Colors.greenAccent : Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildMetricTile('Total Assets', '$total', Colors.white, Icons.storage_outlined)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildMetricTile('In-Service', '$active', Colors.greenAccent, Icons.bolt_outlined)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildMetricTile('Spares', '$spares', Colors.cyanAccent, Icons.inventory_2_outlined)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildMetricTile(
                      maintenance > 0 ? 'Maintenance' : 'Critical',
                      maintenance > 0 ? '$maintenance' : '$critical',
                      maintenance > 0 ? Colors.redAccent : Colors.orangeAccent,
                      maintenance > 0 ? Icons.build_circle_outlined : Icons.warning_amber_outlined,
                    )),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.white70)),
        ],
      ),
    );
  }

  // --- 3. QUICK ACTIONS ---
  Widget _buildQuickActionsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionBtn(
            context,
            title: 'Log Fault',
            icon: Icons.warning_amber_rounded,
            color: Colors.redAccent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogFaultPage())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionBtn(
            context,
            title: 'General Work',
            icon: Icons.engineering_outlined,
            color: Colors.blueAccent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GenWorkLogPage())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionBtn(
            context,
            title: 'LOTO Permits',
            icon: Icons.lock_clock_outlined,
            color: Colors.amberAccent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IsolationManagementPage())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionBtn(
            context,
            title: 'Checklists',
            icon: Icons.checklist_outlined,
            color: Colors.tealAccent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChecklistManagementDashboard())),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. LIVE CRITICAL FAULTS STREAM ---
  Widget _buildLiveFaultsStream(BuildContext context) {
    return StreamBuilder<List<FaultLogModel>>(
      stream: _firestoreService.getOpenFaultLogsStream(),
      builder: (context, snapshot) {
        final faults = snapshot.data ?? [];

        if (faults.isEmpty) {
          return GlassContainer(
            borderRadius: 16,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('All Systems Operating Normally', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('No active critical breakdown faults recorded', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: faults.take(3).map((fault) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              fault.masterEquipmentId.isNotEmpty ? fault.masterEquipmentId : 'Plant Equipment',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              _getRelativeTime(fault.reportedAt),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fault.odc.isNotEmpty ? fault.odc : fault.cause,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // --- 5. LIVE RECENT ACTIVITY LOGS ---
  Widget _buildLiveActivityLogStream(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getActivityLogsStream(limit: 6),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: PulseLoading(size: 24));
        }

        final logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return GlassContainer(
            borderRadius: 16,
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No recent activity records found.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            ),
          );
        }

        return Column(
          children: logs.map((log) {
            final action = log['action']?.toString() ?? 'Operation Performed';
            final details = log['details']?.toString() ?? '';
            final ts = (log['timestamp'] as Timestamp?)?.toDate();
            final timeStr = _getRelativeTime(ts);

            IconData icon = Icons.check_circle_outline;
            Color iconColor = AppColors.accent;
            if (action.toLowerCase().contains('fault') || action.toLowerCase().contains('breakdown')) {
              icon = Icons.warning_amber_rounded;
              iconColor = Colors.redAccent;
            } else if (action.toLowerCase().contains('diagnostic') || action.toLowerCase().contains('test')) {
              icon = Icons.monitor_heart_outlined;
              iconColor = Colors.cyanAccent;
            } else if (action.toLowerCase().contains('spare') || action.toLowerCase().contains('replace')) {
              icon = Icons.swap_horiz;
              iconColor = Colors.orangeAccent;
            } else if (action.toLowerCase().contains('loto') || action.toLowerCase().contains('isolation')) {
              icon = Icons.lock_clock_outlined;
              iconColor = Colors.amberAccent;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        if (details.isNotEmpty)
                          Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(timeStr, style: const TextStyle(fontSize: 9, color: Colors.white38)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
