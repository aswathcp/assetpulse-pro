import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/widgets/glass_container.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/widgets/pulse_loading.dart';
import 'package:asset_pulse_pro/core/constants/app_roles.dart';
import 'package:asset_pulse_pro/core/utils/permission_helper.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/data_import_page.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/add_edit_hierarchy_page.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/workmen_management_page.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/others_review_page.dart';
import 'package:asset_pulse_pro/core/constants/app_version.dart';
import 'package:asset_pulse_pro/core/services/app_version_service.dart';

// --- MAIN DASHBOARD (MENU) ---

class AdminDatabasePage extends StatelessWidget {
  final String? initialCollection;
  const AdminDatabasePage({super.key, this.initialCollection});

  final Map<String, String> _collections = const {
    'combined_hierarchy': 'Master Hierarchy Import',
    'locations': 'Physical Areas',
    'panel_rooms': 'Panel Rooms',
    'panels': 'Panels / MCCs',
    'feeders': 'Feeders',
    'transformers': 'Transformers',
    'master_equipments': 'Master Equipment',
    'fault_types': 'Fault Types',
    'odc': 'ODC (Damage Cause)',
    'workmen': 'Plant Workmen & Contractors',
    'others_suggestions': 'Others Review Queue',
    'app_version': 'App Version & Release Control',
  };

  final Map<String, IconData> _icons = const {
    'combined_hierarchy': Icons.account_tree,
    'locations': Icons.map,
    'panel_rooms': Icons.room_preferences,
    'panels': Icons.electric_bolt,
    'feeders': Icons.power_input,
    'transformers': Icons.electrical_services,
    'master_equipments': Icons.precision_manufacturing,
    'fault_types': Icons.warning_amber,
    'odc': Icons.broken_image,
    'workmen': Icons.engineering,
    'others_suggestions': Icons.pending_actions,
    'app_version': Icons.system_update_alt,
  };

  final Map<String, String> _subtitles = const {
    'combined_hierarchy': 'Import/Export 6 Levels (Multi-Sheet Excel)',
    'locations': 'Physical Plant Areas (e.g. BF1-RMHS)',
    'panel_rooms': 'Substation Rooms (e.g. MCC 2 & 9)',
    'panels': 'MCCs & PCC Panels (Voltage, Bus Sections)',
    'feeders': 'Power Feeders & Sources (State, Upstream Source)',
    'transformers': 'Distribution & Power Step-Down Transformers',
    'master_equipments': 'Functional Tags & Machinery',
    'fault_types': 'Root Cause Analysis Codes',
    'odc': 'Object Damage Categories (ISO 14224)',
    'workmen': 'Technicians, Tradesmen & Agency Crews',
    'others_suggestions': 'Review & approve field-submitted catalog additions',
    'app_version': 'Enforce Min Required Version & Gate Old Builds',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            childAspectRatio: 0.9,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _collections.length,
          itemBuilder: (context, index) {
            final key = _collections.keys.elementAt(index);
            final title = _collections[key]!;
            final icon = _icons[key] ?? Icons.storage;
            
            return GlassContainer(
              child: InkWell(
                onTap: () {
                  if (key == 'app_version') {
                    showDialog(
                      context: context,
                      builder: (c) => const AppVersionControlDialog(),
                    );
                  } else if (key == 'workmen') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => const WorkmenManagementPage(),
                      ),
                    );
                  } else if (key == 'others_suggestions') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => const OthersReviewPage(),
                      ),
                    );
                  } else if (key == 'combined_hierarchy') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => const DataImportPage(
                          collectionId: 'combined_hierarchy',
                          title: 'Master Hierarchy Import',
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (c) => DatabaseCollectionView(collectionId: key, title: title))
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title, 
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          _subtitles[key] ?? '', 
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- DETAIL PAGE (COLLECTION VIEW) ---

class DatabaseCollectionView extends StatefulWidget {
  final String collectionId;
  final String title;
  
  const DatabaseCollectionView({super.key, required this.collectionId, required this.title});

  @override
  State<DatabaseCollectionView> createState() => _DatabaseCollectionViewState();
}

