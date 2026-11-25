import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import 'log_fault_page.dart';
import 'gen_work_log_page.dart';
import 'add_fault_log_page.dart';
import 'add_gen_work_log_page.dart';

class LogManagementDashboard extends StatefulWidget {
  const LogManagementDashboard({super.key});

  @override
  State<LogManagementDashboard> createState() => _LogManagementDashboardState();
}

class _LogManagementDashboardState extends State<LogManagementDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _faultFilter = 'Pending'; // 'Pending' or 'Resolved'
  String _genFilter = 'Pending';

  // Scope state
  List<String> _plants = [];
  List<String> _units = [];
  String? _selectedPlant;
  String? _selectedUnit;
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  bool _isLoadingScope = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadScope();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadScope() async {
    setState(() => _isLoadingScope = true);
    final user = AuthService().currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingScope = false);
      return;
    }

    final profile = await FirestoreService().getUserProfile(user.uid);
    if (profile == null) {
      if (mounted) setState(() => _isLoadingScope = false);
      return;
    }

    final userBusinessId = profile['businessId'] as String? ?? 'VISL';
    await HierarchyService().init(businessId: userBusinessId);

    final userScope = PermissionHelper.resolveUserScope(profile);
    _isPlantLocked = userScope.isPlantLocked;
    _isUnitLocked = userScope.isUnitLocked;

    _plants = userScope.getAvailablePlants();
    _selectedPlant = userScope.getInitialPlant(_plants);
    if (_selectedPlant != null) {
      _units = userScope.getAvailableUnits(_selectedPlant!);
      _selectedUnit = userScope.getInitialUnit(_units);
    }

    if (mounted) setState(() => _isLoadingScope = false);
  }

  void _updateUnitList() {
    if (_selectedPlant == null) {
      _units = [];
      _selectedUnit = null;
    } else {
      _units = HierarchyService().getUnitsForPlant(_selectedPlant!);
      if (_units.isEmpty) _units = ['PID1', 'MCD'];
      if (!_units.contains(_selectedUnit)) {
        _selectedUnit = _units.isNotEmpty ? _units.first : null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: const CustomAppBar(title: 'Log Management'),
      body: AnimatedGradientBackground(
        child: Column(
          children: [
            // 1. SCOPE & ROLE BAR (Role-based unlocking & auto-selection)
            _buildScopeBar(),

            // 2. TAB SELECTOR BAR
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryLight.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.report_problem_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Fault Logs'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.engineering_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('General Work'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. TAB CONTENT VIEWS
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
        icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
        label: const Text('Log Fault (AI)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildScopeBar() {
    if (_isLoadingScope) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_plants.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GlassContainer(
        borderRadius: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _plants.contains(_selectedPlant) ? _selectedPlant : (_plants.isNotEmpty ? _plants.first : null),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Select Plant', border: InputBorder.none),
                  items: _plants.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _isPlantLocked
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() {
                              _selectedPlant = val;
                              _updateUnitList();
                            });
                          }
                        },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _units.contains(_selectedUnit) ? _selectedUnit : (_units.isNotEmpty ? _units.first : null),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Select Unit', border: InputBorder.none),
                  items: _units.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _isUnitLocked
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _selectedUnit = val);
                          }
                        },
                ),
              ),
            ],
          ),
        ),
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
            plantId: _selectedPlant,
            unitId: _selectedUnit,
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
        Expanded(
          child: GenWorkLogPage(
            showAppBar: false,
            plantId: _selectedPlant,
            unitId: _selectedUnit,
            listFilter: _genFilter,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips({required String currentFilter, required ValueChanged<String> onFilterChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ChoiceChip(
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pending_actions_rounded, size: 15, color: Colors.amber),
                SizedBox(width: 6),
                Text('Pending'),
              ],
            ),
            selected: currentFilter == 'Pending',
            onSelected: (selected) {
              if (selected) onFilterChanged('Pending');
            },
            selectedColor: Colors.amber.withValues(alpha: 0.22),
            labelStyle: TextStyle(
              color: currentFilter == 'Pending' ? Colors.amber : Colors.grey,
              fontWeight: currentFilter == 'Pending' ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          ChoiceChip(
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 15, color: Colors.green),
                SizedBox(width: 6),
                Text('Closed'),
              ],
            ),
            selected: currentFilter == 'Closed' || currentFilter == 'Resolved',
            onSelected: (selected) {
              if (selected) onFilterChanged('Closed');
            },
            selectedColor: Colors.green.withValues(alpha: 0.22),
            labelStyle: TextStyle(
              color: (currentFilter == 'Closed' || currentFilter == 'Resolved') ? Colors.green : Colors.grey,
              fontWeight: (currentFilter == 'Closed' || currentFilter == 'Resolved') ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          ChoiceChip(
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.all_inclusive_rounded, size: 15, color: Colors.blueAccent),
                SizedBox(width: 6),
                Text('All Logs'),
              ],
            ),
            selected: currentFilter == 'All',
            onSelected: (selected) {
              if (selected) onFilterChanged('All');
            },
            selectedColor: Colors.blueAccent.withValues(alpha: 0.22),
            labelStyle: TextStyle(
              color: currentFilter == 'All' ? Colors.blueAccent : Colors.grey,
              fontWeight: currentFilter == 'All' ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
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
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.purpleAccent, Colors.blueAccent],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                title: const Text('Log Equipment Fault', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('AI Voice / Free Text Auto-Fill + Manual Entry', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddFaultLogPage(masterEquipmentId: '', masterEquipmentName: ''),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.engineering, color: Color(0xFF2563EB), size: 20),
                ),
                title: const Text('Log General Work', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('WhatsApp Log Fast-Paste + Multi-Task Entry', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddGenWorkLogPage(
                        plantId: _selectedPlant,
                        unitId: _selectedUnit,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
