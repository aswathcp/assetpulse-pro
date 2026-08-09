import 'package:flutter/material.dart';
import '../../../../features/home/presentation/widgets/custom_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../features/assets/data/models/isolation_permit_model.dart';
import 'isolation_management_page.dart';
import '../../../log_data/presentation/pages/log_management_dashboard.dart';
import 'checklist/checklist_management_dashboard.dart';

class OperationsTab extends StatelessWidget {
  const OperationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Operations Center'),
      body: ResponsiveContentWrapper(
        maxWidth: 1320,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Modules',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: ResponsiveLayout.isDesktop(context) ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: ResponsiveLayout.isDesktop(context) ? 1.2 : 0.85,
              children: [
                StreamBuilder<List<IsolationPermitModel>>(
                  stream: FirestoreService().getActiveIsolationsStream(
                    businessId: HierarchyService().currentBusinessId
                  ),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    return _buildDashboardCard(
                      context,
                      title: 'Isolation\nManagement',
                      icon: Icons.lock_outline,
                      color: Colors.blueAccent,
                      badgeCount: count > 0 ? count : null,
                      onTap: () => Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => const IsolationManagementPage())
                      ),
                    );
                  }
                ),
                _buildDashboardCard(
                  context,
                  title: 'Log\nManagement',
                  icon: Icons.menu_book,
                  color: AppColors.primaryLight,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogManagementDashboard())),
                ),
                _buildDashboardCard(
                  context,
                  title: 'Checklist\nManagement',
                  icon: Icons.checklist_rtl,
                  color: Colors.green,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChecklistManagementDashboard())),
                ),
                _buildDashboardCard(
                  context,
                  title: 'Safety Interlock\nBypass',
                  icon: Icons.security,
                  color: Colors.grey.shade400,
                  isComingSoon: true,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
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
    return GestureDetector(
      onTap: isComingSoon
          ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Module Coming Soon!')))
          : onTap,
      child: GlassContainer(
        width: double.infinity,
        height: null,
        borderRadius: 20,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Badge(
                  label: badgeCount != null ? Text(badgeCount.toString()) : null,
                  isLabelVisible: badgeCount != null,
                  backgroundColor: Colors.red,
                  child: Icon(icon, color: color, size: 36),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (isComingSoon) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Coming Soon', style: TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
