import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/widgets/glass_container.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/widgets/pulse_loading.dart';
import 'package:asset_pulse_pro/core/constants/app_roles.dart';
import 'package:asset_pulse_pro/core/utils/permission_helper.dart';
import 'package:asset_pulse_pro/features/assets/data/models/location_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/panel_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/feeder_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/panel_room_model.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/data_import_page.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/add_edit_master_page.dart';
import 'package:asset_pulse_pro/features/assets/data/models/master_equipment_model.dart';

// --- MAIN DASHBOARD (MENU) ---

class AdminDatabasePage extends StatelessWidget {
  final String? initialCollection;
  const AdminDatabasePage({super.key, this.initialCollection});

  final Map<String, String> _collections = const {
    'locations': 'Physical Areas',
    'panel_rooms': 'Panel Rooms',
    'panels': 'Panels / MCCs',
    'feeders': 'Feeders',
    'master_equipments': 'Master Equipment',
    'equipment_types': 'Equipment Types',
    'fault_types': 'Fault Types',
    'odc_causes': 'ODC (Damage Cause)',
  };

  final Map<String, IconData> _icons = const {
    'locations': Icons.map,
    'panel_rooms': Icons.room_preferences,
    'panels': Icons.electric_bolt,
    'feeders': Icons.power_input,
    'master_equipments': Icons.precision_manufacturing,
    'equipment_types': Icons.category,
    'fault_types': Icons.warning_amber,
    'odc_causes': Icons.broken_image,
  };

