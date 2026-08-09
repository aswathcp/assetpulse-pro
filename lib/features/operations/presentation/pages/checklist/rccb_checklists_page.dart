import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/widgets/glass_container.dart';
import 'package:asset_pulse_pro/core/widgets/pulse_loading.dart';
import 'package:asset_pulse_pro/features/home/presentation/widgets/custom_app_bar.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/constants/app_roles.dart';
import 'package:uuid/uuid.dart';

// PDF, Excel & Import Pages
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:asset_pulse_pro/core/services/excel_service.dart';
import 'package:asset_pulse_pro/core/utils/file_download_helper.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/data_import_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

// Alphanumeric natural comparator for sorting IDs
int compareNatural(String a, String b) {
  final RegExp reg = RegExp(r'(\d+)|(\D+)');
  final matchesA = reg.allMatches(a).toList();
  final matchesB = reg.allMatches(b).toList();
  for (int i = 0; i < matchesA.length && i < matchesB.length; i++) {
    final mA = matchesA[i].group(0)!;
    final mB = matchesB[i].group(0)!;
    final isNumA = int.tryParse(mA) != null;
    final isNumB = int.tryParse(mB) != null;
    if (isNumA && isNumB) {
      final intA = int.parse(mA);
      final intB = int.parse(mB);
      if (intA != intB) return intA.compareTo(intB);
    } else {
      if (mA != mB) return mA.compareTo(mB);
    }
  }
  return matchesA.length.compareTo(matchesB.length);
}

class RccbChecklistsPage extends StatefulWidget {
  const RccbChecklistsPage({super.key});

  @override
  State<RccbChecklistsPage> createState() => _RccbChecklistsPageState();
}

class _ChecklistLdbState {
  final Map<int, String> poleTypes = {};
  final Map<int, TextEditingController> timeControllers1x = {};
  final Map<int, TextEditingController> timeControllers5x = {};
  final Map<int, bool> replacedFlags = {};
}

