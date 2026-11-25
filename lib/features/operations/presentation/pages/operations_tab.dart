import 'package:flutter/material.dart';
import '../../../../features/home/presentation/widgets/custom_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../features/assets/data/models/isolation_permit_model.dart';
import 'isolation_management_page.dart';
import '../../../log_data/presentation/pages/log_management_dashboard.dart';
import 'checklist/checklist_management_dashboard.dart';

import 'sld/single_line_diagram_page.dart';

class OperationsTab extends StatefulWidget {
  const OperationsTab({super.key});

  @override
  State<OperationsTab> createState() => _OperationsTabState();
}

class _OperationsTabState extends State<OperationsTab> {
  final FirestoreService _firestoreService = FirestoreService();
  final HierarchyService _hierarchyService = HierarchyService();

  String? _userPlantId;
  String? _userUnitId;

  @override
  void initState() {
    super.initState();
    _loadUserScope();
  }

  Future<void> _loadUserScope() async {
    try {
      final user = _firestoreService.currentUser;
      if (user != null) {
        final profile = await _firestoreService.getUserProfile(user.uid);
        if (profile != null && mounted) {
          final businessId = profile['businessId'] as String? ?? 'VISL';
          await _hierarchyService.init(businessId: businessId);

          final userScope = PermissionHelper.resolveUserScope(profile);
          final plants = userScope.getAvailablePlants();
          final initialPlant = userScope.getInitialPlant(plants);
          String? initialUnit;
          if (initialPlant != null) {
            final units = userScope.getAvailableUnits(initialPlant);
            initialUnit = userScope.getInitialUnit(units);
          }
          setState(() {
            _userPlantId = initialPlant;
            _userUnitId = initialUnit;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user scope in OperationsTab: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Operations Center'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Modules',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (isDesktop) ...[
              Row(
                children: [
                  Expanded(child: _buildSldCard(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildIsolationCard(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildLogCard(context)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildChecklistCard(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSafetyCard(context)),
                  const SizedBox(width: 16),
                  const Spacer(),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(child: _buildSldCard(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildIsolationCard(context)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildLogCard(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildChecklistCard(context)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildSafetyCard(context)),
                  const SizedBox(width: 16),
                  const Spacer(),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSldCard(BuildContext context) {
    return _buildDashboardCard(
      context,
      title: 'Power Flow &\nSingle Line (SLD)',
      icon: Icons.schema,
      color: Colors.cyan,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SingleLineDiagramPage()),
      ),
    );
  }

  Widget _buildIsolationCard(BuildContext context) {
    return StreamBuilder<List<IsolationPermitModel>>(
      stream: _firestoreService.getActiveIsolationsStream(
        businessId: _hierarchyService.currentBusinessId,
        plantId: _userPlantId,
        unitId: _userUnitId,
      ),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        return _buildDashboardCard(
          context,
          title: 'Isolation\nManagement',
          icon: Icons.lock_outline,
          color: Colors.blueAccent,
          badgeCount: count > 0 ? count : null,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IsolationManagementPage()),
            );
            _loadUserScope();
          },
        );
      },
    );
  }

  Widget _buildLogCard(BuildContext context) {
    return _buildDashboardCard(
      context,
      title: 'Log\nManagement',
      icon: Icons.menu_book,
      color: AppColors.primaryLight,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LogManagementDashboard()),
      ),
    );
  }

  Widget _buildChecklistCard(BuildContext context) {
    return _buildDashboardCard(
      context,
      title: 'Checklist\nManagement',
      icon: Icons.checklist_rtl,
      color: Colors.green,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChecklistManagementDashboard()),
      ),
    );
  }

  Widget _buildSafetyCard(BuildContext context) {
    return _buildDashboardCard(
      context,
      title: 'Safety Interlock\nBypass',
      icon: Icons.security,
      color: Colors.grey.shade400,
      isComingSoon: true,
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool isComingSoon = false,
    int? badgeCount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: isComingSoon
          ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Module Coming Soon!')))
          : onTap,
      child: GlassContainer(
        width: double.infinity,
        height: 170,
        borderRadius: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Badge(
                  label: badgeCount != null ? Text(badgeCount.toString()) : null,
                  isLabelVisible: badgeCount != null,
                  backgroundColor: Colors.red,
                  child: Icon(icon, color: color, size: 30),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              if (isComingSoon) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.amber.withValues(alpha: 0.2) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.amberAccent.withValues(alpha: 0.4) : const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    'Coming Soon',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
