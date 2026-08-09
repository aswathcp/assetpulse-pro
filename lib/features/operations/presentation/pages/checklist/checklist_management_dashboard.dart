import 'package:flutter/material.dart';
import 'package:asset_pulse_pro/core/widgets/glass_container.dart';
import 'package:asset_pulse_pro/features/home/presentation/widgets/custom_app_bar.dart';
import 'package:asset_pulse_pro/core/widgets/responsive_layout.dart';
import 'shift_checklists_page.dart';
import 'rccb_checklists_page.dart';
import 'lux_level_checklist_page.dart';
import 'joint_illumination_audit_page.dart';
import 'power_tools_checklist_page.dart';
import 'panel_room_checklist_page.dart';
import 'water_cooler_checklist_page.dart';
import 'high_mast_checklist_page.dart';
import 'high_mast_trial_page.dart';

class ChecklistManagementDashboard extends StatelessWidget {
  const ChecklistManagementDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Checklist Management'),
      body: ResponsiveContentWrapper(
        maxWidth: 1320,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Categories',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: ResponsiveLayout.isDesktop(context) ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: ResponsiveLayout.isDesktop(context) ? 1.25 : 0.85,
                children: [
                  _buildDashboardCard(
                    context,
                    title: 'Shift\nChecklist',
                    icon: Icons.access_time_filled,
                    color: Colors.greenAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShiftChecklistsPage())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'RCCB Testing\nChecklist',
                    icon: Icons.electric_meter,
                    color: Colors.orangeAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RccbChecklistsPage())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Lux Level\nChecklist',
                    icon: Icons.lightbulb_outline,
                    color: Colors.yellowAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LuxLevelChecklistPage())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Joint Illumination\nAudit',
                    icon: Icons.groups_3,
                    color: Colors.cyanAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JointIlluminationAuditPage())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Panel\nChecklist',
                    icon: Icons.settings_input_component,
                    color: Colors.grey.shade400,
                    isComingSoon: true,
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Panel Room\nChecklist',
                    icon: Icons.meeting_room,
                    color: Colors.tealAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PanelRoomChecklistPage())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Power Tools\nChecklist',
                    icon: Icons.precision_manufacturing,
                    color: Colors.tealAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PowerToolsChecklistPage())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Water Dispenser\nHot & Cold',
                    icon: Icons.water_drop,
                    color: Colors.cyanAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WaterCoolerChecklistPage())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'High Mast Tower\nChecklist',
                    icon: Icons.wb_incandescent,
                    color: Colors.amberAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HighMastChecklistPage())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'High Mast Tower\n(Trial Pro) ✨',
                    icon: Icons.stars,
                    color: Colors.purpleAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HighMastTrialPage())),
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
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
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