class _DatabaseCollectionViewState extends State<DatabaseCollectionView> {
  // Scope State
  String? _selectedPlant;
  String? _selectedUnit;
  
  String? _selectedBusinessId;
  List<String> _plants = [];
  List<String> _units = [];
  
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  bool _isLoadingScope = true;
  String _userRole = '';
  String? _userPlantId;
  String? _userUnitId;
  bool _isAdmin = false;
  
  // Data State
  List<Map<String, dynamic>> _importedData = [];
  bool _isUploading = false;

  // Search Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadScope();
    
    // Auto-open if initial collection provided
    if (widget.collectionId == 'hierarchy_config') {
       // Optional: specific logic for hierarchy?
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadScope() async {
    setState(() => _isLoadingScope = true);
    final user = AuthService().currentUser;
    if (user == null) return;
    
    final profile = await FirestoreService().getUserProfile(user.uid);
    if (profile == null) return;
    
    _userRole = profile['role'] ?? AppRoles.guest;
    final userBusinessId = profile['businessId'] as String? ?? 'VISL';
    await HierarchyService().init(businessId: userBusinessId);
    _selectedBusinessId = HierarchyService().currentBusinessId;

    _isAdmin = profile['isAdmin'] == true;
    _userPlantId = profile['plantId'] as String?;
    _userUnitId = profile['unitId'] as String?;

    final userScope = PermissionHelper.resolveUserScope(profile);
    _isPlantLocked = userScope.isPlantLocked;
    _isUnitLocked = userScope.isUnitLocked;

    _plants = userScope.getAvailablePlants();
    _selectedPlant = userScope.getInitialPlant(_plants);
    if (_selectedPlant != null) {
      _units = userScope.getAvailableUnits(_selectedPlant!);
      _selectedUnit = userScope.getInitialUnit(_units);
    }
    
    setState(() => _isLoadingScope = false);
  }

  void _updateUnitList() {
    if (_selectedPlant == null) {
      _units = [];
      _selectedUnit = null;
    } else {
      _units = HierarchyService().getUnitsForPlant(_selectedPlant!);
      if (_units.isEmpty) _units = ['PID1', 'MCD'];
      if (!_units.contains(_selectedUnit)) _selectedUnit = _units.isNotEmpty ? _units.first : null;
    }
  }

  // --- ACTIONS ---
  

  
  void _upload() async {
    if (_importedData.isEmpty) return;
    setState(() => _isUploading = true);
    try {
      await FirestoreService().batchSave(widget.collectionId, _importedData);
      setState(() => _importedData = []);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload Success')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  bool _canEdit(String? itemPlantId, String? itemUnitId) {
    return PermissionHelper.canEditDatabaseItem(
      userRole: _userRole,
      isAdmin: _isAdmin,
      userPlantId: _userPlantId,
      userUnitId: _userUnitId,
      itemPlantId: itemPlantId,
      itemUnitId: itemUnitId,
    );
  }

  bool get _canAddInSelectedScope {
    return PermissionHelper.canEditDatabaseItem(
      userRole: _userRole,
      isAdmin: _isAdmin,
      userPlantId: _userPlantId,
      userUnitId: _userUnitId,
      itemPlantId: _selectedPlant,
      itemUnitId: _selectedUnit,
    );
  }

  void _showAdd() {
    if (!_canAddInSelectedScope) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to add items in this scope.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditHierarchyItemPage(
          collection: widget.collectionId,
          title: widget.title,
          baseData: {
            'plantId': _selectedPlant, 
            'unitId': _selectedUnit,
            'businessId': _selectedBusinessId,
          },
          userRole: _userRole,
          isEditing: false,
          onSave: (d) => setState((){}),
        ),
      ),
    ).then((_) => setState((){}));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingScope) return const Scaffold(body: Center(child: PulseLoading(size: 60)));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
      ),
      body: Column(
        children: [
          // 1. SCOPE & ACTIONS HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SCOPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.accent)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _isPlantLocked 
                        ? _buildScopeChip(label: 'Plant', value: HierarchyService().getPlantNames()[_selectedPlant] ?? _selectedPlant ?? '...', icon: Icons.factory)
                        : _buildScopeDropdown(
                            label: 'Plant',
                            value: _selectedPlant,
                            items: _plants,
                            onChanged: (v) => setState(() { _selectedPlant = v; _updateUnitList(); }),
                            icon: Icons.factory,
                            itemNames: HierarchyService().getPlantNames(),
                          ),
                      const SizedBox(width: 8),

                      _isUnitLocked
                        ? _buildScopeChip(label: 'Unit', value: HierarchyService().getUnitNamesForPlant(_selectedPlant ?? '')[_selectedUnit] ?? _selectedUnit ?? '...', icon: Icons.settings_input_component)
                        : _buildScopeDropdown(
                            label: 'Unit',
                            value: _selectedUnit,
                            items: _units,
                            onChanged: (v) => setState(() { _selectedUnit = v; }),
                            icon: Icons.settings_input_component,
                            itemNames: HierarchyService().getUnitNamesForPlant(_selectedPlant ?? ''),
                          ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Action Row
                Row(
                   children: [
                     if (_canAddInSelectedScope)
                       Expanded(
                         child: ElevatedButton.icon(
                           onPressed: _showAdd,
                           icon: const Icon(Icons.add, size: 16),
                           label: const Text('Add'),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: AppColors.primary, 
                             foregroundColor: Colors.white,
                             fixedSize: const Size.fromHeight(48),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           ),
                         ),
                       ),
                      if (_userRole == AppRoles.developer) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(builder: (context) => DataImportPage(
                                   collectionId: widget.collectionId, 
                                   title: widget.title,
                                   unitId: _selectedUnit,
                                   plantId: _selectedPlant,
                                 )),
                               );
                            },
                            icon: const Icon(Icons.upload_file, size: 16),
                            label: const Text('Import'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success, 
                              foregroundColor: Colors.white,
                              fixedSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                      if (_userRole == AppRoles.developer || _isAdmin) ...[
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Clear / Delete Entire Collection',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withValues(alpha: 0.15),
                            foregroundColor: Colors.redAccent,
                            fixedSize: const Size(48, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.delete_sweep_rounded, size: 22),
                          onPressed: _showWipeConfirmation,
                        ),
                      ],
                   ],
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // 2. CONTENT AREA
          Expanded(
             child: _importedData.isNotEmpty
               ? Column(
                   children: [
                     // Preview Toolbar
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                       color: AppColors.warning.withValues(alpha: 0.1),
                       child: Row(
                         children: [
                           Expanded(child: Text('${_importedData.length} Records Loaded (Preview)', style: const TextStyle(fontWeight: FontWeight.bold))),
                           TextButton(onPressed: () => setState(() => _importedData = []), child: const Text('Cancel')),
                           ElevatedButton(
                             onPressed: _isUploading ? null : _upload,
                             child: _isUploading ? const SizedBox(width: 16, height: 16, child: PulseLoading(size: 16)) : const Text('Save'),
                           )
                         ],
                       ),
                     ),
                     Expanded(child: SingleChildScrollView(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                       headingRowColor: WidgetStateProperty.all(Theme.of(context).cardColor),
                       columns: _importedData.first.keys.map((k) => DataColumn(label: Text(k))).toList(),
                       rows: _importedData.take(20).map((r) => DataRow(cells: r.values.map((v) => DataCell(Text(v.toString()))).toList())).toList(),
                     )))),
                   ],
                 )
               : Column(
                   children: [
                     // Search bar OUTSIDE StreamBuilder so it never loses focus on rebuild
                     Padding(
                       padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                       child: TextField(
                         controller: _searchController,
                         decoration: InputDecoration(
                           hintText: 'Search ${widget.title} by name, ID, type, panel, voltage, state...',
                           hintStyle: const TextStyle(fontSize: 13),
                           prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.accent),
                           suffixIcon: _searchQuery.isNotEmpty
                               ? IconButton(
                                   icon: const Icon(Icons.clear, size: 18),
                                   onPressed: () {
                                     _searchController.clear();
                                     setState(() => _searchQuery = '');
                                   },
                                 )
                               : null,
                           filled: true,
                           fillColor: Theme.of(context).cardColor,
                           contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                           border: OutlineInputBorder(
                             borderRadius: BorderRadius.circular(10),
                             borderSide: BorderSide(color: Theme.of(context).dividerColor),
                           ),
                           enabledBorder: OutlineInputBorder(
                             borderRadius: BorderRadius.circular(10),
                             borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                           ),
                           focusedBorder: OutlineInputBorder(
                             borderRadius: BorderRadius.circular(10),
                             borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                           ),
                         ),
                         onChanged: (val) => setState(() => _searchQuery = val),
                       ),
                     ),

                     // StreamBuilder only renders the list (doesn't include TextField)
                     Expanded(
                       child: StreamBuilder<List<Map<String, dynamic>>>(
                         stream: FirestoreService().getCollectionStream(widget.collectionId, _selectedUnit, _selectedPlant),
                         builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: 6,
                                itemBuilder: (context, index) => Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                                  ),
                                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white12),
                              );
                            }
                            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                            final items = snapshot.data ?? [];
                            
                            if (items.isEmpty) return Center(child: Text('No Items in $_selectedPlant/$_selectedUnit', style: const TextStyle(color: Colors.grey)));
                            
                            final filteredItems = _searchQuery.isEmpty
                                ? items
                                : items.where((item) {
                                    final q = _searchQuery.toLowerCase().trim();
                                    final id = item['id']?.toString().toLowerCase() ?? '';
                                    final rawId = HierarchyService.stripPrefix(item['id']?.toString() ?? '', _selectedPlant ?? '', _selectedUnit ?? '').toLowerCase();
                                    final name = (item['name']?.toString() ?? '').toLowerCase();
                                    final type = (item['type']?.toString() ?? item['category']?.toString() ?? '').toLowerCase();
                                    final desc = (item['description']?.toString() ?? '').toLowerCase();
                                    final panelId = (item['panelId']?.toString() ?? '').toLowerCase();
                                    final panelRoomId = (item['panelRoomId']?.toString() ?? '').toLowerCase();
                                    final locId = (item['locationId']?.toString() ?? '').toLowerCase();
                                    final volt = (item['voltageLevel']?.toString() ?? '').toLowerCase();
                                    final busSec = (item['busSection']?.toString() ?? item['busSections']?.toString() ?? '').toLowerCase();
                                    final opState = (item['operatingState']?.toString() ?? '').toLowerCase();
                                    final upFeeder = (item['upstreamFeederId']?.toString() ?? '').toLowerCase();
                                    final secTarget = (item['secondaryTargetPanelId']?.toString() ?? '').toLowerCase();
                                    final tertTarget = (item['tertiaryTargetPanelId']?.toString() ?? '').toLowerCase();

                                    return id.contains(q) ||
                                        rawId.contains(q) ||
                                        name.contains(q) ||
                                        type.contains(q) ||
                                        desc.contains(q) ||
                                        panelId.contains(q) ||
                                        panelRoomId.contains(q) ||
                                        locId.contains(q) ||
                                        volt.contains(q) ||
                                        busSec.contains(q) ||
                                        opState.contains(q) ||
                                        upFeeder.contains(q) ||
                                        secTarget.contains(q) ||
                                        tertTarget.contains(q);
                                  }).toList();

                            return Column(
                              children: [
                                // Search Filter Stats Counter
                                if (_searchQuery.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Showing ${filteredItems.length} of ${items.length} records',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                          child: const Text(
                                            'Clear',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Items List or Empty Search State
                                Expanded(
                                  child: filteredItems.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.search_off, size: 48, color: Colors.grey),
                                              const SizedBox(height: 12),
                                              Text(
                                                'No ${widget.title} found matching "$_searchQuery"',
                                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                              ),
                                              const SizedBox(height: 8),
                                              TextButton(
                                                onPressed: () {
                                                  _searchController.clear();
                                                  setState(() => _searchQuery = '');
                                                },
                                                child: const Text('Clear search filter'),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.only(bottom: 80),
                                          itemCount: filteredItems.length,
                                          itemBuilder: (context, index) {
                                            final item = filteredItems[index];
                                            final id = item['id']?.toString() ?? 'unknown';
                                            final rawId = HierarchyService.stripPrefix(id, _selectedPlant ?? '', _selectedUnit ?? '');
                                            String title = item['name'] ?? rawId;
                                            String typeOrCategory = item['type'] ?? item['category'] ?? '';
                                            String subtitle = typeOrCategory.isEmpty ? 'ID: $rawId' : '$typeOrCategory | ID: $rawId';
                                            
                                            // Enhanced Subtitles for hierarchy
                                            if (widget.collectionId == 'panels') {
                                              final cleanRoom = HierarchyService.stripPrefix(item['panelRoomId'] ?? '-', _selectedPlant ?? '', _selectedUnit ?? '');
                                              final volt = item['voltageLevel'] ?? '415V';
                                              final busSec = HierarchyService.formatBusSectionsForDisplay(item['busSections']);
                                              subtitle += ' | Room: $cleanRoom | $volt | Bus: $busSec';
                                            }
                                            if (widget.collectionId == 'feeders') {
                                              final cleanPanel = HierarchyService.stripPrefix(item['panelId'] ?? '-', _selectedPlant ?? '', _selectedUnit ?? '');
                                              final busSec = HierarchyService.normalizeFeederBusSection(item['busSection']);
                                              final opState = item['operatingState'] ?? 'CLOSED';
                                              final upSrc = item['upstreamFeederId'] != null && item['upstreamFeederId'].toString().isNotEmpty
                                                  ? ' | From: ${HierarchyService.stripPrefix(item['upstreamFeederId'].toString(), _selectedPlant ?? '', _selectedUnit ?? '')}'
                                                  : '';
                                              subtitle += ' | Panel: $cleanPanel | Sec: $busSec | State: $opState$upSrc';
                                            }
                                            if (widget.collectionId == 'transformers') {
                                              final kva = item['ratingKva']?.toString() ?? '1000';
                                              final prim = item['primaryVoltage'] ?? '11kV';
                                              final sec = item['secondaryVoltage'] ?? '415V';
                                              final tert = item['tertiaryVoltage'] != null && item['tertiaryVoltage'].toString().isNotEmpty ? '/${item['tertiaryVoltage']}' : '';
                                              final cleanYard = HierarchyService.stripPrefix(item['locationId'] ?? '-', _selectedPlant ?? '', _selectedUnit ?? '');
                                              subtitle += ' | $kva kVA | $prim -> $sec$tert | Yard: $cleanYard';
                                            }
                                            if (widget.collectionId == 'rccb_equipments' || widget.collectionId == 'lighting_dbs') {
                                              final loc = item['location'] ?? '-';
                                              final rccbCount = item['rccbCount'] ?? '0';
                                              final incomingSource = item['incomingSource'] ?? '-';
                                              String modifiedStr = '-';
                                              final rawUpdatedAt = item['updatedAt'];
                                              if (rawUpdatedAt is Timestamp) {
                                                modifiedStr = rawUpdatedAt.toDate().toLocal().toString().substring(0, 16);
                                              } else if (rawUpdatedAt is String) {
                                                final parsed = DateTime.tryParse(rawUpdatedAt);
                                                if (parsed != null) modifiedStr = parsed.toLocal().toString().substring(0, 16);
                                              }
                                              subtitle += ' | Loc: $loc | RCCBs: $rccbCount | Source: $incomingSource\nModified At: $modifiedStr';
                                            }
                                            if (widget.collectionId == 'master_equipments') {
                                              final cleanLoc = HierarchyService.stripPrefix(item['locationId'] ?? '-', _selectedPlant ?? '', _selectedUnit ?? '');
                                              subtitle += ' | Loc: $cleanLoc';
                                            }
                                            if (widget.collectionId == 'fault_types') {
                                              final code = item['faultCode'] ?? item['id'] ?? rawId;
                                              final cat = item['category'] ?? item['discipline'] ?? 'Electrical';
                                              final sev = item['severity'] ?? item['defaultSeverity'] ?? 'Major';
                                              final target = item['targetEquipment'] ?? item['equipmentType'] ?? '';
                                              title = item['name'] ?? item['faultName'] ?? rawId;
                                              final targetPart = target.isNotEmpty ? '• $target ' : '';
                                              subtitle = 'Code: $code | $cat $targetPart| Severity: $sev';
                                            }
                                            if (widget.collectionId == 'odc' || widget.collectionId == 'odc_causes') {
                                              final obj = item['objectPart'] ?? item['object'] ?? '';
                                              final dmg = item['damage'] ?? item['damageMode'] ?? '';
                                              final cau = item['cause'] ?? item['rootCause'] ?? item['name'] ?? '';
                                              final eqCat = item['equipmentCategory'] ?? item['category'] ?? '';
                                              final disc = item['discipline'] ?? '';
                                              if (obj.isNotEmpty && dmg.isNotEmpty) {
                                                title = '$obj ➔ $dmg';
                                                subtitle = 'Root Cause: $cau\nEq: $eqCat ($disc) | Code: $rawId';
                                              } else {
                                                title = item['name'] ?? (cau.isNotEmpty ? cau : rawId);
                                                subtitle = 'Root Cause: $cau | Eq: $eqCat ($disc) | Code: $rawId';
                                              }
                                            }

                                            return Card(
                                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                              color: Theme.of(context).cardColor,
                                              child: ListTile(
                                                title: Text(title),
                                                subtitle: Text(subtitle),
                                                trailing: _canEdit(item['plantId'] as String?, item['unitId'] as String?)
                                                    ? Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(Icons.edit, color: AppColors.accent, size: 20),
                                                            onPressed: () => _showEdit(item),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
                                                            onPressed: () => _showDeleteConfirmation(item),
                                                          ),
                                                        ],
                                                      )
                                                    : null,
                                              ),
                                            )
                                                .animate()
                                                .fadeIn(duration: 250.ms, delay: (index.clamp(0, 10) * 20).ms)
                                                .slideY(begin: 0.03, end: 0, curve: Curves.easeOutQuad);
                                          },
                                        ),
                                ),
                              ],
                            );
                         },
                       ),
                     ),
                   ],
                 ),
          ),
        ],
      ),
    );
  }

  void _showEdit(Map<String, dynamic> item) {
    final scopedItem = Map<String, dynamic>.from(item);
    if ((scopedItem['plantId'] == null || scopedItem['plantId'].toString().isEmpty || scopedItem['plantId'] == '-') && _selectedPlant != null) {
      scopedItem['plantId'] = _selectedPlant;
    }
    if ((scopedItem['unitId'] == null || scopedItem['unitId'].toString().isEmpty || scopedItem['unitId'] == '-') && _selectedUnit != null) {
      scopedItem['unitId'] = _selectedUnit;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditHierarchyItemPage(
          collection: widget.collectionId,
          title: widget.title,
          baseData: scopedItem,
          userRole: _userRole,
          isEditing: true,
          onSave: (d) => setState((){}),
        ),
      ),
    ).then((_) => setState((){}));
  }

  Future<void> _showDeleteConfirmation(Map<String, dynamic> item) async {
    final name = item['name'] ?? item['id'] ?? 'this item';
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Are you sure you want to delete "$name" (ID: ${item['id']})? This may affect linked assets.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );

    if (confirm == true) {
      await FirestoreService().deleteDocument(widget.collectionId, item['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted')));
      }
    }
  }

  Widget _buildScopeChip({required String label, required String value, required IconData icon}) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildScopeDropdown({
    required String label, 
    required String? value, 
    required List<String> items, 
    required void Function(String?) onChanged, 
    required IconData icon,
    Map<String, String>? itemNames,
  }) {
    // Safety check for dropdown value
    final safeValue = items.contains(value) ? value : null;
    
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButton<String>(
        value: safeValue,
        underline: const SizedBox(),
        icon: const SizedBox(), // Hide default icon to use our custom one
        hint: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
        selectedItemBuilder: (context) {
          return items.map((String item) {
            final display = itemNames != null ? (itemNames[item] ?? item) : item;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(display, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            );
          }).toList();
        },
        items: items.map((p) {
          final display = itemNames != null ? (itemNames[p] ?? p) : p;
          return DropdownMenuItem(value: p, child: Text(display, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13)));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _showWipeConfirmation() {
    final isMasterCatalog = widget.collectionId == 'odc' || widget.collectionId == 'odc_causes' || widget.collectionId == 'fault_types';
    final scopeDesc = isMasterCatalog ? 'the entire catalog in Firestore' : 'all records for plant ${_selectedPlant ?? ''} / unit ${_selectedUnit ?? ''}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text('Wipe ${widget.title}?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: Text(
          'Are you sure you want to delete $scopeDesc?\n\nThis will permanently delete all records in collection "${widget.collectionId}" so you can re-import clean data from Excel. This action CANNOT be undone.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete All'),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isUploading = true);
              try {
                int count = await FirestoreService().clearCollection(
                  widget.collectionId,
                  unitId: _selectedUnit,
                  plantId: _selectedPlant,
                );
                // Also clean legacy collection if wiping odc
                if (widget.collectionId == 'odc') {
                  final legacyCount = await FirestoreService().clearCollection('odc_causes');
                  count += legacyCount;
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Successfully deleted $count records from ${widget.title}! Ready for clean import.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error wiping collection: $e'), backgroundColor: AppColors.error),
                  );
                }
              } finally {
                if (mounted) setState(() => _isUploading = false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class AppVersionControlDialog extends StatefulWidget {
  const AppVersionControlDialog({super.key});

  @override
  State<AppVersionControlDialog> createState() => _AppVersionControlDialogState();
}

class _AppVersionControlDialogState extends State<AppVersionControlDialog> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _cloudMinVersion = 'Loading...';
  String _cloudLatestVersion = 'Loading...';
  final TextEditingController _minVersionController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchVersionData();
  }

  @override
  void dispose() {
    _minVersionController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchVersionData() async {
    setState(() => _isLoading = true);
    final doc = await AppVersionService.getVersionDoc();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (doc != null) {
          _cloudMinVersion = doc['min_supported_version'] ?? 'Not Set';
          _cloudLatestVersion = doc['latest_version'] ?? 'Not Set';
          _minVersionController.text = doc['min_supported_version'] ?? AppVersion.currentVersion;
          _messageController.text = doc['force_update_message'] ?? '';
        } else {
          _cloudMinVersion = 'None';
          _cloudLatestVersion = 'None';
          _minVersionController.text = AppVersion.currentVersion;
        }
      });
    }
  }

  Future<void> _saveVersionSettings(String minVersion, {String? message}) async {
    setState(() => _isSaving = true);
    try {
      await AppVersionService.setMinSupportedVersion(
        minVersion.trim(),
        message: message?.trim(),
        latestVersion: AppVersion.currentVersion,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully updated Cloud Min Required Version to v${minVersion.trim()}! Older versions will now be required to update.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating cloud version: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.system_update_alt, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'App Version & Release Control',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Running App Build', 'v${AppVersion.currentVersion}', Colors.cyanAccent),
                        const Divider(height: 16),
                        _buildInfoRow('Cloud Latest Release', 'v$_cloudLatestVersion', Colors.greenAccent),
                        const Divider(height: 16),
                        _buildInfoRow('Cloud Min Required', 'v$_cloudMinVersion', Colors.orangeAccent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick One-Tap Enforce Current Release Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _saveVersionSettings(
                                AppVersion.currentVersion,
                                message: _messageController.text,
                              ),
                      icon: const Icon(Icons.security_update_good, size: 18),
                      label: Text('Enforce v${AppVersion.currentVersion} Globally'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Or configure custom requirements:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _minVersionController,
                    decoration: InputDecoration(
                      labelText: 'Minimum Required Version',
                      hintText: 'e.g. ${AppVersion.currentVersion}',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.tag, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _messageController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Custom Force Update Message (Optional)',
                      hintText: 'e.g. Please update to latest APK from your supervisor.',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.message_outlined, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!_isLoading)
          ElevatedButton(
            onPressed: _isSaving
                ? null
                : () => _saveVersionSettings(
                      _minVersionController.text,
                      message: _messageController.text,
                    ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Changes'),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }
}
