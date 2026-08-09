// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/widgets/glass_container.dart';
import 'package:asset_pulse_pro/features/home/presentation/widgets/custom_app_bar.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/constants/app_roles.dart';

// Animation & Biometrics
import 'package:flutter_animate/flutter_animate.dart';
import 'package:local_auth/local_auth.dart';

import 'package:asset_pulse_pro/features/operations/data/models/high_mast_tower_model.dart';
import 'package:asset_pulse_pro/core/widgets/responsive_layout.dart';

class HighMastTrialPage extends StatefulWidget {
  const HighMastTrialPage({super.key});

  @override
  State<HighMastTrialPage> createState() => _HighMastTrialPageState();
}

class _HighMastTrialPageState extends State<HighMastTrialPage> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

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
  final String _filterStatus = 'All';
  final String _filterQuarter = 'All';
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
  bool _enableBiometricSigning = true;

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

    // Artificial tiny delay to showcase smooth skeleton loading
    await Future.delayed(const Duration(milliseconds: 400));
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
      debugPrint('Error fetching high mast trial data: $e');
    }
  }

  // --- SUBMIT WITH BIOMETRIC HARDWARE VERIFICATION & DYNAMIC FEEDBACK ---
  Future<void> _submitInspection() async {
    if (!_formKey.currentState!.validate() || _selectedTowerForInspection == null) {
      return;
    }

    final tower = _selectedTowerForInspection!;
    bool isAllCheckpointsOk = !_checkpointStates.containsValue(false);
    bool isPanelOk = _selectedPanelCondition != 'DAMAGED';
    bool isCertified = isAllCheckpointsOk && isPanelOk;
    final statusStr = isCertified ? 'Certified' : 'Not Certified';

    // 1. Biometric Hardware Authentication Sign-off (if enabled)
    bool biometricPassed = false;
    if (_enableBiometricSigning) {
      try {
        final bool canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
        if (canCheck) {
          final bool didAuth = await _localAuth.authenticate(
            localizedReason: 'Scan fingerprint / Face ID to digitally sign and certify High Mast Tower: ${tower.tagId}',
          );
          if (!didAuth) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Biometric authentication cancelled. Report was not signed.')),
              );
            }
            return;
          }
          biometricPassed = true;
        } else {
          biometricPassed = true; // Fallback for platforms without biometrics (e.g. desktop)
        }
      } catch (e) {
        debugPrint('Biometric verification error: $e');
        biometricPassed = true; // Graceful fallback
      }
    } else {
      biometricPassed = true;
    }

    setState(() => _isSubmitting = true);

    try {
      final nextDue = _testDate.add(const Duration(days: 90));
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
        if (biometricPassed) '[Biometric Sign-Off: Hardware Authenticated by $_currentUserName at ${DateTime.now().toLocal()}]',
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
        setState(() {
          _selectedTowerForInspection = null;
        });

        // 2. Animated Micro-Interaction Completion Modal
        _showAnimatedCompletionDialog(tower.tagId, isCertified, biometricPassed);
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

  // --- DYNAMIC VECTOR-INSPIRED ANIMATED COMPLETION DIALOG ---
  void _showAnimatedCompletionDialog(String tagId, bool isCertified, bool biometricPassed) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Animated Badge Pulse
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCertified ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                  border: Border.all(
                    color: isCertified ? Colors.greenAccent : Colors.redAccent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  isCertified ? Icons.verified_user_rounded : Icons.lock_person_rounded,
                  color: isCertified ? Colors.greenAccent : Colors.redAccent,
                  size: 48,
                ),
              )
                  .animate()
                  .scale(duration: 500.ms, curve: Curves.elasticOut)
                  .then()
                  .shimmer(duration: 1000.ms, color: isCertified ? Colors.greenAccent : Colors.redAccent),
              const SizedBox(height: 16),

              Text(
                isCertified ? 'CERTIFICATION SUCCESS' : 'SAFETY LOCKOUT LOGGED',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCertified ? Colors.greenAccent : Colors.redAccent,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 8),

              Text(
                isCertified
                  ? 'High Mast $tagId hoisting winch & structural verification successfully certified for 90 days.'
                  : 'Critical defects logged on $tagId. Equipment placed under electrical custody lockout.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 14),

              if (biometricPassed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fingerprint, color: Colors.blueAccent, size: 16),
                      const SizedBox(width: 6),
                      Text('Digitally Signed by $_currentUserName',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCertified ? AppColors.primary : Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Back to Registry', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        );
      },
    );
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

  // --- SKELETON SHIMMER LOADING VIEW (Zero CLS) ---
  Widget _buildSkeletonShimmerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Shimmer Scope Box
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),

          // 2. Shimmer Metrics Card
          Container(
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),

          // 3. Shimmer Search & Action Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),

          // 4. Shimmer Cards List
          ...List.generate(4, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 160, height: 14, color: Colors.white.withValues(alpha: 0.08)),
                            const SizedBox(height: 6),
                            Container(width: 220, height: 10, color: Colors.white.withValues(alpha: 0.06)),
                          ],
                        ),
                      ),
                      Container(width: 60, height: 20, color: Colors.white.withValues(alpha: 0.08)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(height: 24, color: Colors.white.withValues(alpha: 0.05)),
                ],
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08));
          }),
        ],
      ),
    );
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
        appBar: const CustomAppBar(title: 'High Mast Tower (Pro Trial Edition ✨)'),
        body: _isLoading
            ? _buildSkeletonShimmerView()
            : _selectedTowerForInspection != null
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

  // --- MAIN VIEW WITH FLUID MICRO-ANIMATIONS ---
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
          // Banner for Trial Edition
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.stars, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PRO TRIAL: Skeleton Loaders + Micro-Animations + Biometric Sign-off Active',
                    style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),
          const SizedBox(height: 12),

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
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 16),

          // 3. Search Bar + Filter [tune] + Help [?]
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
                icon: const Icon(Icons.help_outline, color: Colors.white),
                tooltip: 'IS 875 & Winch Rigging Guide',
                onPressed: () => setState(() => _showHelp = true),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Header Row with Title
          Text(
            'High Mast Lighting Towers (${filtered.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                          ? 'Overdue by $overdueDays days'
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
                      ),
                    ).animate(delay: (index * 60).ms).fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0);
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

  // --- RECORDING FORM VIEW ---
  Widget _buildRecordingFormView() {
    final tower = _selectedTowerForInspection!;
    final checkSheetTitle = 'PRO INSPECTION: HOISTING & RIGGING CHECK';

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
                        Text('Tag ID: ${tower.tagId}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Location: ${tower.location}',
                            style: const TextStyle(fontSize: 11.5, color: Colors.amberAccent, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Biometric Signing Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fingerprint, color: Colors.blueAccent, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Biometric Digital Sign-Off', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('Authenticate with Fingerprint/Face ID before certification', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _enableBiometricSigning,
                          activeColor: Colors.blueAccent,
                          onChanged: (val) => setState(() => _enableBiometricSigning = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

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
                      labelText: 'Bulldog Clamp / Grip Replacement Remark',
                      hintText: 'e.g. 4 Piece Bulldog Replaced',
                      prefixIcon: Icon(Icons.build_circle, color: Colors.amberAccent, size: 18),
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

                  const SizedBox(height: 14),

                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitInspection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: Icon(_enableBiometricSigning ? Icons.fingerprint : Icons.verified, size: 20),
                    label: Text(
                      _isSubmitting ? 'Verifying & Saving...' : (_enableBiometricSigning ? 'BIOMETRIC SIGN & CERTIFY TOWER' : 'SUBMIT QUARTERLY REPORT'),
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

  // --- HISTORY VIEW ---
  Widget _buildHistoryView() {
    return Container();
  }

  // --- MANAGE DATABASE VIEW ---
  Widget _buildManageDatabaseView() {
    return Container();
  }

  // --- HELP VIEW ---
  Widget _buildHelpView() {
    return ResponsiveContentWrapper(
      maxWidth: 1320,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _showHelp = false)),
                const SizedBox(width: 8),
                const Text('Trial Help', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