  final Map<String, String> _subtitles = const {
    'locations': 'Physical Plant Areas (e.g. BF1-RMHS)',
    'panel_rooms': 'Substation Rooms (e.g. MCC 2 & 9)',
    'panels': 'MCCs & PCC Panels',
    'feeders': 'Power Feeders & Sources',
    'master_equipments': 'Functional Tags & Machinery',
    'equipment_types': 'Standardize Machinery Types',
    'fault_types': 'Root Cause Analysis Codes',
    'odc_causes': 'Object Damage Categories',
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
           childAspectRatio: 0.9, // Taller cards to prevent overflow
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
                   if (['equipment_types', 'fault_types', 'odc_causes'].contains(key)) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Coming Soon!'), behavior: SnackBarBehavior.floating),
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

  @override
  void initState() {
    super.initState();
    _loadScope();
    
    // Auto-open if initial collection provided
    if (widget.collectionId == 'hierarchy_config') {
       // Optional: specific logic for hierarchy?
    }
  }

  Future<void> _loadScope() async {
    setState(() => _isLoadingScope = true);
    final user = AuthService().currentUser;
    if (user == null) return;
    
    final profile = await FirestoreService().getUserProfile(user.uid);
    if (profile == null) return;
    
    _userRole = profile['role'] ?? AppRoles.guest;
    final userPlantId = profile['plantId'] as String?;
    final userUnitId = profile['unitId'] as String?;
    final userBusinessId = profile['businessId'] as String? ?? 'VISL'; // NEW
    
    await HierarchyService().init(businessId: userBusinessId); // PREVENT BLANK
    _selectedBusinessId = HierarchyService().currentBusinessId;
    
    _plants = HierarchyService().getPlants();
    
    _isAdmin = profile['isAdmin'] == true;
    _userPlantId = userPlantId;
    _userUnitId = userUnitId;
    
    final String? cleanPlant = (userPlantId == null || userPlantId.isEmpty || userPlantId == 'Unknown') ? null : userPlantId;
    final String? cleanUnit = (userUnitId == null || userUnitId.isEmpty || userUnitId == 'Unknown') ? null : userUnitId;
    
    final bool hasGlobalAdmin = _isAdmin && cleanPlant == null;
    final bool hasPlantAdmin = _isAdmin && cleanPlant != null;

    final bool isPlantScope = (hasPlantAdmin || _userRole == AppRoles.plantAdmin || _userRole == AppRoles.plantHod) &&
        _userRole != AppRoles.manager &&
        _userRole != AppRoles.deputyManager &&
        _userRole != AppRoles.associateManager &&
        _userRole != AppRoles.assistantManager &&
        _userRole != AppRoles.unitAdmin &&
        _userRole != AppRoles.unitHod;

    if (_userRole == AppRoles.developer || _userRole == AppRoles.auditor || hasGlobalAdmin) {
      _isPlantLocked = false;
      _isUnitLocked = false;
      _selectedPlant = _plants.isNotEmpty ? _plants.first : null;
    } else if (isPlantScope) {
      _isPlantLocked = true;
      _selectedPlant = cleanPlant ?? (_plants.isNotEmpty ? _plants.first : null);
      _isUnitLocked = false;
    } else {
      _isPlantLocked = true;
      _selectedPlant = cleanPlant ?? (_plants.isNotEmpty ? _plants.first : null);
      _isUnitLocked = true;
      _selectedUnit = cleanUnit;
    }
    
    _updateUnitList();
    
    // If unit is not locked and not selected, pick first
    if (!_isUnitLocked && _selectedUnit == null) {
      _selectedUnit = _units.isNotEmpty ? _units.first : null;
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
    if (widget.collectionId == 'master_equipments') {
       Navigator.push(
         context,
         MaterialPageRoute(builder: (context) => AddEditMasterPage(
           unitId: _selectedUnit ?? '', 
           plantId: _selectedPlant ?? '',
           userRole: _userRole,
         )),
       ).then((_) => setState((){})); // Refresh on return
    } else {
      showDialog(
         context: context,
         builder: (c) => _AddEntryDialog(
           collection: widget.collectionId,
           baseData: {
             'plantId': _selectedPlant, 
             'unitId': _selectedUnit,
             'businessId': _selectedBusinessId,
           },
           userRole: _userRole,
           onSave: (d) async {
              await FirestoreService().batchSave(widget.collectionId, [d]);
              setState((){});
           }
         )
      );
    }
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
               : StreamBuilder<List<Map<String, dynamic>>>(
                   stream: FirestoreService().getCollectionStream(widget.collectionId, _selectedUnit, _selectedPlant),
                   builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: PulseLoading(size: 30));
                      if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                      final items = snapshot.data ?? [];
                      
                      if (items.isEmpty) return Center(child: Text('No Items in $_selectedPlant/$_selectedUnit', style: const TextStyle(color: Colors.grey)));
                      
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                           final item = items[index];
                           final id = item['id']?.toString() ?? 'unknown';
                           final rawId = HierarchyService.stripPrefix(id, _selectedPlant ?? '', _selectedUnit ?? '');
                           String title = item['name'] ?? rawId;
                           String typeOrCategory = item['type'] ?? item['category'] ?? '';
                           String subtitle = typeOrCategory.isEmpty ? 'ID: $rawId' : '$typeOrCategory | ID: $rawId';
                           
                           // Enhanced Subtitles for hierarchy
                           if (widget.collectionId == 'panels') {
                             final cleanRoom = HierarchyService.stripPrefix(item['panelRoomId'] ?? '-', _selectedPlant ?? '', _selectedUnit ?? '');
                             subtitle += ' | Room: $cleanRoom';
                           }
                           if (widget.collectionId == 'feeders') {
                             final cleanPanel = HierarchyService.stripPrefix(item['panelId'] ?? '-', _selectedPlant ?? '', _selectedUnit ?? '');
                             subtitle += ' | Panel: $cleanPanel';
                           }
                           if (widget.collectionId == 'lighting_dbs') {
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
                           );
                        },
                      );
                   },
                 ),
          ),
        ],
      ),
    );
  }

  void _showEdit(Map<String, dynamic> item) {
    if (widget.collectionId == 'master_equipments') {
       final id = item['id']?.toString() ?? '';
       Navigator.push(
         context,
         MaterialPageRoute(
           builder: (context) => AddEditMasterPage(
             unitId: _selectedUnit ?? item['unitId'] ?? '',
             plantId: _selectedPlant ?? item['plantId'] ?? '',
             userRole: _userRole,
             existingItem: MasterEquipmentModel.fromMap(item, id),
           ),
         ),
       );
       return;
    }

    showDialog(
      context: context,
      builder: (c) => _AddEntryDialog(
        collection: widget.collectionId,
        baseData: item,
        userRole: _userRole,
        isEditing: true,
        onSave: (d) async {
           // Batch save handles single items too
           await FirestoreService().batchSave(widget.collectionId, [d]);
           setState((){});
        }
      )
    );
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
}

