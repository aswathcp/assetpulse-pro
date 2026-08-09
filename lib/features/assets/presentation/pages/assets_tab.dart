// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/home/presentation/widgets/custom_app_bar.dart';
import '../../../../core/services/firestore_service.dart';
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

class AssetsTab extends StatefulWidget {
  const AssetsTab({super.key});

  @override
  State<AssetsTab> createState() => _AssetsTabState();
}

class _AssetsTabState extends State<AssetsTab> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  bool _isManagingAssets = false;
  bool _showHelp = false;

  String _filterStatus = 'All';
  String _filterType = 'All';
  String _filterCriticality = 'All';

  bool get _hasActiveFilters => _filterStatus != 'All' || _filterType != 'All' || _filterCriticality != 'All';

  List<AssetModel> _assets = [];

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

    await _fetchAssets();
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

  Future<void> _fetchAssets() async {
    if (_selectedPlantId == null || _selectedUnitId == null) return;
    try {
      final snap = await _firestore.collection('assets').get();
      final prefix = '$_selectedPlantId-$_selectedUnitId-';

      final list = snap.docs
          .map((d) => AssetModel.fromMap(d.data(), d.id))
          .where((a) => a.id.startsWith(prefix) || a.tagNo.startsWith(prefix))
          .toList();

      if (mounted) {
        setState(() {
          _assets = list;
        });
      }
    } catch (e) {
      debugPrint('Error fetching assets: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AssetModel> get _filteredAssets {
    final query = _searchController.text.trim().toLowerCase();
    return _assets.where((a) {
      if (_filterStatus != 'All') {
        final normalizedStatus = _filterStatus.toLowerCase().replaceAll(' ', '');
        if (a.status.name.toLowerCase() != normalizedStatus) return false;
      }
      if (_filterType != 'All') {
        if (a.type.name.toLowerCase() != _filterType.toLowerCase()) return false;
      }
      if (_filterCriticality == 'Critical Only' && !a.isCritical) return false;
      if (_filterCriticality == 'Standard Only' && a.isCritical) return false;

      if (query.isEmpty) return true;
      return a.tagNo.toLowerCase().contains(query) ||
          a.name.toLowerCase().contains(query) ||
          a.serialNo.toLowerCase().contains(query) ||
          a.make.toLowerCase().contains(query) ||
          a.model.toLowerCase().contains(query) ||
          (a.rfidTag?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        String tempStatus = _filterStatus;
        String tempType = _filterType;
        String tempCrit = _filterCriticality;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter Asset Inventory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempStatus = 'All';
                            tempType = 'All';
                            tempCrit = 'All';
                          });
                        },
                        child: const Text('Reset All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: tempStatus,
                    decoration: const InputDecoration(labelText: 'Operational Status', border: OutlineInputBorder(), isDense: true),
                    items: ['All', 'Active', 'Spare', 'Under Maintenance', 'Scrapped']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) => setModalState(() => tempStatus = v!),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: tempType,
                    decoration: const InputDecoration(labelText: 'Asset Classification', border: OutlineInputBorder(), isDense: true),
                    items: ['All', 'Motor', 'Gearbox', 'Pump']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) => setModalState(() => tempType = v!),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: tempCrit,
                    decoration: const InputDecoration(labelText: 'Asset Criticality', border: OutlineInputBorder(), isDense: true),
                    items: ['All', 'Critical Only', 'Standard Only']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) => setModalState(() => tempCrit = v!),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _filterStatus = tempStatus;
                        _filterType = tempType;
                        _filterCriticality = tempCrit;
                      });
                      Navigator.pop(modalCtx);
                    },
                    child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- KPI STATS ---
  int get _totalAssets => _assets.length;
  int get _activeCount => _assets.where((a) => a.status == AssetStatus.active).length;
  int get _maintenanceCount => _assets.where((a) => a.status == AssetStatus.underMaintenance || a.isCritical).length;
  int get _spareCount => _assets.where((a) => a.status == AssetStatus.spare).length;
  double get _activeRate => _totalAssets == 0 ? 0.0 : (_activeCount / _totalAssets) * 100;

  // --- EXCEL REPORT EXPORT ---
  Future<void> _exportExcelReport() async {
    if (_selectedPlantId == null || _selectedUnitId == null) return;

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

      for (var a in _filteredAssets) {
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
        final savedPath = await downloadFile(bytes, fileName);
        if (savedPath != null && mounted) {
          _handleSavedFile(savedPath, fileName);
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

  // --- PDF REPORT EXPORT ---
  Future<void> _exportPdfReport() async {
    if (_selectedPlantId == null || _selectedUnitId == null) return;

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('VEDANTA IRON & STEEL LTD - ASSET REGISTRY REPORT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Plant: $_selectedPlantId | Unit: $_selectedUnitId | Generated: ${DateTime.now().toLocal().toString().split('.').first}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text('ISO 55000 ASSET PULSE PRO', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Tag No', 'Equipment Name', 'Type', 'Status', 'Make', 'Model', 'Serial No', 'Power (kW)', 'RFID Tag', 'Critical'],
              data: _filteredAssets.map((a) => [
                a.tagNo,
                a.name,
                a.type.name.toUpperCase(),
                a.status.name.toUpperCase(),
                a.make,
                a.model,
                a.serialNo,
                a.powerKw?.toString() ?? '-',
                a.rfidTag ?? '-',
                a.isCritical ? 'YES' : 'NO',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.all(4),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final fileName = 'Asset_Report_${_selectedPlantId}_${_selectedUnitId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final savedPath = await downloadFile(bytes, fileName);
      if (savedPath != null && mounted) {
        _handleSavedFile(savedPath, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF generation failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _handleSavedFile(String path, String fileName) {
    if (!mounted) return;

    final bool isPublic = path.contains('/storage/emulated/0/Download/Assetpulse-pro');
    final String locationMessage = isPublic
        ? 'Saved to Internal Storage: Download/Assetpulse-pro/$fileName'
        : 'Saved to Application Storage: $fileName';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.file_download_done, color: Colors.greenAccent, size: 24),
              SizedBox(width: 10),
              Text('Report Exported', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(locationMessage, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 12),
              const Text('Would you like to open or share this file?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close', style: TextStyle(color: Colors.grey)),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.share, size: 16),
              label: const Text('Share'),
              onPressed: () {
                Navigator.pop(dialogCtx);
                Share.shareXFiles([XFile(path)], text: 'Asset Inventory Export: $fileName');
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white),
              label: const Text('Open', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(dialogCtx);
                OpenFile.open(path);
              },
            ),
          ],
        );
      },
    );
  }

  // --- SKELETON SHIMMER LOADER (ZERO CLS) ---
  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // 1. Shimmer Scope Box
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),

          // 2. Shimmer Stats Card
          Container(
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),

          // 3. Shimmer Search & Action Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),

          // 4. Shimmer Cards
          ...List.generate(4, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08));
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CustomAppBar(title: 'Asset Inventory'),
        body: _buildSkeletonLoader(),
      );
    }

    if (_isManagingAssets) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CustomAppBar(title: 'Asset Inventory'),
        body: _buildManageAssetsView(),
      );
    }

    if (_showHelp) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CustomAppBar(title: 'Asset Inventory'),
        body: _buildHelpView(),
      );
    }

    final filtered = _filteredAssets;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Asset Inventory'),
      body: ResponsiveContentWrapper(
        maxWidth: 1320,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Signature Scope Selectors Box (Matching Lux Checklist & Panel Room)
              GlassContainer(
                borderRadius: 16,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedPlantId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Select Plant', border: OutlineInputBorder()),
                          items: _plants
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: _isPlantLocked
                              ? null
                              : (val) async {
                                  if (val != null) {
                                    setState(() {
                                      _selectedPlantId = val;
                                      _updateUnitList();
                                      _isLoading = true;
                                    });
                                    await _fetchAssets();
                                    if (mounted) setState(() => _isLoading = false);
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedUnitId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Select Unit', border: OutlineInputBorder()),
                          items: _units
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: _isUnitLocked
                              ? null
                              : (val) async {
                                  if (val != null) {
                                    setState(() {
                                      _selectedUnitId = val;
                                      _isLoading = true;
                                    });
                                    await _fetchAssets();
                                    if (mounted) setState(() => _isLoading = false);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 16),

              // 2. Metrics Overview Dashboard Card (Matching Screenshot)
              GlassContainer(
                borderRadius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Asset Inventory Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _activeRate >= 80.0 ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_activeRate.toStringAsFixed(1)}%',
                              style: TextStyle(fontWeight: FontWeight.bold, color: _activeRate >= 80.0 ? Colors.greenAccent : Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Total Assets', '$_totalAssets', Colors.white),
                          _buildStatItem('Active / Healthy', '$_activeCount', Colors.greenAccent),
                          _buildStatItem('Maintenance / Critical', '$_maintenanceCount', Colors.redAccent),
                          _buildStatItem('Spares', '$_spareCount', Colors.orangeAccent),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 350.ms),
              const SizedBox(height: 16),

              // 3. Search Bar & Filter [tune] / Help [?] / Settings [gear] Buttons
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search tag, name or ID...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: _hasActiveFilters ? AppColors.accent : AppColors.primary,
                        ),
                        icon: const Icon(Icons.tune, color: Colors.white),
                        tooltip: 'Filter Asset Inventory',
                        onPressed: _showFilterModal,
                      ),
                      if (_hasActiveFilters)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                    icon: const Icon(Icons.help_outline, color: Colors.white),
                    tooltip: 'Asset Hierarchy Guide',
                    onPressed: () => setState(() => _showHelp = true),
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(width: 4),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                      icon: const Icon(Icons.settings, color: Colors.white),
                      tooltip: 'Manage Assets in Database',
                      onPressed: () => setState(() => _isManagingAssets = true),
                    ),
                  ],
                ],
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 16),

              // 4. Header Row with Title & Excel / PDF Action Buttons (RCCB / Lux Style)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Assets (${filtered.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _exportExcelReport,
                        icon: const Icon(Icons.table_chart, size: 16, color: Colors.greenAccent),
                        label: const Text('Excel', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: _exportPdfReport,
                        icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.redAccent),
                        label: const Text('PDF Report', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 5. Asset Cards List
              filtered.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.inbox, color: Colors.grey, size: 48),
                          SizedBox(height: 12),
                          Text('No matching assets found in this scope.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final asset = filtered[index];
                        return AssetCard(
                          asset: asset,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AssetDetailPage(asset: asset),
                              ),
                            ).then((_) => _fetchAssets());
                          },
                        ).animate(delay: (index * 30).ms).fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0);
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MANAGE ASSETS VIEW (MATCHING LUX LEVEL CHECKLIST SETTINGS) ---
  Widget _buildManageAssetsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _isManagingAssets = false),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Manage Asset Registry',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons: Add New & Import Excel
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add New Asset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      ).then((_) => _fetchAssets());
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                    foregroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DataImportPage(
                          collectionId: 'assets',
                          title: 'Asset Inventory',
                          plantId: _selectedPlantId,
                          unitId: _selectedUnitId,
                        ),
                      ),
                    );
                    await _fetchAssets();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Asset List with Edit & Delete Actions
          _assets.isEmpty
              ? const Center(child: Text('No assets registered in this scope. Add one above!'))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _assets.length,
                  itemBuilder: (context, idx) {
                    final a = _assets[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text('${a.tagNo} - ${a.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Type: ${a.type.name.toUpperCase()} | Status: ${a.status.name.toUpperCase()}\nMake: ${a.make} | Model: ${a.model} | Serial: ${a.serialNo}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.amberAccent, size: 20),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddEditAssetPage(asset: a),
                                  ),
                                ).then((_) => _fetchAssets());
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                              onPressed: () => _confirmDeleteSingleAsset(a),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  void _confirmDeleteSingleAsset(AssetModel a) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete Asset'),
          content: Text('Are you sure you want to permanently delete asset "${a.tagNo} (${a.name})"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _firestore.collection('assets').doc(a.id).delete();
                await _fetchAssets();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Asset ${a.tagNo} deleted successfully')),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- HELP VIEW ---
  Widget _buildHelpView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showHelp = false),
              ),
              const SizedBox(width: 8),
              const Text('Asset Registry & ISO 55000 Guide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          GlassContainer(
            borderRadius: 16,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Asset Naming & Hierarchy Taxonomy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accent)),
                  SizedBox(height: 8),
                  Text('• Tag ID Standard: [PLANT]-[UNIT]-[TYPE]-[SEQ] (e.g. IOG-COD-MTR-001)\n• MTR = Motors | GBX = Gearboxes | PMP = Pumps\n• Sequence numbers auto-generate with next available 3-digit number.', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 14),
                  Text('Spare Pooling Architecture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accent)),
                  SizedBox(height: 8),
                  Text('• Spare assets can be linked to multiple compatible parent machines.\n• Unique Tag IDs ensure field replacements never overwrite historical records.', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 14),
                  Text('Direct In-Situ NFC Scanning', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accent)),
                  SizedBox(height: 8),
                  Text('• Tap "Scan NFC" on the registration form to capture high-frequency RFID tags directly into the asset identity without leaving the form.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
