import 'package:flutter/material.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import '../../../../features/assets/data/models/isolation_permit_model.dart';
import 'add_isolation_permit_page.dart';
import 'clear_isolation_page.dart';
import 'isolation_records_page.dart';

class IsolationManagementPage extends StatelessWidget {
  const IsolationManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final businessId = HierarchyService().currentBusinessId;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: const CustomAppBar(title: 'Isolation Management'),
      body: AnimatedGradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildStatsSection(context, businessId),
              const SizedBox(height: 32),
              _buildActionGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plant Isolation Management',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Issue, clear, and view isolation permits for maintenance work.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildStatsSection(BuildContext context, String businessId) {
    return StreamBuilder<List<IsolationPermitModel>>(
      stream: FirestoreService().getActiveIsolationsStream(businessId: businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: PulseLoading(size: 30));
        }
        
        final activePermits = snapshot.data ?? [];
        final totalCount = activePermits.length;
        
        // Department Breakdown
        final electrical = activePermits.where((p) => p.requestingDepartment == 'Electrical').length;
        final mechanical = activePermits.where((p) => p.requestingDepartment == 'Mechanical').length;
        final instrumentation = activePermits.where((p) => p.requestingDepartment == 'Instrumentation').length;
        final production = activePermits.where((p) => p.requestingDepartment == 'Production').length;

        return GlassContainer(
          width: double.infinity,
          height: null,
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade400, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Active Isolation Status',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Text(
                  '$totalCount Total Active Permits',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Electrical', electrical, Colors.red),
                    _buildStatItem('Mechanical', mechanical, Colors.blue),
                    _buildStatItem('Inst.', instrumentation, Colors.green),
                    _buildStatItem('Prod.', production, Colors.deepPurple),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return Column(
      children: [
        _buildMenuCard(
          context,
          title: 'Add New Isolation Permit',
          subtitle: 'Issue a new permit for equipment isolation.',
          icon: Icons.add_moderator,
          color: Colors.green,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddIsolationPermitPage()),
          ),
        ),
        const SizedBox(height: 16),
        _buildMenuCard(
          context,
          title: 'Clear Issued Isolation',
          subtitle: 'Clear active permits and normalize equipment.',
          icon: Icons.verified_user,
          color: Colors.orange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClearIsolationPage()),
          ),
        ),
        const SizedBox(height: 16),
        _buildMenuCard(
          context,
          title: 'View Isolation Records',
          subtitle: 'View all historical isolation permits.',
          icon: Icons.history_edu,
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IsolationRecordsPage()),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      width: double.infinity,
      height: null,
      borderRadius: 16,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.withValues(alpha: 0.5), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
