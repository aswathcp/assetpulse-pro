import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/home/presentation/widgets/custom_app_bar.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../data/models/asset_model.dart';
import '../widgets/asset_card.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../../core/widgets/glass_container.dart';
import 'asset_detail_page.dart';
import 'add_edit_asset_page.dart';
import '../../data/models/master_equipment_model.dart';

class AssetsTab extends StatefulWidget {
  const AssetsTab({super.key});

  @override
  State<AssetsTab> createState() => _AssetsTabState();
}

class _AssetsTabState extends State<AssetsTab> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  
  AssetType? _selectedTypeFilter; // null means 'All'
  String? _selectedPlantId;
  String? _selectedUnitId;
  List<String> _plants = [];
  List<String> _units = [];
  
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  String _userRole = '';
  bool _isAdmin = false;
  String? _userPlantId;
  String? _userUnitId;
  
  bool _isLoadingProfile = true;
  Stream<List<AssetModel>>? _assetsStream;
  List<MasterEquipmentModel> _scopeEquipments = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }
  
  Future<void> _loadUserProfile() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    
    final profile = await _firestoreService.getUserProfile(user.uid);
    if (profile == null) return;
    
    _userRole = profile['role'] ?? AppRoles.guest;
    _isAdmin = profile['isAdmin'] == true;
    _userPlantId = profile['plantId'] as String?;
    _userUnitId = profile['unitId'] as String?;
    final uBusinessId = profile['businessId'] as String? ?? 'VISL'; // NEW
    
    await HierarchyService().init(businessId: uBusinessId); // PREVENT BLANK
    
    _plants = HierarchyService().getPlants();
    
    final String? userPlant = (_userPlantId == null || _userPlantId!.isEmpty || _userPlantId == 'Unknown') ? null : _userPlantId;
    final String? userUnit = (_userUnitId == null || _userUnitId!.isEmpty || _userUnitId == 'Unknown') ? null : _userUnitId;
    
    final bool hasGlobalAdmin = profile['isAdmin'] == true && userPlant == null;
    final bool hasPlantAdmin = profile['isAdmin'] == true && userPlant != null;

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
      _selectedPlantId = _plants.isNotEmpty ? _plants.first : null;
    } else if (isPlantScope) {
      _isPlantLocked = true;
      _isUnitLocked = false;
      _selectedPlantId = userPlant ?? (_plants.isNotEmpty ? _plants.first : null);
    } else {
      _isPlantLocked = true;
      _isUnitLocked = true;
      _selectedPlantId = userPlant ?? (_plants.isNotEmpty ? _plants.first : null);
      _selectedUnitId = userUnit;
    }
    
    _updateUnitList();
    
    if (!_isUnitLocked && _selectedUnitId == null) {
      _selectedUnitId = _units.isNotEmpty ? _units.first : null;
    }
    
    if (mounted) setState(() => _isLoadingProfile = false);
  }

  void _updateUnitList() {
    if (_selectedPlantId == null) {
      _units = [];
      _selectedUnitId = null;
    } else {
      _units = HierarchyService().getUnitsForPlant(_selectedPlantId!);
      if (_units.isEmpty) _units = ['PID1', 'MCD']; // Fallback
      if (!_units.contains(_selectedUnitId)) {
        _selectedUnitId = _units.isNotEmpty ? _units.first : null;
      }
    }
    _refreshStreams();
  }

  void _refreshStreams() {
    setState(() {
      _assetsStream = _firestoreService.getAssetsStream(_selectedUnitId, _selectedPlantId);
    });
    
    // Also load master equipments for filtering
    _firestoreService.getAllMasterEquipmentsStream(_selectedUnitId, _selectedPlantId).listen((equipments) {
      if (mounted) {
        setState(() {
          _scopeEquipments = equipments;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AssetModel> _filterAssets(List<AssetModel> assets) {
    return assets.where((a) {
      // 1. Type Logic
      bool matchesType = true;
      if (_selectedTypeFilter != null) {
        matchesType = a.type == _selectedTypeFilter;
      }
      
      // 1. Scope Logic (Only show assets belonging to Master Equipments in the current scope)
      // If we have no scope equipments loaded, either the scope is empty or loading. We allow all for now, 
      // but ideally we check if the asset's masterEquipmentId matches our list.
      bool matchesScope = true;
      if (_selectedPlantId != null || _selectedUnitId != null) {
         if (_scopeEquipments.isNotEmpty) {
           matchesScope = _scopeEquipments.any((e) => e.id == a.masterEquipmentId);
         } else {
           // If scope is selected but no master equipments exist there, show nothing
           matchesScope = false; 
         }
      }

      // 2. Search Logic
      final query = _searchController.text.toLowerCase();
      bool matchesSearch = true;
      if (query.isNotEmpty) {
         matchesSearch = a.tagNo.toLowerCase().contains(query) ||
           a.name.toLowerCase().contains(query) ||
           a.serialNo.toLowerCase().contains(query);
      }
      
      return matchesType && matchesScope && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: PulseLoading(size: 60)),
      );
    }

    // ALLOW nulls for Developer/Unit Admin
    // if (_userUnitId == null ...) <-- Removed blocking check

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Inventory'),
      body: StreamBuilder<List<AssetModel>>(
        stream: _assetsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: PulseLoading(size: 60));
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Theme.of(context).colorScheme.error)));
          }

          final allAssets = snapshot.data ?? [];

          return Column(
            children: [
              // SCOPE SELECTORS
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _isPlantLocked 
                        ? _buildScopeChip(label: 'Plant', value: HierarchyService().getPlantNames()[_selectedPlantId] ?? _selectedPlantId ?? '...', icon: Icons.factory)
                        : _buildScopeDropdown(
                            label: 'Plant',
                            value: _selectedPlantId,
                            items: _plants,
                            onChanged: (v) => setState(() { _selectedPlantId = v; _updateUnitList(); }),
                            icon: Icons.factory,
                            itemNames: HierarchyService().getPlantNames(),
                          ),
                      const SizedBox(width: 8),

                      _isUnitLocked
                        ? _buildScopeChip(label: 'Unit', value: HierarchyService().getUnitNamesForPlant(_selectedPlantId ?? '')[_selectedUnitId] ?? _selectedUnitId ?? '...', icon: Icons.settings_input_component)
                        : _buildScopeDropdown(
                            label: 'Unit',
                            value: _selectedUnitId,
                            items: _units,
                            onChanged: (v) => setState(() { _selectedUnitId = v; }),
                            icon: Icons.settings_input_component,
                            itemNames: HierarchyService().getUnitNamesForPlant(_selectedPlantId ?? ''),
                          ),
                    ],
                  ),
                ),
              ),

              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}), // Trigger rebuild for search
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Tag ID, Name, Serial...',
                                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.filter_list, color: AppColors.primaryLight),
                        onPressed: _showFilterBottomSheet,
                      ),
                    ),
                    if (PermissionHelper.canEditDatabaseItem(
                      userRole: _userRole,
                      isAdmin: _isAdmin,
                      userPlantId: _userPlantId,
                      userUnitId: _userUnitId,
                      itemPlantId: _selectedPlantId,
                      itemUnitId: _selectedUnitId,
                    )) ...[
                      const SizedBox(width: 8),
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: AppColors.accent),
                          onPressed: () {
                             if (_selectedUnitId != null && _selectedPlantId != null) {
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(
                                   builder: (context) => AddEditAssetPage(
                                     unitId: _selectedUnitId,
                                     plantId: _selectedPlantId,
                                   ),
                                 ),
                               );
                             } else {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Plant and Unit first.')));
                             }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // Unified List Content
              Expanded(
                child: _buildAssetList(allAssets),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return GlassContainer(
          borderRadius: 24,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter by Type', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
              
              // "All" Option
              ListTile(
                title: const Text('All Types', style: TextStyle(color: Colors.white)),
                trailing: _selectedTypeFilter == null ? const Icon(Icons.check, color: AppColors.accent) : null,
                onTap: () {
                  setState(() => _selectedTypeFilter = null);
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white24),

              // Dynamic List of Enums
              ...AssetType.values.map((type) {
                final display = () {
                  final idx = AssetType.values.indexOf(type);
                  if (idx >= 0 && idx < HierarchyService.assetTypes.length) {
                    return HierarchyService.assetTypes[idx];
                  }
                  return type.name;
                }();
                return ListTile(
                  title: Text(display, style: const TextStyle(color: Colors.white)),
                  trailing: _selectedTypeFilter == type ? const Icon(Icons.check, color: AppColors.accent) : null,
                  onTap: () {
                    setState(() => _selectedTypeFilter = type);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 32),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildAssetList(List<AssetModel> allAssets) {
    final assets = _filterAssets(allAssets);
    
    if (assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, color: Theme.of(context).disabledColor, size: 48),
            const SizedBox(height: 16),
            Text('No items found', style: TextStyle(color: Theme.of(context).disabledColor)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100), // Bottom padding for navbar
      itemCount: assets.length,
      itemBuilder: (context, index) {
        return AssetCard(
          asset: assets[index],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssetDetailPage(asset: assets[index]),
              ),
            );
          },
        ).animate().fadeIn(duration: 300.ms, delay: (50 * index).ms).slideX(begin: 0.1);
      },
    );
  }

  // --- HELPER UI ---
  Widget _buildScopeChip({required String label, required String value, required IconData icon}) {
    return GlassContainer(
      height: 48,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: 8),
            Text('$label:', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
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
    return GlassContainer(
      height: 48,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: items.contains(value) ? value : null,
              hint: Text('Select $label', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              items: items.map((e) {
                final display = itemNames != null ? (itemNames[e] ?? e) : e;
                return DropdownMenuItem(value: e, child: Text(display, style: const TextStyle(fontWeight: FontWeight.bold)));
              }).toList(),
              onChanged: onChanged,
              underline: const SizedBox(),
              icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
              dropdownColor: Theme.of(context).colorScheme.surface,
            ),
          ],
        ),
      ),
    );
  }
}
