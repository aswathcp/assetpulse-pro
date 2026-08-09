import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import 'log_fault_page.dart';
import 'gen_work_log_page.dart';
import 'add_fault_log_page.dart';

class LogManagementDashboard extends StatefulWidget {
  const LogManagementDashboard({super.key});

  @override
  State<LogManagementDashboard> createState() => _LogManagementDashboardState();
}

class _LogManagementDashboardState extends State<LogManagementDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _faultFilter = 'Pending'; // 'Pending' or 'Resolved'
  String _genFilter = 'Pending';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: const CustomAppBar(title: 'Log Management'),
      body: AnimatedGradientBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Container(
                height: 45,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(21),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Fault Logs'),
                    Tab(text: 'General Work'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFaultLogTab(),
                  _buildGenLogTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLogMenu,
        backgroundColor: AppColors.primaryLight,
        icon: const Icon(Icons.add),
        label: const Text('New Log'),
      ),
    );
  }

  Widget _buildFaultLogTab() {
    return Column(
      children: [
        _buildFilterChips(
          currentFilter: _faultFilter,
          onFilterChanged: (val) => setState(() => _faultFilter = val),
        ),
        Expanded(
          child: LogFaultPage(
            listFilter: _faultFilter,
            showAppBar: false,
          ), 
        ),
      ],
    );
  }

  Widget _buildGenLogTab() {
    return Column(
      children: [
        _buildFilterChips(
          currentFilter: _genFilter,
          onFilterChanged: (val) => setState(() => _genFilter = val),
        ),
        const Expanded(
          child: GenWorkLogPage(showAppBar: false),
        ),
      ],
    );
  }

  Widget _buildFilterChips({required String currentFilter, required ValueChanged<String> onFilterChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ChoiceChip(
            label: const Text('Pending'),
            selected: currentFilter == 'Pending',
            onSelected: (selected) {
              if (selected) onFilterChanged('Pending');
            },
            selectedColor: Colors.orange.withValues(alpha: 0.2),
            labelStyle: TextStyle(color: currentFilter == 'Pending' ? Colors.orange : Colors.grey),
          ),
          const SizedBox(width: 12),
          ChoiceChip(
            label: const Text('Resolved'),
            selected: currentFilter == 'Resolved',
            onSelected: (selected) {
              if (selected) onFilterChanged('Resolved');
            },
            selectedColor: Colors.green.withValues(alpha: 0.2),
            labelStyle: TextStyle(color: currentFilter == 'Resolved' ? Colors.green : Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showAddLogMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.report_problem, color: Colors.orange),
                title: const Text('Log Equipment Fault'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // We pass nulls so it triggers the "Search for Equipment" Dropdown in AddFaultLogPage
                      builder: (_) => const AddFaultLogPage(masterEquipmentId: '', masterEquipmentName: ''),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.engineering, color: Colors.blue),
                title: const Text('Log General Work'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('General Work form coming soon!')));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
