import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../log_data/presentation/pages/log_fault_page.dart';
import '../../../log_data/presentation/pages/gen_work_log_page.dart';
import '../widgets/custom_app_bar.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(),
      body: ResponsiveContentWrapper(
        maxWidth: 1320,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Shift Status Header
            _buildShiftHeader(context),
            const SizedBox(height: 32),

            // 2. Critical Alerts Carousel
            Text(
              'Critical Alerts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: PageView(
                padEnds: false,
                controller: PageController(viewportFraction: 0.9),
                children: [
                  // The provided snippet for MaterialPageRoute is not a valid Widget for PageView children.
                  // Keeping the original card for syntactical correctness.
                  // If the intent was to navigate, it should be wrapped in a GestureDetector or similar.
                  _buildCriticalAlertCard(
                    context,
                    'Motor M-101 Critical Fault',
                    'Overheating Detected (95°C)',
                    'Unit A • Pending',
                  ),
                  _buildCriticalAlertCard(
                    context,
                    'Hydraulic Pump P-4 Failure',
                    'Pressure Drop < 100 PSI',
                    'Unit B • Technicians Assigned',
                  ),
                ],
              ),
            ).animate().fadeIn().slideX(),
            const SizedBox(height: 32),

            // 3. Shift Progress
            Text(
              'Shift Progress',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            GlassContainer(
              width: double.infinity,
              height: 100,
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: 0.75,
                            strokeWidth: 6,
                            backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                          ),
                        ),
                        Text(
                          '75%',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Daily Checklist',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '15/20 tasks complete',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

             // 4. Log Data Entry Points
            Text(
              'Log Data',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickAction(context, Icons.build_circle_outlined, 'Fault Logs', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const LogFaultPage()));
                }),
                _buildQuickAction(context, Icons.engineering_outlined, 'Work Logs', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const GenWorkLogPage()));
                }),
                _buildQuickAction(context, Icons.history_edu_outlined, 'Reports'),
                _buildQuickAction(context, Icons.analytics_outlined, 'Trends'),
              ],
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 32),

            // 5. Recent Activity
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
             _buildActivityItem(context, 'System Backup Completed', '10 mins ago', Icons.cloud_done, AppColors.info),
             _buildActivityItem(context, 'Shift Handover: Team A -> B', '30 mins ago', Icons.swap_horiz, AppColors.accent),
             _buildActivityItem(context, 'Maintenance logged on P-200', '2 hours ago', Icons.build, AppColors.warning),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildShiftHeader(BuildContext context) {
    return GlassContainer(
      width: double.infinity,
      height: 90,
      borderRadius: 20,
      border: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                     Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Text('SHIFT A', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
                const SizedBox(height: 4),
                FutureBuilder<Map<String, dynamic>?>(
                  future: FirestoreService().getUserProfile(AuthService().currentUser?.uid ?? ''),
                  builder: (context, snapshot) {
                     // Loading State
                     if (!snapshot.hasData) {
                       return const PulseLoading(size: 20);
                     }
                     final name = snapshot.data?['displayName'] ?? 'Unknown User';
                     return Text(
                       'User: $name', 
                       style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface)
                     );
                  },
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening Shift Log Entry...')),
                );
              },
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Add Entry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: const TextStyle(fontSize: 12),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalAlertCard(BuildContext context, String title, String subtitle, String footer) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.error.withValues(alpha: 0.2),
            AppColors.error.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              subtitle,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                footer,
                style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, String title, String time, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        width: double.infinity,
        height: 70,
        borderRadius: 16,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500, fontSize: 14)),
                    Text(time, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
