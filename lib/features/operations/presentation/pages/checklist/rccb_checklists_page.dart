// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/widgets/glass_container.dart';
import 'package:asset_pulse_pro/features/home/presentation/widgets/custom_app_bar.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/constants/app_roles.dart';
import 'package:uuid/uuid.dart';

// PDF, Excel, Scanning & Import Pages
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:asset_pulse_pro/core/services/excel_service.dart';
import 'package:asset_pulse_pro/core/utils/file_download_helper.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/data_import_page.dart';
import 'package:asset_pulse_pro/core/utils/permission_helper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:asset_pulse_pro/features/scanning/presentation/pages/qr_scanner_page.dart';
import 'rccb_certification_tag_pdf_helper.dart';

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
  final String? initialScannedCode;
  const RccbChecklistsPage({super.key, this.initialScannedCode});

  @override
  State<RccbChecklistsPage> createState() => _RccbChecklistsPageState();
}

class _ChecklistLdbState {
  final Map<int, String> poleTypes = {};
  final Map<int, String> ratings = {}; // '30mA' or '100mA'
  final Map<int, TextEditingController> timeControllers1x = {};
  final Map<int, TextEditingController> timeControllers5x = {};
  final Map<int, bool> replacedFlags = {};
}

class _RccbChecklistsPageState extends State<RccbChecklistsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HierarchyService _hierarchyService = HierarchyService();

  // Firestore Collection for RCCB Equipments (LDB, Welding Outlets, Power Sockets)
  static const String kRccbEquipmentsCollection = 'rccb_equipments';

  // RCCB Categories
  static const String kCatLdb = 'LDB';
  static const String kCatWelding = 'Welding Outlet';
  static const String kCatPowerSocket = 'Power Socket';
  static const List<String> kCategories = [kCatLdb, kCatWelding, kCatPowerSocket];

  // Predefined Corrective Actions
  static const List<String> kPredefinedCorrectiveActions = [
    'Replaced faulty RCCB breaker',
    'Tightened loose terminals & busbar screws',
    'Resolved earth leakage / isolated faulty branch',
    'Cleaned dust, moisture & carbon deposits',
    'Replaced damaged enclosure / weather seal',
    'Neutral-Earth ground loop rectified',
    'Swapped to new rated breaker (30mA / 100mA)',
    'Replaced damaged test button / trip latch',
    'Re-torqued lugs and tested phase balance',
    'Re-tested & verified within trip limits',
  ];

  // Scope State
  UserScope? _userScope;
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

  // Active Equipment List & Testing State
  List<Map<String, dynamic>> _availableLdbs = [];
  List<Map<String, dynamic>> _processedLdbs = [];
  Map<String, Map<String, dynamic>> _ldbLatestReports = {}; // ldbId -> latest report map

  // Filter & Search
  String _selectedCategoryFilter = 'All';
  String _selectedStatusFilter = 'All'; // 'All', 'Due Soon', 'Overdue', 'Compliant', 'Failed', 'Never Tested'
  final TextEditingController _searchController = TextEditingController();
  String _manageCategoryFilter = 'All';
  final TextEditingController _manageSearchController = TextEditingController();

  // Multi-Select Tag Printing Mode
  bool _isSelectionMode = false;
  final Set<String> _selectedEquipmentIds = {};

  // Selection, history, manage and help states
  Map<String, dynamic>? _selectedLdb;
  Map<String, dynamic>? _historyLdb; // If non-null, show the full-screen history view
  bool _isManagingLdbs = false; // If true, show the full-screen manage view
  bool _showHelp = false;
  String? _editingReportId; // tracks if editing existing report

  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  final _actionTakenController = TextEditingController();
  final Set<String> _selectedCorrectiveActions = {};

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
  int _dueSoonLdbsCount = 0;
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
    _manageSearchController.dispose();
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
    _checklistState.ratings.clear();
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
    final userBusinessId = profile['businessId'] as String? ?? 'VISL';

    await _hierarchyService.init(businessId: userBusinessId);
    final allPlants = _hierarchyService.getPlants();

    final userScope = PermissionHelper.resolveUserScope(profile);
    _userScope = userScope;

    _plants = userScope.getAvailablePlants(allPlants);
    _isPlantLocked = userScope.isPlantLocked;
    _isUnitLocked = userScope.isUnitLocked;

    _selectedPlantId = userScope.getInitialPlant(null, _plants);
    _updateUnitList();

    await _loadDashboardMetricsAndLdbs();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      // Handle initial scanned code if navigated from external scanner or main home
      if (widget.initialScannedCode != null && widget.initialScannedCode!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleScannedRccbCode(widget.initialScannedCode!);
        });
      }
    }
  }

  void _updateUnitList() {
    if (_selectedPlantId == null) {
      _units = [];
      _selectedUnitId = null;
    } else {
      final allUnits = _hierarchyService.getUnitsForPlant(_selectedPlantId!);
      if (_userScope != null) {
        _units = _userScope!.getAvailableUnits(_selectedPlantId, allUnits);
        _selectedUnitId = _userScope!.getInitialUnit(_selectedPlantId, _selectedUnitId, _units);
      } else {
        _units = allUnits.isNotEmpty ? allUnits : ['PID1', 'MCD'];
        if (!_units.contains(_selectedUnitId)) {
          _selectedUnitId = _units.isNotEmpty ? _units.first : null;
        }
      }
    }
  }

  Future<void> _loadDashboardMetricsAndLdbs() async {
    if (_selectedPlantId == null || _selectedUnitId == null) return;

    try {
      // 1. Fetch RCCB Boards / Outlets / Sockets
      final ldbSnapshot = await _firestore
          .collection(kRccbEquipmentsCollection)
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();

      final ldbItems = ldbSnapshot.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        // Default category to LDB if not present
        data['category'] ??= kCatLdb;
        data['defaultRating'] ??= '30mA';
        return data;
      }).toList();

      // Sort natural alphanumeric
      ldbItems.sort((a, b) => compareNatural(a['id'].toString(), b['id'].toString()));

      // 2. Fetch all reports to determine last tested dates
      final reportsSnapshot = await _firestore
          .collection('rccb_test_reports')
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<Map<String, dynamic>> processed = [];

    int completed = 0;
    int failed = 0;
    int overdue = 0;
    int dueSoon = 0;

    for (final ldb in _availableLdbs) {
      final ldbId = ldb['id'].toString().toUpperCase();
      final latestReport = _ldbLatestReports[ldbId];
      final history = allReportsMap[ldbId] ?? [];
      history.sort((a, b) => DateTime.parse(b['testingDate']).compareTo(DateTime.parse(a['testingDate'])));

      String status = 'Never Tested';
      DateTime? lastTestedDate;
      DateTime? nextDueDate;
      int? daysUntilDue;
      bool isDueSoon = false;
      String dueText = '';

      if (latestReport == null) {
        status = 'Never Tested';
        dueText = 'Initial Audit Pending';
        overdue++;
      } else {
        lastTestedDate = DateTime.parse(latestReport['testingDate']);
        final lastTestedDay = DateTime(lastTestedDate.year, lastTestedDate.month, lastTestedDate.day);
        // RCCB Testing is valid for 3 months (90 days)
        nextDueDate = lastTestedDay.add(const Duration(days: 90));
        daysUntilDue = nextDueDate.difference(today).inDays;

        final isOverdue = daysUntilDue < 0;

        // Evaluate failure
        final rccbLogs = latestReport['rccbLogs'] as List<dynamic>? ?? [];
        final hasFailedRccb = rccbLogs.any((log) => log['result'] == 'Fail');
        final currentRccbCount = ldb['rccbCount'] as int? ?? 0;
        final loggedRccbCount = rccbLogs.length;
        final isIncomplete = loggedRccbCount < currentRccbCount;

        if (isOverdue || isIncomplete) {
          status = 'Overdue';
          overdue++;
          if (isIncomplete && !isOverdue) {
            dueText = 'Incomplete ($loggedRccbCount/$currentRccbCount Breakers)';
          } else {
            final daysAgo = -daysUntilDue;
            dueText = 'Overdue by $daysAgo day${daysAgo == 1 ? '' : 's'}';
          }
        } else if (hasFailedRccb) {
          status = 'Failed';
          failed++;
          dueText = 'Failed Trip Limit • Retest Needed';
        } else {
          status = 'Compliant';
          completed++;
          if (daysUntilDue == 0) {
            dueText = 'Due Today';
            isDueSoon = true;
          } else if (daysUntilDue == 1) {
            dueText = 'Due Tomorrow';
            isDueSoon = true;
          } else if (daysUntilDue <= 15) {
            dueText = 'Due in $daysUntilDue days';
            isDueSoon = true;
          } else {
            dueText = 'Due in $daysUntilDue days';
          }
        }

        if (isDueSoon) {
          dueSoon++;
        }
      }

      final rawId = HierarchyService.stripPrefix(ldb['id'], _selectedPlantId!, _selectedUnitId!);

      processed.add({
        ...ldb,
        'displayId': rawId,
        'status': status,
        'lastTested': lastTestedDate,
        'nextDueDate': nextDueDate,
        'daysUntilDue': daysUntilDue,
        'isDueSoon': isDueSoon,
        'dueText': dueText,
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
      _dueSoonLdbsCount = dueSoon;
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

  // Time-locked & Role-based Edit/Delete permission check
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

  // Helper to determine category icon and badge color
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case kCatWelding:
        return Icons.construction;
      case kCatPowerSocket:
        return Icons.power;
      case kCatLdb:
      default:
        return Icons.lightbulb_outline;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case kCatWelding:
        return Colors.purpleAccent;
      case kCatPowerSocket:
        return Colors.tealAccent;
      case kCatLdb:
      default:
        return Colors.amberAccent;
    }
  }

  // --- Add/Edit Equipment Dialog ---
  void _showAddEditLdbDialog(Map<String, dynamic>? existing, VoidCallback onSaved) {
    final formKey = GlobalKey<FormState>();
    String selectedCategory = existing?['category'] ?? kCatLdb;
    String selectedDefaultRating = existing?['defaultRating'] ?? (selectedCategory == kCatWelding ? '100mA' : '30mA');

    final locCtrl = TextEditingController(text: existing?['location']);
    final countCtrl = TextEditingController(text: existing?['rccbCount']?.toString() ?? '1');
    final sourceCtrl = TextEditingController(text: existing?['incomingSource'] ?? (selectedCategory == kCatWelding ? 'Welding DB' : 'LDB Panel'));
    final descCtrl = TextEditingController(text: existing?['description']);

    // Suggest next numerical index based on category
    String getPrefixForCat(String cat) {
      switch (cat) {
        case kCatWelding:
          return 'WLD-';
        case kCatPowerSocket:
          return 'SOC-';
        case kCatLdb:
        default:
          return 'LDB-';
      }
    }

    String suggestNextNumber(String cat) {
      final pfx = getPrefixForCat(cat);
      int maxIdx = 0;
      for (var item in _availableLdbs) {
        final stripped = HierarchyService.stripPrefix(item['id'], _selectedPlantId!, _selectedUnitId!);
        if (stripped.startsWith(pfx)) {
          final numPart = int.tryParse(stripped.substring(pfx.length));
          if (numPart != null && numPart > maxIdx) {
            maxIdx = numPart;
          }
        }
      }
      return '${maxIdx + 1}';
    }

    String initialNumber = '';
    if (existing == null) {
      initialNumber = suggestNextNumber(selectedCategory);
    } else {
      final stripped = HierarchyService.stripPrefix(existing['id'], _selectedPlantId!, _selectedUnitId!);
      final pfx = getPrefixForCat(selectedCategory);
      if (stripped.startsWith(pfx)) {
        initialNumber = stripped.substring(pfx.length);
      } else {
        initialNumber = stripped;
      }
    }

    final idCtl = TextEditingController(text: initialNumber);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final activePrefix = getPrefixForCat(selectedCategory);

            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(_getCategoryIcon(selectedCategory), color: _getCategoryColor(selectedCategory), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    existing == null ? 'Add RCCB Equipment' : 'Edit Equipment Details',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Category Selector
                      DropdownButtonFormField<String>(
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Equipment Category',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: kCategories.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Row(
                              children: [
                                Icon(_getCategoryIcon(cat), color: _getCategoryColor(cat), size: 18),
                                const SizedBox(width: 8),
                                Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: existing != null
                            ? null
                            : (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedCategory = val;
                                    idCtl.text = suggestNextNumber(val);
                                    if (val == kCatWelding) {
                                      selectedDefaultRating = '100mA';
                                      sourceCtrl.text = 'Welding Feeder DB';
                                    } else {
                                      selectedDefaultRating = '30mA';
                                      sourceCtrl.text = 'LDB Panel Feed';
                                    }
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 12),

                      // 2. ID Field
                      TextFormField(
                        controller: idCtl,
                        decoration: InputDecoration(
                          prefixText: activePrefix,
                          prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: _getCategoryColor(selectedCategory)),
                          labelText: '$selectedCategory ID Number',
                          border: const OutlineInputBorder(),
                          helperText: 'Saved as: PLANT-UNIT-$activePrefix[Number]',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.contains('-')) {
                            return 'Input sequence only (e.g. 1, 2, 5B)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // 3. Default RCCB Rating
                      DropdownButtonFormField<String>(
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        value: selectedDefaultRating,
                        decoration: const InputDecoration(
                          labelText: 'Default RCCB Rating (Tripping Sensitivity)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.electric_meter_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: '30mA', child: Text('30mA (Personnel Shock Protection - Standard)')),
                          DropdownMenuItem(value: '100mA', child: Text('100mA (Welding / Equipment Protection - Heavy Duty)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedDefaultRating = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // 4. Location
                      TextFormField(
                        controller: locCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Physical Location / Bay',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // 5. Number of RCCBs
                      TextFormField(
                        controller: countCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Number of RCCB Breakers',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final val = int.tryParse(v);
                          if (val == null || val < 1) return 'Must be a positive integer';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // 6. Incoming Power Source
                      TextFormField(
                        controller: sourceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Incoming Power Source / Feeder',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.power_input),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // 7. Description
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description / Remarks (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
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
                      final rawId = '$activePrefix${idCtl.text.trim().toUpperCase()}';
                      final prefixedId = HierarchyService.prefixId(rawId, _selectedPlantId!, _selectedUnitId!);

                      final data = {
                        'id': prefixedId,
                        'category': selectedCategory,
                        'defaultRating': selectedDefaultRating,
                        'plantId': _selectedPlantId!,
                        'unitId': _selectedUnitId!,
                        'location': locCtrl.text.trim(),
                        'rccbCount': int.parse(countCtrl.text.trim()),
                        'incomingSource': sourceCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                      };

                      await _firestore.collection(kRccbEquipmentsCollection).doc(prefixedId).set(data, SetOptions(merge: true));
                      onSaved();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Equipment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteLdb(Map<String, dynamic> ldb, VoidCallback onDelete) {
    final rawId = HierarchyService.stripPrefix(ldb['id'], _selectedPlantId!, _selectedUnitId!);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Board / Outlet'),
        content: Text('Are you sure you want to delete "$rawId - ${ldb['location']}"? History logs will remain auditable in database.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await _firestore.collection(kRccbEquipmentsCollection).doc(ldb['id']).delete();
              onDelete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- QR Scanner Handler ---
  Future<void> _openQrScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerPage()),
    );

    if (result != null && result.isNotEmpty && mounted) {
      await _handleScannedRccbCode(result);
    }
  }

  Future<void> _handleScannedRccbCode(String rawCode) async {
    String cleanCode = rawCode.trim();
    if (cleanCode.toUpperCase().startsWith('RCCB:')) {
      cleanCode = cleanCode.substring(5).trim();
    }

    // Try finding in currently processed items first
    Map<String, dynamic>? found;
    for (final item in _processedLdbs) {
      final id = item['id'].toString().toUpperCase();
      final stripped = (item['displayId'] ?? '').toString().toUpperCase();
      if (id == cleanCode.toUpperCase() || stripped == cleanCode.toUpperCase()) {
        found = item;
        break;
      }
    }

    // If not found in current scope, query Firestore directly
    if (found == null) {
      try {
        final doc = await _firestore.collection(kRccbEquipmentsCollection).doc(cleanCode).get();
        if (doc.exists) {
          final data = doc.data()!;
          data['id'] = doc.id;
          data['category'] ??= kCatLdb;
          data['defaultRating'] ??= '30mA';
          data['displayId'] = HierarchyService.stripPrefix(doc.id, data['plantId'] ?? '', data['unitId'] ?? '');
          data['status'] = 'Registered';
          data['latestReport'] = null;
          data['history'] = [];
          found = data;
        }
      } catch (e) {
        debugPrint('Error finding scanned RCCB: $e');
      }
    }

    if (!mounted) return;

    if (found != null) {
      _showScannedEquipmentDetailsSheet(found);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text('Unrecognized Code'),
            ],
          ),
          content: Text('No RCCB equipment found matching code: "$cleanCode".\n\nWould you like to register a new board/outlet with this identifier?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(ctx);
                _showAddEditLdbDialog(null, () async {
                  await _loadDashboardMetricsAndLdbs();
                  setState(() {});
                });
              },
              child: const Text('Register Equipment'),
            ),
          ],
        ),
      );
    }
  }

  void _showScannedEquipmentDetailsSheet(Map<String, dynamic> equipment) {
    final rawId = equipment['displayId'] ?? equipment['id'];
    final category = equipment['category'] ?? kCatLdb;
    final rccbCount = equipment['rccbCount'] as int? ?? 1;
    final defaultRating = equipment['defaultRating'] ?? '30mA';
    final status = equipment['status'] ?? 'Never Tested';
    final location = equipment['location'] ?? 'No Location';
    final incomingSource = equipment['incomingSource'] ?? 'Panel Feed';
    final latestReport = equipment['latestReport'] as Map<String, dynamic>?;

    Color statusColor = Colors.grey;
    if (status == 'Compliant') statusColor = Colors.greenAccent;
    if (status == 'Failed') statusColor = Colors.redAccent;
    if (status == 'Overdue') statusColor = Colors.orangeAccent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getCategoryIcon(category), color: _getCategoryColor(category), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(rawId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(category).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                category.toUpperCase(),
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _getCategoryColor(category)),
                              ),
                            ),
                          ],
                        ),
                        Text(location, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
              const Divider(height: 24),

              // Specs Grid
              Row(
                children: [
                  Expanded(
                    child: _buildDetailTile('Incoming Feed', incomingSource, Icons.power_input),
                  ),
                  Expanded(
                    child: _buildDetailTile('Breakers', '$rccbCount Units ($defaultRating)', Icons.electric_meter_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailTile('Last Tested', latestReport != null ? _formatDate(DateTime.parse(latestReport['testingDate'])) : 'Never', Icons.calendar_today_outlined),
                  ),
                  Expanded(
                    child: _buildDetailTile('Condition', equipment['ldbCondition'] ?? latestReport?['ldbCondition'] ?? 'Good', Icons.health_and_safety_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailTile('Next Due', equipment['nextDueDate'] != null ? _formatDate(equipment['nextDueDate']) : 'Immediate', Icons.alarm),
                  ),
                  Expanded(
                    child: _buildDetailTile('Audit Status', equipment['dueText'] ?? 'Immediate Audit Required', Icons.timer_outlined),
                  ),
                ],
              ),
              if (latestReport != null && latestReport['remarks'] != null && latestReport['remarks'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Remarks: ${latestReport['remarks']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
              ],
              const SizedBox(height: 20),

              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('View History', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        setState(() {
                          _historyLdb = equipment;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.print, size: 18, color: Colors.cyanAccent),
                      label: const Text('Print Tag', style: TextStyle(fontSize: 12, color: Colors.cyanAccent)),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _printCertificationTags(specificEquipments: [equipment]);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                label: Text(
                  status == 'Failed' || status == 'Overdue' ? 'Record Retest Checklist' : 'Record Audit Checklist',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  _startRecordOrEdit(equipment, null);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PRINT TAG OPTIONS (2x4 A4 Grid) ---
  Future<void> _printCertificationTags({List<Map<String, dynamic>>? specificEquipments}) async {
    final targets = specificEquipments ??
        (_selectedEquipmentIds.isNotEmpty
            ? _processedLdbs.where((e) => _selectedEquipmentIds.contains(e['id'])).toList()
            : _filteredEquipments);

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No equipment available to generate tags.')),
      );
      return;
    }

    _showPrintOptionsSheet(targets);
  }

  void _showPrintOptionsSheet(List<Map<String, dynamic>> targets) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.print_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Tag Print Format',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Printing ${targets.length} equipment tag(s) on optimized 2x4 A4 sheet',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Option 1: Periodic Audit Certification Tag
              _buildPrintOptionTile(
                icon: Icons.verified_rounded,
                iconColor: const Color(0xFF1B8755),
                title: 'Periodic Audit Certification Tags',
                badgeText: 'Audit Cycle: 3 Months',
                badgeColor: const Color(0xFF1B8755),
                description:
                    'Includes live test readings (1x & 5x tripping ms), last test date, 3-month next due date, technician name & compliance badge.',
                subNote: 'Re-printed after every 3-month periodic safety audit.',
                onTap: () {
                  Navigator.pop(ctx);
                  _generateTagsPdf(targets: targets, isPermanent: false);
                },
              ),
              const SizedBox(height: 12),

              // Option 2: Permanent Equipment ID Tag
              _buildPrintOptionTile(
                icon: Icons.qr_code_2_rounded,
                iconColor: const Color(0xFF2D3748),
                title: 'Permanent Equipment ID Tags',
                badgeText: 'Permanent • Static Data',
                badgeColor: const Color(0xFF2D3748),
                description:
                    'Durable identification plate with extra-large QR code, Equipment Name/ID, Location, Incomer/Feeder source & RCCB count/rating.',
                subNote: 'Permanent panel tag. Affix once — contains no test readings or expiry dates.',
                onTap: () {
                  Navigator.pop(ctx);
                  _generateTagsPdf(targets: targets, isPermanent: true);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrintOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String description,
    required String subNote,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border.all(color: iconColor.withOpacity(0.25), width: 1.2),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: iconColor.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.3),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 12, color: iconColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            subNote,
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: iconColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateTagsPdf({
    required List<Map<String, dynamic>> targets,
    required bool isPermanent,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Generating ${targets.length} ${isPermanent ? "Permanent ID" : "Audit"} Tags (2x4 A4 Grid)...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final pdf = await RccbCertificationTagPdfHelper.generateCertificationTagsPdf(
        equipments: targets,
        plantName: _selectedPlantId,
        unitName: _selectedUnitId,
        isPermanent: isPermanent,
      );

      final prefix = isPermanent ? 'Permanent_ID_Tags' : 'RCCB_Certification_Tags';
      final fileName = '${prefix}_${_selectedPlantId}_${_selectedUnitId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final bytes = await pdf.save();
      final path = await downloadFile(bytes, fileName);

      if (path != null && mounted) {
        _handleSavedFile(path, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating tags: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // --- Help Dialog for RCCB (IEC 61008 & 100mA Standards) ---
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
                  'RCCB Safety & Testing Standards Guide',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Residual Current Circuit Breakers (RCCBs) protect against fatal electric shock and electrical fire hazards in industrial plants. Routine safety testing is valid for 3 months (90 days / quarterly audit).',
            style: TextStyle(fontSize: 12.5, color: Colors.grey),
          ),
          const Divider(height: 24),

          // 1. Categories
          const Text('1. Equipment Application by Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amberAccent)),
          const SizedBox(height: 8),
          _buildHelpCategoryTile(
            title: 'Lighting Distribution Boards (LDB)',
            desc: 'Supplies facility lighting and auxiliary control circuits. Standard sensitivity rating is 30mA for personnel direct shock protection.',
            icon: Icons.lightbulb_outline,
            color: Colors.amberAccent,
          ),
          const SizedBox(height: 8),
          _buildHelpCategoryTile(
            title: 'Welding Outlets (Receptacles)',
            desc: 'Dedicated heavy-duty 3-phase/single-phase welding stations. Standard rating is 100mA to avoid nuisance tripping from welding arc harmonics and high transient surges while protecting against insulation breakdown.',
            icon: Icons.construction,
            color: Colors.purpleAccent,
          ),
          const SizedBox(height: 8),
          _buildHelpCategoryTile(
            title: 'Power Sockets (Utility & Heavy Sockets)',
            desc: 'General power points for hand tools, portable blowers, and machines. 30mA is mandated for 16A/20A portable power sockets; 100mA for dedicated 32A/63A industrial machinery outlets.',
            icon: Icons.power,
            color: Colors.tealAccent,
          ),
          const Divider(height: 24),

          // 2. Standards
          const Text('2. IEC 61008-1 / BS 7671 Tripping Standards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent)),
          const SizedBox(height: 10),
          _buildHelpItem(
            title: '30mA Rating (Human Safety / Direct Contact)',
            desc: '• 1x Test (30mA Fault): Must trip in <= 300 ms.\n'
                '• 5x Test (150mA Fault): Must trip in <= 40 ms for high-speed shock isolation.\n'
                '• Either 1x or 5x test is required; both readings can be recorded if tested.',
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 8),
          _buildHelpItem(
            title: '100mA Rating (Equipment & Fire Hazard Protection)',
            desc: '• 1x Test (100mA Fault): Must trip in <= 300 ms.\n'
                '• 5x Test (500mA Fault): Must trip in <= 40 ms under heavy earth fault conditions.\n'
                '• Either 1x or 5x test is required; both readings can be recorded if tested.',
            color: Colors.cyanAccent,
          ),
          const Divider(height: 24),

          // 3. Status Rules
          const Text('3. Audit Status Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.greenAccent)),
          const SizedBox(height: 8),
          const Text(
            '• COMPLIANT: Board audited within 3 months (90 days), and 100% of RCCBs passed recorded trip time limits (1x or 5x required; both tested if recorded).\n'
            '• FAILED: One or more RCCB breakers failed to trip within required thresholds. Requires immediate maintenance or breaker replacement.\n'
            '• OVERDUE: More than 3 months (90 days) since the last test, or test submitted without testing all breaker units.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
          const Divider(height: 24),

          // 4. Predefined Corrective Actions
          const Text('4. Predefined Corrective Actions for Retests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orangeAccent)),
          const SizedBox(height: 8),
          const Text(
            'When retesting a board, technicians can select multiple predefined corrective actions (e.g., Replaced breaker, tightened terminals, resolved ground fault) to maintain accurate maintenance logs.',
            style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHelpCategoryTile({required String title, required String desc, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 3),
                Text(desc, style: const TextStyle(fontSize: 10.5, color: Colors.white70, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem({required String title, required String desc, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        border: Border.all(color: Colors.grey.shade800),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.35)),
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
                    await Share.shareXFiles([XFile(path)], text: 'RCCB Report: $fileName');
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
      final rawId = ldb['displayId'] ?? ldb['id'];
      final category = ldb['category'] ?? kCatLdb;

      final rccbLogs = latest != null ? (latest['rccbLogs'] as List<dynamic>? ?? []) : [];
      final lastTestedStr = latest != null ? _formatDate(DateTime.parse(latest['testingDate'])) : 'Never';

      if (rccbLogs.isEmpty) {
        excelData.add({
          'Category': category,
          'Equipment ID': rawId,
          'Location': ldb['location'] ?? '',
          'Incoming Source': ldb['incomingSource'] ?? '',
          'No of RCCBs': ldb['rccbCount'] ?? 0,
          'Default Rating': ldb['defaultRating'] ?? '30mA',
          'Condition': ldb['ldbCondition'] ?? 'Good',
          'Overall Status': ldb['status'],
          'Last Tested': lastTestedStr,
          'RCCB No': '-',
          'Rating': '-',
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
            'Category': category,
            'Equipment ID': rawId,
            'Location': ldb['location'] ?? '',
            'Incoming Source': ldb['incomingSource'] ?? '',
            'No of RCCBs': ldb['rccbCount'] ?? 0,
            'Default Rating': ldb['defaultRating'] ?? '30mA',
            'Condition': ldb['ldbCondition'] ?? 'Good',
            'Overall Status': ldb['status'],
            'Last Tested': lastTestedStr,
            'RCCB No': 'RCCB-${log['rccbNo']}',
            'Rating': log['rating'] ?? '30mA',
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

    final bytes = ExcelService().generateExcel(excelData, 'RCCB Safety Report');
    if (bytes != null) {
      final fileName = 'RCCB_Safety_Report_${_selectedPlantId}_$_selectedUnitId.xlsx';
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
                    pw.Text(_hierarchyService.businessName, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('PERIODICAL RCCB SAFETY AUDIT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blue800)),
                    pw.Text('Standards Reference: IEC 61008-1 / BS 7671', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 8),

            // Plant / Scope metadata
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Plant: $_selectedPlantId | Unit: $_selectedUnitId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('Report Date: ${_formatDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Summary Metrics
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfStatItem('Total Boards/Outlets', '$_totalLdbsCount'),
                _pdfStatItem('Compliant (Valid)', '$_completedLdbsCount', color: PdfColors.green800),
                _pdfStatItem('Due Soon (<=15d)', '$_dueSoonLdbsCount', color: PdfColors.amber800),
                _pdfStatItem('Overdue (>90d)', '$_overdueLdbsCount', color: PdfColors.orange800),
                _pdfStatItem('Failed Points', '$_failedLdbsCount', color: PdfColors.red800),
                _pdfStatItem('Audit Coverage', '${_coveragePercentage.toStringAsFixed(1)}%'),
              ],
            ),
            pw.SizedBox(height: 16),

            // Table of Equipment & Breakers
            pw.Text('AUDITED EQUIPMENT & BREAKER TEST DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 6),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                  children: [
                    _pdfTableCellHelper('Category', isHeader: true),
                    _pdfTableCellHelper('ID & Location', isHeader: true),
                    _pdfTableCellHelper('Incoming Feed', isHeader: true),
                    _pdfTableCellHelper('RCCBs', isHeader: true),
                    _pdfTableCellHelper('Last Test', isHeader: true),
                    _pdfTableCellHelper('Status', isHeader: true),
                    _pdfTableCellHelper('Audited By', isHeader: true),
                  ],
                ),
                ..._processedLdbs.map((item) {
                  final rawId = item['displayId'] ?? item['id'];
                  final latest = item['latestReport'] as Map<String, dynamic>?;
                  final status = item['status'] as String;
                  final category = item['category'] ?? kCatLdb;

                  PdfColor statusColor = PdfColors.grey700;
                  if (status == 'Compliant') statusColor = PdfColors.green800;
                  if (status == 'Failed') statusColor = PdfColors.red800;
                  if (status == 'Overdue') statusColor = PdfColors.orange800;

                  return pw.TableRow(
                    children: [
                      _pdfTableCellHelper(category),
                      _pdfTableCellHelper('$rawId\n${item['location'] ?? ""}'),
                      _pdfTableCellHelper(item['incomingSource'] ?? '-'),
                      _pdfTableCellHelper('${item['rccbCount'] ?? 0} (${item['defaultRating'] ?? '30mA'})'),
                      _pdfTableCellHelper(latest != null ? _formatDate(DateTime.parse(latest['testingDate'])) : 'Never'),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          status.toUpperCase(),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: statusColor),
                        ),
                      ),
                      _pdfTableCellHelper(latest?['testedBy'] ?? '-'),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),

            // Signatures block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(width: 140, child: pw.Divider(thickness: 0.8)),
                    pw.Text('Inspected By: $_currentUserName', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Electrical Testing Engineer', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(width: 140, child: pw.Divider(thickness: 0.8)),
                    pw.Text('Verified By: Head of Electrical (QA)', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Plant Maintenance Lead', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final fileName = 'RCCB_Safety_Audit_Report_${_selectedPlantId}_${_selectedUnitId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final bytes = await pdf.save();
    final path = await downloadFile(bytes, fileName);
    if (path != null && mounted) {
      _handleSavedFile(path, fileName);
    }
  }

  pw.Widget _pdfStatItem(String label, String value, {PdfColor color = PdfColors.black}) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: color)),
        pw.SizedBox(height: 2),
        pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _pdfTableCellHelper(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.blueGrey900 : PdfColors.black,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  // --- Start Record / Edit Checklist ---
  void _startRecordOrEdit(Map<String, dynamic> ldb, Map<String, dynamic>? existingReport) {
    _disposeTimeControllers();

    setState(() {
      _selectedLdb = ldb;
      _editingReportId = existingReport?['id'];
      _ldbCondition = existingReport?['ldbCondition'] ?? ldb['ldbCondition'] ?? 'Good';
      _checkType = existingReport?['checkType'] ?? (ldb['status'] == 'Failed' || ldb['status'] == 'Overdue' ? 'Retest' : 'Routine');
      _remarksController.text = existingReport?['remarks'] ?? '';
      _actionTakenController.text = existingReport?['actionTaken'] ?? '';
      _testDate = existingReport != null ? DateTime.parse(existingReport['testingDate']) : DateTime.now();

      // Parse existing corrective actions
      _selectedCorrectiveActions.clear();
      final existingActionText = _actionTakenController.text;
      for (var action in kPredefinedCorrectiveActions) {
        if (existingActionText.contains(action)) {
          _selectedCorrectiveActions.add(action);
        }
      }

      final currentRccbCount = ldb['rccbCount'] as int? ?? 0;
      final rccbLogs = existingReport?['rccbLogs'] as List<dynamic>? ?? [];
      final defaultRating = ldb['defaultRating'] ?? '30mA';

      for (int i = 1; i <= currentRccbCount; i++) {
        _checklistState.poleTypes[i] = '2P';
        _checklistState.ratings[i] = defaultRating;
        _checklistState.timeControllers1x[i] = TextEditingController();
        _checklistState.timeControllers5x[i] = TextEditingController();
        _checklistState.replacedFlags[i] = false;
      }

      for (var log in rccbLogs) {
        final rIdx = log['rccbNo'] as int;
        if (rIdx <= currentRccbCount) {
          _checklistState.poleTypes[rIdx] = log['poleType'] ?? '2P';
          _checklistState.ratings[rIdx] = log['rating'] ?? defaultRating;
          _checklistState.timeControllers1x[rIdx]?.text = log['trippingTime1x']?.toString() ?? '';
          _checklistState.timeControllers5x[rIdx]?.text = log['trippingTime5x']?.toString() ?? '';
          _checklistState.replacedFlags[rIdx] = log['replaced'] == true;
        }
      }
    });
  }

  void _toggleCorrectiveAction(String action) {
    setState(() {
      if (_selectedCorrectiveActions.contains(action)) {
        _selectedCorrectiveActions.remove(action);
      } else {
        _selectedCorrectiveActions.add(action);
      }

      // Reconstruct action controller text
      if (_selectedCorrectiveActions.isEmpty) {
        _actionTakenController.text = '';
      } else {
        _actionTakenController.text = _selectedCorrectiveActions.join(', ');
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

      if (t1xStr.isEmpty && t5xStr.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter at least 1x or 5x tripping time for RCCB unit $i')),
        );
        return;
      }

      double? t1x;
      if (t1xStr.isNotEmpty) {
        t1x = double.tryParse(t1xStr);
        if (t1x == null || t1x <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid positive numeric 1x trip time for RCCB unit $i')),
          );
          return;
        }
      }

      double? t5x;
      if (t5xStr.isNotEmpty) {
        t5x = double.tryParse(t5xStr);
        if (t5x == null || t5x <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid positive numeric 5x trip time for RCCB unit $i')),
          );
          return;
        }
      }

      // Standard IEC 61008 testing condition:
      // 1x trip time limit: <= 300ms; 5x trip time limit: <= 40ms.
      // Either 1x or 5x is required; both can be recorded if tested.
      final rating = _checklistState.ratings[i] ?? '30mA';
      final bool pass1x = t1x == null || t1x <= 300.0;
      final bool pass5x = t5x == null || t5x <= 40.0;
      final bool isPass = pass1x && pass5x;

      logs.add({
        'rccbNo': i,
        'rating': rating,
        'poleType': _checklistState.poleTypes[i] ?? '2P',
        'trippingTime1x': t1x,
        'trippingTime5x': t5x,
        'result': isPass ? 'Pass' : 'Fail',
        'replaced': _checklistState.replacedFlags[i] ?? false,
      });
    }

    setState(() => _isSubmitting = true);

    try {
      final rawId = _selectedLdb!['displayId'] ?? HierarchyService.stripPrefix(_selectedLdb!['id'], _selectedPlantId!, _selectedUnitId!);
      final reportId = _editingReportId ?? const Uuid().v4();
      final bool isEdit = _editingReportId != null;

      final reportData = {
        'id': reportId,
        'ldbId': _selectedLdb!['id'],
        'ldbName': rawId,
        'category': _selectedLdb!['category'] ?? kCatLdb,
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
        'selectedCorrectiveActions': _selectedCorrectiveActions.toList(),
      };

      if (isEdit) {
        reportData['lastModifiedBy'] = _currentUserName;
        reportData['lastModifiedAt'] = DateTime.now().toIso8601String();
      }

      await _firestore.collection('rccb_test_reports').doc(reportId).set(reportData);

      // Update physical condition inside rccb_equipments
      await _firestore.collection(kRccbEquipmentsCollection).doc(_selectedLdb!['id']).set({
        'ldbCondition': _ldbCondition,
      }, SetOptions(merge: true));

      await _loadDashboardMetricsAndLdbs();

      setState(() {
        _selectedLdb = null;
        _editingReportId = null;
        _remarksController.clear();
        _actionTakenController.clear();
        _selectedCorrectiveActions.clear();
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

  // Filtered equipments list getter
  List<Map<String, dynamic>> get _filteredEquipments {
    final query = _searchController.text.trim().toLowerCase();

    final list = _processedLdbs.where((item) {
      final loc = (item['location'] ?? '').toString().toLowerCase();
      final source = (item['incomingSource'] ?? '').toString().toLowerCase();
      final id = (item['displayId'] ?? item['id']).toString().toLowerCase();
      final cat = (item['category'] ?? kCatLdb).toString();
      final status = (item['status'] ?? '').toString();
      final isDueSoon = item['isDueSoon'] == true;

      final matchesQuery = query.isEmpty || loc.contains(query) || source.contains(query) || id.contains(query) || cat.toLowerCase().contains(query);
      final matchesCategory = _selectedCategoryFilter == 'All' || cat == _selectedCategoryFilter;

      bool matchesStatus = true;
      if (_selectedStatusFilter == 'Due Soon') {
        matchesStatus = isDueSoon;
      } else if (_selectedStatusFilter == 'Overdue') {
        matchesStatus = status == 'Overdue';
      } else if (_selectedStatusFilter == 'Compliant') {
        matchesStatus = status == 'Compliant';
      } else if (_selectedStatusFilter == 'Failed') {
        matchesStatus = status == 'Failed';
      } else if (_selectedStatusFilter == 'Never Tested') {
        matchesStatus = status == 'Never Tested';
      }

      return matchesQuery && matchesCategory && matchesStatus;
    }).toList();

    // Prioritize Due Soon / Overdue by urgency
    if (_selectedStatusFilter == 'Due Soon' || _selectedStatusFilter == 'Overdue') {
      list.sort((a, b) {
        final aDays = a['daysUntilDue'] as int? ?? -9999;
        final bDays = b['daysUntilDue'] as int? ?? -9999;
        return aDays.compareTo(bDays);
      });
    }

    return list;
  }

  // --- SKELETON SHIMMER VIEW ---
  Widget _buildSkeletonShimmerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scope selector skeleton
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

          // Metrics card skeleton
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1100.ms, color: Colors.white.withValues(alpha: 0.09)),
          const SizedBox(height: 16),

          // Search row skeleton
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1100.ms, color: Colors.white.withValues(alpha: 0.09)),
          const SizedBox(height: 16),

          // Cards skeleton
          ...List.generate(4, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 125,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
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
    if (_isLoading) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'RCCB Safety Checklist'),
        body: _buildSkeletonShimmerView(),
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
        floatingActionButton: (_selectedEquipmentIds.isNotEmpty && _selectedLdb == null && _historyLdb == null && !_isManagingLdbs && !_showHelp)
            ? FloatingActionButton.extended(
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.print, color: Colors.white),
                label: Text(
                  'Print ${_selectedEquipmentIds.length} Tags (2x4 A4)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _printCertificationTags(),
              ).animate().scale(curve: Curves.elasticOut)
            : null,
      ),
    );
  }

  Widget _buildLdbListView() {
    final filtered = _filteredEquipments;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Scope Selectors
          GlassContainer(
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
                      onChanged: _isPlantLocked
                          ? null
                          : (val) {
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
                      items: _units.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: _isUnitLocked
                          ? null
                          : (val) {
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
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05, end: 0),
          const SizedBox(height: 16),

          // 2. Metrics Card
          _buildMetricsDashboard()
              .animate()
              .fadeIn(duration: 350.ms)
              .scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1)),
          const SizedBox(height: 16),

          // 3. Category Filter Tabs
          _buildCategoryFilterTabs()
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 10),

          // 4. Status & Urgency Filter Chips (Due Soon, Overdue, etc.)
          _buildStatusFilterChips()
              .animate()
              .fadeIn(duration: 420.ms),
          const SizedBox(height: 14),

          // 4. Search & Actions Toolbar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search ID, location, feed, category...',
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

              // QR Code Scan Button in Page
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                tooltip: 'Scan Equipment QR Code',
                onPressed: _openQrScanner,
              ),
              const SizedBox(width: 4),

              // Multi-Select Tags Print Mode Toggle
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
                    if (!_isSelectionMode) _selectedEquipmentIds.clear();
                  });
                },
              ),
              const SizedBox(width: 4),

              // Help Guide Button
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.help_outline, color: Colors.white, size: 20),
                tooltip: 'RCCB Safety & Testing Guide',
                onPressed: () => setState(() => _showHelp = true),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 4),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.settings, color: Colors.white, size: 20),
                  tooltip: 'Manage Equipment',
                  onPressed: () => setState(() => _isManagingLdbs = true),
                ),
              ],
            ],
          ).animate().fadeIn(duration: 450.ms),
          const SizedBox(height: 14),

          // 5. Batch Selection Action Bar
          if (_isSelectionMode || _selectedEquipmentIds.isNotEmpty) ...[
            _buildSelectionActionBar(filtered)
                .animate()
                .fadeIn(duration: 250.ms)
                .slideY(begin: -0.1, end: 0),
            const SizedBox(height: 12),
          ],

          // 6. Section Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Safety Points (${filtered.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _exportExcelReport,
                    icon: const Icon(Icons.table_chart, size: 14, color: Colors.greenAccent),
                    label: const Text('Excel', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 2),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _exportPDFReport,
                    icon: const Icon(Icons.picture_as_pdf, size: 14, color: Colors.redAccent),
                    label: const Text('PDF', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 2),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _printCertificationTags(specificEquipments: filtered),
                    icon: const Icon(Icons.print, size: 14, color: Colors.cyanAccent),
                    label: const Text('Tags', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ).animate().fadeIn(duration: 480.ms),
          const SizedBox(height: 8),

          // 7. Equipment Cards List
          filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36.0),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          _availableLdbs.isEmpty
                              ? 'No boards registered for this unit. Tap the settings icon to add boards.'
                              : 'No equipment matched your filters.',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildEquipmentCard(item, index)
                        .animate(delay: (index * 20).ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.05, end: 0);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterTabs() {
    final counts = {
      'All': _processedLdbs.length,
      kCatLdb: _processedLdbs.where((e) => (e['category'] ?? kCatLdb) == kCatLdb).length,
      kCatWelding: _processedLdbs.where((e) => (e['category'] ?? kCatLdb) == kCatWelding).length,
      kCatPowerSocket: _processedLdbs.where((e) => (e['category'] ?? kCatLdb) == kCatPowerSocket).length,
    };

    final items = [
      {'key': 'All', 'label': 'All Points', 'icon': Icons.tune},
      {'key': kCatLdb, 'label': 'LDBs (Lighting)', 'icon': Icons.lightbulb_outline},
      {'key': kCatWelding, 'label': 'Welding Outlets', 'icon': Icons.construction},
      {'key': kCatPowerSocket, 'label': 'Power Sockets', 'icon': Icons.power},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: items.map((t) {
          final isSelected = _selectedCategoryFilter == t['key'];
          final count = counts[t['key']] ?? 0;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                t['icon'] as IconData,
                size: 14,
                color: isSelected ? Colors.black : Colors.grey,
              ),
              label: Text(
                '${t['label']} ($count)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              ),
              selected: isSelected,
              selectedColor: Colors.cyanAccent,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? Colors.cyanAccent : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              onSelected: (_) {
                setState(() => _selectedCategoryFilter = t['key'] as String);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusFilterChips() {
    final items = [
      {'key': 'All', 'label': 'All Status', 'count': _processedLdbs.length, 'color': Colors.cyanAccent, 'icon': Icons.tune},
      {'key': 'Due Soon', 'label': 'Due Soon', 'count': _dueSoonLdbsCount, 'color': Colors.amberAccent, 'icon': Icons.alarm},
      {'key': 'Overdue', 'label': 'Overdue', 'count': _overdueLdbsCount, 'color': Colors.orangeAccent, 'icon': Icons.history_toggle_off},
      {'key': 'Compliant', 'label': 'Compliant', 'count': _completedLdbsCount, 'color': Colors.greenAccent, 'icon': Icons.check_circle_outline},
      {'key': 'Failed', 'label': 'Failed', 'count': _failedLdbsCount, 'color': Colors.redAccent, 'icon': Icons.error_outline},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: items.map((t) {
          final isSelected = _selectedStatusFilter == t['key'];
          final count = t['count'] as int;
          final color = t['color'] as Color;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                t['icon'] as IconData,
                size: 13,
                color: isSelected ? Colors.black : color,
              ),
              label: Text(
                '${t['label']} ($count)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.black : (count > 0 && t['key'] != 'All' ? color : Colors.white70),
                ),
              ),
              selected: isSelected,
              selectedColor: color,
              backgroundColor: count > 0 && (t['key'] == 'Due Soon' || t['key'] == 'Overdue')
                  ? color.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? color
                      : (count > 0 && (t['key'] == 'Due Soon' || t['key'] == 'Overdue')
                          ? color.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              onSelected: (_) {
                setState(() => _selectedStatusFilter = t['key'] as String);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectionActionBar(List<Map<String, dynamic>> filtered) {
    final allSelected = filtered.isNotEmpty && filtered.every((e) => _selectedEquipmentIds.contains(e['id']));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.cyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            activeColor: Colors.cyanAccent,
            checkColor: Colors.black,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedEquipmentIds.addAll(filtered.map((e) => e['id'] as String));
                } else {
                  _selectedEquipmentIds.clear();
                }
              });
            },
          ),
          Text(
            '${_selectedEquipmentIds.length} Selected',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.cyanAccent),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedEquipmentIds.clear();
                _isSelectionMode = false;
              });
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.print, size: 14, color: Colors.white),
            label: const Text('Print Selected Tags', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
            onPressed: () => _printCertificationTags(),
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
                      Text('RCCB Safety Audit Coverage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Mandatory: 3-Month (Quarterly) 100% compliant trip safety', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildMetricColumn('Total Points', '$_totalLdbsCount', Colors.white, 'All'),
                  const SizedBox(width: 6),
                  _buildMetricColumn('Compliant', '$_completedLdbsCount', Colors.greenAccent, 'Compliant'),
                  const SizedBox(width: 6),
                  _buildMetricColumn('Due Soon', '$_dueSoonLdbsCount', Colors.amberAccent, 'Due Soon'),
                  const SizedBox(width: 6),
                  _buildMetricColumn('Overdue', '$_overdueLdbsCount', Colors.orangeAccent, 'Overdue'),
                  const SizedBox(width: 6),
                  _buildMetricColumn('Failed', '$_failedLdbsCount', Colors.redAccent, 'Failed'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color valColor, String filterKey) {
    final isSelected = _selectedStatusFilter == filterKey;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          if (_selectedStatusFilter == filterKey && filterKey != 'All') {
            _selectedStatusFilter = 'All';
          } else {
            _selectedStatusFilter = filterKey;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? valColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? valColor : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: valColor)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? valColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentCard(Map<String, dynamic> item, int index) {
    final status = item['status'] as String;
    final rccbCount = item['rccbCount'] as int? ?? 0;
    final defaultRating = item['defaultRating'] ?? '30mA';
    final latestReport = item['latestReport'] as Map<String, dynamic>?;
    final rawId = item['displayId'] ?? item['id'];
    final category = item['category'] ?? kCatLdb;
    final isSelected = _selectedEquipmentIds.contains(item['id']);
    final bool isDueSoon = item['isDueSoon'] == true;
    final String dueText = item['dueText'] ?? '';
    final DateTime? nextDueDate = item['nextDueDate'] as DateTime?;

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;

    switch (status) {
      case 'Compliant':
        if (isDueSoon) {
          statusColor = Colors.amberAccent;
          statusIcon = Icons.alarm;
        } else {
          statusColor = Colors.greenAccent;
          statusIcon = Icons.check_circle_outline;
        }
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
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.hourglass_empty;
        break;
    }

    final String lastTestedStr = latestReport != null ? _formatDate(DateTime.parse(latestReport['testingDate'])) : 'Never';
    final String nextDueStr = nextDueDate != null ? _formatDate(nextDueDate) : 'Immediate';
    final cond = item['ldbCondition'] ?? latestReport?['ldbCondition'] ?? 'Good';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? Colors.cyanAccent : Colors.white.withValues(alpha: 0.05),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    activeColor: Colors.cyanAccent,
                    checkColor: Colors.black,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedEquipmentIds.add(item['id']);
                        } else {
                          _selectedEquipmentIds.remove(item['id']);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getCategoryIcon(category), color: _getCategoryColor(category), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '$rawId - ${item['location'] ?? ""}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(category).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _getCategoryColor(category).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: _getCategoryColor(category)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Incoming Feed: ${item['incomingSource'] ?? "-"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 3),
                      Text('RCCB Breakers: $rccbCount unit(s) • $defaultRating Rating', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      // Due Status Urgency Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                status == 'Overdue'
                                    ? '$dueText (Due: $nextDueStr)'
                                    : (isDueSoon
                                        ? 'Due Soon • $dueText'
                                        : (status == 'Compliant'
                                            ? 'Valid • $dueText'
                                            : (status == 'Failed'
                                                ? 'Limit Exceeded • Retest Needed'
                                                : 'Initial Audit Due • Never Tested'))),
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        isDueSoon && status == 'Compliant' ? 'DUE SOON' : status.toUpperCase(),
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last Tested: $lastTestedStr', style: const TextStyle(fontSize: 10.5, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        status == 'Never Tested'
                            ? 'Next Due: Immediate'
                            : 'Next Due: $nextDueStr',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: status == 'Overdue'
                              ? Colors.orangeAccent
                              : (isDueSoon ? Colors.amberAccent : (status == 'Compliant' ? Colors.greenAccent : Colors.grey)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('Condition: $cond', style: const TextStyle(fontSize: 10.5, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (latestReport != null && latestReport['checkType'] == 'Retest')
                        const Text(
                          'Retest Completed',
                          style: TextStyle(fontSize: 9.5, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Single Tag Print Button
                    IconButton(
                      icon: const Icon(Icons.print, size: 18, color: Colors.cyanAccent),
                      tooltip: 'Print Equipment Tag',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _printCertificationTags(specificEquipments: [item]),
                    ),
                    // History Button
                    IconButton(
                      icon: const Icon(Icons.history, size: 18),
                      tooltip: 'View History & Edit Logs',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => setState(() {
                        _historyLdb = item;
                      }),
                    ),
                    const SizedBox(width: 2),
                    // Test / Retest Action Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor.withValues(alpha: 0.15),
                        foregroundColor: statusColor,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(
                        status == 'Failed'
                            ? Icons.build
                            : (status == 'Overdue'
                                ? Icons.history_toggle_off
                                : (isDueSoon ? Icons.alarm : (status == 'Never Tested' ? Icons.play_arrow : Icons.add_chart))),
                        size: 14,
                      ),
                      label: Text(
                        status == 'Failed'
                            ? 'Retest'
                            : (status == 'Never Tested' ? 'Test Now' : 'Test'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _startRecordOrEdit(item, null),
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

  // --- History View with Categories & Predefined Actions ---
  Widget _buildHistoryView() {
    final List<dynamic> history = _historyLdb!['history'] ?? [];
    final rawId = _historyLdb!['displayId'] ?? HierarchyService.stripPrefix(_historyLdb!['id'], _selectedPlantId!, _selectedUnitId!);
    final category = _historyLdb!['category'] ?? kCatLdb;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Test History: $rawId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(category).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _getCategoryColor(category)),
                          ),
                        ),
                      ],
                    ),
                    Text('Location: ${_historyLdb!['location'] ?? "No Location"} | Incoming: ${_historyLdb!['incomingSource'] ?? "-"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.print, color: Colors.cyanAccent),
                tooltip: 'Print Tag for this Equipment',
                onPressed: () => _printCertificationTags(specificEquipments: [_historyLdb!]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          history.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 36.0),
                    child: Text('No historical logs found for this equipment.'),
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
                    final correctiveActions = (rep['selectedCorrectiveActions'] as List<dynamic>?)?.cast<String>() ?? [];

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                    Text(_formatDate(testingDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: checkTypeStr == 'Retest' ? Colors.blue.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        checkTypeStr.toUpperCase(),
                                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: checkTypeStr == 'Retest' ? Colors.blueAccent : Colors.white70),
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
                                    isFail ? '$failCount BREAKER(S) FAILED' : 'ALL BREAKERS PASSED',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isFail ? Colors.redAccent : Colors.greenAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Board Condition: ${rep['ldbCondition'] ?? "Good"}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),

                            // Corrective Actions Badges for Retest
                            if (checkTypeStr == 'Retest') ...[
                              const SizedBox(height: 6),
                              if (correctiveActions.isNotEmpty) ...[
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: correctiveActions.map((act) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        '✓ $act',
                                        style: const TextStyle(fontSize: 9.5, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 4),
                              ],
                              if (rep['actionTaken'] != null && rep['actionTaken'].toString().isNotEmpty)
                                Text('Corrective Action Notes: "${rep['actionTaken']}"', style: const TextStyle(fontSize: 10.5, color: Colors.blueAccent)),
                            ],
                            const Divider(height: 14),

                            // Breakers Test Table with Ratings
                            Table(
                              border: TableBorder.all(color: Colors.grey.shade800, width: 0.5),
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3)),
                                  children: const [
                                    Padding(padding: EdgeInsets.all(4), child: Text('Breaker', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(4), child: Text('Rating', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(4), child: Text('Pole', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(4), child: Text('1x Trip', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(4), child: Text('5x Trip', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(4), child: Text('Status', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                ...rccbLogs.map((log) {
                                  final rating = log['rating'] ?? '30mA';
                                  final t1x = log['trippingTime1x'] != null ? '${log['trippingTime1x']} ms' : '-';
                                  final t5x = log['trippingTime5x'] != null ? '${log['trippingTime5x']} ms' : '-';
                                  final itemPass = log['result'] == 'Pass';
                                  return TableRow(
                                    children: [
                                      Padding(padding: const EdgeInsets.all(4), child: Text('RCCB-${log['rccbNo']}', style: const TextStyle(fontSize: 8.5))),
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(rating, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: rating == '100mA' ? Colors.cyanAccent : Colors.white70)),
                                      ),
                                      Padding(padding: const EdgeInsets.all(4), child: Text('${log['poleType'] ?? "2P"}', style: const TextStyle(fontSize: 8.5))),
                                      Padding(padding: const EdgeInsets.all(4), child: Text(t1x, style: const TextStyle(fontSize: 8.5))),
                                      Padding(padding: const EdgeInsets.all(4), child: Text(t5x, style: const TextStyle(fontSize: 8.5))),
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(
                                          log['result'] ?? 'Pass',
                                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: itemPass ? Colors.greenAccent : Colors.redAccent),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),

                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Tested By: ${rep['testedBy']}', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                      if (rep['remarks'] != null && rep['remarks'].toString().isNotEmpty)
                                        Text('Remarks: ${rep['remarks']}', style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic)),
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
                                          setState(() => _historyLdb = null);
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
                    ).animate(delay: (idx * 20).ms).fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
                  },
                ),
        ],
      ),
    );
  }

  // --- Manage Boards / Outlets View ---
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
                onPressed: () => setState(() => _isManagingLdbs = false),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Manage RCCB Equipment Registry',
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
                  label: const Text('Add Equipment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                          collectionId: kRccbEquipmentsCollection,
                          title: 'RCCB Equipment Registry',
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
          const SizedBox(height: 14),

          // Search in Manage / Settings View
          TextField(
            controller: _manageSearchController,
            decoration: InputDecoration(
              hintText: 'Search equipment ID, location, feed...',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              isDense: true,
              suffixIcon: _manageSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => setState(() => _manageSearchController.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          // Category Filter Tabs in Manage / Settings View
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                {'key': 'All', 'label': 'All Points', 'icon': Icons.tune},
                {'key': kCatLdb, 'label': 'LDBs', 'icon': Icons.lightbulb_outline},
                {'key': kCatWelding, 'label': 'Welding Outlets', 'icon': Icons.construction},
                {'key': kCatPowerSocket, 'label': 'Power Sockets', 'icon': Icons.power},
              ].map((t) {
                final isSelected = _manageCategoryFilter == t['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    avatar: Icon(t['icon'] as IconData, size: 13, color: isSelected ? Colors.black : Colors.grey),
                    label: Text(
                      t['label'] as String,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.cyanAccent,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: isSelected ? Colors.cyanAccent : Colors.white.withValues(alpha: 0.1)),
                    ),
                    onSelected: (_) {
                      setState(() => _manageCategoryFilter = t['key'] as String);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 20),

          Builder(builder: (context) {
            final mQuery = _manageSearchController.text.trim().toLowerCase();
            final filteredManage = _availableLdbs.where((item) {
              final rawId = HierarchyService.stripPrefix(item['id'], _selectedPlantId!, _selectedUnitId!).toLowerCase();
              final loc = (item['location'] ?? '').toString().toLowerCase();
              final source = (item['incomingSource'] ?? '').toString().toLowerCase();
              final cat = (item['category'] ?? kCatLdb).toString();

              final matchesQuery = mQuery.isEmpty || rawId.contains(mQuery) || loc.contains(mQuery) || source.contains(mQuery);
              final matchesCat = _manageCategoryFilter == 'All' || cat == _manageCategoryFilter;
              return matchesQuery && matchesCat;
            }).toList();

            if (filteredManage.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No equipment matched filters. Add one above!'),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredManage.length,
              itemBuilder: (context, idx) {
                final item = filteredManage[idx];
                final rawId = HierarchyService.stripPrefix(item['id'], _selectedPlantId!, _selectedUnitId!);
                final category = item['category'] ?? kCatLdb;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(category).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getCategoryIcon(category), color: _getCategoryColor(category), size: 18),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$rawId - ${item['location'] ?? "No Location"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(category).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: _getCategoryColor(category)),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'RCCBs: ${item['rccbCount'] ?? 0} (${item['defaultRating'] ?? '30mA'}) | Source: ${item['incomingSource'] ?? "-"}',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.amberAccent, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showAddEditLdbDialog(item, () async {
                            await _loadDashboardMetricsAndLdbs();
                            setState(() {});
                          }),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _confirmDeleteLdb(item, () async {
                            await _loadDashboardMetricsAndLdbs();
                            setState(() {});
                          }),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  // --- Testing Form View with 30mA / 100mA Selection & Predefined Corrective Actions ---
  Widget _buildTestingFormView() {
    final rawId = _selectedLdb!['displayId'] ?? HierarchyService.stripPrefix(_selectedLdb!['id'], _selectedPlantId!, _selectedUnitId!);
    final category = _selectedLdb!['category'] ?? kCatLdb;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isEdit ? 'Edit Report: $rawId' : 'Test $category: $rawId',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(category).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _getCategoryColor(category)),
                          ),
                        ),
                      ],
                    ),
                    Text('Location: ${_selectedLdb!['location'] ?? ""}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Equipment Specifications
          GlassContainer(
            borderRadius: 16,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$category Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: _getCategoryColor(category))),
                      Text('Default Rating: ${_selectedLdb!['defaultRating'] ?? '30mA'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                    ],
                  ),
                  const Divider(height: 14),
                  _buildLdbSpecRow('Location Description:', _selectedLdb!['location'] ?? ''),
                  _buildLdbSpecRow('RCCB Quantity:', '${_selectedLdb!['rccbCount'] ?? 0} breaker units'),
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
                // Inspection Check Type Selector
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
                const SizedBox(height: 14),

                // Corrective Actions Section
                if (_checkType == 'Retest') ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.build_circle_outlined, size: 15, color: Colors.blueAccent),
                            SizedBox(width: 6),
                            Text('Corrective Action:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: kPredefinedCorrectiveActions.map((action) {
                              final isSelected = _selectedCorrectiveActions.contains(action);
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  label: Text(action, style: TextStyle(fontSize: 10, color: isSelected ? Colors.black : Colors.white70)),
                                  selected: isSelected,
                                  selectedColor: Colors.blueAccent,
                                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                                  checkmarkColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (_) => _toggleCorrectiveAction(action),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _actionTakenController,
                          decoration: const InputDecoration(
                            labelText: 'Action Taken *',
                            hintText: 'Select actions above or type custom details',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            errorStyle: TextStyle(fontSize: 10),
                          ),
                          maxLines: 2,
                          validator: (v) => _checkType == 'Retest' && (v == null || v.trim().isEmpty) ? 'Corrective action is required for Retest' : null,
                        ),
                      ],
                    ),
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
                  decoration: const InputDecoration(labelText: 'Physical Condition', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Good', child: Text('Good (Clean & Securely Mounted)')),
                    DropdownMenuItem(value: 'Fair', child: Text('Fair (Minor Dust / Cleaning Needed)')),
                    DropdownMenuItem(value: 'Poor', child: Text('Poor (Repair / Re-wiring Required)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _ldbCondition = v);
                  },
                ),
                const SizedBox(height: 12),

                // Tester field pre-filled and LOCKED
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
    final currentRating = _checklistState.ratings[rccbNo] ?? '30mA';
    final is100mA = currentRating == '100mA';

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
                  Row(
                    children: [
                      Text(
                        'RCCB Unit $rccbNo',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: is100mA ? Colors.cyan.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          currentRating,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: is100mA ? Colors.cyanAccent : Colors.amberAccent,
                          ),
                        ),
                      ),
                    ],
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
                            if (t1x == null || t1x <= 0) return const Text('Invalid 1x', style: TextStyle(color: Colors.redAccent, fontSize: 10));
                            final ok1x = t1x <= 300.0;
                            pass = pass && ok1x;
                            statusText += '1x: ${ok1x ? "Pass" : "Fail"} ';
                          }
                          if (t5xStr.isNotEmpty) {
                            final t5x = double.tryParse(t5xStr);
                            if (t5x == null || t5x <= 0) return const Text('Invalid 5x', style: TextStyle(color: Colors.redAccent, fontSize: 10));
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
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              const Divider(height: 12),

              Row(
                children: [
                  // Pole Selection
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      value: _checklistState.poleTypes[rccbNo],
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Pole',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: '2P', child: Text('2P (Single Phase)')),
                        DropdownMenuItem(value: '4P', child: Text('4P (Three Phase)')),
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

                  // Rating Selection (30mA vs 100mA) with Default to 30mA
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      value: currentRating,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'RCCB Rating',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: '30mA', child: Text('30mA (Personnel)')),
                        DropdownMenuItem(value: '100mA', child: Text('100mA (Welding/Equip)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _checklistState.ratings[rccbNo] = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tripping Time Input Row with Standards
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _checklistState.timeControllers1x[rccbNo],
                      decoration: InputDecoration(
                        labelText: is100mA ? '1x Trip Time (ms) [100mA]' : '1x Trip Time (ms) [30mA]',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        helperText: 'Limit <= 300ms (1x or 5x req.)',
                        helperStyle: const TextStyle(fontSize: 8.5),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _checklistState.timeControllers5x[rccbNo],
                      decoration: InputDecoration(
                        labelText: is100mA ? '5x Trip Time (ms) [500mA]' : '5x Trip Time (ms) [150mA]',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        helperText: 'Limit <= 40ms (1x or 5x req.)',
                        helperStyle: const TextStyle(fontSize: 8.5),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Replaced breaker during test?', style: TextStyle(fontSize: 12)),
                  Switch(
                    activeColor: AppColors.primaryLight,
                    value: _checklistState.replacedFlags[rccbNo] ?? false,
                    onChanged: (val) {
                      setState(() {
                        _checklistState.replacedFlags[rccbNo] = val;
                      });
                    },
                  ),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
