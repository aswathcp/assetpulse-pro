// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/home/presentation/widgets/custom_app_bar.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../data/models/asset_model.dart';
import '../widgets/asset_card.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../admin/presentation/pages/data_import_page.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AssetType? _selectedTypeFilter;
  AssetStatus? _selectedStatusFilter;
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

  bool _isLoading = true;
  Stream<List<AssetModel>>? _assetsStream;
  List<MasterEquipmentModel> _scopeEquipments = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    final user = AuthService().currentUser;
    if (user == null) return;

    final profile = await _firestoreService.getUserProfile(user.uid);
    if (profile == null) return;

    _userRole = profile['role'] ?? AppRoles.guest;
    _isAdmin = profile['isAdmin'] == true || _userRole == AppRoles.developer;
    _userPlantId = profile['plantId'] as String?;
    _userUnitId = profile['unitId'] as String?;
    final uBusinessId = profile['businessId'] as String? ?? 'VISL';

    await HierarchyService().init(businessId: uBusinessId);

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

    _refreshStreams();
    if (mounted) setState(() => _isLoading = false);
  }

  void _updateUnitList() {
    if (_selectedPlantId == null) {
      _units = [];
      _selectedUnitId = null;
    } else {
      _units = HierarchyService().getUnitsForPlant(_selectedPlantId!);
      if (_units.isEmpty) _units = ['PID1', 'MCD'];
      if (!_units.contains(_selectedUnitId)) {
        _selectedUnitId = _units.isNotEmpty ? _units.first : null;
      }
    }
  }

  void _refreshStreams() {
    setState(() {
      _assetsStream = _firestoreService.getAssetsStream(_selectedUnitId, _selectedPlantId);
    });

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
      if (_selectedTypeFilter != null && a.type != _selectedTypeFilter) {
        return false;
      }

      // 2. Status Logic
      if (_selectedStatusFilter != null && a.status != _selectedStatusFilter) {
        return false;
      }

      // 3. Search Logic
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matchesTag = a.tagNo.toLowerCase().contains(query);
        final matchesName = a.name.toLowerCase().contains(query);
        final matchesSerial = a.serialNo.toLowerCase().contains(query);
        final matchesMake = a.make.toLowerCase().contains(query);
        final matchesModel = a.model.toLowerCase().contains(query);
        final matchesRfid = a.rfidTag?.toLowerCase().contains(query) ?? false;
        if (!matchesTag && !matchesName && !matchesSerial && !matchesMake && !matchesModel && !matchesRfid) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // --- EXPORT ASSETS TO EXCEL ---
  Future<void> _exportAssetsToExcel(List<AssetModel> assets) async {
    if (_selectedPlantId == null || _selectedUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select scope first.')),
      );
      return;
    }

    try {
      var excel = Excel.createExcel();
      String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'Asset_Inventory');
      Sheet sheet = excel['Asset_Inventory'];

      final headers = [
        'Tag No',
        'Equipment Name',
        'Type',
        'Status',
        'Make',
        'Model',
        'Serial No',
        'Power (kW)',
        'Voltage (V)',
        'Speed (RPM)',
        'RFID Tag',
        'Critical Asset',
        'Parent Equipment',
      ];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      for (var a in assets) {
        sheet.appendRow([
          TextCellValue(a.tagNo),
          TextCellValue(a.name),
          TextCellValue(a.type.name.toUpperCase()),
          TextCellValue(a.status.name.toUpperCase()),
          TextCellValue(a.make),
          TextCellValue(a.model),
          TextCellValue(a.serialNo),
          TextCellValue(a.powerKw?.toString() ?? ''),
          TextCellValue(a.voltage?.toString() ?? ''),
          TextCellValue(a.speedRpm?.toString() ?? ''),
          TextCellValue(a.rfidTag ?? ''),
          TextCellValue(a.isCritical ? 'YES' : 'NO'),
          TextCellValue(a.masterEquipmentId),
        ]);
      }

      final bytes = excel.save();
      if (bytes != null) {
        final fileName = 'Asset_Inventory_${_selectedPlantId}_${_selectedUnitId}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final savedPath = await FileDownloadHelper.downloadFile(bytes, fileName);
        if (savedPath != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel exported: $fileName'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // --- ADMIN SETTINGS & DATABASE MANAGEMENT MODAL ---
  void _showSettingsModal(List<AssetModel> currentAssets) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return GlassContainer(
          borderRadius: 24,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.settings, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Asset Registry Management',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. Bulk Excel Import
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.cyanAccent),
                  title: const Text('Bulk Excel Import', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Upload Motors, Gearboxes & Pumps via Excel sheet'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_selectedPlantId != null && _selectedUnitId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DataImportPage(collectionId: 'assets'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select scope first.')),
                      );
                    }
                  },
                ),
                const Divider(),

                // 2. Export Inventory
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.greenAccent),
                  title: const Text('Export Inventory to Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Export ${currentAssets.length} assets to .xlsx spreadsheet'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportAssetsToExcel(currentAssets);
                  },
                ),
                const Divider(),

                // 3. Batch Delete / Purge (Admins only)
                if (_isAdmin) ...[
                  ListTile(
                    leading: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                    title: const Text('Purge Current Scope Assets', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    subtitle: Text('Delete all ${currentAssets.length} assets in $_selectedPlantId / $_selectedUnitId'),
                    trailing: const Icon(Icons.warning, color: Colors.redAccent),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmPurgeAssets(currentAssets);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmPurgeAssets(List<AssetModel> assets) {
    if (assets.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Confirm Batch Delete'),
            ],
          ),
          content: Text(
            'Are you sure you want to permanently delete all ${assets.length} assets in ${_selectedPlantId} / ${_selectedUnitId}?\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                setState(() => _isLoading = true);
                try {
                  final batch = _firestore.batch();
                  for (var a in assets) {
                    batch.delete(_firestore.collection('assets').doc(a.id));
                  }
                  await batch.commit();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Successfully deleted ${assets.length} assets.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Purge failed: $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Delete All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- HELP DIALOG ---
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.help_outline, color: AppColors.primary, size: 24),
              SizedBox(width: 10),
              Text('Asset Registry Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('ISO 55000 Plant Asset Architecture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                SizedBox(height: 6),
                Text('• Tag ID Standard: [PLANT]-[UNIT]-[TYPE]-[SEQ] (e.g. IOG-COD-MTR-001)\n• Types: MTR (Motors), GBX (Gearboxes), PMP (Pumps).\n• Statuses: ACTIVE (in service), SPARE (standby/pooled), UNDER MAINTENANCE, SCRAPPED.', style: TextStyle(fontSize: 12)),
                SizedBox(height: 12),
                Text('Spare Pooling & Replacement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                SizedBox(height: 6),
                Text('• Spares can be assigned to multiple compatible parent equipments.\n• When replacing in the field, Tag IDs remain unique and prevent record collision.', style: TextStyle(fontSize: 12)),
                SizedBox(height: 12),
                Text('RFID / NFC Tagging', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                SizedBox(height: 6),
                Text('• Tap the NFC scan button in Add/Edit Asset to capture physical high-frequency RFID tags directly into the asset identity record.', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final canEdit = PermissionHelper.canEditDatabaseItem(
      userRole: _userRole,
      isAdmin: _isAdmin,
      userPlantId: _userPlantId,
      userUnitId: _userUnitId,
      itemPlantId: _selectedPlantId,
      itemUnitId: _selectedUnitId,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Asset Inventory'),
      body: ResponsiveContentWrapper(
        maxWidth: 1320,
        child: StreamBuilder<List<AssetModel>>(
          stream: _assetsStream,
          builder: (context, snapshot) {
            final allAssets = snapshot.data ?? [];
            final filtered = _filterAssets(allAssets);

            return Column(
              children: [
                // 1. Signature Checklist-style Scope Selectors
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: GlassContainer(
                    borderRadius: 16,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedPlantId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Select Plant', border: InputBorder.none),
                              items: _plants
                                  .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(HierarchyService().getPlantNames()[e] ?? e,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: _isPlantLocked
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedPlantId = val;
                                          _updateUnitList();
                                          _refreshStreams();
                                        });
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedUnitId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Select Unit', border: InputBorder.none),
                              items: _units
                                  .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(HierarchyService().getUnitNamesForPlant(_selectedPlantId ?? '')[e] ?? e,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: _isUnitLocked
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedUnitId = val;
                                          _refreshStreams();
                                        });
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 350.ms),
                ),

                // 2. Clean Single-Layer Search & Action Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      // Clean Search Field
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Search Tag ID, Name, Serial, RFID...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Filter Button [tune]
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                        icon: const Icon(Icons.tune, color: Colors.white, size: 20),
                        tooltip: 'Filter by Type & Status',
                        onPressed: _showFilterBottomSheet,
                      ),
                      const SizedBox(width: 6),

                      // Settings / Admin Management Icon [⚙️]
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: Colors.indigoAccent),
                        icon: const Icon(Icons.settings, color: Colors.white, size: 20),
                        tooltip: 'Registry Settings & Import/Export',
                        onPressed: () => _showSettingsModal(filtered),
                      ),
                      const SizedBox(width: 6),

                      // Help Button [?]
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: Colors.teal),
                        icon: const Icon(Icons.help_outline, color: Colors.white, size: 20),
                        tooltip: 'Asset Hierarchy Guide',
                        onPressed: _showHelpDialog,
                      ),

                      // Add Asset Button [+]
                      if (canEdit) ...[
                        const SizedBox(width: 6),
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                          icon: const Icon(Icons.add, color: Colors.black, size: 20),
                          tooltip: 'Add New Asset',
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select a Plant and Unit first.')),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // 3. Active Filter Chip Summary (if applied)
                if (_selectedTypeFilter != null || _selectedStatusFilter != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Row(
                      children: [
                        if (_selectedTypeFilter != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Chip(
                              label: Text('Type: ${_selectedTypeFilter!.name.toUpperCase()}', style: const TextStyle(fontSize: 11)),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () => setState(() => _selectedTypeFilter = null),
                            ),
                          ),
                        if (_selectedStatusFilter != null)
                          Chip(
                            label: Text('Status: ${_selectedStatusFilter!.name.toUpperCase()}', style: const TextStyle(fontSize: 11)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setState(() => _selectedStatusFilter = null),
                          ),
                      ],
                    ),
                  ),

                // 4. Asset List
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : _buildAssetList(filtered),
                ),
              ],
            );
          },
        ),
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
                Text('Filter Inventory', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Type Filter
                const Text('Asset Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All Types'),
                      selected: _selectedTypeFilter == null,
                      onSelected: (val) => setState(() => _selectedTypeFilter = null),
                    ),
                    ...AssetType.values.map((type) {
                      return ChoiceChip(
                        label: Text(type.name.toUpperCase()),
                        selected: _selectedTypeFilter == type,
                        onSelected: (val) => setState(() => _selectedTypeFilter = val ? type : null),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                // Status Filter
                const Text('Asset Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All Statuses'),
                      selected: _selectedStatusFilter == null,
                      onSelected: (val) => setState(() => _selectedStatusFilter = null),
                    ),
                    ...AssetStatus.values.map((st) {
                      return ChoiceChip(
                        label: Text(st.name.toUpperCase()),
                        selected: _selectedStatusFilter == st,
                        onSelected: (val) => setState(() => _selectedStatusFilter = val ? st : null),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Center(child: Text('Apply Filter', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssetList(List<AssetModel> assets) {
    if (assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, color: Theme.of(context).disabledColor, size: 48),
            const SizedBox(height: 16),
            Text('No matching assets found in this scope.', style: TextStyle(color: Theme.of(context).disabledColor)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final asset = assets[index];
        return AssetCard(
          asset: asset,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssetDetailPage(assetId: asset.id),
              ),
            );
          },
        ).animate(delay: (index * 40).ms).fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0);
      },
    );
  }
}
