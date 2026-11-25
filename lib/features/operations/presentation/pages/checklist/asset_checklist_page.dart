// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/widgets/glass_container.dart';
import 'package:asset_pulse_pro/core/widgets/responsive_layout.dart';
import 'package:asset_pulse_pro/core/widgets/pulse_loading.dart';
import 'package:asset_pulse_pro/core/utils/file_download_helper.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:asset_pulse_pro/features/home/presentation/widgets/custom_app_bar.dart';
import 'package:asset_pulse_pro/features/assets/data/models/asset_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/health_log_model.dart';
import 'package:asset_pulse_pro/features/assets/presentation/pages/asset_detail_page.dart';
import 'package:asset_pulse_pro/features/assets/presentation/pages/log_diagnostic_test_page.dart';
import 'package:asset_pulse_pro/core/utils/permission_helper.dart';
import 'asset_certification_tag_pdf_helper.dart';

class AssetChecklistPage extends StatefulWidget {
  const AssetChecklistPage({super.key});

  @override
  State<AssetChecklistPage> createState() => _AssetChecklistPageState();
}

class _AssetChecklistPageState extends State<AssetChecklistPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  // Hierarchy & Scope
  UserScope? _userScope;
  String? _selectedPlantId;
  String? _selectedUnitId;
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  bool _isLoading = true;

  // Filters
  String _filterStatus = 'All'; // All, Spares, Maintenance, Active, Certified, Pending, Overdue, Warning
  String _filterType = 'All'; // All, Motor, Gearbox, Pump, Brake, Actuator

  // Multi-Selection for Tag Printing
  final Set<String> _selectedAssetIds = {};
  bool _isSelectionMode = false;

  // Assets Cache
  List<AssetModel> _allAssets = [];

  @override
  void initState() {
    super.initState();
    _loadHierarchyAndScope();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHierarchyAndScope() async {
    setState(() => _isLoading = true);
    try {
      final user = AuthService().currentUser;
      Map<String, dynamic>? profile;
      if (user != null) {
        profile = await FirestoreService().getUserProfile(user.uid);
      }

      final userBusinessId = profile?['businessId'] as String? ?? 'VISL';
      await HierarchyService().init(businessId: userBusinessId);

      final allPlants = HierarchyService().getPlants();
      final userScope = PermissionHelper.resolveUserScope(profile);
      _userScope = userScope;
      _plants = userScope.getAvailablePlants(allPlants);
      _isPlantLocked = userScope.isPlantLocked;
      _isUnitLocked = userScope.isUnitLocked;

      _selectedPlantId = userScope.getInitialPlant(null, _plants);
      if (_selectedPlantId != null) {
        final allUnits = HierarchyService().getUnitsForPlant(_selectedPlantId!);
        _units = userScope.getAvailableUnits(_selectedPlantId, allUnits);
        _selectedUnitId = userScope.getInitialUnit(_selectedPlantId, null, _units);
      } else {
        _units = [];
        _selectedUnitId = null;
      }

      await _fetchAssets();
    } catch (e) {
      debugPrint('Error initializing AssetChecklistPage: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAssets() async {
    try {
      final snapshot = await _firestore.collection('assets').get();
      final loaded = snapshot.docs.map((doc) => AssetModel.fromMap(doc.data(), doc.id)).toList();

      if (mounted) {
        setState(() {
          _allAssets = loaded;
        });
      }
    } catch (e) {
      debugPrint('Error fetching assets: $e');
    }
  }

  void _onPlantChanged(String? newPlant) {
    if (newPlant == null || _isPlantLocked) return;
    setState(() {
      _selectedPlantId = newPlant;
      final allUnits = HierarchyService().getUnitsForPlant(newPlant);
      if (_userScope != null) {
        _units = _userScope!.getAvailableUnits(newPlant, allUnits);
        _selectedUnitId = _userScope!.getInitialUnit(newPlant, null, _units);
      } else {
        _units = allUnits;
        _selectedUnitId = _units.isNotEmpty ? _units.first : null;
      }
      _selectedAssetIds.clear();
    });
  }

  void _onUnitChanged(String? newUnit) {
    if (newUnit == null || _isUnitLocked) return;
    setState(() {
      _selectedUnitId = newUnit;
      _selectedAssetIds.clear();
    });
  }

  // --- HEALTH & DUE DATE CALCULATION (6-MONTH CYCLE) ---
  bool _isAssetCertified(AssetModel asset) {
    final lastTest = asset.lastServiceDate ?? asset.lastPulseTime;
    if (lastTest == null) return false;
    final cutoff = DateTime.now().subtract(const Duration(days: 180));
    return lastTest.isAfter(cutoff) && asset.healthStatus == AssetHealthStatus.healthy;
  }

  bool _isAssetPending(AssetModel asset) {
    final nextDue = asset.nextServiceDue ?? asset.lastServiceDate?.add(const Duration(days: 180));
    if (nextDue == null) return false;
    final now = DateTime.now();
    final daysRemaining = nextDue.difference(now).inDays;
    return daysRemaining >= 0 && daysRemaining <= 30;
  }

  bool _isAssetOverdue(AssetModel asset) {
    final lastTest = asset.lastServiceDate ?? asset.lastPulseTime;
    if (lastTest == null) return true; // Never tested
    final nextDue = asset.nextServiceDue ?? lastTest.add(const Duration(days: 180));
    return DateTime.now().isAfter(nextDue);
  }

  bool _isAssetWarningOrCritical(AssetModel asset) {
    return asset.healthStatus == AssetHealthStatus.warning || asset.healthStatus == AssetHealthStatus.critical;
  }

  // Assets in selected Plant & Unit Scope
  List<AssetModel> get _scopedAssets {
    return _allAssets.where((asset) {
      if (_selectedPlantId != null && _selectedPlantId!.isNotEmpty) {
        if (_selectedUnitId != null && _selectedUnitId!.isNotEmpty) {
          final prefix = '${_selectedPlantId!}-${_selectedUnitId!}';
          if (!asset.tagNo.startsWith(prefix) && !asset.masterEquipmentId.startsWith(prefix)) {
            return false;
          }
        } else {
          if (!asset.tagNo.startsWith(_selectedPlantId!) && !asset.masterEquipmentId.startsWith(_selectedPlantId!)) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  // Filtered Assets Pipeline
  List<AssetModel> get _filteredAssets {
    final query = _searchController.text.trim().toLowerCase();

    return _scopedAssets.where((asset) {
      final isSpare = asset.status == AssetStatus.spare;
      final isUnderMaintenance = asset.status == AssetStatus.underMaintenance;
      final isActive = asset.status == AssetStatus.active;

      // 1. Type Filter
      if (_filterType != 'All') {
        if (asset.type.name.toLowerCase() != _filterType.toLowerCase()) {
          return false;
        }
      }

      // 2. Status Filter
      if (_filterStatus == 'Spares') {
        if (!isSpare) return false;
      } else if (_filterStatus == 'Under Maintenance') {
        if (!isUnderMaintenance) return false;
      } else if (_filterStatus == 'Active Fleet') {
        if (!isActive) return false;
      } else if (_filterStatus == 'Certified') {
        if (!_isAssetCertified(asset)) return false;
      } else if (_filterStatus == 'Pending') {
        if (!_isAssetPending(asset)) return false;
      } else if (_filterStatus == 'Overdue') {
        if (!_isAssetOverdue(asset)) return false;
      } else if (_filterStatus == 'Warning / Critical') {
        if (!_isAssetWarningOrCritical(asset)) return false;
      }

      // 3. Search Filter
      if (query.isNotEmpty) {
        final matchesTag = asset.tagNo.toLowerCase().contains(query);
        final matchesName = asset.name.toLowerCase().contains(query);
        final matchesMake = asset.make.toLowerCase().contains(query);
        final matchesModel = asset.model.toLowerCase().contains(query);
        final matchesSerial = asset.serialNo.toLowerCase().contains(query);
        final matchesLocation = (asset.spareLocation ?? '').toLowerCase().contains(query);
        final matchesParent = asset.masterEquipmentId.toLowerCase().contains(query);
        return matchesTag || matchesName || matchesMake || matchesModel || matchesSerial || matchesLocation || matchesParent;
      }

      return true;
    }).toList();
  }

  // --- STATS METRICS (SCOPED) ---
  int get _totalScopedCount => _scopedAssets.length;
  int get _spareCount => _scopedAssets.where((a) => a.status == AssetStatus.spare).length;
  int get _maintCount => _scopedAssets.where((a) => a.status == AssetStatus.underMaintenance).length;
  int get _activeCount => _scopedAssets.where((a) => a.status == AssetStatus.active).length;
  int get _spareCertifiedCount => _scopedAssets.where((a) => a.status == AssetStatus.spare && _isAssetCertified(a)).length;
  int get _sparePendingCount => _scopedAssets.where((a) => a.status == AssetStatus.spare && _isAssetPending(a)).length;
  int get _spareOverdueCount => _scopedAssets.where((a) => a.status == AssetStatus.spare && _isAssetOverdue(a)).length;
  int get _warningCount => _scopedAssets.where((a) => _isAssetWarningOrCritical(a)).length;

  double get _spareComplianceRate {
    if (_spareCount == 0) return 100.0;
    return (_spareCertifiedCount / _spareCount) * 100.0;
  }

  // --- PRINT CERTIFICATION TAGS (2x3 A4 PDF) ---
  Future<void> _printCertificationTags({List<AssetModel>? specificAssets}) async {
    final targets = specificAssets ?? _filteredAssets.where((a) => _selectedAssetIds.contains(a.id)).toList();

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one asset to generate certification tags.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Generating ${targets.length} Tags (2x3 A4 Grid)...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final pdf = await AssetCertificationTagPdfHelper.generateCertificationTagsPdf(
        assets: targets,
        plantName: _selectedPlantId,
        unitName: _selectedUnitId,
      );

      final fileName = 'Asset_Certification_Tags_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final bytes = await pdf.save();
      final path = await downloadFile(bytes, fileName);

      if (path != null && mounted) {
        _handleSavedFile(path, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating certification tags: $e'), backgroundColor: AppColors.error),
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
              Icon(Icons.verified, color: Colors.greenAccent, size: 24),
              SizedBox(width: 10),
              Text('Tags Exported Successfully', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(locationMessage, style: TextStyle(fontSize: 12, color: Theme.of(dialogCtx).colorScheme.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 12),
              const Text('Would you like to open or share this printable PDF?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                Share.shareXFiles([XFile(path)], text: 'Asset Certification Tags - 6 Months Periodic QA');
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white),
              label: const Text('Open PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // --- EXCEL SUMMARY EXPORT ---
  Future<void> _exportExcelSummary() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Asset_Checklist_Report'];
      excel.setDefaultSheet('Asset_Checklist_Report');

      sheet.appendRow([
        TextCellValue('VEDANTA IRON & STEEL - ASSET HEALTH & QA CHECKLIST REPORT'),
      ]);
      sheet.appendRow([
        TextCellValue('Exported Date: ${DateTime.now()}'),
        TextCellValue('Plant: ${_selectedPlantId ?? "All"}'),
        TextCellValue('Unit: ${_selectedUnitId ?? "All"}'),
      ]);
      sheet.appendRow([TextCellValue('')]);

      sheet.appendRow([
        TextCellValue('Tag No'),
        TextCellValue('Asset Name'),
        TextCellValue('Type'),
        TextCellValue('Pool Status'),
        TextCellValue('Health Status'),
        TextCellValue('Storage Bay / Location'),
        TextCellValue('Assigned Parent Machine'),
        TextCellValue('Make'),
        TextCellValue('Model'),
        TextCellValue('Serial No'),
        TextCellValue('Last Tested Date'),
        TextCellValue('6-Month Next Due Date'),
        TextCellValue('Certification State'),
        TextCellValue('Power (kW)'),
        TextCellValue('Voltage (V)'),
        TextCellValue('FLC (A)'),
        TextCellValue('Inspector / Tested By'),
      ]);

      final assets = _filteredAssets;
      for (var a in assets) {
        final lastTest = a.lastServiceDate ?? a.lastPulseTime;
        final nextDue = a.nextServiceDue ?? a.lastServiceDate?.add(const Duration(days: 180));
        final isCert = _isAssetCertified(a);
        final isOver = _isAssetOverdue(a);
        final certState = isCert
            ? 'CERTIFIED (VALID)'
            : isOver
                ? 'OVERDUE / EXPIRED'
                : 'PENDING / DUE SOON';

        sheet.appendRow([
          TextCellValue(a.tagNo),
          TextCellValue(a.name),
          TextCellValue(a.type.name.toUpperCase()),
          TextCellValue(a.status.name.toUpperCase()),
          TextCellValue(a.healthStatus.name.toUpperCase()),
          TextCellValue(a.spareLocation ?? 'Warehouse'),
          TextCellValue(a.masterEquipmentId.isNotEmpty ? a.masterEquipmentId : 'Standalone'),
          TextCellValue(a.make),
          TextCellValue(a.model),
          TextCellValue(a.serialNo),
          TextCellValue(lastTest?.toString().split(' ')[0] ?? 'Never Tested'),
          TextCellValue(nextDue?.toString().split(' ')[0] ?? 'N/A'),
          TextCellValue(certState),
          TextCellValue(a.powerKw != null ? a.powerKw.toString() : '-'),
          TextCellValue(a.voltage != null ? a.voltage.toString() : '-'),
          TextCellValue(a.fullLoadCurrent != null ? a.fullLoadCurrent.toString() : '-'),
          TextCellValue(a.modifiedBy ?? a.createdBy ?? 'QC Tech'),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final fileName = 'Asset_Health_Checklist_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final path = await downloadFile(fileBytes, fileName);
        if (path != null && mounted) {
          _handleSavedFile(path, fileName);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exporting excel: $e')));
      }
    }
  }

  void _showHelpGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.help_outline, color: Colors.cyanAccent, size: 24),
              SizedBox(width: 10),
              Text('Asset Checklist Guide', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('6-Month Periodic Health Certification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                const Text(
                  '• Spare Assets: Must undergo periodic health checkups every 6 months (180 days) to ensure zero failure upon emergency replacement.\n'
                  '• Active Fleet: Continuous operating assets. 6-month recertification is optional.\n'
                  '• Maintenance Assets: Move to spare pool upon logging a healthy test and passing QC certification.\n'
                  '• History: Tap the history icon on any card to view its complete past test log records.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                const Text('Test Verification Standards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                const Text(
                  '• Insulation Resistance (IR): Minimum 5 MΩ (> 50 MΩ recommended for certified tags).\n'
                  '• Winding Resistance: Phase-to-phase deviation < 2% balance.\n'
                  '• Vibration: ISO 10816 Zone A/B (< 2.3 mm/s RMS).',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- HEALTH TEST HISTORY MODAL (DETAILED RECORDS) ---
  void _showAssetHealthHistoryModal(AssetModel asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history_rounded, color: Colors.amberAccent, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${asset.tagNo} History',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  asset.status.name.toUpperCase(),
                                  style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            asset.name.isNotEmpty ? asset.name : '${asset.type.name.toUpperCase()} Asset',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),

              // History Stream List
              Expanded(
                child: StreamBuilder<List<HealthLogModel>>(
                  stream: FirestoreService().getHealthLogsStream(asset.id, tagNo: asset.tagNo),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: PulseLoading(size: 44));
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text('Error loading history: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                        ),
                      );
                    }

                    final logs = snapshot.data ?? [];
                    if (logs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off_rounded, size: 52, color: Theme.of(context).disabledColor),
                            const SizedBox(height: 14),
                            const Text('No Diagnostic Test Logs Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 6),
                            Text(
                              'No periodic health tests have been recorded for ${asset.tagNo} yet.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                              icon: const Icon(Icons.add_chart, size: 16, color: Colors.white),
                              label: const Text('Record Health Test Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.pop(sheetCtx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => LogDiagnosticTestPage(asset: asset)),
                                ).then((_) => _fetchAssets());
                              },
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return _buildHealthHistoryCard(log, asset, index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHealthHistoryCard(HealthLogModel log, AssetModel asset, int index) {
    final bool isHealthy = log.healthStatus == 'healthy';
    final bool isWarning = log.healthStatus == 'warning';
    final Color statusColor = isHealthy
        ? Colors.greenAccent
        : isWarning
            ? Colors.orangeAccent
            : Colors.redAccent;
    final String statusLabel = isHealthy
        ? 'CERTIFIED (PASS)'
        : isWarning
            ? 'ATTENTION REQUIRED'
            : 'CRITICAL DEFECT';

    final DateTime testDate = log.testDate;
    final DateTime validUntil = testDate.add(const Duration(days: 180));
    final String dateStr = "${testDate.year}-${_twoDigits(testDate.month)}-${_twoDigits(testDate.day)} ${_twoDigits(testDate.hour)}:${_twoDigits(testDate.minute)}";
    final String validUntilStr = "${validUntil.year}-${_twoDigits(validUntil.month)}-${_twoDigits(validUntil.day)}";

    final irMap = log.insulationResistance ?? {};
    final windingMap = log.windingResistance ?? {};
    final vibMap = log.vibration ?? {};
    final specs = log.specs ?? {};

    return Card(
      color: Theme.of(context).cardColor.withValues(alpha: 0.4),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
          ),
          child: Icon(
            isHealthy
                ? Icons.verified_user_rounded
                : isWarning
                    ? Icons.warning_amber_rounded
                    : Icons.gpp_bad_rounded,
            color: statusColor,
            size: 17,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                dateStr,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Tested by: ${log.testedBy.isNotEmpty ? log.testedBy : "QC Tech"}  •  Valid: $validUntilStr',
          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 12),

                // 1. Motor Electrical Details
                if (asset.type == AssetType.motor) ...[
                  const Text('Electrical Test Measurements:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.cyanAccent)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text('IR Lowest: ${irMap['lowest'] ?? irMap['R-E'] ?? "N/A"} MΩ', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            Text('No-Load I: ${log.noLoadCurrent != null ? "${log.noLoadCurrent} A" : "N/A"}', style: const TextStyle(fontSize: 10.5)),
                            Text('PI: ${log.polarizationIndex ?? "N/A"}', style: const TextStyle(fontSize: 10.5)),
                          ],
                        ),
                        if (irMap.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'IR P-P: R-Y: ${irMap['R-Y'] ?? "-"} | Y-B: ${irMap['Y-B'] ?? "-"} | B-R: ${irMap['B-R'] ?? "-"} MΩ',
                            style: const TextStyle(fontSize: 9.5, color: Colors.white70),
                          ),
                          Text(
                            'IR P-E: R-E: ${irMap['R-E'] ?? "-"} | Y-E: ${irMap['Y-E'] ?? "-"} | B-E: ${irMap['B-E'] ?? "-"} MΩ',
                            style: const TextStyle(fontSize: 9.5, color: Colors.white70),
                          ),
                        ],
                        if (windingMap.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Winding Res: R-Y: ${windingMap['R-Y'] ?? "-"} | Y-B: ${windingMap['Y-B'] ?? "-"} | R-B: ${windingMap['R-B'] ?? "-"} Ω',
                            style: const TextStyle(fontSize: 9.5, color: Colors.white70),
                          ),
                        ],
                        if (specs['fanCondition'] != null || specs['shaftRotation'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Visual/Mech: Fan: ${specs['fanCondition'] ?? "OK"} | Shaft: ${specs['shaftRotation'] ?? "Smooth"}',
                            style: const TextStyle(fontSize: 9.5, color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // 2. Gearbox Details
                if (asset.type == AssetType.gearbox) ...[
                  const Text('Gearbox Inspection Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.cyanAccent)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text('Backlash: ${specs['backlash'] ?? "Normal"} mm', style: const TextStyle(fontSize: 10.5)),
                            Text('Sump Temp: ${specs['sumpTemp'] ?? "Normal"} °C', style: const TextStyle(fontSize: 10.5)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('Oil Quality: ${specs['oilLevelQuality'] ?? "Clean"} | Seal: ${specs['oilSeal'] ?? "Zero Leak"}', style: const TextStyle(fontSize: 9.5, color: Colors.white70)),
                        Text('Mesh: ${specs['toothContact'] ?? "Normal"} | Rotation: ${specs['shaftRotation'] ?? "Smooth"}', style: const TextStyle(fontSize: 9.5, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // 3. Pump Details
                if (asset.type == AssetType.pump) ...[
                  const Text('Pump Hydraulic & Seal Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.cyanAccent)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text('Head: ${specs['head'] ?? "Normal"} m', style: const TextStyle(fontSize: 10.5)),
                            Text('Press: ${specs['dischargePressure'] ?? "Normal"} Bar', style: const TextStyle(fontSize: 10.5)),
                            Text('Flow: ${specs['flowRate'] ?? "Normal"} m3/h', style: const TextStyle(fontSize: 10.5)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('Seal Condition: ${specs['sealStatus'] ?? "Zero Leak"} | Noise: ${specs['impellerNoise'] ?? "Silent"}', style: const TextStyle(fontSize: 9.5, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // 4. Brake Details
                if (asset.type == AssetType.brake) ...[
                  const Text('Brake & Thruster Test Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.cyanAccent)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text('Stroke: ${specs['stroke'] ?? "Normal"} mm', style: const TextStyle(fontSize: 10.5)),
                            Text('Lining: ${specs['lining'] ?? "Normal"} mm', style: const TextStyle(fontSize: 10.5)),
                            Text('Torque: ${specs['torque'] ?? "Normal"} Nm', style: const TextStyle(fontSize: 10.5)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('Drum Gap: ${specs['drumClearance'] ?? "0.8"} mm | Holding: ${specs['holdingTest'] ?? "Pass"}', style: const TextStyle(fontSize: 9.5, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // 5. Actuator Details
                if (asset.type == AssetType.actuator) ...[
                  const Text('Actuator & Limit Test Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.cyanAccent)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text('Torque: ${specs['torque'] ?? "Normal"} Nm', style: const TextStyle(fontSize: 10.5)),
                            Text('Travel: ${specs['travelTime'] ?? "Normal"} s', style: const TextStyle(fontSize: 10.5)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('Feedback: ${specs['feedbackSignal'] ?? "4-20mA Linear"} | Limit: ${specs['limitSwitch'] ?? "Pass"}', style: const TextStyle(fontSize: 9.5, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // 6. Vibration Details
                if (vibMap.isNotEmpty) ...[
                  const Text('Vibration (ISO 10816 Velocity mm/s):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.cyanAccent)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text('Peak: ${vibMap['peak'] ?? "Normal"} mm/s', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        Text('DE: ${vibMap['DE_H'] ?? "-"}/${vibMap['DE_V'] ?? "-"}', style: const TextStyle(fontSize: 10)),
                        Text('NDE: ${vibMap['NDE_H'] ?? "-"}/${vibMap['NDE_V'] ?? "-"}', style: const TextStyle(fontSize: 10)),
                        Text('G: ${vibMap['G_Value'] ?? "-"} g', style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // 7. Inspector Remarks
                if (log.remarks.isNotEmpty) ...[
                  const Text('Remarks & Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.cyanAccent)),
                  const SizedBox(height: 3),
                  Text(log.remarks, style: const TextStyle(fontSize: 10.5, color: Colors.white70, height: 1.3)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SKELETON SHIMMER VIEW ---
  Widget _buildSkeletonShimmerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1100.ms, color: Colors.white.withValues(alpha: 0.09)),
          const SizedBox(height: 16),

          Container(
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1100.ms, color: Colors.white.withValues(alpha: 0.09)),
          const SizedBox(height: 16),

          ...List.generate(5, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 1100.ms, color: Colors.white.withValues(alpha: 0.09));
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAssets;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Asset Checklist'),
      body: _isLoading
          ? _buildSkeletonShimmerView()
          : ResponsiveContentWrapper(
              maxWidth: 1380,
              child: RefreshIndicator(
                onRefresh: _fetchAssets,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Scope Selector (Lux Checklist Design)
                      _buildLuxStyleScopeSelector()
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: -0.1, end: 0),
                      const SizedBox(height: 16),

                      // 2. Overview Metrics Card (Lux Checklist Design)
                      _buildOverviewMetricsCard()
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1)),
                      const SizedBox(height: 16),

                      // 3. Search & Manage Action Row (Lux Checklist Design)
                      _buildSearchAndManageRow()
                          .animate()
                          .fadeIn(duration: 450.ms),
                      const SizedBox(height: 16),

                      // 4. Header Row with Title & Excel / PDF Action Buttons
                      _buildSectionHeader(filtered.length)
                          .animate()
                          .fadeIn(duration: 480.ms),
                      const SizedBox(height: 10),

                      // 5. Status Filter Pills
                      _buildStatusFilterPills()
                          .animate()
                          .fadeIn(duration: 500.ms),
                      const SizedBox(height: 12),

                      // 6. Batch Selection Info Bar (When selection mode active)
                      if (_isSelectionMode || _selectedAssetIds.isNotEmpty) ...[
                        _buildSelectionActionBar(filtered)
                            .animate()
                            .fadeIn(duration: 250.ms)
                            .slideY(begin: -0.1, end: 0),
                        const SizedBox(height: 12),
                      ],

                      // 7. Assets Cards List / Grid
                      if (filtered.isEmpty) ...[
                        _buildEmptyState(),
                      ] else if (isDesktop) ...[
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.75,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _buildAssetChecklistCard(filtered[index], index)
                                .animate(delay: (index * 25).ms)
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: 0.05, end: 0);
                          },
                        ),
                      ] else ...[
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _buildAssetChecklistCard(filtered[index], index)
                                .animate(delay: (index * 20).ms)
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: 0.05, end: 0);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: _selectedAssetIds.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.print, color: Colors.white),
              label: Text(
                'Print ${_selectedAssetIds.length} Tags (2x3 A4)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _printCertificationTags(),
            ).animate().scale(curve: Curves.elasticOut)
          : null,
    );
  }

  // --- LUX STYLE COMPACT SCOPE SELECTOR WIDGET ---
  Widget _buildLuxStyleScopeSelector() {
    return GlassContainer(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedPlantId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Select Plant', border: InputBorder.none),
                items: _plants.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _isPlantLocked ? null : _onPlantChanged,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedUnitId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Select Unit', border: InputBorder.none),
                items: _units.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _isUnitLocked ? null : _onUnitChanged,
              ),
            ),
            if (_isPlantLocked || _isUnitLocked) ...[
              const SizedBox(width: 8),
              const Tooltip(
                message: 'Scope locked to your assigned operational post',
                child: Icon(Icons.lock, size: 16, color: Colors.amberAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- OVERVIEW METRICS CARD (MATCHING LUX CHECKLIST) ---
  Widget _buildOverviewMetricsCard() {
    final bool isCompliant = _spareComplianceRate >= 80.0;

    return GlassContainer(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Asset Health & QA Overview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompliant ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_spareComplianceRate.toStringAsFixed(1)}% Spares Cert.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isCompliant ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total Assets', '$_totalScopedCount', Theme.of(context).colorScheme.onSurface),
                _buildStatItem('Spares Cert.', '$_spareCertifiedCount', Colors.greenAccent),
                _buildStatItem('Due Soon', '$_sparePendingCount', Colors.yellowAccent),
                _buildStatItem('Spares Overdue', '$_spareOverdueCount', Colors.orangeAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  // --- SEARCH & MANAGE ROW (MATCHING LUX CHECKLIST) ---
  Widget _buildSearchAndManageRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tag, name, make, bay, parent eq...',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              isDense: true,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => setState(() => _searchController.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),

        // Type Filter Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterType,
              isDense: true,
              dropdownColor: Theme.of(context).cardColor,
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Types', style: TextStyle(fontSize: 11.5))),
                DropdownMenuItem(value: 'motor', child: Text('Motors ⚡', style: TextStyle(fontSize: 11.5))),
                DropdownMenuItem(value: 'gearbox', child: Text('Gearboxes ⚙️', style: TextStyle(fontSize: 11.5))),
                DropdownMenuItem(value: 'pump', child: Text('Pumps 💧', style: TextStyle(fontSize: 11.5))),
                DropdownMenuItem(value: 'brake', child: Text('Brakes 🛑', style: TextStyle(fontSize: 11.5))),
                DropdownMenuItem(value: 'actuator', child: Text('Actuators 🎛️', style: TextStyle(fontSize: 11.5))),
              ],
              onChanged: (v) => setState(() => _filterType = v ?? 'All'),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Help Button
        IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: AppColors.primary),
          icon: const Icon(Icons.help_outline, color: Colors.white, size: 20),
          tooltip: 'Asset Checklist & QA Standards Guide',
          onPressed: _showHelpGuideDialog,
        ),
        const SizedBox(width: 4),

        // Multi-Select Toggle Button
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: _isSelectionMode ? Colors.cyanAccent : AppColors.primary,
          ),
          icon: Icon(
            _isSelectionMode ? Icons.check_circle : Icons.checklist,
            color: _isSelectionMode ? Colors.black : Colors.white,
            size: 20,
          ),
          tooltip: 'Tag Multi-Select Print Mode',
          onPressed: () {
            setState(() {
              _isSelectionMode = !_isSelectionMode;
              if (!_isSelectionMode) _selectedAssetIds.clear();
            });
          },
        ),
      ],
    );
  }

  // --- SECTION HEADER WITH TITLE & ACTION BUTTONS ---
  Widget _buildSectionHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Asset Registry ($count)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.table_chart, color: Colors.greenAccent, size: 18),
              label: const Text('Excel', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: _exportExcelSummary,
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              icon: const Icon(Icons.print, color: Colors.cyanAccent, size: 18),
              label: const Text('Print Tags (2x3)', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () => _printCertificationTags(specificAssets: _filteredAssets),
            ),
          ],
        ),
      ],
    );
  }

  // --- STATUS FILTER PILLS ---
  Widget _buildStatusFilterPills() {
    final tabs = [
      {'key': 'All', 'label': 'All Assets', 'badge': '$_totalScopedCount'},
      {'key': 'Spares', 'label': 'Spares', 'badge': '$_spareCount'},
      {'key': 'Under Maintenance', 'label': 'Maintenance', 'badge': '$_maintCount'},
      {'key': 'Active Fleet', 'label': 'Active Fleet', 'badge': '$_activeCount'},
      {'key': 'Certified', 'label': 'Certified (6-Mo)', 'badge': '$_spareCertifiedCount'},
      {'key': 'Pending', 'label': 'Due Soon', 'badge': '$_sparePendingCount'},
      {'key': 'Overdue', 'label': 'Overdue', 'badge': '$_spareOverdueCount'},
      {'key': 'Warning / Critical', 'label': 'Attention', 'badge': '$_warningCount'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: tabs.map((t) {
          final isSelected = _filterStatus == t['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t['label']!, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.25) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(t['badge']!, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.4),
              onSelected: (_) => setState(() => _filterStatus = t['key']!),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- SELECTION ACTION BAR ---
  Widget _buildSelectionActionBar(List<AssetModel> filtered) {
    final allSelected = filtered.isNotEmpty && filtered.every((a) => _selectedAssetIds.contains(a.id));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.cyan.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Checkbox(
                value: allSelected,
                activeColor: Colors.cyanAccent,
                checkColor: Colors.black,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedAssetIds.addAll(filtered.map((a) => a.id));
                    } else {
                      _selectedAssetIds.clear();
                    }
                  });
                },
              ),
              Text(
                '${_selectedAssetIds.length} of ${filtered.length} Selected',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.cyanAccent),
              ),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear', style: TextStyle(fontSize: 11)),
                onPressed: () => setState(() => _selectedAssetIds.clear()),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.print, size: 15, color: Colors.white),
                label: const Text('Print Tags (2x3)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                onPressed: () => _printCertificationTags(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ASSET CARD (TAPPING OPENS ASSET DETAILS - INCLUDES INDIVIDUAL HISTORY BUTTON) ---
  Widget _buildAssetChecklistCard(AssetModel asset, int index) {
    final bool isCertified = _isAssetCertified(asset);
    final bool isPending = _isAssetPending(asset);
    final bool isOverdue = _isAssetOverdue(asset);
    final bool isSpare = asset.status == AssetStatus.spare;
    final bool isActive = asset.status == AssetStatus.active;

    final DateTime lastTested = asset.lastServiceDate ?? asset.lastPulseTime ?? DateTime.now();
    final DateTime nextDue = asset.nextServiceDue ?? lastTested.add(const Duration(days: 180));
    final int daysRemaining = nextDue.difference(DateTime.now()).inDays;

    Color badgeColor = Colors.greenAccent;
    String badgeText = 'CERTIFIED';
    if (asset.healthStatus == AssetHealthStatus.critical) {
      badgeColor = Colors.redAccent;
      badgeText = 'CRITICAL';
    } else if (asset.healthStatus == AssetHealthStatus.warning) {
      badgeColor = Colors.orangeAccent;
      badgeText = 'ATTENTION';
    } else if (isSpare && isOverdue) {
      badgeColor = Colors.orangeAccent;
      badgeText = 'OVERDUE';
    } else if (isSpare && isPending) {
      badgeColor = Colors.yellowAccent;
      badgeText = 'DUE IN ${daysRemaining}d';
    } else if (isActive) {
      badgeColor = Colors.blueAccent;
      badgeText = 'ACTIVE FLEET';
    }

    final bool isSelected = _selectedAssetIds.contains(asset.id);

    return Card(
      color: Theme.of(context).cardColor.withValues(alpha: isSelected ? 0.6 : 0.35),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? Colors.cyanAccent : badgeColor.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedAssetIds.remove(asset.id);
              } else {
                _selectedAssetIds.add(asset.id);
              }
            });
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AssetDetailPage(asset: asset)));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      activeColor: Colors.cyanAccent,
                      checkColor: Colors.black,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedAssetIds.add(asset.id);
                          } else {
                            _selectedAssetIds.remove(asset.id);
                          }
                        });
                      },
                    ),
                  ],
                  // Icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      asset.type == AssetType.motor
                          ? Icons.electric_bolt
                          : asset.type == AssetType.gearbox
                              ? Icons.settings
                              : asset.type == AssetType.pump
                                  ? Icons.water_drop
                                  : asset.type == AssetType.brake
                                      ? Icons.offline_bolt
                                      : Icons.precision_manufacturing,
                      color: AppColors.accent,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Tag & Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                asset.tagNo,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isSpare
                                    ? Colors.cyan.withValues(alpha: 0.2)
                                    : isActive
                                        ? Colors.blue.withValues(alpha: 0.2)
                                        : Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                isSpare ? 'SPARE' : (isActive ? 'ACTIVE' : 'MAINT.'),
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSpare ? Colors.cyanAccent : (isActive ? Colors.blueAccent : Colors.orangeAccent),
                                ),
                              ),
                            ),
                            if (asset.isCritical) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4), width: 0.8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.workspace_premium_rounded, size: 9, color: Colors.amberAccent),
                                    SizedBox(width: 2),
                                    Text('CRITICAL SPARE', style: TextStyle(color: Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          asset.name.isNotEmpty ? asset.name : '${asset.type.name.toUpperCase()} Asset',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Health Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Specs & Storage Bay Location / Parent Machine
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSpare ? Icons.warehouse : Icons.precision_manufacturing,
                      size: 13,
                      color: isSpare ? Colors.cyanAccent : Colors.blueAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        asset.spareLocation != null && asset.spareLocation!.isNotEmpty
                            ? 'Bay Loc: ${asset.spareLocation}'
                            : (asset.masterEquipmentId.isNotEmpty ? 'Parent: ${asset.masterEquipmentId}' : 'Central Warehouse'),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (asset.powerKw != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${asset.powerKw} kW',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                    if (asset.speedRpm != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '| ${asset.speedRpm} RPM',
                        style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 6-Month Recertification Dates Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Last Tested: ${asset.lastServiceDate?.toString().split(' ')[0] ?? "Never"}',
                    style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  Text(
                    'Next Due: ${nextDue.toString().split(' ')[0]}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isSpare && isOverdue ? Colors.orangeAccent : Colors.greenAccent,
                    ),
                  ),
                ],
              ),
              const Divider(height: 14),

              // Action Buttons Row (Checkup + History + Print Tag)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (isSpare && isOverdue) || !isCertified ? AppColors.accent : AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_chart, size: 15, color: Colors.white),
                      label: Text(
                        isSpare && isOverdue ? 'Recertify Now' : 'Health Checkup',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LogDiagnosticTestPage(asset: asset)),
                        );
                        _fetchAssets();
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.history_rounded, size: 17, color: Colors.amberAccent),
                    tooltip: 'View Past Test History',
                    onPressed: () => _showAssetHealthHistoryModal(asset),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.print_outlined, size: 17, color: Colors.cyanAccent),
                    tooltip: 'Print Single Certification Tag (2x3 A4)',
                    onPressed: () => _printCertificationTags(specificAssets: [asset]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- EMPTY STATE ---
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 54, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          const Text('No assets matching current checklist filters.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Text('Try switching plant, unit or resetting search filters.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _filterStatus = 'All';
                _filterType = 'All';
                _searchController.clear();
              });
            },
            child: const Text('Reset All Filters'),
          ),
        ],
      ),
    );
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
