import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_roles.dart';
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
  String? _userPlant;
  String? _userUnit;
  String? _userRole;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = AuthService().currentUser;
    if (user != null) {
      final profile = await _firestoreService.getUserProfile(user.uid);
      if (profile != null && mounted) {
        setState(() {
          _userProfile = profile;
          _userRole = profile['role'] ?? AppRoles.guest;
          _userPlant = profile['plantId'] as String?;
          _userUnit = profile['unitId'] as String?;
        });
      }
    }
    // Smooth zero-CLS transition matching assets tab
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _isLoading = false);
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

  // --- SKELETON SHIMMER LOADER (ZERO CLS - Matches Assets Tab) ---
  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        children: [
          // 1. Shimmer Shift Header
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),

          // 2. Shimmer Live Fleet Status Card
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),

          // 3. Shimmer Operational Actions
          Row(
            children: List.generate(4, (index) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
              ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
            )),
          ),
          const SizedBox(height: 18),

          // 4. Shimmer Alerts & Faults
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 18),

          // 5. Shimmer Activity Cards
          ...List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08));
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CustomAppBar(title: 'Dashboard'),
        body: _buildSkeletonLoader(),
      );
    }

    final currentShift = _getCurrentShiftCode();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Dashboard'),
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
              _buildSectionTitle(_userUnit != null && _userUnit!.isNotEmpty && _userUnit != 'All'
                  ? 'Recent Activity Log ($_userUnit)'
                  : 'Recent Plant Activity Log'),
              const SizedBox(height: 10),
              _buildLiveActivityLogStream(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 16,
          decoration: BoxDecoration(
            color: isDark ? AppColors.accent : const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  // --- 1. SHIFT HEADER ---
  Widget _buildShiftHeader(BuildContext context, String currentShift) {
    final user = AuthService().currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                color: isDark ? AppColors.accent.withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppColors.accent.withValues(alpha: 0.3) : const Color(0xFFBFDBFE)),
              ),
              child: Icon(Icons.access_time_filled, color: isDark ? AppColors.accent : const Color(0xFF2563EB), size: 24),
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
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.success : const Color(0xFF059669),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getShiftLabel(currentShift),
                        style: TextStyle(
                          color: isDark ? AppColors.accent : const Color(0xFF1D4ED8),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Builder(
                    builder: (context) {
                      final name = _userProfile?['displayName'] ?? user?.displayName ?? 'Duty Engineer';
                      final dept = _userProfile?['department'] ?? 'Operations';
                      final roleStr = _userRole != null && _userRole!.isNotEmpty ? ' (${_userRole!})' : '';
                      final scopeStr = (_userPlant != null && _userPlant!.isNotEmpty && _userUnit != null && _userUnit!.isNotEmpty)
                          ? ' • $_userPlant · $_userUnit'
                          : (_userUnit != null && _userUnit!.isNotEmpty ? ' • $_userUnit' : '');
                      return Text(
                        '$name$roleStr • $dept$scopeStr',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)
                              : const Color(0xFF475569),
                          fontSize: 12,
                          fontWeight: isDark ? FontWeight.normal : FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.playlist_add_check, color: isDark ? AppColors.accent : const Color(0xFF2563EB), size: 24),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('assets').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
          );
        }

        final allDocs = snapshot.data!.docs;
        final docs = (_userUnit == null || _userUnit!.isEmpty || _userUnit == 'All')
            ? allDocs
            : allDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final u = _userUnit!.toUpperCase();
                final assetUnit = (data['unitId'] ?? '').toString().toUpperCase();
                if (assetUnit.isNotEmpty && assetUnit == u) return true;
                final idUpper = d.id.toUpperCase();
                final tagUpper = (data['tagNo'] ?? '').toString().toUpperCase();
                return idUpper.contains('-$u-') ||
                    tagUpper.contains('-$u-') ||
                    idUpper.startsWith('$u-') ||
                    tagUpper.startsWith('$u-');
              }).toList();

        final total = docs.length;
        final active = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'active').length;
        final spares = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'spare').length;
        final maintenance = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'underMaintenance').length;
        final critical = docs.where((d) => (d.data() as Map<String, dynamic>)['isCritical'] == true).length;
        final readiness = total == 0 ? 0.0 : ((active + spares) / total) * 100;

        final bool isHighReadiness = readiness >= 85;
        final badgeBg = isDark
            ? (isHighReadiness ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15))
            : (isHighReadiness ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7));
        final badgeBorder = isDark
            ? (isHighReadiness ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.orangeAccent.withValues(alpha: 0.4))
            : (isHighReadiness ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A));
        final badgeText = isDark
            ? (isHighReadiness ? Colors.greenAccent : Colors.orangeAccent)
            : (isHighReadiness ? const Color(0xFF15803D) : const Color(0xFFB45309));

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
                    Row(
                      children: [
                        Icon(Icons.hub_outlined, color: isDark ? AppColors.accent : const Color(0xFF2563EB), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          (_userUnit != null && _userUnit!.isNotEmpty && _userUnit != 'All')
                              ? '$_userUnit Asset Fleet Status'
                              : 'Plant Asset Fleet Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Text(
                        '${readiness.toStringAsFixed(0)}% Fleet Ready',
                        style: TextStyle(
                          color: badgeText,
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
                    Expanded(
                      child: _buildMetricTile(
                        context: context,
                        label: 'Total Assets',
                        value: '$total',
                        icon: Icons.storage_outlined,
                        darkColor: Colors.white,
                        lightIconColor: const Color(0xFF334155),
                        lightValColor: const Color(0xFF0F172A),
                        lightBg: const Color(0xFFF8FAFC),
                        lightBorder: const Color(0xFFE2E8F0),
                        lightLabelColor: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMetricTile(
                        context: context,
                        label: 'In-Service',
                        value: '$active',
                        icon: Icons.bolt_outlined,
                        darkColor: Colors.greenAccent,
                        lightIconColor: const Color(0xFF059669),
                        lightValColor: const Color(0xFF047857),
                        lightBg: const Color(0xFFECFDF5),
                        lightBorder: const Color(0xFFA7F3D0),
                        lightLabelColor: const Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMetricTile(
                        context: context,
                        label: 'Spares',
                        value: '$spares',
                        icon: Icons.inventory_2_outlined,
                        darkColor: Colors.cyanAccent,
                        lightIconColor: const Color(0xFF0284C7),
                        lightValColor: const Color(0xFF0369A1),
                        lightBg: const Color(0xFFF0F9FF),
                        lightBorder: const Color(0xFFBAE6FD),
                        lightLabelColor: const Color(0xFF075985),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMetricTile(
                        context: context,
                        label: maintenance > 0 ? 'Maintenance' : 'Critical',
                        value: maintenance > 0 ? '$maintenance' : '$critical',
                        icon: maintenance > 0 ? Icons.build_circle_outlined : Icons.warning_amber_outlined,
                        darkColor: maintenance > 0 ? Colors.redAccent : Colors.orangeAccent,
                        lightIconColor: maintenance > 0 ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                        lightValColor: maintenance > 0 ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
                        lightBg: maintenance > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                        lightBorder: maintenance > 0 ? const Color(0xFFFECACA) : const Color(0xFFFDE68A),
                        lightLabelColor: maintenance > 0 ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color darkColor,
    required Color lightIconColor,
    required Color lightValColor,
    required Color lightBg,
    required Color lightBorder,
    Color? lightLabelColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? darkColor.withValues(alpha: 0.08) : lightBg;
    final border = isDark ? darkColor.withValues(alpha: 0.2) : lightBorder;
    final icColor = isDark ? darkColor : lightIconColor;
    final valColor = isDark ? darkColor : lightValColor;
    final lblColor = isDark ? Colors.white70 : (lightLabelColor ?? const Color(0xFF475569));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: icColor, size: 15),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valColor)),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isDark ? FontWeight.normal : FontWeight.w600,
              color: lblColor,
            ),
          ),
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
            darkColor: Colors.redAccent,
            lightIconColor: const Color(0xFFDC2626),
            lightBg: const Color(0xFFFEF2F2),
            lightBorder: const Color(0xFFFECACA),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogFaultPage())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionBtn(
            context,
            title: 'General Work',
            icon: Icons.engineering_outlined,
            darkColor: Colors.blueAccent,
            lightIconColor: const Color(0xFF2563EB),
            lightBg: const Color(0xFFEFF6FF),
            lightBorder: const Color(0xFFBFDBFE),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GenWorkLogPage())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionBtn(
            context,
            title: 'LOTO Permits',
            icon: Icons.lock_clock_outlined,
            darkColor: Colors.amberAccent,
            lightIconColor: const Color(0xFFD97706),
            lightBg: const Color(0xFFFFFBEB),
            lightBorder: const Color(0xFFFDE68A),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IsolationManagementPage())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionBtn(
            context,
            title: 'Checklists',
            icon: Icons.checklist_outlined,
            darkColor: Colors.tealAccent,
            lightIconColor: const Color(0xFF0D9488),
            lightBg: const Color(0xFFF0FDFA),
            lightBorder: const Color(0xFF99F6E4),
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
    required Color darkColor,
    required Color lightIconColor,
    required Color lightBg,
    required Color lightBorder,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? darkColor.withValues(alpha: 0.1) : lightBg;
    final border = isDark ? darkColor.withValues(alpha: 0.3) : lightBorder;
    final icColor = isDark ? darkColor : lightIconColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Icon(icon, color: icColor, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. LIVE CRITICAL FAULTS STREAM ---
  Widget _buildLiveFaultsStream(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<FaultLogModel>>(
      stream: _firestoreService.getOpenFaultLogsStream(),
      builder: (context, snapshot) {
        var faults = snapshot.data ?? [];
        if (_userUnit != null && _userUnit!.isNotEmpty && _userUnit != 'All') {
          final u = _userUnit!.toUpperCase();
          faults = faults.where((f) {
            final fUnit = (f.unitId ?? '').toUpperCase();
            if (fUnit.isNotEmpty && fUnit == u) return true;
            final meId = f.masterEquipmentId.toUpperCase();
            final aId = (f.assetId ?? '').toUpperCase();
            return meId.contains('-$u-') ||
                meId.startsWith('$u-') ||
                aId.contains('-$u-') ||
                aId.startsWith('$u-');
          }).toList();
        }

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
                      color: isDark ? Colors.green.withValues(alpha: 0.15) : const Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_outline, color: isDark ? Colors.greenAccent : const Color(0xFF059669), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Systems Operating Normally',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          (_userUnit != null && _userUnit!.isNotEmpty && _userUnit != 'All')
                              ? 'No active critical breakdown faults recorded for $_userUnit'
                              : 'No active critical breakdown faults recorded',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey : const Color(0xFF475569),
                          ),
                        ),
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
                color: isDark ? Colors.red.withValues(alpha: 0.1) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.redAccent.withValues(alpha: 0.3) : const Color(0xFFFECACA)),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: isDark ? Colors.redAccent : const Color(0xFFDC2626), size: 22),
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              _getRelativeTime(fault.reportedAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey : const Color(0xFF64748B),
                                fontWeight: isDark ? FontWeight.normal : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fault.odc.isNotEmpty ? fault.odc : fault.cause,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getActivityLogsStream(limit: 25),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: PulseLoading(size: 24));
        }

        var logs = snapshot.data ?? [];
        if (_userUnit != null && _userUnit!.isNotEmpty && _userUnit != 'All') {
          final u = _userUnit!.toUpperCase();
          logs = logs.where((log) {
            final logUnit = (log['unitId'] ?? '').toString().toUpperCase();
            if (logUnit.isNotEmpty && logUnit == u) return true;
            final details = (log['details'] ?? '').toString().toUpperCase();
            final action = (log['action'] ?? '').toString().toUpperCase();
            return details.contains('-$u-') ||
                details.contains('$u-') ||
                details.contains('FOR $u') ||
                details.contains('IN $u') ||
                action.contains('-$u-') ||
                action.contains('$u-');
          }).toList();
        }

        if (logs.isEmpty) {
          return GlassContainer(
            borderRadius: 16,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  (_userUnit != null && _userUnit!.isNotEmpty && _userUnit != 'All')
                      ? 'No recent activity records found for $_userUnit.'
                      : 'No recent activity records found.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          children: logs.take(6).map((log) {
            final action = log['action']?.toString() ?? 'Operation Performed';
            final details = log['details']?.toString() ?? '';
            final ts = (log['timestamp'] as Timestamp?)?.toDate();
            final timeStr = _getRelativeTime(ts);

            IconData icon = Icons.check_circle_outline;
            Color iconColor = isDark ? AppColors.accent : const Color(0xFF2563EB);
            if (action.toLowerCase().contains('fault') || action.toLowerCase().contains('breakdown')) {
              icon = Icons.warning_amber_rounded;
              iconColor = isDark ? Colors.redAccent : const Color(0xFFDC2626);
            } else if (action.toLowerCase().contains('diagnostic') || action.toLowerCase().contains('test')) {
              icon = Icons.monitor_heart_outlined;
              iconColor = isDark ? Colors.cyanAccent : const Color(0xFF0284C7);
            } else if (action.toLowerCase().contains('spare') || action.toLowerCase().contains('replace')) {
              icon = Icons.swap_horiz;
              iconColor = isDark ? Colors.orangeAccent : const Color(0xFFD97706);
            } else if (action.toLowerCase().contains('loto') || action.toLowerCase().contains('isolation')) {
              icon = Icons.lock_clock_outlined;
              iconColor = isDark ? Colors.amberAccent : const Color(0xFFD97706);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0)),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (details.isNotEmpty)
                          Text(
                            details,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.grey : const Color(0xFF475569),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isDark ? FontWeight.normal : FontWeight.w500,
                      color: isDark ? Colors.white38 : const Color(0xFF64748B),
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
}