class _RccbChecklistsPageState extends State<RccbChecklistsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HierarchyService _hierarchyService = HierarchyService();

  // Scope State
  String? _selectedPlantId;
  String? _selectedUnitId;
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  bool _isLoading = true;
  String _userRole = '';
  String _currentUserName = '';
  bool _isAdmin = false;

  // Active LDB List & Testing State
  List<Map<String, dynamic>> _availableLdbs = [];
  List<Map<String, dynamic>> _processedLdbs = [];
  Map<String, Map<String, dynamic>> _ldbLatestReports = {}; // ldbId -> latest report map
  
  // Selection, history and editing states
  Map<String, dynamic>? _selectedLdb;
  Map<String, dynamic>? _historyLdb; // If non-null, show the full-screen history view
  bool _isManagingLdbs = false; // If true, show the full-screen manage LDBs view
  bool _showHelp = false;
  String? _editingReportId; // tracks if editing existing report
  
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  final _actionTakenController = TextEditingController();
  final _searchController = TextEditingController();
  
  String _ldbCondition = 'Good';
  String _checkType = 'Routine';
  DateTime _testDate = DateTime.now();
  final _checklistState = _ChecklistLdbState();
  bool _isSubmitting = false;

  // Dashboard Metrics
  int _totalLdbsCount = 0;
  int _completedLdbsCount = 0;
  int _failedLdbsCount = 0;
  int _overdueLdbsCount = 0;
  double _coveragePercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserScope();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _actionTakenController.dispose();
    _searchController.dispose();
    _disposeTimeControllers();
    super.dispose();
  }

  void _disposeTimeControllers() {
    for (var ctrl in _checklistState.timeControllers1x.values) {
      ctrl.dispose();
    }
    for (var ctrl in _checklistState.timeControllers5x.values) {
      ctrl.dispose();
    }
    _checklistState.timeControllers1x.clear();
    _checklistState.timeControllers5x.clear();
    _checklistState.poleTypes.clear();
    _checklistState.replacedFlags.clear();
  }

  Future<void> _loadUserScope() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    
    final profile = await _firestoreService.getUserProfile(user.uid);
    if (profile == null) return;
    
    _userRole = profile['role'] ?? AppRoles.guest;
    _currentUserName = profile['displayName'] ?? 'Unknown Operator';
    _isAdmin = profile['isAdmin'] == true || _userRole == AppRoles.developer;
    final userPlantId = profile['plantId'] as String?;
    final userUnitId = profile['unitId'] as String?;
    final userBusinessId = profile['businessId'] as String? ?? 'VISL';
    
    await _hierarchyService.init(businessId: userBusinessId);
    _plants = _hierarchyService.getPlants();
    
    final String? cleanPlant = (userPlantId == null || userPlantId.isEmpty || userPlantId == 'Unknown') ? null : userPlantId;
    final String? cleanUnit = (userUnitId == null || userUnitId.isEmpty || userUnitId == 'Unknown') ? null : userUnitId;

    final bool hasGlobalAdmin = _isAdmin && cleanPlant == null;
    final bool hasPlantAdmin = _isAdmin && cleanPlant != null;

    final bool isPlantScope = (hasPlantAdmin || _userRole == AppRoles.businessAdmin || _userRole == AppRoles.plantAdmin || _userRole == AppRoles.plantHod) &&
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
      _selectedPlantId = cleanPlant ?? (_plants.isNotEmpty ? _plants.first : null);
    } else {
      _isPlantLocked = true;
      _isUnitLocked = true;
      _selectedPlantId = cleanPlant ?? (_plants.isNotEmpty ? _plants.first : null);
      _selectedUnitId = cleanUnit;
    }
    
    _updateUnitList();
    if (!_isUnitLocked && _selectedUnitId == null) {
      _selectedUnitId = _units.isNotEmpty ? _units.first : null;
    }
    
    await _loadDashboardMetricsAndLdbs();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateUnitList() {
    if (_selectedPlantId == null) {
      _units = [];
      _selectedUnitId = null;
    } else {
      _units = _hierarchyService.getUnitsForPlant(_selectedPlantId!);
      if (_units.isEmpty) _units = ['PID1', 'MCD'];
      if (!_units.contains(_selectedUnitId)) {
        _selectedUnitId = _units.isNotEmpty ? _units.first : null;
      }
    }
  }

  Future<void> _loadDashboardMetricsAndLdbs() async {
    if (_selectedPlantId == null || _selectedUnitId == null) return;
    
    try {
      // 1. Fetch LDBs
      final ldbSnapshot = await _firestore.collection('lighting_dbs')
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();
      
      final ldbItems = ldbSnapshot.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      // Sort natural alphanumeric
      ldbItems.sort((a, b) => compareNatural(a['id'].toString(), b['id'].toString()));

      // 2. Fetch all reports to determine last tested dates
      final reportsSnapshot = await _firestore.collection('rccb_test_reports')
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();

      final Map<String, Map<String, dynamic>> lastReportMap = {};
      final Map<String, List<Map<String, dynamic>>> allReportsMap = {};

      for (final doc in reportsSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['deleted'] == true) continue; // Soft-delete filter
        
        final ldbId = data['ldbId']?.toString().toUpperCase();
        final dateStr = data['testingDate'] as String?;
        if (ldbId != null && dateStr != null) {
          allReportsMap.putIfAbsent(ldbId, () => []).add(data);
          
          final date = DateTime.parse(dateStr);
          final existing = lastReportMap[ldbId];
          if (existing == null) {
            lastReportMap[ldbId] = data;
          } else {
            final existingDate = DateTime.parse(existing['testingDate'] ?? '');
            if (date.isAfter(existingDate)) {
              lastReportMap[ldbId] = data;
            }
          }
        }
      }

      _availableLdbs = ldbItems;
      _ldbLatestReports = lastReportMap;

      _processComplianceData(allReportsMap);
    } catch (e) {
      debugPrint("Error loading dashboard metrics: $e");
    }
  }

  void _processComplianceData(Map<String, List<Map<String, dynamic>>> allReportsMap) {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 180));
    final List<Map<String, dynamic>> processed = [];
    
    int completed = 0;
    int failed = 0;
    int overdue = 0;

    for (final ldb in _availableLdbs) {
      final ldbId = ldb['id'].toString().toUpperCase();
      final latestReport = _ldbLatestReports[ldbId];
      final history = allReportsMap[ldbId] ?? [];
      history.sort((a, b) => DateTime.parse(b['testingDate']).compareTo(DateTime.parse(a['testingDate'])));

      String status = 'Never Tested';
      DateTime? lastTestedDate;
      
      if (latestReport == null) {
        status = 'Never Tested';
        overdue++;
      } else {
        lastTestedDate = DateTime.parse(latestReport['testingDate']);
        final isOverdue = lastTestedDate.isBefore(cutoffDate);
        
        // Evaluate failure
        final rccbLogs = latestReport['rccbLogs'] as List<dynamic>? ?? [];
        final hasFailedRccb = rccbLogs.any((log) => log['result'] == 'Fail');
        final currentRccbCount = ldb['rccbCount'] as int? ?? 0;
        final loggedRccbCount = rccbLogs.length;
        final isIncomplete = loggedRccbCount < currentRccbCount;

        if (isOverdue || isIncomplete) {
          status = 'Overdue';
          overdue++;
        } else if (hasFailedRccb) {
          status = 'Failed';
          failed++;
        } else {
          status = 'Compliant';
          completed++;
        }
      }

      processed.add({
        ...ldb,
        'status': status,
        'lastTested': lastTestedDate,
        'latestReport': latestReport,
        'history': history,
      });
    }

    setState(() {
      _processedLdbs = processed;
      _totalLdbsCount = _availableLdbs.length;
      _completedLdbsCount = completed;
      _failedLdbsCount = failed;
      _overdueLdbsCount = overdue;
      _coveragePercentage = _totalLdbsCount == 0 ? 0.0 : (completed / _totalLdbsCount) * 100.0;
      
      // Update history reference if active
      if (_historyLdb != null) {
        _historyLdb = _processedLdbs.firstWhere(
          (element) => element['id'] == _historyLdb!['id'],
          orElse: () => _historyLdb!,
        );
      }
    });
  }

  // Time-locked & Role-based Edit/Delete permission check (8-hour limit for operator, infinite for Admin)
  bool _canEditOrDeleteReport(DateTime testingDate, String testedBy) {
    if (_isAdmin) return true;
    final diff = DateTime.now().difference(testingDate);
    final isTester = testedBy.toLowerCase() == _currentUserName.toLowerCase();
    return isTester && diff.inHours < 8;
  }

  // Soft Delete report function keeping database audit trails
  void _confirmDeleteReport(String reportId, Map<String, dynamic> ldb) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this inspection report? This action is soft-deleted and remains auditable.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await _firestore.collection('rccb_test_reports').doc(reportId).update({
                'deleted': true,
                'deletedBy': _currentUserName,
                'deletedAt': DateTime.now().toIso8601String(),
              });
              Navigator.pop(context);
              await _loadDashboardMetricsAndLdbs();
              setState(() {});
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- Board Dialog triggers for CRUD ---
  void _showAddEditLdbDialog(Map<String, dynamic>? existing, VoidCallback onSaved) {
    final formKey = GlobalKey<FormState>();
    final locCtrl = TextEditingController(text: existing?['location']);
    final countCtrl = TextEditingController(text: existing?['rccbCount']?.toString() ?? '1');
    final sourceCtrl = TextEditingController(text: existing?['incomingSource'] ?? 'LDB Panel');
    final descCtrl = TextEditingController(text: existing?['description']);

    // Suggest next numerical LDB index
    String suggestedNumber = '';
    if (existing == null) {
      int maxIdx = 0;
      for (var ldb in _availableLdbs) {
        final stripped = HierarchyService.stripPrefix(ldb['id'], _selectedPlantId!, _selectedUnitId!);
        if (stripped.startsWith('LDB-')) {
          final numPart = int.tryParse(stripped.substring(4));
          if (numPart != null && numPart > maxIdx) {
            maxIdx = numPart;
          }
        }
      }
      suggestedNumber = '${maxIdx + 1}';
    } else {
      final stripped = HierarchyService.stripPrefix(existing['id'], _selectedPlantId!, _selectedUnitId!);
      if (stripped.startsWith('LDB-')) {
        suggestedNumber = stripped.substring(4);
      } else {
        suggestedNumber = stripped;
      }
    }

    final idCtl = TextEditingController(text: suggestedNumber);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(existing == null ? 'Add Lighting LDB Board' : 'Edit LDB Board Details'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: idCtl,
                    decoration: const InputDecoration(
                      prefixText: 'LDB-',
                      prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      labelText: 'LDB ID Number',
                      border: OutlineInputBorder(),
                      helperText: 'Saved as: PLANT-UNIT-LDB-[Number]',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.contains('-') || v.toUpperCase().contains('LDB')) {
                        return 'Input sequence only (e.g. 1, 2, 5B)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: locCtrl,
                    decoration: const InputDecoration(labelText: 'Location Description', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: countCtrl,
                    decoration: const InputDecoration(labelText: 'Number of RCCBs', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final val = int.tryParse(v);
                      if (val == null || val < 1) return 'Must be a positive integer';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: sourceCtrl,
                    decoration: const InputDecoration(labelText: 'Incoming Power Source', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description / Remarks', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final rawId = 'LDB-${idCtl.text.trim().toUpperCase()}';
                  final prefixedId = HierarchyService.prefixId(rawId, _selectedPlantId!, _selectedUnitId!);

                  final data = {
                    'id': prefixedId,
                    'plantId': _selectedPlantId!,
                    'unitId': _selectedUnitId!,
                    'location': locCtrl.text.trim(),
                    'rccbCount': int.parse(countCtrl.text.trim()),
                    'incomingSource': sourceCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                  };
                  
                  await _firestore.collection('lighting_dbs').doc(prefixedId).set(data, SetOptions(merge: true));
                  onSaved();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save Board'),
            )
          ],
        );
      },
    );
  }

  void _confirmDeleteLdb(Map<String, dynamic> ldb, VoidCallback onDelete) {
    final rawId = HierarchyService.stripPrefix(ldb['id'], _selectedPlantId!, _selectedUnitId!);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Board'),
        content: Text('Are you sure you want to delete "$rawId - ${ldb['location']}"? History logs will not be deleted but the board will be removed from checklists.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await _firestore.collection('lighting_dbs').doc(ldb['id']).delete();
              onDelete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- Help Dialog for RCCB (IEC Standards) ---
  Widget _buildHelpView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showHelp = false),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'RCCB Testing Guide',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Residual Current Circuit Breakers (RCCBs) are critical for protection against electric shock and electrical fire hazards in the plant. Audits are performed every 6 months.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const Divider(height: 24),
          
          const Text('1. IEC 61008 Standard Trip Times', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent)),
          const SizedBox(height: 10),
          _buildHelpItem(
            title: '1x Trip Current Test (30mA)',
            desc: 'Simulates normal leakage fault. RCCB must trip in \u2264 300 ms. Anything slower fails safety code.',
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 8),
          _buildHelpItem(
            title: '5x Trip Current Test (150mA)',
            desc: 'Simulates high current transient faults. RCCB must trip in \u2264 40 ms for fast shock protection.',
            color: Colors.blueAccent,
          ),

          const Divider(height: 24),
          
          const Text('2. Status Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent)),
          const SizedBox(height: 8),
          const Text(
            '• COMPLIANT: Board was tested within 6 months, and all RCCBs successfully passed tripping limits.\n'
            '• FAILED: A test was done but one or more RCCBs failed to trip within standard times, requiring immediate replacement.\n'
            '• OVERDUE: No tests recorded in the last 180 days, or a test was submitted without completing all RCCB units.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem({required String title, required String desc, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        border: Border.all(color: Colors.grey.shade800),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  // --- File Open / Share Prompt ---
  void _handleSavedFile(String path, String fileName) {
    if (!mounted) return;

    final bool isPublic = path.contains('/storage/emulated/0/Download/Assetpulse-pro');
    final String locationMessage = isPublic 
        ? 'Saved to Internal Storage: Download/Assetpulse-pro/$fileName'
        : 'Saved to Application Storage: $fileName';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.share, size: 14),
                  label: const Text('Share', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    Navigator.pop(context);
                    await Share.shareXFiles([XFile(path)], text: 'RCCB Trip Report: $fileName');
                  },
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 14, color: Colors.white),
                  label: const Text('Open', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await OpenFile.open(path);
                    if (result.type != ResultType.done && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open file: ${result.message}')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // --- Export Excel function ---
  void _exportExcelReport() async {
    if (_processedLdbs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }

    final List<Map<String, dynamic>> excelData = [];
    for (var ldb in _processedLdbs) {
      final latest = ldb['latestReport'] as Map<String, dynamic>?;
      final rawId = HierarchyService.stripPrefix(ldb['id'], _selectedPlantId!, _selectedUnitId!);
      
      final rccbLogs = latest != null ? (latest['rccbLogs'] as List<dynamic>? ?? []) : [];
      final lastTestedStr = latest != null ? _formatDate(DateTime.parse(latest['testingDate'])) : 'Never';
      
      if (rccbLogs.isEmpty) {
        excelData.add({
          'Board ID': rawId,
          'Location': ldb['location'] ?? '',
          'Incoming Source': ldb['incomingSource'] ?? '',
          'No of RCCBs': ldb['rccbCount'] ?? 0,
          'Board Condition': ldb['ldbCondition'] ?? 'Good',
          'Overall Status': ldb['status'],
          'Last Tested': lastTestedStr,
          'RCCB No': '-',
          'Pole Type': '-',
          '1x Trip Time (ms)': '-',
          '5x Trip Time (ms)': '-',
          'Test Status': '-',
          'Replaced': '-',
          'Tested By': latest?['testedBy'] ?? '-',
          'Remarks': latest?['remarks'] ?? '',
        });
      } else {
        for (var log in rccbLogs) {
          excelData.add({
            'Board ID': rawId,
            'Location': ldb['location'] ?? '',
            'Incoming Source': ldb['incomingSource'] ?? '',
            'No of RCCBs': ldb['rccbCount'] ?? 0,
            'Board Condition': ldb['ldbCondition'] ?? 'Good',
            'Overall Status': ldb['status'],
            'Last Tested': lastTestedStr,
            'RCCB No': 'RCCB-${log['rccbNo']}',
            'Pole Type': log['poleType'] ?? '2P',
            '1x Trip Time (ms)': log['trippingTime1x'] ?? '-',
            '5x Trip Time (ms)': log['trippingTime5x'] ?? '-',
            'Test Status': log['result'] ?? 'Pass',
            'Replaced': log['replaced'] == true ? 'Yes' : 'No',
            'Tested By': latest?['testedBy'] ?? '-',
            'Remarks': latest?['remarks'] ?? '',
          });
        }
      }
    }

    final bytes = ExcelService().generateExcel(excelData, 'RCCB Trip Report');
    if (bytes != null) {
      final fileName = 'RCCB_Trip_Report_${_selectedPlantId}_${_selectedUnitId}.xlsx';
      final path = await downloadFile(bytes, fileName);
      if (path != null) {
        _handleSavedFile(path, fileName);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel report exported successfully!')));
        }
      }
    }
  }

  // --- Export Premium PDF Report ---
  void _exportPDFReport() async {
    if (_processedLdbs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export PDF.')));
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            // Corporate Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('VEDANTA IRON & STEEL LTD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text('${_hierarchyService.businessName}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('PERIODICAL RCCB SAFETY AUDIT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blue800)),
                    pw.Text('Standards Reference: IEC 61008 / BS 7671', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.blue900, height: 16),

            // Metadata Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Plant: ${_selectedPlantId}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('Unit: ${_selectedUnitId}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('Report Date: ${_formatDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 12),

            // Summary Stats Box
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 1),
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              padding: const pw.EdgeInsets.all(10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfStatItem('Total Boards', '$_totalLdbsCount'),
                  _pdfStatItem('Compliant', '$_completedLdbsCount', color: PdfColors.green800),
                  _pdfStatItem('Failed RCCBs', '$_failedLdbsCount', color: PdfColors.red800),
                  _pdfStatItem('Overdue / Unchecked', '$_overdueLdbsCount', color: PdfColors.orange800),
                  _pdfStatItem('Compliance Coverage', '${_coveragePercentage.toStringAsFixed(1)}%', color: PdfColors.blue800),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            pw.Text('LDB Boards Audit Sheet', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.SizedBox(height: 6),

            // Data Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(2.6),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.4),
                5: const pw.FlexColumnWidth(1.2),
                6: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Headers Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  children: [
                    _pdfTableCellHelper('LDB ID', isHeader: true),
                    _pdfTableCellHelper('Location', isHeader: true),
                    _pdfTableCellHelper('RCCB Count', isHeader: true),
                    _pdfTableCellHelper('Condition', isHeader: true),
                    _pdfTableCellHelper('Status', isHeader: true),
                    _pdfTableCellHelper('Check Type', isHeader: true),
                    _pdfTableCellHelper('Last Audit', isHeader: true),
                  ],
                ),
                // Rows
                ..._processedLdbs.map((ldb) {
                  final latest = ldb['latestReport'] as Map<String, dynamic>?;
                  final statusText = ldb['status'].toString().toUpperCase();
                  final rawId = HierarchyService.stripPrefix(ldb['id'], _selectedPlantId!, _selectedUnitId!);
                  
                  PdfColor statusColor = PdfColors.black;
                  if (statusText == 'COMPLIANT') statusColor = PdfColors.green800;
                  if (statusText == 'FAILED') statusColor = PdfColors.red800;
                  if (statusText == 'OVERDUE') statusColor = PdfColors.orange800;

                  final checkTypeStr = latest != null ? (latest['checkType'] ?? 'Routine') : '-';

                  return pw.TableRow(
                    children: [
                      _pdfTableCellHelper(rawId, isBold: true),
                      _pdfTableCellHelper(ldb['location'] ?? ''),
                      _pdfTableCellHelper('${ldb['rccbCount'] ?? 0} RCCBs'),
                      _pdfTableCellHelper(ldb['ldbCondition'] ?? 'Good'),
                      _pdfTableCellHelper(statusText, color: statusColor, isBold: true),
                      _pdfTableCellHelper(checkTypeStr),
                      _pdfTableCellHelper(latest != null ? _formatDate(DateTime.parse(latest['testingDate'])) : 'Never'),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 36),

            // Signatures Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(width: 120, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)))),
                    pw.SizedBox(height: 4),
                    pw.Text('Prepared By / Tested By', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Electrician / Engineer', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(width: 120, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)))),
                    pw.SizedBox(height: 4),
                    pw.Text('Reviewed & Approved By', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Safety Manager / HOD', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'RCCB_Audit_Report_${_selectedPlantId}_${_selectedUnitId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final path = await downloadFile(bytes, fileName);
    if (path != null) {
      _handleSavedFile(path, fileName);
    }
  }

  pw.Widget _pdfStatItem(String label, String val, {PdfColor color = PdfColors.black}) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(val, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  pw.Widget _pdfTableCellHelper(String text, {bool isHeader = false, bool isBold = false, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : color,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  void _startRecordOrEdit(Map<String, dynamic> ldb, Map<String, dynamic>? existingReport) {
    _disposeTimeControllers();
    
    setState(() {
      _selectedLdb = ldb;
      _editingReportId = existingReport?['id'];
      _ldbCondition = existingReport?['ldbCondition'] ?? 'Good';
      _checkType = existingReport?['checkType'] ?? (ldb['status'] == 'Failed' || ldb['status'] == 'Overdue' ? 'Retest' : 'Routine');
      _remarksController.text = existingReport?['remarks'] ?? '';
      _actionTakenController.text = existingReport?['actionTaken'] ?? '';
      _testDate = existingReport != null ? DateTime.parse(existingReport['testingDate']) : DateTime.now();

      final currentRccbCount = ldb['rccbCount'] as int? ?? 0;
      final rccbLogs = existingReport?['rccbLogs'] as List<dynamic>? ?? [];

      for (int i = 1; i <= currentRccbCount; i++) {
        _checklistState.poleTypes[i] = '2P';
        _checklistState.timeControllers1x[i] = TextEditingController();
        _checklistState.timeControllers5x[i] = TextEditingController();
        _checklistState.replacedFlags[i] = false;
      }

      for (var log in rccbLogs) {
        final rIdx = log['rccbNo'] as int;
        if (rIdx <= currentRccbCount) {
          _checklistState.poleTypes[rIdx] = log['poleType'] ?? '2P';
          _checklistState.timeControllers1x[rIdx]?.text = log['trippingTime1x']?.toString() ?? '';
          _checklistState.timeControllers5x[rIdx]?.text = log['trippingTime5x']?.toString() ?? '';
          _checklistState.replacedFlags[rIdx] = log['replaced'] == true;
        }
      }
    });
  }

  Future<void> _submitRccbTestReport() async {
    if (!_formKey.currentState!.validate() || _selectedLdb == null) return;

    final rccbCount = _selectedLdb!['rccbCount'] as int? ?? 0;
    final List<Map<String, dynamic>> logs = [];

    for (int i = 1; i <= rccbCount; i++) {
      final t1xStr = _checklistState.timeControllers1x[i]!.text.trim();
      final t5xStr = _checklistState.timeControllers5x[i]!.text.trim();

      if (t1xStr.isEmpty || t5xStr.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter tripping times for RCCB Break unit $i')),
        );
        return;
      }

      final t1x = double.tryParse(t1xStr);
      final t5x = double.tryParse(t5xStr);

      if (t1x == null || t5x == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid numeric time inputs for RCCB Break unit $i')),
        );
        return;
      }

      final bool isPass = (t1x <= 300.0) && (t5x <= 40.0);
      logs.add({
        'rccbNo': i,
        'poleType': _checklistState.poleTypes[i] ?? '2P',
        'trippingTime1x': t1x,
        'trippingTime5x': t5x,
        'result': isPass ? 'Pass' : 'Fail',
        'replaced': _checklistState.replacedFlags[i] ?? false,
      });
    }

    setState(() => _isSubmitting = true);

    try {
      final rawId = HierarchyService.stripPrefix(_selectedLdb!['id'], _selectedPlantId!, _selectedUnitId!);
      final reportId = _editingReportId ?? const Uuid().v4();
      final bool isEdit = _editingReportId != null;

      final reportData = {
        'id': reportId,
        'ldbId': _selectedLdb!['id'],
        'ldbName': rawId,
        'plantId': _selectedPlantId!,
        'unitId': _selectedUnitId!,
        'testedBy': isEdit ? (_selectedLdb!['latestReport']?['testedBy'] ?? _currentUserName) : _currentUserName,
        'testingDate': _testDate.toIso8601String(),
        'ldbCondition': _ldbCondition,
        'rccbCount': rccbCount,
        'rccbLogs': logs,
        'remarks': _remarksController.text.trim(),
        'checkType': _checkType,
        'actionTaken': _checkType == 'Retest' ? _actionTakenController.text.trim() : '',
      };

      if (isEdit) {
        reportData['lastModifiedBy'] = _currentUserName;
        reportData['lastModifiedAt'] = DateTime.now().toIso8601String();
      }

      await _firestore.collection('rccb_test_reports').doc(reportId).set(reportData);

      // Update original LDB physical condition inside lighting_dbs
      await _firestore.collection('lighting_dbs').doc(_selectedLdb!['id']).set({
        'ldbCondition': _ldbCondition,
      }, SetOptions(merge: true));

      await _loadDashboardMetricsAndLdbs();

      setState(() {
        _selectedLdb = null;
        _editingReportId = null;
        _remarksController.clear();
        _actionTakenController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RCCB test report successfully saved!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'RCCB Safety Checklist'),
        body: Center(child: PulseLoading()),
      );
    }

    return PopScope(
      canPop: _selectedLdb == null && _historyLdb == null && !_isManagingLdbs && !_showHelp,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          if (_selectedLdb != null) {
            _selectedLdb = null;
            _editingReportId = null;
          } else if (_historyLdb != null) {
            _historyLdb = null;
          } else if (_isManagingLdbs) {
            _isManagingLdbs = false;
          } else if (_showHelp) {
            _showHelp = false;
          }
        });
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: 'RCCB Safety Checklist'),
        body: _selectedLdb != null
            ? _buildTestingFormView()
            : _historyLdb != null
                ? _buildHistoryView()
                : _isManagingLdbs
                    ? _buildManageLdbsView()
                    : _showHelp
                        ? _buildHelpView()
                        : _buildLdbListView(),
      ),
    );
  }

  Widget _buildLdbListView() {
    final query = _searchController.text.trim().toLowerCase();
    final filteredLdbs = _processedLdbs.where((ldb) {
      final loc = (ldb['location'] ?? '').toString().toLowerCase();
      final source = (ldb['incomingSource'] ?? '').toString().toLowerCase();
      final id = HierarchyService.stripPrefix(ldb['id'], _selectedPlantId!, _selectedUnitId!).toLowerCase();
      return loc.contains(query) || source.contains(query) || id.contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Scope selectors
          GlassContainer(
            borderRadius: 16,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedPlantId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Select Plant', border: InputBorder.none),
                      items: _plants.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: _isPlantLocked ? null : (val) {
                        if (val != null) {
                          setState(() {
                            _selectedPlantId = val;
                            _updateUnitList();
                            _isLoading = true;
                          });
                          _loadDashboardMetricsAndLdbs().then((_) {
                            setState(() => _isLoading = false);
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
                      items: _units.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: _isUnitLocked ? null : (val) {
                        if (val != null) {
                          setState(() {
                            _selectedUnitId = val;
                            _isLoading = true;
                          });
                          _loadDashboardMetricsAndLdbs().then((_) {
                            setState(() => _isLoading = false);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Metrics Card
          _buildMetricsDashboard(),
          const SizedBox(height: 20),

          // 3. Search and Actions
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search board ID or location...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.help_outline, color: Colors.white),
                tooltip: 'RCCB Safety Help Guide',
                onPressed: () => setState(() => _showHelp = true),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 4),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.settings, color: Colors.white),
                  tooltip: 'Manage Boards',
                  onPressed: () => setState(() {
                    _isManagingLdbs = true;
                  }),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // 4. Content headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Safety Boards (${filteredLdbs.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _exportExcelReport,
                    icon: const Icon(Icons.table_chart, size: 16, color: Colors.greenAccent),
                    label: const Text('Excel', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _exportPDFReport,
                    icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.redAccent),
                    label: const Text('PDF Report', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          filteredLdbs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Text(
                      _availableLdbs.isEmpty
                          ? 'No LDB boards registered. Click the settings cog to add boards.'
                          : 'No boards matched your search.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredLdbs.length,
                  itemBuilder: (context, index) {
                    final ldb = filteredLdbs[index];
                    return _buildLdbCard(ldb);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildMetricsDashboard() {
    return GlassContainer(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('RCCB Audit Test Coverage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Required: 100% compliant tripping safety', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                Text(
                  '${_coveragePercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _coveragePercentage > 90
                        ? Colors.greenAccent
                        : _coveragePercentage > 60
                            ? Colors.orangeAccent
                            : Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _totalLdbsCount == 0 ? 0.0 : (_completedLdbsCount / _totalLdbsCount),
                minHeight: 10,
                backgroundColor: Colors.grey.shade800,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _coveragePercentage > 90
                      ? Colors.greenAccent
                      : _coveragePercentage > 60
                          ? Colors.orangeAccent
                          : Colors.redAccent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricColumn('Total Boards', '$_totalLdbsCount', Colors.white),
                _buildMetricColumn('Compliant', '$_completedLdbsCount', Colors.greenAccent),
                _buildMetricColumn('Failed Units', '$_failedLdbsCount', Colors.redAccent),
                _buildMetricColumn('Overdue', '$_overdueLdbsCount', Colors.orangeAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color valColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valColor)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildLdbCard(Map<String, dynamic> ldb) {
    final status = ldb['status'] as String;
    final rccbCount = ldb['rccbCount'] as int? ?? 0;
    final latestReport = ldb['latestReport'] as Map<String, dynamic>?;
    final rawId = HierarchyService.stripPrefix(ldb['id'], _selectedPlantId!, _selectedUnitId!);

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;

    switch (status) {
      case 'Compliant':
        statusColor = Colors.greenAccent;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'Failed':
        statusColor = Colors.redAccent;
        statusIcon = Icons.warning_amber_outlined;
        break;
      case 'Overdue':
        statusColor = Colors.orangeAccent;
        statusIcon = Icons.history_toggle_off;
        break;
      case 'Never Tested':
        statusColor = Colors.grey;
        statusIcon = Icons.hourglass_empty;
        break;
    }

    final String lastTestedStr = latestReport != null ? _formatDate(DateTime.parse(latestReport['testingDate'])) : 'Never';
    final ldbCond = ldb['ldbCondition'] ?? latestReport?['ldbCondition'] ?? 'Good';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$rawId - ${ldb['location'] ?? ""}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('Incoming Feed: ${ldb['incomingSource'] ?? "-"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('RCCB Units count: $rccbCount breakers', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Checked: $lastTestedStr',
                      style: TextStyle(
                        fontSize: 11,
                        color: status == 'Overdue' ? Colors.orangeAccent : Colors.grey,
                        fontWeight: status == 'Overdue' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text('Physical Condition: $ldbCond', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    if (latestReport != null && latestReport['checkType'] == 'Retest')
                      const Text(
                        'Retest Completed',
                        style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.history, size: 20),
                      tooltip: 'View History & Edit Logs',
                      onPressed: () => setState(() {
                        _historyLdb = ldb;
                      }),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor.withValues(alpha: 0.15),
                        foregroundColor: statusColor,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(status == 'Failed' || status == 'Overdue' ? Icons.build : Icons.add_chart, size: 16),
                      label: Text(
                        status == 'Failed' || status == 'Overdue' ? 'Retest Board' : 'Test Board',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _startRecordOrEdit(ldb, null),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    final List<dynamic> history = _historyLdb!['history'] ?? [];
    final rawId = HierarchyService.stripPrefix(_historyLdb!['id'], _selectedPlantId!, _selectedUnitId!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _historyLdb = null;
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Test History: $rawId',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Location: ${_historyLdb!['location'] ?? "No Location"}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          history.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Text('No historical logs found for this board.'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  itemBuilder: (context, idx) {
                    final rep = history[idx] as Map<String, dynamic>;
                    final testingDate = DateTime.parse(rep['testingDate']);
                    
                    final rccbLogs = rep['rccbLogs'] as List<dynamic>? ?? [];
                    final failCount = rccbLogs.where((log) => log['result'] == 'Fail').length;
                    final isFail = failCount > 0;
                    final checkTypeStr = rep['checkType'] ?? 'Routine';
                    final showActions = _canEditOrDeleteReport(testingDate, rep['testedBy'] ?? '');
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_formatDate(testingDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: checkTypeStr == 'Retest' ? Colors.blue.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        checkTypeStr.toUpperCase(),
                                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: checkTypeStr == 'Retest' ? Colors.blueAccent : Colors.white70),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isFail ? Colors.red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isFail ? '$failCount FAILURES' : 'ALL PASSED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isFail ? Colors.redAccent : Colors.greenAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Board Condition: ${rep['ldbCondition'] ?? "Good"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            if (checkTypeStr == 'Retest' && rep['actionTaken'] != null && rep['actionTaken'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Corrective Action Taken: "${rep['actionTaken']}"', style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                            ],
                            const Divider(height: 12),
                            
                            // Compact table summary of RCCBs
                            Table(
                              border: TableBorder.all(color: Colors.grey.shade800, width: 0.5),
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3)),
                                  children: const [
                                    Padding(padding: EdgeInsets.all(4), child: Text('RCCB', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(4), child: Text('Pole', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(4), child: Text('1x Trip', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(4), child: Text('5x Trip', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(4), child: Text('Status', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                                  ]
                                ),
                                ...rccbLogs.map((log) {
                                  final t1x = log['trippingTime1x']?.toString() ?? '-';
                                  final t5x = log['trippingTime5x']?.toString() ?? '-';
                                  final itemPass = log['result'] == 'Pass';
                                  return TableRow(
                                    children: [
                                      Padding(padding: const EdgeInsets.all(4), child: Text('RCCB-${log['rccbNo']}', style: const TextStyle(fontSize: 8))),
                                      Padding(padding: const EdgeInsets.all(4), child: Text('${log['poleType'] ?? "2P"}', style: const TextStyle(fontSize: 8))),
                                      Padding(padding: const EdgeInsets.all(4), child: Text('${t1x} ms', style: const TextStyle(fontSize: 8))),
                                      Padding(padding: const EdgeInsets.all(4), child: Text('${t5x} ms', style: const TextStyle(fontSize: 8))),
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(
                                          log['result'] ?? 'Pass',
                                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: itemPass ? Colors.greenAccent : Colors.redAccent),
                                        ),
                                      ),
                                    ]
                                  );
                                }),
                              ],
                            ),
                            
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Tested By: ${rep['testedBy']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      if (rep['remarks'] != null && rep['remarks'].toString().isNotEmpty)
                                        Text('Remarks: ${rep['remarks']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                                      if (rep['lastModifiedBy'] != null)
                                        Text('Modified By: ${rep['lastModifiedBy']} at ${_formatDate(DateTime.parse(rep['lastModifiedAt']))}', style: const TextStyle(fontSize: 9, color: Colors.orangeAccent)),
                                    ],
                                  ),
                                ),
                                if (showActions)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.edit_note, size: 16, color: Colors.orangeAccent),
                                        label: const Text('Edit', style: TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                                        onPressed: () {
                                          setState(() {
                                            _historyLdb = null;
                                          });
                                          _startRecordOrEdit(_historyLdb!, rep);
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      TextButton.icon(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                        label: const Text('Delete', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        onPressed: () => _confirmDeleteReport(rep['id'], _historyLdb!),
                                      ),
                                    ],
                                  ),
                              ],
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

  Widget _buildManageLdbsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _isManagingLdbs = false;
                }),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Manage LDB Boards',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                  label: const Text('Add New Board (LDB)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddEditLdbDialog(null, () async {
                    await _loadDashboardMetricsAndLdbs();
                    setState(() {});
                  }),
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
                          collectionId: 'lighting_dbs',
                          title: 'Lighting DBs',
                          plantId: _selectedPlantId,
                          unitId: _selectedUnitId,
                        ),
                      ),
                    );
                    await _loadDashboardMetricsAndLdbs();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _availableLdbs.isEmpty
              ? const Center(child: Text('No boards found. Add one above!'))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _availableLdbs.length,
                  itemBuilder: (context, idx) {
                    final ldb = _availableLdbs[idx];
                    final rawId = HierarchyService.stripPrefix(ldb['id'], _selectedPlantId!, _selectedUnitId!);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text('$rawId - ${ldb['location'] ?? "No Location"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'RCCBs: ${ldb['rccbCount'] ?? 0} | Source: ${ldb['incomingSource'] ?? "-"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.amberAccent, size: 20),
                              onPressed: () => _showAddEditLdbDialog(ldb, () async {
                                await _loadDashboardMetricsAndLdbs();
                                setState(() {});
                              }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                              onPressed: () => _confirmDeleteLdb(ldb, () async {
                                await _loadDashboardMetricsAndLdbs();
                                setState(() {});
                              }),
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

  Widget _buildTestingFormView() {
    final rawId = HierarchyService.stripPrefix(_selectedLdb!['id'], _selectedPlantId!, _selectedUnitId!);
    final bool isEdit = _editingReportId != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Back Row
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selectedLdb = null;
                  _editingReportId = null;
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEdit ? 'Edit Report: $rawId' : 'Test LDB Board: $rawId',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // LDB Specifications
          GlassContainer(
            borderRadius: 16,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LDB Board Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent)),
                  const Divider(height: 16),
                  _buildLdbSpecRow('Location Description:', _selectedLdb!['location'] ?? ''),
                  _buildLdbSpecRow('RCCB Quantity:', '${_selectedLdb!['rccbCount'] ?? 0} units'),
                  _buildLdbSpecRow('Incoming Feed:', _selectedLdb!['incomingSource'] ?? '-'),
                  _buildLdbSpecRow('Description details:', _selectedLdb!['description'] ?? '-'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Testing Form
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Check Type Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Inspection Check Type:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Routine', label: Text('Routine', style: TextStyle(fontSize: 11)), icon: Icon(Icons.loop, size: 12)),
                        ButtonSegment(value: 'Retest', label: Text('Retest', style: TextStyle(fontSize: 11)), icon: Icon(Icons.build, size: 12)),
                      ],
                      selected: {_checkType},
                      onSelectionChanged: (val) {
                        setState(() => _checkType = val.first);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Corrective action input for retests
                if (_checkType == 'Retest') ...[
                  TextFormField(
                    controller: _actionTakenController,
                    decoration: const InputDecoration(
                      labelText: 'Corrective Action Taken *',
                      hintText: 'e.g. Replaced 2 faulty RCCB breakers, tightened terminals',
                      border: OutlineInputBorder(),
                      errorStyle: TextStyle(fontSize: 10),
                    ),
                    validator: (v) => _checkType == 'Retest' && (v == null || v.trim().isEmpty) ? 'Corrective action is required' : null,
                  ),
                  const SizedBox(height: 12),
                ],

                const Text('RCCB Measured Tripping Times', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedLdb!['rccbCount'] as int? ?? 0,
                  itemBuilder: (context, idx) {
                    final rccbNo = idx + 1;
                    return _buildRccbTestingRow(rccbNo);
                  },
                ),
                const SizedBox(height: 16),
                
                const Text('General Audit Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                DropdownButtonFormField<String>(
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  value: _ldbCondition,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'LDB Board Physical Condition', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Good', child: Text('Good (Clean & Secured)')),
                    DropdownMenuItem(value: 'Fair', child: Text('Fair (Minor Cleaning Needed)')),
                    DropdownMenuItem(value: 'Poor', child: Text('Poor (Re-wiring / Repair Required)')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _ldbCondition = v); },
                ),
                const SizedBox(height: 12),
                
                // Tester field pre-filled and LOCKED for accountability
                TextFormField(
                  initialValue: _currentUserName,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Tested By (Logged-in User)',
                    border: OutlineInputBorder(),
                    filled: true,
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Testing Date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Testing Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  subtitle: Text(_formatDate(_testDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _testDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _testDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Remarks
                TextFormField(
                  controller: _remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks / Observations', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRccbTestReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Update RCCB Audit Report' : 'Submit RCCB Audit Report', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRccbTestingRow(int rccbNo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: 12,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RCCB Break Unit $rccbNo',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
                  ),
                  ListenableBuilder(
                    listenable: _checklistState.timeControllers1x[rccbNo]!,
                    builder: (context, _) {
                      return ListenableBuilder(
                        listenable: _checklistState.timeControllers5x[rccbNo]!,
                        builder: (context, _) {
                          final t1xStr = _checklistState.timeControllers1x[rccbNo]!.text.trim();
                          final t5xStr = _checklistState.timeControllers5x[rccbNo]!.text.trim();
                          
                          if (t1xStr.isEmpty && t5xStr.isEmpty) {
                            return const Text('Pending Test', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold));
                          }
                          
                          bool pass = true;
                          String statusText = '';
                          
                          if (t1xStr.isNotEmpty) {
                            final t1x = double.tryParse(t1xStr);
                            if (t1x == null) return const Text('Invalid 1x', style: TextStyle(color: Colors.redAccent, fontSize: 10));
                            final ok1x = t1x <= 300.0;
                            pass = pass && ok1x;
                            statusText += '1x: ${ok1x ? "Pass" : "Fail"} ';
                          }
                          if (t5xStr.isNotEmpty) {
                            final t5x = double.tryParse(t5xStr);
                            if (t5x == null) return const Text('Invalid 5x', style: TextStyle(color: Colors.redAccent, fontSize: 10));
                            final ok5x = t5x <= 40.0;
                            pass = pass && ok5x;
                            statusText += '5x: ${ok5x ? "Pass" : "Fail"}';
                          }
                          
                          return Row(
                            children: [
                              Icon(
                                pass ? Icons.check_circle : Icons.warning,
                                color: pass ? Colors.greenAccent : Colors.redAccent,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusText.trim(),
                                style: TextStyle(
                                  color: pass ? Colors.greenAccent : Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold
                                )
                              ),
                            ],
                          );
                        }
                      );
                    }
                  )
                ],
              ),
              const Divider(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      value: _checklistState.poleTypes[rccbNo],
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Pole',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                      ),
                      items: const [
                        DropdownMenuItem(value: '2P', child: Text('2P')),
                        DropdownMenuItem(value: '4P', child: Text('4P')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _checklistState.poleTypes[rccbNo] = val;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tripping Current Rating', style: TextStyle(fontSize: 8, color: Colors.grey)),
                          SizedBox(height: 2),
                          Text('30mA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _checklistState.timeControllers1x[rccbNo],
                      decoration: const InputDecoration(
                        labelText: '1x Trip Time (ms)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        helperText: 'Limit \u2264 300ms (IEC)',
                        helperStyle: TextStyle(fontSize: 8),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _checklistState.timeControllers5x[rccbNo],
                      decoration: const InputDecoration(
                        labelText: '5x Trip Time (ms)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        helperText: 'Limit \u2264 40ms (IEC)',
                        helperStyle: TextStyle(fontSize: 8),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Replaced during test?', style: TextStyle(fontSize: 12)),
                  Switch(
                    activeColor: AppColors.primaryLight,
                    value: _checklistState.replacedFlags[rccbNo] ?? false,
                    onChanged: (val) {
                      setState(() {
                        _checklistState.replacedFlags[rccbNo] = val;
                      });
                    },
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLdbSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }
}