class _AddEntryDialog extends StatefulWidget {
  final String collection;
  final Map<String, dynamic> baseData;
  final String userRole;
  final bool isEditing;
  final Function(Map<String, dynamic>) onSave;
  
  const _AddEntryDialog({
    required this.collection, 
    required this.baseData, 
    required this.userRole, 
    this.isEditing = false,
    required this.onSave
  });

  @override
  State<_AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<_AddEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  final _idController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    _formData.addAll(widget.baseData);
    _formData['businessId'] = widget.baseData['businessId'] ?? HierarchyService().currentBusinessId;
    if (!widget.isEditing) {
       _formData['createdBy'] = user?.uid;
    }
    _formData['modifiedBy'] = user?.uid;
    
    _idController.text = widget.isEditing 
        ? HierarchyService.stripPrefix(_formData['id']?.toString() ?? '', _formData['plantId'] ?? '', _formData['unitId'] ?? '') 
        : '';

    _loadReferenceData();
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  // Reference Data for Dropdowns

  List<PanelRoomModel> _refPanelRooms = [];
  List<PanelModel> _refPanels = [];
  List<String> _refPlants = [];
  List<String> _refUnits = [];
  bool _isLoadingRef = true;

  Future<void> _loadReferenceData() async {
    setState(() => _isLoadingRef = true);
    try {
      final plantId = _formData['plantId'] as String?;
      final unitId = _formData['unitId'] as String?;

      if (widget.userRole == AppRoles.developer) {
        _refPlants = HierarchyService().getPlants();
        if (plantId != null) _refUnits = HierarchyService().getUnitsForPlant(plantId);
      }

      final db = FirebaseFirestore.instance;
      if (widget.collection == 'panels' || widget.collection == 'master_equipments') {
         if (unitId != null && plantId != null) {
           final rooms = await db.collection('panel_rooms')
             .where('unitId', isEqualTo: unitId)
             .where('plantId', isEqualTo: plantId)
             .get();
           _refPanelRooms = rooms.docs.map((e) => PanelRoomModel.fromMap(e.data(), e.id)).toList();
         }
      }

      if (widget.collection == 'feeders' || widget.collection == 'master_equipments') {
         if (unitId != null && plantId != null) {
            final pnlSnapshot = await db.collection('panels')
              .where('unitId', isEqualTo: unitId)
              .where('plantId', isEqualTo: plantId)
              .get();
            _refPanels = pnlSnapshot.docs.map((d) => PanelModel.fromMap(d.data(), d.id)).toList();
         }
      }
    } catch (e) {
      debugPrint("Error loading reference data: $e");
    } finally {
      if (mounted) setState(() => _isLoadingRef = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Modify' : 'Add New';
    return AlertDialog(
      title: Text('$title ${widget.collection.replaceAll('_', ' ').toUpperCase()}'),
      content: _isLoadingRef 
        ? const SizedBox(height: 120, child: Center(child: PulseLoading(size: 40)))
        : SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _buildFields(),
              ),
            ),
          ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              
              // Ensure ID is prefixed and uppercase/clean
              if (_formData['id'] != null) {
                final rawId = _formData['id'].toString().trim().toUpperCase();
                _formData['id'] = HierarchyService.prefixId(
                  rawId,
                  _formData['plantId'] ?? '',
                  _formData['unitId'] ?? '',
                );
                if (widget.collection == 'lighting_dbs') {
                  _formData['name'] = rawId;
                }
              }

              try {
                final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
                final createdAtRaw = _formData['createdAt'];
                DateTime? dtCreatedAt;
                if (createdAtRaw is Timestamp) {
                  dtCreatedAt = createdAtRaw.toDate();
                } else if (createdAtRaw is DateTime) {
                  dtCreatedAt = createdAtRaw;
                }
                final createdBy = !widget.isEditing ? currentUserUid : _formData['createdBy'];

                if (widget.collection == 'locations') {
                  final loc = LocationModel(
                    id: _formData['id'],
                    unitId: _formData['unitId'] ?? '',
                    plantId: _formData['plantId'] ?? '',
                    name: _formData['name'],
                    type: 'Area',
                    description: _formData['description'] ?? '',
                    createdAt: dtCreatedAt,
                    createdBy: createdBy,
                    modifiedBy: currentUserUid,
                  );
                  await FirestoreService().saveLocation(loc);
                } else if (widget.collection == 'panel_rooms') {
                  final room = PanelRoomModel(
                    id: _formData['id'],
                    unitId: _formData['unitId'] ?? '',
                    plantId: _formData['plantId'] ?? '',
                    name: _formData['name'],
                    description: _formData['description'] ?? '',
                    createdAt: dtCreatedAt,
                    createdBy: createdBy,
                    modifiedBy: currentUserUid,
                  );
                  await FirestoreService().savePanelRoom(room);
                } else if (widget.collection == 'panels') {
                  final panel = PanelModel(
                    id: _formData['id'],
                    plantId: _formData['plantId'] ?? '',
                    unitId: _formData['unitId'] ?? '',
                    panelRoomId: _formData['panelRoomId'] ?? _formData['locationId'] ?? '',
                    name: _formData['name'],
                    type: _formData['type'] ?? 'MCC',
                    description: _formData['description'] ?? '',
                    createdAt: dtCreatedAt,
                    createdBy: createdBy,
                    modifiedBy: currentUserUid,
                  );
                  await FirestoreService().savePanel(panel);
                } else if (widget.collection == 'feeders') {
                  final feeder = FeederModel(
                    id: _formData['id'],
                    plantId: _formData['plantId'] ?? '',
                    unitId: _formData['unitId'] ?? '',
                    panelId: _formData['panelId'] ?? '',
                    name: _formData['name'],
                    type: _formData['type'] ?? 'Feeder',
                    description: _formData['description'] ?? '',
                    createdAt: dtCreatedAt,
                    createdBy: createdBy,
                    modifiedBy: currentUserUid,
                  );
                  await FirestoreService().saveFeeder(feeder);
                } else {
                  _formData['modifiedBy'] = currentUserUid;
                  if (!widget.isEditing) {
                    _formData['createdBy'] = currentUserUid;
                    _formData['createdAt'] = dtCreatedAt ?? DateTime.now();
                  }
                  _formData['updatedAt'] = DateTime.now();
                  // Remove unused fields for lighting_dbs
                  if (widget.collection == 'lighting_dbs') {
                    _formData.remove('businessId');
                  }
                  await FirestoreService().batchSave(widget.collection, [_formData]);
                }
                
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save Error: $e')));
              }
            }
          },
          child: const Text('Save'),
        )
      ],
    );
  }

  List<Widget> _buildFields() {
    List<Widget> children = [];
    
    // 1. Immutable/Auto-filled Context (Show as info if not Developer)
    // Don't show Plant/Unit info for lighting_dbs — scope is implied
    if (widget.userRole != AppRoles.developer && widget.collection != 'lighting_dbs') {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(child: _buildInfoBox('PLANT', _formData['plantId'] ?? '-')),
              const SizedBox(width: 8),
              Expanded(child: _buildInfoBox('UNIT', _formData['unitId'] ?? '-')),
            ],
          ),
        )
      );
    } else {
      // Developer can change plant/unit
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: _formData['plantId'],
            decoration: const InputDecoration(labelText: 'Plant', border: OutlineInputBorder()),
            items: _refPlants.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() {
              _formData['plantId'] = v;
              if (v != null) _refUnits = HierarchyService().getUnitsForPlant(v);
              _formData['unitId'] = _refUnits.isNotEmpty ? _refUnits.first : null;
              _loadReferenceData(); // Re-load parents for new unit
            }),
          ),
        )
      );
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: _formData['unitId'],
            decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
            items: _refUnits.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() {
               _formData['unitId'] = v;
               _loadReferenceData(); // Re-load parents
            }),
          ),
        )
      );
    }

    // 2. Common Fields (ID and Name)
    children.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: _idController,
          enabled: !widget.isEditing, // Lock ID on edit
          decoration: InputDecoration(
            labelText: 'ID (Unique Code)', 
            border: const OutlineInputBorder(), 
            hintText: 'e.g. MCC-2',
            helperText: widget.isEditing ? 'ID cannot be changed.' : 'Must be unique (system will auto-prepend prefix in the background).',
            fillColor: widget.isEditing ? Colors.grey.withValues(alpha: 0.1) : null,
            filled: widget.isEditing,
          ),
          textCapitalization: TextCapitalization.characters,
          onSaved: (v) => _formData['id'] = v,
          validator: (v) => v == null || v.isEmpty ? 'ID is required' : null,
        ),
      )
    );

    if (widget.collection != 'lighting_dbs') {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            initialValue: _formData['name']?.toString(),
            decoration: const InputDecoration(labelText: 'Display Name', border: OutlineInputBorder()),
            onSaved: (v) => _formData['name'] = v,
            validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
          ),
        )
      );
    }

    // 3. Collection Specific Fields
    if (widget.collection == 'locations') {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            initialValue: _formData['description']?.toString(),
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            onSaved: (v) => _formData['description'] = v,
          ),
        )
      );
    } else if (widget.collection == 'panel_rooms') {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            initialValue: _formData['description']?.toString(),
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            onSaved: (v) => _formData['description'] = v,
          ),
        )
      );
    } else if (widget.collection == 'panels') {
      children.add(_buildDropdown('Panel Category', 'type', HierarchyService.panelTypes, _formData['type'] ?? 'MCC'));
      final safeSelectedRoomId = _refPanelRooms.any((e) => e.id == (_formData['panelRoomId'] ?? _formData['locationId'])) 
          ? (_formData['panelRoomId'] ?? _formData['locationId']) 
          : null;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: safeSelectedRoomId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Parent Panel Room', border: OutlineInputBorder(), hintText: 'Select Panel Room'),
            items: _refPanelRooms.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.id})', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _formData['panelRoomId'] = v),
            validator: (v) => v == null ? 'Panel Room selection is required' : null,
          ),
        )
      );
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            initialValue: _formData['description']?.toString(),
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            onSaved: (v) => _formData['description'] = v,
          ),
        )
      );
    } else if (widget.collection == 'feeders') {
      children.add(_buildDropdown('Feeder Type', 'type', HierarchyService.feederTypes, _formData['type'] ?? 'Feeder'));
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: _formData['panelId'],
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Parent Panel', border: OutlineInputBorder(), hintText: 'Which panel does this belong to?'),
            items: _refPanels.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.id})', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _formData['panelId'] = v),
            validator: (v) => v == null ? 'Panel selection is required' : null,
          ),
        )
      );
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            initialValue: _formData['description']?.toString(),
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            onSaved: (v) => _formData['description'] = v,
          ),
        )
      );
    } else if (widget.collection == 'lighting_dbs') {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            initialValue: _formData['location']?.toString(),
            decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder(), hintText: 'e.g. Near Compressor House'),
            onSaved: (v) => _formData['location'] = v,
            validator: (v) => v == null || v.isEmpty ? 'Location is required' : null,
          ),
        )
      );

      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            initialValue: _formData['rccbCount']?.toString(),
            decoration: const InputDecoration(labelText: 'No of RCCB', border: OutlineInputBorder(), hintText: 'e.g. 10'),
            keyboardType: TextInputType.number,
            onSaved: (v) => _formData['rccbCount'] = v != null ? int.tryParse(v) : null,
            validator: (v) {
              if (v == null || v.isEmpty) return 'No of RCCB is required';
              if (int.tryParse(v) == null) return 'Must be a valid integer';
              return null;
            },
          ),
        )
      );

      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            initialValue: _formData['incomingSource']?.toString(),
            decoration: const InputDecoration(labelText: 'Incoming Source', border: OutlineInputBorder(), hintText: 'e.g. MCC-1 Feeder 4'),
            onSaved: (v) => _formData['incomingSource'] = v,
            validator: (v) => v == null || v.isEmpty ? 'Incoming source is required' : null,
          ),
        )
      );
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            initialValue: _formData['description']?.toString(),
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            onSaved: (v) => _formData['description'] = v,
          ),
        )
      );
    }

    return children;
  }

  Widget _buildInfoBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05), 
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.accent)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String key, List<String> items, String current) {
    final safeCurrent = items.contains(current) ? current : (items.isNotEmpty ? items.first : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: safeCurrent,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => _formData[key] = v),
      ),
    );
  }
}
