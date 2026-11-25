import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import '../../data/models/workman_model.dart';

class WorkmenManagementPage extends StatefulWidget {
  final String? initialPlant;
  final String? initialUnit;

  const WorkmenManagementPage({
    super.key,
    this.initialPlant,
    this.initialUnit,
  });

  @override
  State<WorkmenManagementPage> createState() => _WorkmenManagementPageState();
}

class _WorkmenManagementPageState extends State<WorkmenManagementPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedPlant;
  String? _selectedUnit;
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  bool _isLoadingScope = true;
  String _userRole = '';
  String _selectedTradeFilter = 'All';
  String _searchQuery = '';

  final List<String> _trades = const [
    'Electrician',
    'Fitter',
    'Welder',
    'Helper',
    'Rigger',
    'Contractor',
    'Apprentice',
    'Technician',
    'Operator',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPlant = widget.initialPlant;
    _selectedUnit = widget.initialUnit;
    _loadScope();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadScope() async {
    setState(() => _isLoadingScope = true);
    final user = AuthService().currentUser;
    if (user != null) {
      final profile = await _firestoreService.getUserProfile(user.uid);
      if (profile != null) {
        _userRole = profile['role'] ?? AppRoles.guest;
        final userBusinessId = profile['businessId'] as String? ?? 'VISL';
        await HierarchyService().init(businessId: userBusinessId);

        final userScope = PermissionHelper.resolveUserScope(profile);
        _isPlantLocked = userScope.isPlantLocked;
        _isUnitLocked = userScope.isUnitLocked;

        _plants = userScope.getAvailablePlants();
        _selectedPlant ??= userScope.getInitialPlant(_plants);
        if (_selectedPlant != null) {
          _units = userScope.getAvailableUnits(_selectedPlant!);
          _selectedUnit ??= userScope.getInitialUnit(_units);
        }
      }
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

  void _showAddEditWorkmanModal({WorkmanModel? workman}) {
    final canEdit = PermissionHelper.canEditDatabase(_userRole);
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Admins and Engineers can add or modify workmen.')),
      );
      return;
    }

    final nameController = TextEditingController(text: workman?.name ?? '');
    final contractorController = TextEditingController(text: workman?.contractor ?? 'In-House');
    final phoneController = TextEditingController(text: workman?.phone ?? '');
    final empIdController = TextEditingController(text: workman?.employeeId ?? '');
    String selectedTrade = workman?.trade ?? 'Electrician';
    String? modalPlant = workman?.plantId ?? _selectedPlant;
    String? modalUnit = workman?.unitId ?? _selectedUnit;
    bool isActive = workman?.isActive ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        workman == null ? 'Add Workman / Contractor' : 'Edit Workman',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'e.g. Sachine, Shantaram, Swaraj',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _trades.contains(selectedTrade) ? selectedTrade : _trades.first,
                    decoration: InputDecoration(
                      labelText: 'Trade / Skill *',
                      prefixIcon: const Icon(Icons.handyman_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: _trades.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedTrade = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contractorController,
                    decoration: InputDecoration(
                      labelText: 'Agency / Contractor',
                      hintText: 'e.g. In-House, Monomark, Apex',
                      prefixIcon: const Icon(Icons.business_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: empIdController,
                          decoration: InputDecoration(
                            labelText: 'Badge / ID (Optional)',
                            hintText: 'e.g. W-104',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone (Optional)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Active Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Available for selection in shift work logs', style: TextStyle(fontSize: 11)),
                    value: isActive,
                    activeThumbColor: Colors.greenAccent,
                    onChanged: (val) => setModalState(() => isActive = val),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Please enter a name for the workman.')),
                        );
                        return;
                      }

                      final newWorkman = WorkmanModel(
                        id: workman?.id ?? '',
                        name: name,
                        trade: selectedTrade,
                        contractor: contractorController.text.trim().isNotEmpty ? contractorController.text.trim() : 'In-House',
                        employeeId: empIdController.text.trim().isNotEmpty ? empIdController.text.trim() : null,
                        phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                        plantId: modalPlant,
                        unitId: modalUnit,
                        isActive: isActive,
                        createdAt: workman?.createdAt ?? DateTime.now(),
                        createdBy: workman?.createdBy ?? AuthService().currentUser?.displayName ?? 'Admin',
                      );

                      if (workman != null) {
                        await _firestoreService.updateWorkman(newWorkman);
                      } else {
                        await _firestoreService.addWorkman(newWorkman);
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(workman != null ? 'Workman updated!' : 'Workman added successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      workman == null ? 'Add Workman' : 'Save Changes',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteWorkman(WorkmanModel workman) async {
    final canEdit = PermissionHelper.canEditDatabase(_userRole);
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Admins can delete workmen.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workman?'),
        content: Text('Remove ${workman.name} from the database?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.deleteWorkman(workman.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${workman.name} removed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Workmen & Contractors'),
      body: AnimatedGradientBackground(
        child: Column(
          children: [
            // 1. Scope Bar
            if (_plants.isNotEmpty) _buildScopeBar(isDark),

            // 2. Search & Trade Filters
            _buildSearchAndTradeFilters(isDark),

            // 3. Workmen Stream List
            Expanded(
              child: StreamBuilder<List<WorkmanModel>>(
                stream: _firestoreService.getWorkmenStream(
                  plantId: _selectedPlant,
                  unitId: _selectedUnit,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: PulseLoading(size: 40));
                  }

                  var workmen = snapshot.data ?? [];

                  if (_selectedTradeFilter != 'All') {
                    workmen = workmen.where((w) => w.trade.toLowerCase() == _selectedTradeFilter.toLowerCase()).toList();
                  }

                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    workmen = workmen.where((w) =>
                        w.name.toLowerCase().contains(q) ||
                        w.trade.toLowerCase().contains(q) ||
                        w.contractor.toLowerCase().contains(q) ||
                        (w.phone != null && w.phone!.contains(q))).toList();
                  }

                  if (workmen.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.engineering_outlined, size: 64, color: Theme.of(context).disabledColor),
                          const SizedBox(height: 16),
                          const Text(
                            'No workmen registered in database.',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap the button below to add plant technicians & contractors.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: workmen.length,
                    itemBuilder: (context, index) {
                      final workman = workmen[index];
                      return _buildWorkmanTile(context, workman, isDark);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditWorkmanModal(),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.person_add, color: Colors.white, size: 20),
        label: const Text('Add Workman', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildScopeBar(bool isDark) {
    if (_isLoadingScope) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

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
                  decoration: const InputDecoration(labelText: 'Plant Scope', border: InputBorder.none),
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
                  decoration: const InputDecoration(labelText: 'Unit Scope', border: InputBorder.none),
                  items: _units.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _isUnitLocked
                      ? null
                      : (val) {
                          if (val != null) setState(() => _selectedUnit = val);
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndTradeFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search workman by name, trade, contractor...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            style: const TextStyle(fontSize: 12),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Trades'),
                  selected: _selectedTradeFilter == 'All',
                  onSelected: (val) => setState(() => _selectedTradeFilter = 'All'),
                  selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: _selectedTradeFilter == 'All' ? FontWeight.bold : FontWeight.normal,
                    color: _selectedTradeFilter == 'All' ? const Color(0xFF2563EB) : Colors.grey,
                  ),
                ),
                ..._trades.map((t) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(t),
                    selected: _selectedTradeFilter == t,
                    onSelected: (val) => setState(() => _selectedTradeFilter = t),
                    selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: _selectedTradeFilter == t ? FontWeight.bold : FontWeight.normal,
                      color: _selectedTradeFilter == t ? const Color(0xFF2563EB) : Colors.grey,
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkmanTile(BuildContext context, WorkmanModel workman, bool isDark) {
    Color tradeColor = const Color(0xFF2563EB);
    IconData tradeIcon = Icons.electrical_services;
    if (workman.trade.toLowerCase().contains('fitter')) {
      tradeColor = Colors.cyan;
      tradeIcon = Icons.build;
    } else if (workman.trade.toLowerCase().contains('welder')) {
      tradeColor = Colors.orange;
      tradeIcon = Icons.fireplace;
    } else if (workman.trade.toLowerCase().contains('helper')) {
      tradeColor = Colors.teal;
      tradeIcon = Icons.handyman;
    } else if (workman.trade.toLowerCase().contains('contractor')) {
      tradeColor = Colors.purpleAccent;
      tradeIcon = Icons.business;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tradeColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(tradeIcon, color: tradeColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      workman.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    if (!workman.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Inactive', style: TextStyle(fontSize: 9, color: Colors.redAccent)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${workman.trade} • ${workman.contractor}${workman.phone != null ? " • ${workman.phone}" : ""}',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _showAddEditWorkmanModal(workman: workman),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            onPressed: () => _deleteWorkman(workman),
          ),
        ],
      ),
    );
  }
}
