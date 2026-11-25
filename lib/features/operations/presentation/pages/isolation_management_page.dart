import 'package:flutter/material.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import '../../../../features/assets/data/models/isolation_permit_model.dart';
import 'add_isolation_permit_page.dart';
import 'clear_isolation_page.dart';
import 'isolation_records_page.dart';

class IsolationManagementPage extends StatefulWidget {
  const IsolationManagementPage({super.key});

  @override
  State<IsolationManagementPage> createState() => _IsolationManagementPageState();
}

class _IsolationManagementPageState extends State<IsolationManagementPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final HierarchyService _hierarchyService = HierarchyService();

  String? _selectedPlantId;
  String? _selectedUnitId;
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  bool _isLoadingScope = true;

  @override
  void initState() {
    super.initState();
    _loadUserScope();
  }

  Future<void> _loadUserScope() async {
    try {
      final user = _firestoreService.currentUser;
      _plants = _hierarchyService.getPlants();

      if (user != null) {
        final profile = await _firestoreService.getUserProfile(user.uid);
        if (profile != null) {
          final businessId = profile['businessId'] as String? ?? 'VISL';
          await _hierarchyService.init(businessId: businessId);

          final userScope = PermissionHelper.resolveUserScope(profile);
          _isPlantLocked = userScope.isPlantLocked;
          _isUnitLocked = userScope.isUnitLocked;

          _plants = userScope.getAvailablePlants();
          _selectedPlantId = userScope.getInitialPlant(_plants);
          if (_selectedPlantId != null) {
            _units = userScope.getAvailableUnits(_selectedPlantId!);
            _selectedUnitId = userScope.getInitialUnit(_units);
          }
        }
      }

      _selectedPlantId ??= _plants.isNotEmpty ? _plants.first : null;
      if (_selectedPlantId != null) {
        _units = _hierarchyService.getUnitsForPlant(_selectedPlantId!);
        if (_selectedUnitId == null || !_units.contains(_selectedUnitId)) {
          _selectedUnitId = _units.isNotEmpty ? _units.first : null;
        }
      }
    } catch (e) {
      debugPrint('Error loading scope in IsolationManagementPage: $e');
    } finally {
      if (mounted) setState(() => _isLoadingScope = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = _hierarchyService.currentBusinessId;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: const CustomAppBar(title: 'Isolation Management'),
      body: AnimatedGradientBackground(
        child: _isLoadingScope
            ? const Center(child: PulseLoading(size: 50))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 20),
                    _buildScopeSelector(context),
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

  Widget _buildScopeSelector(BuildContext context) {
    return GlassContainer(
      width: double.infinity,
      height: null,
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('dash_plant_$_selectedPlantId'),
                initialValue: _selectedPlantId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select Plant', 
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.business_outlined, size: 20),
                ),
                items: _plants.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _isPlantLocked ? null : (val) {
                  if (val != null) {
                    setState(() {
                      _selectedPlantId = val;
                      _units = _hierarchyService.getUnitsForPlant(val);
                      _selectedUnitId = _units.isNotEmpty ? _units.first : null;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('dash_unit_${_selectedPlantId}_$_selectedUnitId'),
                initialValue: _selectedUnitId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select Unit', 
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.factory_outlined, size: 20),
                ),
                items: _units.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _isUnitLocked ? null : (val) {
                  if (val != null) {
                    setState(() {
                      _selectedUnitId = val;
                    });
                  }
                },
              ),
            ),
          ],
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
      stream: _firestoreService.getActiveIsolationsStream(
        businessId: businessId,
        plantId: _selectedPlantId,
        unitId: _selectedUnitId,
      ),
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
            MaterialPageRoute(
              builder: (_) => AddIsolationPermitPage(
                plantId: _selectedPlantId,
                unitId: _selectedUnitId,
              ),
            ),
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
            MaterialPageRoute(
              builder: (_) => ClearIsolationPage(
                plantId: _selectedPlantId,
                unitId: _selectedUnitId,
              ),
            ),
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
            MaterialPageRoute(
              builder: (_) => IsolationRecordsPage(
                plantId: _selectedPlantId,
                unitId: _selectedUnitId,
              ),
            ),
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
