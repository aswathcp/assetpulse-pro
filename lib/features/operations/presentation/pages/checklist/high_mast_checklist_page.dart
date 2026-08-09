// ignore_for_file: deprecated_member_use

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

// PDF, Excel & Export dependencies
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:asset_pulse_pro/core/services/excel_service.dart';
import 'package:asset_pulse_pro/core/utils/file_download_helper.dart';
import 'package:asset_pulse_pro/features/operations/data/models/high_mast_tower_model.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/data_import_page.dart';
import 'package:asset_pulse_pro/core/widgets/responsive_layout.dart';

class HighMastChecklistPage extends StatefulWidget {
  const HighMastChecklistPage({super.key});

  @override
  State<HighMastChecklistPage> createState() => _HighMastChecklistPageState();
}

class _HighMastChecklistPageState extends State<HighMastChecklistPage> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;

  // Navigation State
  HighMastTowerModel? _historyTower;
  bool _isManagingDatabase = false;
  bool _showHelp = false;

  // Scope State
  String? _selectedPlantId;
  String? _selectedUnitId;
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  bool _isLoading = true;
  String? _userPlantId;
  String? _userUnitId;
  bool _isAdmin = false;
  String _currentUserName = 'Inspector';

  final List<String> _gearboxOilOptions = [
    'OK',
    'Filling Done',
    'Overhauled',
  ];

  final List<String> _panelConditionOptions = [
    'OK',
    'NOT OK',
    'DAMAGED',
  ];

  // Filters
  String _filterStatus = 'All';
  String _filterQuarter = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Loaded Collections Data
  List<HighMastTowerModel> _towers = [];
  List<HighMastReportModel> _reports = [];

  // Form State
  final _formKey = GlobalKey<FormState>();
  HighMastTowerModel? _selectedTowerForInspection;

  final TextEditingController _testedByController = TextEditingController();
  final TextEditingController _bulldogClampRemarksController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  String _selectedGearboxOil = 'OK';
  String _selectedPanelCondition = 'OK';

  final DateTime _testDate = DateTime.now();
  String _selectedQuarter = '';
  Map<String, bool> _checkpointStates = {};
  Map<String, String> _checkpointRemarks = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedQuarter = _getQuarterString(DateTime.now());
    _loadScopeAndData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _testedByController.dispose();
    _bulldogClampRemarksController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  String _generateTagCode({
    required String plant,
    required String unit,
    required String seqNo,
  }) {
    final seqStr = seqNo.trim().isEmpty ? '001' : seqNo.trim();
    return '$plant-$unit-HMT-$seqStr';
  }

  String _getNextSeqNo() {
    int maxSeq = 0;
    for (var t in _towers) {
      final parts = t.tagId.split('-');
      if (parts.isNotEmpty) {
        final seqInt = int.tryParse(parts.last) ?? 0;
        if (seqInt > maxSeq) maxSeq = seqInt;
      }
    }
    return (maxSeq + 1).toString().padLeft(3, '0');
  }

  bool _isTagIdExists(String tagId) {
    return _towers.any((t) => t.tagId.toUpperCase() == tagId.trim().toUpperCase());
  }

  String _getQuarterString(DateTime date) {
    final year = date.year;
    final month = date.month;
    if (month >= 1 && month <= 3) return '$year-Q1';
    if (month >= 4 && month <= 6) return '$year-Q2';
    if (month >= 7 && month <= 9) return '$year-Q3';
    return '$year-Q4';
  }

  List<String> _getCheckpoints() {
    return const [
      '1. Lowering trial of luminaire carriage ring to bottom maintenance landing',
      '2. Raising trial of carriage ring and secure docking into top latching mechanism',
      '3. Foundation anchor bolts condition, double hex nuts tightness & base flange weld check',
      '4. Raise / Lower internal hoist motor condition, insulation & torque limiter',
      '5. Dual-drum worm gearbox and mechanical winch condition',
      '6. Gearbox oil level check, top-up and zero oil leakage',
      '7. Sprocket and chain condition, tensioning and graphite greasing',
      '8. Wire rope (IS 2266) condition (no kinks, broken strands, bird-caging or corrosion)',
      '9. Wire rope anti-corrosive marine greasing & dressing',
      '10. Bulldog clamp condition, duplex wire rope grip tightness & replacement check',
      '11. Light fitting and lantern carriage overhauling & safety sling check',
      '12. Check whether all floodlights are working or not (active working vs fused check)',
      '13. Gearbox weatherproof rain protection hood & canopy latch seal',
      '14. Main power trailing cable (EPR/PCP insulated) condition & twist-free routing',
      '15. High mast starter cleaning, contactor contact tips & terminal tightness',
      '16. Auto ON/OFF trial, astronomical timer & lux photocell dusk-to-dawn switching',
      '17. Base feeder control panel condition (door gasket, IP65 sealing & earthing)',
      '18. Aviation obstruction light (AOL) flashing red beacon atop mast apex',
      '19. High mast verticality alignment, mast shaft galvanizing & door locking',
      '20. Check tower identification tag number & quarterly certification label',
    ];
  }

  void _initializeCheckpoints() {
    final list = _getCheckpoints();
    _checkpointStates = {for (var item in list) item: true};
    _checkpointRemarks = {for (var item in list) item: ''};
  }

  Future<void> _loadScopeAndData() async {
    setState(() => _isLoading = true);
    final user = AuthService().currentUser;
    if (user != null) {
      final profile = await _firestoreService.getUserProfile(user.uid);
      if (profile != null) {
        final role = profile['role'] ?? AppRoles.guest;
        _userPlantId = profile['plantId'] as String?;
        _userUnitId = profile['unitId'] as String?;
        _isAdmin = profile['isAdmin'] == true || role == AppRoles.developer;
        _currentUserName = profile['displayName'] ?? profile['name'] ?? profile['fullName'] ?? 'Inspector';
        _testedByController.text = _currentUserName;
        final userBusinessId = profile['businessId'] as String? ?? 'VISL';

        await HierarchyService().init(businessId: userBusinessId);
        _plants = HierarchyService().getPlants();

        final plantNames = HierarchyService().getPlantNames();
        if (!_isAdmin && _userPlantId != null && plantNames.containsKey(_userPlantId)) {
          _selectedPlantId = _userPlantId;
          _isPlantLocked = true;
        }
        _selectedPlantId ??= _plants.isNotEmpty ? _plants.first : null;

        _updateUnitList();

        if (!_isAdmin && _userUnitId != null && _units.contains(_userUnitId)) {
          _selectedUnitId = _userUnitId;
          _isUnitLocked = true;
        }
      }
    }

    await _fetchData();
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

  // Uses dedicated 'high_mast_towers' and 'high_mast_reports' collections
  Future<void> _fetchData() async {
    if (_selectedPlantId == null || _selectedUnitId == null) return;

    try {
      final towerSnap = await _firestore
          .collection('high_mast_towers')
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();

      _towers = towerSnap.docs
          .map((doc) => HighMastTowerModel.fromMap(doc.data(), doc.id))
          .toList();

      final now = DateTime.now();
      for (var i = 0; i < _towers.length; i++) {
        final tower = _towers[i];
        if (tower.status == 'Certified' && tower.nextDueDate != null && tower.nextDueDate!.isBefore(now)) {
          _towers[i] = HighMastTowerModel(
            id: tower.id,
            plantId: tower.plantId,
            unitId: tower.unitId,
            tagId: tower.tagId,
            location: tower.location,
            status: 'Expired',
            lastServicingDate: tower.lastServicingDate,
            nextDueDate: tower.nextDueDate,
            currentQuarter: tower.currentQuarter,
            remarks: tower.remarks,
            createdAt: tower.createdAt,
            updatedAt: tower.updatedAt,
          );
        }
      }

      final reportSnap = await _firestore
          .collection('high_mast_reports')
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();

      _reports = reportSnap.docs
          .map((doc) => HighMastReportModel.fromMap(doc.data(), doc.id))
          .toList();

      _reports.sort((a, b) => b.testingDate.compareTo(a.testingDate));
    } catch (e) {
      debugPrint('Error fetching high mast tower data: $e');
    }
  }

  void _handleSavedFile(String path, String fileName) {
    final locationMessage = 'File saved to internal storage at:\n$path';
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
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
              Text(locationMessage, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              const Text('Would you like to open or share this file?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
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
                    Navigator.pop(dialogCtx);
                    await Share.shareXFiles([XFile(path)], text: 'Report: $fileName');
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
                    Navigator.pop(dialogCtx);
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

  // --- Add / Edit High Mast Tower Dialog (ONLY Tag ID & Location) ---
  void _showAddEditTowerDialog([HighMastTowerModel? existing]) {
    final formKey = GlobalKey<FormState>();
    final isEdit = existing != null;

    final initialSeq = isEdit ? existing.tagId.split('-').last : _getNextSeqNo();
    final seqNoCtl = TextEditingController(text: initialSeq);
    final locationCtl = TextEditingController(text: existing?.location ?? '');

    String currentGeneratedId = isEdit
        ? existing.tagId
        : _generateTagCode(
            plant: _selectedPlantId!,
            unit: _selectedUnitId!,
            seqNo: seqNoCtl.text,
          );

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            void updateTagIdAndSeq() {
              if (!isEdit) {
                setDialogState(() {
                  currentGeneratedId = _generateTagCode(
                    plant: _selectedPlantId!,
                    unit: _selectedUnitId!,
                    seqNo: seqNoCtl.text,
                  );
                });
              }
            }

            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(isEdit ? 'Edit High Mast: ${existing.tagId}' : 'Register High Mast Lighting Tower'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isEdit) ...[
                          TextFormField(
                            controller: seqNoCtl,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'Sequence Number (Auto-Suggested)',
                              hintText: 'e.g. 001',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            onChanged: (_) => updateTagIdAndSeq(),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final testId = _generateTagCode(
                                plant: _selectedPlantId!,
                                unit: _selectedUnitId!,
                                seqNo: v.trim(),
                              );
                              if (_isTagIdExists(testId)) {
                                return 'Tag ID "$testId" already exists!';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amberAccent),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Auto-Generated Tag ID (Document Key)',
                                  style: TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(currentGeneratedId,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: locationCtl,
                          decoration: const InputDecoration(
                            labelText: 'Location / Physical Area Name',
                            hintText: 'e.g. BF 1 Sizer / Dispatch Loading Bay / Jayanti Yard',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Enter location' : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    Navigator.pop(dialogCtx);
                    setState(() => _isLoading = true);

                    try {
                      if (isEdit) {
                        await _firestore.collection('high_mast_towers').doc(existing.id).update({
                          'location': locationCtl.text.trim(),
                          'updatedAt': DateTime.now().toIso8601String(),
                        });
                      } else {
                        final newTower = HighMastTowerModel(
                          id: currentGeneratedId,
                          plantId: _selectedPlantId!,
                          unitId: _selectedUnitId!,
                          tagId: currentGeneratedId,
                          location: locationCtl.text.trim(),
                          status: 'Never Tested',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        await _firestore.collection('high_mast_towers').doc(currentGeneratedId).set(newTower.toMap());
                      }

                      await _fetchData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdit ? 'Updated High Mast: $currentGeneratedId' : 'Registered High Mast: $currentGeneratedId')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving tower: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: Text(isEdit ? 'Update Tower' : 'Save Tower'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTower(HighMastTowerModel tower) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete High Mast Tower'),
        content: Text('Are you sure you want to delete "${tower.tagId} (${tower.location})"? Associated inspection history will remain for audit trail.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() => _isLoading = true);

              try {
                await _firestore.collection('high_mast_towers').doc(tower.id).delete();
                await _fetchData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting tower: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
        String tempQuarter = _filterQuarter;

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
                      const Text('Filter High Mast Towers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempStatus = 'All';
                            tempQuarter = 'All';
                          });
                        },
                        child: const Text('Reset All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: tempQuarter,
                          decoration: const InputDecoration(labelText: 'Quarter', border: OutlineInputBorder(), isDense: true),
                          items: [
                            'All',
                            '${DateTime.now().year}-Q1',
                            '${DateTime.now().year}-Q2',
                            '${DateTime.now().year}-Q3',
                            '${DateTime.now().year}-Q4'
                          ].map((q) => DropdownMenuItem(value: q, child: Text(q, style: const TextStyle(fontSize: 11)))).toList(),
                          onChanged: (v) => setModalState(() => tempQuarter = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: tempStatus,
                          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                          items: ['All', 'Certified', 'Not Certified', 'Expired', 'Never Tested']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11))))
                              .toList(),
                          onChanged: (v) => setModalState(() => tempStatus = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _filterStatus = tempStatus;
                        _filterQuarter = tempQuarter;
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

  // --- SUBMIT QUARTERLY HOISTING & STRUCTURAL CERTIFICATION ---
  Future<void> _submitInspection() async {
    if (!_formKey.currentState!.validate() || _selectedTowerForInspection == null) {
      if (_selectedTowerForInspection == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a high mast tower to perform checklist')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final tower = _selectedTowerForInspection!;
      bool isAllCheckpointsOk = !_checkpointStates.containsValue(false);
      bool isPanelOk = _selectedPanelCondition != 'DAMAGED';
      bool isCertified = isAllCheckpointsOk && isPanelOk;
      final statusStr = isCertified ? 'Certified' : 'Not Certified';

      final nextDue = _testDate.add(const Duration(days: 90)); // Quarterly 90-day cycle
      final qStr = _selectedQuarter.isEmpty ? _getQuarterString(_testDate) : _selectedQuarter;

      final List<String> itemizedRemarks = [];
      _checkpointStates.forEach((title, isOk) {
        if (!isOk) {
          final remark = _checkpointRemarks[title]?.trim() ?? '';
          itemizedRemarks.add('$title: ${remark.isEmpty ? "NOT OK" : remark}');
        }
      });

      if (_bulldogClampRemarksController.text.trim().isNotEmpty) {
        itemizedRemarks.add('Bulldog Grips: ${_bulldogClampRemarksController.text.trim()}');
      }

      final fullRemarks = [
        if (itemizedRemarks.isNotEmpty) 'DEFECTS: ${itemizedRemarks.join(" | ")}',
        if (_remarksController.text.trim().isNotEmpty) _remarksController.text.trim(),
      ].join(' \n');

      final reportRef = _firestore.collection('high_mast_reports').doc();
      final reportModel = HighMastReportModel(
        id: reportRef.id,
        plantId: tower.plantId,
        unitId: tower.unitId,
        towerId: tower.id,
        tagId: tower.tagId,
        location: tower.location,
        checkType: 'Quarterly High Mast Servicing & Hoisting Safety Inspection',
        testingDate: _testDate,
        nextDueDate: nextDue,
        quarter: qStr,
        status: statusStr,
        servicedBy: _testedByController.text.trim().isNotEmpty ? _testedByController.text.trim() : _currentUserName,
        gearboxOilStatus: _selectedGearboxOil,
        bulldogClampRemarks: _bulldogClampRemarksController.text.trim(),
        panelCondition: _selectedPanelCondition,
        checkpoints: _checkpointStates,
        actionTaken: itemizedRemarks.isNotEmpty ? itemizedRemarks.join(" ; ") : 'Quarterly hoisting winch trial & greasing completed',
        remarks: fullRemarks,
      );

      await reportRef.set(reportModel.toMap());

      await _firestore.collection('high_mast_towers').doc(tower.id).update({
        'status': statusStr,
        'lastServicingDate': _testDate.toIso8601String(),
        'nextDueDate': nextDue.toIso8601String(),
        'currentQuarter': qStr,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _fetchData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCertified
                  ? 'Quarterly Hoisting & Structural Certification SUCCESS for: ${tower.tagId}'
                  : 'UNSAFE / DEFECTS logged for: ${tower.tagId}. Disconnect winch & schedule immediate overhauling.',
            ),
            backgroundColor: isCertified ? Colors.green.shade700 : Colors.red.shade700,
          ),
        );

        setState(() {
          _selectedTowerForInspection = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save high mast checklist: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _startInspectionForTower(HighMastTowerModel tower) {
    setState(() {
      _selectedTowerForInspection = tower;
      _selectedGearboxOil = 'OK';
      _selectedPanelCondition = 'OK';
      _bulldogClampRemarksController.clear();
      _initializeCheckpoints();
    });
  }

  // --- PDF EXPORTS ---
  Future<void> _exportPdfCertificate(HighMastReportModel report) async {
    try {
      final pdf = pw.Document();
      final checkSheetTitle = 'HIGH MAST LIGHTING TOWER SAFETY & MAINTENANCE CERTIFICATE';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(26),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'VEDANTA IRON & STEEL LIMITED',
                          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                        pw.Text(
                          '$checkSheetTitle (IS 875 / IS 2266 / CEA 2023)',
                          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: report.status == 'Certified' ? PdfColors.green700 : PdfColors.red700,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        report.status.toUpperCase(),
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                  children: [
                    pw.TableRow(children: [
                      _pdfCell('High Mast Tag ID / Code:', report.tagId, isBold: true),
                      _pdfCell('Plant / Unit Scope:', '${report.plantId} - ${report.unitId}'),
                    ]),
                    pw.TableRow(children: [
                      _pdfCell('Location / Physical Area:', report.location, isBold: true),
                      _pdfCell('Servicing Date / Quarter:', '${report.testingDate.toString().split(' ')[0]} (${report.quarter})', isBold: true),
                    ]),
                    pw.TableRow(children: [
                      _pdfCell('Inspection Standard:', 'IS 875 / IS 2266 / CEA 2023'),
                      _pdfCell('Next Quarterly Due Date:', report.nextDueDate.toString().split(' ')[0], isBold: true),
                    ]),
                  ],
                ),
                pw.SizedBox(height: 10),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
                  columnWidths: const {
                    0: pw.FixedColumnWidth(24),
                    1: pw.FlexColumnWidth(5.5),
                    2: pw.FixedColumnWidth(28),
                    3: pw.FixedColumnWidth(36),
                    4: pw.FlexColumnWidth(2.2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _pdfHeaderCell('SL'),
                        _pdfHeaderCell('Check points / Statutory Verification'),
                        _pdfHeaderCell('OK'),
                        _pdfHeaderCell('NOT OK'),
                        _pdfHeaderCell('Remarks'),
                      ],
                    ),
                    ...report.checkpoints.entries.toList().asMap().entries.map((itemEntry) {
                      final idx = itemEntry.key + 1;
                      final pointKey = itemEntry.value.key;
                      final isOk = itemEntry.value.value;

                      String cleanText = pointKey;
                      if (RegExp(r'^\d+\.\s*').hasMatch(cleanText)) {
                        cleanText = cleanText.replaceFirst(RegExp(r'^\d+\.\s*'), '');
                      }

                      return pw.TableRow(
                        children: [
                          _pdfBodyCell('$idx', alignCenter: true),
                          _pdfBodyCell(cleanText),
                          _pdfStatusCheckCell(isOk ? 'OK' : '', isPass: true),
                          _pdfStatusCheckCell(!isOk ? 'NOT OK' : '', isPass: false),
                          _pdfBodyCell(!isOk ? 'Defect logged' : ''),
                        ],
                      );
                    }),
                  ],
                ),

                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    border: pw.Border.all(color: PdfColors.amber300, width: 0.8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Text('Gearbox Oil: ${report.gearboxOilStatus}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      pw.Text('Panel Condition: ${report.panelCondition}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      if (report.bulldogClampRemarks.isNotEmpty)
                        pw.Text('Grips: ${report.bulldogClampRemarks}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    ],
                  ),
                ),

                if (report.remarks.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text('Observations: ${report.remarks}',
                      style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800)),
                ],

                pw.Spacer(),

                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                  ),
                  child: pw.Text(
                    'High mast hoisting winch, wire ropes, and luminaire carriage certified safe for operation under IS 875 & IS 2266.',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                ),
                pw.SizedBox(height: 6),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Certified / Not certified: ${report.status}',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(width: 140, height: 1, color: PdfColors.grey700),
                        pw.SizedBox(height: 2),
                        pw.Text('Inspected & Certified By: ${report.servicedBy}',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final fileName = 'High_Mast_Cert_${report.tagId}_${report.quarter}.pdf';
      final bytes = await pdf.save();
      final path = await downloadFile(bytes, fileName);
      if (path != null) {
        _handleSavedFile(path, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF Certificate: $e')),
        );
      }
    }
  }

  pw.Widget _pdfStatusCheckCell(String text, {required bool isPass}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: isPass ? PdfColors.green900 : PdfColors.red900,
          ),
        ),
      ),
    );
  }

  Future<void> _exportWholePDFReport() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('VEDANTA IRON & STEEL LIMITED',
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text('High Mast Lighting Tower Quarterly Safety & Maintenance Audit Summary',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Text('Plant: $_selectedPlantId | Unit: $_selectedUnitId',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                ],
              ),
              pw.SizedBox(height: 12),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.amber100),
                    children: [
                      _pdfHeaderCell('Tag ID'),
                      _pdfHeaderCell('Location / Area Name'),
                      _pdfHeaderCell('Status'),
                      _pdfHeaderCell('Quarter'),
                      _pdfHeaderCell('Last Serviced'),
                      _pdfHeaderCell('Next Due Date'),
                      _pdfHeaderCell('Inspector'),
                    ],
                  ),
                  ..._towers.map((t) {
                    final matchingReport = _reports.firstWhere(
                      (r) => r.towerId == t.id || r.tagId == t.tagId,
                      orElse: () => HighMastReportModel(
                        id: '',
                        plantId: t.plantId,
                        unitId: t.unitId,
                        towerId: t.id,
                        tagId: t.tagId,
                        location: t.location,
                        checkType: '',
                        testingDate: t.lastServicingDate ?? DateTime.now(),
                        nextDueDate: t.nextDueDate ?? DateTime.now(),
                        quarter: t.currentQuarter,
                        status: t.status,
                        servicedBy: 'N/A',
                        checkpoints: {},
                        remarks: '',
                      ),
                    );

                    final servDateStr = t.lastServicingDate != null ? t.lastServicingDate.toString().split(' ')[0] : 'Never';
                    final nextDueStr = t.nextDueDate != null ? t.nextDueDate.toString().split(' ')[0] : 'N/A';
                    final servicedByStr = matchingReport.servicedBy.isNotEmpty ? matchingReport.servicedBy : 'N/A';

                    return pw.TableRow(
                      children: [
                        _pdfBodyCell(t.tagId, isBold: true),
                        _pdfBodyCell(t.location),
                        _pdfBodyCell(
                          t.status,
                          color: t.status == 'Certified'
                              ? PdfColors.green800
                              : (t.status == 'Expired' ? PdfColors.orange800 : PdfColors.red800),
                        ),
                        _pdfBodyCell(t.currentQuarter.isEmpty ? 'N/A' : t.currentQuarter),
                        _pdfBodyCell(servDateStr, isBold: true),
                        _pdfBodyCell(nextDueStr),
                        _pdfBodyCell(servicedByStr),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      final fileName = 'High_Mast_Summary_${_selectedPlantId}_$_selectedUnitId.pdf';
      final bytes = await pdf.save();
      final path = await downloadFile(bytes, fileName);
      if (path != null) {
        _handleSavedFile(path, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating Whole PDF Summary: $e')),
        );
      }
    }
  }

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
    );
  }

  pw.Widget _pdfBodyCell(String text, {bool isBold = false, bool alignCenter = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3.5),
      child: pw.Text(
        text,
        textAlign: alignCenter ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  pw.Widget _pdfCell(String title, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          pw.SizedBox(height: 1.5),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportExcelReport() async {
    try {
      final List<Map<String, dynamic>> excelData = _towers.map((t) {
        final matchingReport = _reports.firstWhere(
          (r) => r.towerId == t.id || r.tagId == t.tagId,
          orElse: () => HighMastReportModel(
            id: '',
            plantId: t.plantId,
            unitId: t.unitId,
            towerId: t.id,
            tagId: t.tagId,
            location: t.location,
            checkType: '',
            testingDate: t.lastServicingDate ?? DateTime.now(),
            nextDueDate: t.nextDueDate ?? DateTime.now(),
            quarter: t.currentQuarter,
            status: t.status,
            servicedBy: 'N/A',
            checkpoints: {},
            remarks: '',
          ),
        );

        return {
          'Tag ID': t.tagId,
          'Location': t.location,
          'Status': t.status,
          'Quarter': t.currentQuarter,
          'Gearbox Oil': matchingReport.gearboxOilStatus,
          'Panel Condition': matchingReport.panelCondition,
          'Bulldog Remarks': matchingReport.bulldogClampRemarks,
          'Servicing Date': t.lastServicingDate != null ? t.lastServicingDate.toString().split(' ')[0] : 'Never',
          'Next Due Date': t.nextDueDate != null ? t.nextDueDate.toString().split(' ')[0] : 'N/A',
          'Inspector': matchingReport.servicedBy,
          'Remarks': t.remarks,
        };
      }).toList();

      final fileName = 'High_Mast_Report_${_selectedPlantId}_$_selectedUnitId.xlsx';
      final bytes = ExcelService().generateExcel(
        excelData,
        'High Mast Registry',
      );

      if (bytes != null) {
        final path = await downloadFile(bytes, fileName);
        if (path != null) {
          _handleSavedFile(path, fileName);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting Excel report: $e')),
        );
      }
    }
  }

  List<HighMastTowerModel> get _filteredTowers {
    final query = _searchController.text.trim().toLowerCase();
    return _towers.where((tower) {
      final matchesSearch = query.isEmpty ||
          tower.tagId.toLowerCase().contains(query) ||
          tower.location.toLowerCase().contains(query);

      final matchesStatus = _filterStatus == 'All' || tower.status == _filterStatus;
      final matchesQuarter = _filterQuarter == 'All' || tower.currentQuarter == _filterQuarter;

      return matchesSearch && matchesStatus && matchesQuarter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'High Mast Tower Checklist'),
        body: Center(child: PulseLoading()),
      );
    }

    return PopScope(
      canPop: _selectedTowerForInspection == null && _historyTower == null && !_isManagingDatabase && !_showHelp,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          if (_selectedTowerForInspection != null) {
            _selectedTowerForInspection = null;
          } else if (_historyTower != null) {
            _historyTower = null;
          } else if (_isManagingDatabase) {
            _isManagingDatabase = false;
          } else if (_showHelp) {
            _showHelp = false;
          }
        });
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: 'High Mast Tower Checklist'),
        body: _selectedTowerForInspection != null
            ? _buildRecordingFormView()
            : _historyTower != null
                ? _buildHistoryView()
                : _isManagingDatabase
                    ? _buildManageDatabaseView()
                    : _showHelp
                        ? _buildHelpView()
                        : _buildMainView(),
      ),
    );
  }

  // --- MAIN VIEW (Zero Layout Overflows, Simple ID & Location Cards) ---
  Widget _buildMainView() {
    final filtered = _filteredTowers;
    final total = _towers.length;
    final certified = _towers.where((t) => t.status == 'Certified').length;
    final notCertified = _towers.where((t) => t.status == 'Not Certified').length;
    final expired = _towers.where((t) => t.status == 'Expired' || t.status == 'Never Tested').length;
    final compliancePct = total > 0 ? (certified / total) * 100.0 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Spacious Scope Selectors
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
                                await _fetchData();
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
                      decoration: const InputDecoration(labelText: 'Select Unit', border: InputBorder.none),
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
                                await _fetchData();
                                if (mounted) setState(() => _isLoading = false);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Metrics Compliance Overview Card
          GlassContainer(
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Text(
                          'High Mast Tower Hoisting & Rigging Compliance',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          softWrap: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: compliancePct >= 80.0
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${compliancePct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: compliancePct >= 80.0 ? Colors.greenAccent : Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Total Towers', '$total', Colors.white),
                      _buildStatItem('Certified', '$certified', Colors.greenAccent),
                      _buildStatItem('Not Certified', '$notCertified', Colors.redAccent),
                      _buildStatItem('Overdue / Expired', '$expired', Colors.orangeAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Search Bar + Filter [tune] + Help [?] + Settings [gear]
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Location, Tag ID...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.tune, color: Colors.white),
                tooltip: 'Filter Towers',
                onPressed: _showFilterModal,
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.help_outline, color: Colors.white),
                tooltip: 'IS 875 & Winch Rigging Guide',
                onPressed: () => setState(() => _showHelp = true),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 4),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.settings, color: Colors.white),
                  tooltip: 'Manage Towers Registry',
                  onPressed: () => setState(() => _isManagingDatabase = true),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // 4. Header Row with Title & Excel / PDF Action Buttons
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'High Mast Lighting Towers (${filtered.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: _exportExcelReport,
                    icon: const Icon(Icons.table_chart, size: 16, color: Colors.greenAccent),
                    label: const Text('Excel',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _exportWholePDFReport,
                    icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.redAccent),
                    label: const Text('PDF Report',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Tower Cards
          filtered.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text('No matching high mast towers found for the selected scope.'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tower = filtered[index];
                    final now = DateTime.now();
                    final isNotCert = tower.status == 'Not Certified';
                    final isCert = tower.status == 'Certified';

                    int? daysRemaining;
                    int? overdueDays;
                    if (tower.nextDueDate != null) {
                      daysRemaining = tower.nextDueDate!.difference(now).inDays;
                      if (daysRemaining < 0) {
                        overdueDays = now.difference(tower.nextDueDate!).inDays;
                      }
                    }

                    final bool isOverdue = (tower.status == 'Expired') || (daysRemaining != null && daysRemaining < 0);

                    Color statusColor = Colors.grey;
                    Color pillBg = const Color(0xFFF1F5F9);
                    IconData statusIcon = Icons.hourglass_empty;
                    String statusBadgeText = 'NEVER TESTED';
                    String dueText = 'Next Due: Immediately (Quarterly Servicing)';
                    Color dueTextColor = Colors.grey;

                    if (isNotCert) {
                      statusColor = Colors.redAccent;
                      pillBg = Colors.red.withValues(alpha: 0.15);
                      statusIcon = Icons.cancel;
                      statusBadgeText = 'NOT CERTIFIED';
                      dueText = 'Status: FAILED / UNSAFE (Winch Custody Lockout)';
                      dueTextColor = Colors.redAccent;
                    } else if (isOverdue) {
                      statusColor = Colors.orangeAccent;
                      pillBg = Colors.orange.withValues(alpha: 0.15);
                      statusIcon = Icons.hourglass_bottom;
                      statusBadgeText = 'OVERDUE';
                      dueText = overdueDays != null
                          ? 'Overdue by $overdueDays days (Due: ${tower.nextDueDate.toString().split(' ')[0]})'
                          : 'Overdue for Quarterly Servicing';
                      dueTextColor = Colors.orangeAccent;
                    } else if (isCert) {
                      statusColor = Colors.greenAccent;
                      pillBg = Colors.green.withValues(alpha: 0.15);
                      statusIcon = Icons.check_circle;
                      statusBadgeText = 'CERTIFIED';
                      if (daysRemaining != null && daysRemaining > 0) {
                        dueText = 'Due in $daysRemaining days (${tower.nextDueDate.toString().split(' ')[0]})';
                        dueTextColor = Colors.greenAccent;
                      } else if (daysRemaining == 0) {
                        dueText = 'Due Today (${tower.nextDueDate.toString().split(' ')[0]})';
                        dueTextColor = Colors.amberAccent;
                      } else {
                        dueText = 'Next Due: ${tower.nextDueDate.toString().split(' ')[0]}';
                        dueTextColor = Colors.greenAccent;
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(statusIcon, color: statusColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tower.tagId,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 3),
                                      Text('Location: ${tower.location}',
                                          style: const TextStyle(fontSize: 12.5, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: pillBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    statusBadgeText,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 13, color: dueTextColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      dueText,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dueTextColor),
                                    ),
                                  ),
                                  Text(
                                    tower.currentQuarter.isNotEmpty ? 'Q: ${tower.currentQuarter}' : 'Q: N/A',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    tower.lastServicingDate != null
                                        ? 'Last Serviced: ${tower.lastServicingDate.toString().split(' ')[0]}'
                                        : 'Last Serviced: Never',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.history, size: 18, color: Colors.blueAccent),
                                      tooltip: 'Servicing History',
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      onPressed: () => setState(() => _historyTower = tower),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.checklist_rtl, size: 15, color: Colors.white),
                                      label: Text(
                                        isCert ? 'Re-inspect' : 'Inspect Tower',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      onPressed: () => _startInspectionForTower(tower),
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

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  // --- HISTORY VIEW (_historyTower != null) ---
  Widget _buildHistoryView() {
    final tower = _historyTower!;
    final towerReports = _reports.where((r) => r.towerId == tower.id || r.tagId == tower.tagId).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ResponsiveContentWrapper(
      maxWidth: 1320,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _historyTower = null),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inspection History: ${tower.tagId}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Location: ${tower.location}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (towerReports.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Text('No quarterly inspection records found for this tower.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: towerReports.length,
                itemBuilder: (context, index) {
                  final r = towerReports[index];
                  final isCert = r.status == 'Certified';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isCert ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            isCert ? Icons.check_circle : Icons.cancel,
                            color: isCert ? Colors.green.shade600 : Colors.red.shade600,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${r.quarter} - Status: ${r.status}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                        color: isCert ? Colors.green.shade600 : Colors.red.shade600)),
                                Text('Date: ${r.testingDate.toString().split(' ')[0]} | By: ${r.servicedBy} | Oil: ${r.gearboxOilStatus} | Panel: ${r.panelCondition}',
                                    style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white70 : Colors.grey.shade700)),
                                if (r.bulldogClampRemarks.isNotEmpty)
                                  Text('Grips: ${r.bulldogClampRemarks}', style: const TextStyle(fontSize: 10, color: Colors.amberAccent)),
                                if (r.remarks.isNotEmpty)
                                  Text('Remarks: ${r.remarks}', style: TextStyle(fontSize: 9.5, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20),
                            tooltip: 'Download Certificate PDF',
                            onPressed: () => _exportPdfCertificate(r),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- RECORDING FORM VIEW (_selectedTowerForInspection != null) ---
  Widget _buildRecordingFormView() {
    final tower = _selectedTowerForInspection!;
    final checkSheetTitle = 'HIGH MAST TOWER HOISTING & RIGGING CHECK SHEET';

    return ResponsiveContentWrapper(
      maxWidth: 1320,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: GlassContainer(
            borderRadius: 16,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => setState(() => _selectedTowerForInspection = null),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          checkSheetTitle,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.wb_incandescent, color: Colors.amberAccent, size: 16),
                            SizedBox(width: 6),
                            Text('HIGH MAST TOWER DETAILS',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.amberAccent)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Tag ID: ${tower.tagId}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Location: ${tower.location}',
                            style: const TextStyle(fontSize: 11.5, color: Colors.amberAccent, fontWeight: FontWeight.w600)),
                        Text('Plant Scope: $_selectedPlantId - $_selectedUnitId',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _testDate.toString().split(' ')[0],
                          readOnly: true,
                          decoration: const InputDecoration(labelText: 'Inspection Date', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedQuarter,
                          decoration: const InputDecoration(labelText: 'Quarterly Cycle', border: OutlineInputBorder(), isDense: true),
                          items: [
                            '${DateTime.now().year}-Q1',
                            '${DateTime.now().year}-Q2',
                            '${DateTime.now().year}-Q3',
                            '${DateTime.now().year}-Q4'
                          ].map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                          onChanged: (v) => setState(() => _selectedQuarter = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Gearbox Oil Status & Control Panel Condition
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedGearboxOil,
                          decoration: const InputDecoration(
                            labelText: 'Gearbox Oil Status',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _gearboxOilOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                          onChanged: (v) => setState(() => _selectedGearboxOil = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedPanelCondition,
                          decoration: const InputDecoration(
                            labelText: 'Panel Condition',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _panelConditionOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                          onChanged: (v) => setState(() => _selectedPanelCondition = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _bulldogClampRemarksController,
                    decoration: const InputDecoration(
                      labelText: 'Bulldog Clamp / Wire Rope Grip Replacement Remark',
                      hintText: 'e.g. 3 Thibi / 4 Piece Bulldog Replaced / Tightened',
                      prefixIcon: Icon(Icons.build_circle, color: Colors.amberAccent, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _testedByController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Inspected By / Technician (Profile)',
                      prefixIcon: Icon(Icons.lock_person, color: Colors.blueAccent, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Divider(),
                  const SizedBox(height: 6),
                  Text('STATUTORY CHECK POINTS VERIFICATION (${_checkpointStates.length} POINTS)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
                  const SizedBox(height: 8),

                  ..._checkpointStates.keys.map((title) {
                    final isOk = _checkpointStates[title] ?? true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isOk ? Colors.green.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isOk ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                              ),
                              ChoiceChip(
                                label: const Text('OK', style: TextStyle(fontSize: 10)),
                                selected: isOk,
                                selectedColor: Colors.green.shade700,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                onSelected: (val) {
                                  setState(() {
                                    _checkpointStates[title] = true;
                                  });
                                },
                              ),
                              const SizedBox(width: 4),
                              ChoiceChip(
                                label: const Text('NOT OK', style: TextStyle(fontSize: 10)),
                                selected: !isOk,
                                selectedColor: Colors.red.shade700,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                onSelected: (val) {
                                  setState(() {
                                    _checkpointStates[title] = false;
                                  });
                                },
                              ),
                            ],
                          ),

                          if (!isOk) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: _checkpointRemarks[title],
                              decoration: const InputDecoration(
                                labelText: 'Specific defect observation / reason for NOT OK',
                                hintText: 'e.g. Winch jam, Rope strand cut, Anchor nut loose, Relay tripping...',
                                isDense: true,
                                prefixIcon: Icon(Icons.warning_amber, color: Colors.redAccent, size: 16),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) {
                                _checkpointRemarks[title] = val;
                              },
                              validator: (val) {
                                if (!isOk && (val == null || val.trim().isEmpty)) {
                                  return 'Please describe defect reason';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _remarksController,
                    decoration: const InputDecoration(
                      labelText: 'Overall Inspector Remarks / Summary Observations',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'High Mast Tower will be certified only after satisfactory lowering & raising trial and zero wire rope defects (IS 2266).',
                      style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 14),

                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitInspection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.verified, size: 18),
                    label: Text(
                      _isSubmitting ? 'Saving Inspection...' : 'SUBMIT QUARTERLY HOISTING REPORT',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- MANAGE DATABASE VIEW ---
  Widget _buildManageDatabaseView() {
    return ResponsiveContentWrapper(
      maxWidth: 1320,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() {
                    _isManagingDatabase = false;
                  }),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Manage High Mast Towers Registry',
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
                    label: const Text('Add High Mast', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () => _showAddEditTowerDialog(null),
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
                            collectionId: 'high_mast_towers',
                            title: 'High Mast Towers Import',
                            plantId: _selectedPlantId,
                            unitId: _selectedUnitId,
                          ),
                        ),
                      );
                      await _fetchData();
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _towers.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No high mast towers found. Add or import one above!')))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _towers.length,
                    itemBuilder: (context, idx) {
                      final tower = _towers[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(tower.tagId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 3),
                                        Text('Location: ${tower.location}', style: const TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.amberAccent, size: 20),
                                        tooltip: 'Edit Location',
                                        onPressed: () => _showAddEditTowerDialog(tower),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                        tooltip: 'Delete Tower',
                                        onPressed: () => _confirmDeleteTower(tower),
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
      ),
    );
  }

  // --- HELP VIEW ---
  Widget _buildHelpView() {
    return ResponsiveContentWrapper(
      maxWidth: 1320,
      child: SingleChildScrollView(
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
                    'High Mast Tower Safety & Winch Rigging Standards (IS 875 / IS 2266)',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                    softWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            GlassContainer(
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.shield, color: Colors.amberAccent, size: 20),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '1. Statutory Hoisting & Structural Rigging Clusters',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildHelpItem(
                      'Cluster 1: Winch, Motor & Raising/Lowering System',
                      'MECHANICAL HOISTING',
                      Colors.greenAccent,
                      '• Lowering & Raising Trial: Ensure smooth carriage descent to ground landing and secure top docking latch lock.\n'
                      '• Dual-Drum Winch: Dual-drum self-lubricating worm gear winch with irreversible mechanical braking mechanism.\n'
                      '• Gearbox Oil & Protection: Sump oil level check, top-up (*OK / Filling Done*), and waterproof rain canopy seal.',
                    ),
                    const SizedBox(height: 10),

                    _buildHelpItem(
                      'Cluster 2: Wire Rope & Bulldog Clamp Rigging (IS 2266)',
                      'LIFTING ROPE INTEGRITY',
                      Colors.cyanAccent,
                      '• Wire Rope Safety: Stainless steel / Galvanized steel wire rope (6x19 / 7x19 construction, min 5:1 safety factor).\n'
                      '• Wire Rope Dressing: Anti-corrosive marine wire rope greasing across the entire working stroke.\n'
                      '• Bulldog Clamp Grips: Duplex bulldog wire rope grips must be correctly torqued with no slippage (*e.g. 4/6 Piece Replaced*).',
                    ),
                    const SizedBox(height: 10),

                    _buildHelpItem(
                      'Cluster 3: Floodlight Luminaires & Aviation Beacon',
                      'OPTICAL INSPECTION',
                      Colors.amberAccent,
                      '• Lantern Carriage Overhaul: Check lantern ring structural alignment, suspension cables, and safety slings.\n'
                      '• Aviation Obstruction Light (AOL): Flashing red beacon atop apex operational for aircraft warning.',
                    ),
                    const SizedBox(height: 10),

                    _buildHelpItem(
                      'Cluster 4: Foundation Stability & Electrical Controls (IS 875 / CEA 2023)',
                      'STRUCTURAL & AUTOMATION',
                      Colors.purpleAccent,
                      '• Foundation Anchor Bolts: Inspect double hex locking nuts for tightness, corrosion, and civil pedestal cracking.\n'
                      '• Trailing Power Cable: Flexible EPR/PCP trailing cable condition, hanging vertical without twists or snags.\n'
                      '• Astronomical Timer & Panel: Dusk-to-dawn timer/photocell automation and feeder panel ingress protection.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            const Text('2. 20 Statutory Checkpoints Directory',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _getCheckpoints().length,
              itemBuilder: (context, idx) {
                final q = _getCheckpoints()[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: Colors.amberAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          q,
                          style: const TextStyle(fontSize: 11, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(String title, String badge, Color color, String description) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: color)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(fontSize: 11, height: 1.4)),
        ],
      ),
    );
  }
}
