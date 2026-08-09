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
import 'package:asset_pulse_pro/features/operations/data/models/water_cooler_model.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/data_import_page.dart';
import 'package:asset_pulse_pro/core/widgets/responsive_layout.dart';

class WaterCoolerChecklistPage extends StatefulWidget {
  const WaterCoolerChecklistPage({super.key});

  @override
  State<WaterCoolerChecklistPage> createState() => _WaterCoolerChecklistPageState();
}

class _WaterCoolerChecklistPageState extends State<WaterCoolerChecklistPage> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;

  // Navigation State
  WaterCoolerModel? _historyCooler;
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

  final List<String> _coolerTypes = [
    'Hot & Cold Dispenser',
    'Storage Water Cooler',
    'RO + UV Water Cooler',
    'Commercial SS Water Cooler',
    'Wall Mounted Chiller',
    'Other Water Coolers',
  ];

  final Map<String, String> _coolerShortCodes = {
    'Hot & Cold Dispenser': 'HCD',
    'Storage Water Cooler': 'SWC',
    'RO + UV Water Cooler': 'ROUV',
    'Commercial SS Water Cooler': 'CWC',
    'Wall Mounted Chiller': 'WMC',
    'Other Water Coolers': 'WC',
  };

  final Map<String, String> _coolerCategoryClasses = {
    'Hot & Cold Dispenser': 'Dual-Temp Dispenser (Heating & Cooling)',
    'Storage Water Cooler': 'High-Capacity Bulk Storage Cooler',
    'RO + UV Water Cooler': 'Multi-Stage Membrane & Sterilization',
    'Commercial SS Water Cooler': 'Industrial Heavy-Duty Floor Unit',
    'Wall Mounted Chiller': 'Compact Confined Space Drinking Station',
    'Other Water Coolers': 'General Drinking Water Dispenser',
  };

  final List<String> _makes = [
    'Not Specified',
    'Voltas',
    'Blue Star',
    'Eureka Forbes',
    'Kent RO',
    'Aquaguard',
    'Usha',
    'Atlantis',
    'Haier',
    'Thermax',
    'Other',
  ];

  final List<String> _capacities = [
    'Not Specified',
    '20 L/hr',
    '40 L/hr',
    '60 L/hr',
    '80 L/hr',
    '120 L/hr',
    '150 L/hr',
    '200 L/hr',
    '300 L/hr',
    '500 L/hr',
  ];

  // Filters
  String _selectedCoolerTypeChip = 'All Types';
  String _filterCoolerType = 'All';
  String _filterMake = 'All';
  String _filterStatus = 'All';
  String _filterQuarter = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Loaded Collections Data
  List<WaterCoolerModel> _coolers = [];
  List<WaterCoolerReportModel> _reports = [];

  // Form State
  final _formKey = GlobalKey<FormState>();
  WaterCoolerModel? _selectedCoolerForInspection;

  final TextEditingController _testedByController = TextEditingController();
  final TextEditingController _tdsController = TextEditingController(text: '120.0');
  final TextEditingController _coldTempController = TextEditingController(text: '12.0');
  final TextEditingController _hotTempController = TextEditingController(text: '85.0');
  final TextEditingController _remarksController = TextEditingController();

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
    _tdsController.dispose();
    _coldTempController.dispose();
    _hotTempController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  String _generateTagCode({
    required String plant,
    required String unit,
    required String coolerType,
    required String seqNo,
  }) {
    final code = _coolerShortCodes[coolerType] ?? 'WC';
    final seqStr = seqNo.trim().isEmpty ? '001' : seqNo.trim();
    return '$plant-$unit-$code-$seqStr';
  }

  String _getNextSeqNoForType(String coolerType) {
    final sameTypeCoolers = _coolers.where((c) => c.coolerType == coolerType).toList();
    int maxSeq = 0;
    for (var c in sameTypeCoolers) {
      final parts = c.tagId.split('-');
      if (parts.isNotEmpty) {
        final seqInt = int.tryParse(parts.last) ?? 0;
        if (seqInt > maxSeq) maxSeq = seqInt;
      }
    }
    return (maxSeq + 1).toString().padLeft(3, '0');
  }

  bool _isTagIdExists(String tagId) {
    return _coolers.any((c) => c.tagId.toUpperCase() == tagId.trim().toUpperCase());
  }

  String _getQuarterString(DateTime date) {
    final year = date.year;
    final month = date.month;
    if (month >= 1 && month <= 3) return '$year-Q1';
    if (month >= 4 && month <= 6) return '$year-Q2';
    if (month >= 7 && month <= 9) return '$year-Q3';
    return '$year-Q4';
  }

  // Tailored statutory checkpoints for each cooler type
  List<String> _getCheckpointsForCooler(String coolerType) {
    final lower = coolerType.toLowerCase();

    if (lower.contains('hot & cold') || lower.contains('hot and cold') || lower.contains('dispenser')) {
      return const [
        '1. Check 30mA RCCB / ELCB healthiness & trip test at power source',
        '2. Check incoming power cable, 3-pin industrial plug & earthing continuity',
        '3. Check dispenser metal chassis double earthing',
        '4. Check compressor wiring, capacitor & thermal overload relay',
        '5. Clean & sanitize internal SS-304 water tanks (descaling chemical flush)',
        '6. Check inlet to filter braided hose for leakage or pressure drops',
        '7. Check outlet from filter braided hose connections for leakage',
        '8. Check & replace pre-filter spun PP sediment candle (5 micron)',
        '9. Check post-carbon block (CTO) for de-chlorination & organic odor removal',
        '10. Check UV purification chamber lamp & ballast health',
        '11. Test water TDS level (acceptable <= 500 ppm as per IS 10500)',
        '12. Check cold water thermostat operation & auto cut-off (10-15 deg C)',
        '13. Check hot water thermostat & thermal overheat cut-out (80-90 deg C)',
        '14. Check floating switch / magnetic level controller to prevent overflow',
        '15. Check cold water dispensing tap flow & sealing',
        '16. Check hot water dispensing tap anti-scald child safety lock & flow',
        '17. Check normal / ambient water dispensing tap flow & sealing',
        '18. Thorough sanitization of outer body, faucet nozzles & drip tray',
        '19. Clean SS drip tray, waste drain line & check free drainage',
        '20. Check machine identification tag number & quarterly certification label',
      ];
    } else if (lower.contains('ro') || lower.contains('uv') || lower.contains('purifi')) {
      return const [
        '1. Check 30mA RCCB / ELCB healthiness & power source earthing',
        '2. Check power supply SMPS adapter, booster pump wiring & earthing',
        '3. Check high-pressure booster pump pressure & head',
        '4. Sanitize internal pure water storage tank with food-grade disinfectant',
        '5. Check inlet water line & solenoid valve (SV) for leakage',
        '6. Check RO reject water drain line flow & restrictor (FR)',
        '7. Check & replace stage 1 spun PP sediment candle (5 micron)',
        '8. Check stage 2 granular activated carbon (GAC) filter',
        '9. Check stage 3 carbon block (CTO) filter',
        '10. Check stage 4 RO membrane rejection efficiency & pressure tightness',
        '11. Check stage 5 germicidal UV lamp glowing inside quartz sleeve',
        '12. Check stage 6 post-carbon mineralizer / taste enhancer',
        '13. Test raw water TDS vs. purified water TDS (rejection >= 85%)',
        '14. Check auto-flush controller & low pressure switch (LPS)',
        '15. Check high pressure switch (HPS) auto cut-off on full tank',
        '16. Check cold water thermostat & cooling performance (10-15 deg C)',
        '17. Check pure water dispensing taps for drip-free operation',
        '18. Clean drip tray, wastewater outlet & faucet nozzles',
        '19. Check machine identification tag number & quarterly certification label',
      ];
    } else if (lower.contains('storage') || lower.contains('commercial') || lower.contains('cwc')) {
      return const [
        '1. Check 30mA RCCB / ELCB healthiness & trip test at power source',
        '2. Check incoming power cable, plug top & heavy-duty earthing continuity',
        '3. Check unit stainless steel cabinet double earthing',
        '4. Check refrigeration condensing unit, fan motor & compressor health',
        '5. Thorough descaling & chemical sanitization of bulk SS-304 storage tank',
        '6. Check main water inlet line & isolation ball valve for leakage',
        '7. Check internal bypass & distribution piping for joint leakage',
        '8. Check & replace high-flow pre-filter sediment cartridge (5 micron)',
        '9. Check commercial activated carbon filter block condition',
        '10. Test drinking water TDS level (acceptable <= 500 ppm)',
        '11. Check cold water thermostat temperature cut-off (10-15 deg C)',
        '12. Check heavy-duty brass float valve / level switch shut-off',
        '13. Check all push-button / lever dispensing taps for smooth flow & zero drips',
        '14. Check stainless steel splash guard & basin condition',
        '15. Clean wide drain trough, waste trap & check unhindered drainage',
        '16. Check refrigerant piping insulation & condensation tray',
        '17. Thorough outer body washing & faucet sanitization',
        '18. Check machine identification tag number & quarterly certification label',
      ];
    } else {
      return const [
        '1. Check 30mA RCCB / ELCB healthiness & power socket earthing',
        '2. Check supply cord, plug top & chassis earthing',
        '3. Check mounting heavy-duty bracket stability & anchor bolts',
        '4. Check compressor & fan motor vibration mounts',
        '5. Sanitize internal cooling coil & water reservoir',
        '6. Check inlet braided flexible hose & stop-cock for leakage',
        '7. Check inline sediment filter candle condition',
        '8. Check inline carbon filter block',
        '9. Test drinking water TDS level (acceptable <= 500 ppm)',
        '10. Check cold water thermostat cut-off (10-15 deg C)',
        '11. Check push bubbler tap operation, stream height & instant cut-off',
        '12. Check glass filler tap sealing & smooth flow',
        '13. Clean stainless steel basin & anti-splash drain strainer',
        '14. Check waste water P-trap & wall drain pipe connection for leaks',
        '15. Clean outer stainless steel panels & polish',
        '16. Check machine identification tag number & quarterly certification label',
      ];
    }
  }

  void _initializeCheckpointsForCoolerType(String coolerType) {
    final list = _getCheckpointsForCooler(coolerType);
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

  // Uses dedicated 'water_coolers' and 'water_cooler_reports' collections
  Future<void> _fetchData() async {
    if (_selectedPlantId == null || _selectedUnitId == null) return;

    try {
      final coolerSnap = await _firestore
          .collection('water_coolers')
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();

      _coolers = coolerSnap.docs
          .map((doc) => WaterCoolerModel.fromMap(doc.data(), doc.id))
          .toList();

      final now = DateTime.now();
      for (var i = 0; i < _coolers.length; i++) {
        final cooler = _coolers[i];
        if (cooler.status == 'Certified' && cooler.nextDueDate != null && cooler.nextDueDate!.isBefore(now)) {
          _coolers[i] = WaterCoolerModel(
            id: cooler.id,
            plantId: cooler.plantId,
            unitId: cooler.unitId,
            tagId: cooler.tagId,
            coolerType: cooler.coolerType,
            make: cooler.make,
            modelNumber: cooler.modelNumber,
            capacityLiters: cooler.capacityLiters,
            owner: cooler.owner,
            department: cooler.department,
            location: cooler.location,
            status: 'Expired',
            lastServicingDate: cooler.lastServicingDate,
            nextDueDate: cooler.nextDueDate,
            currentQuarter: cooler.currentQuarter,
            remarks: cooler.remarks,
            createdAt: cooler.createdAt,
            updatedAt: cooler.updatedAt,
          );
        }
      }

      final reportSnap = await _firestore
          .collection('water_cooler_reports')
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();

      _reports = reportSnap.docs
          .map((doc) => WaterCoolerReportModel.fromMap(doc.data(), doc.id))
          .toList();

      _reports.sort((a, b) => b.testingDate.compareTo(a.testingDate));
    } catch (e) {
      debugPrint('Error fetching water cooler data: $e');
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

  // --- Add / Edit Master Water Cooler Dialog (No Owner & Department fields, dropdowns for Make & Capacity) ---
  void _showAddEditCoolerDialog([WaterCoolerModel? existing]) {
    final formKey = GlobalKey<FormState>();
    final isEdit = existing != null;

    String selectedType = existing?.coolerType ?? _coolerTypes.first;
    String selectedMake = existing?.make.isNotEmpty == true && _makes.contains(existing!.make)
        ? existing.make
        : 'Voltas';
    String selectedCapacity = existing?.capacityLiters.isNotEmpty == true && _capacities.contains(existing!.capacityLiters)
        ? existing.capacityLiters
        : '40 L/hr';

    final initialSeq = isEdit ? existing.tagId.split('-').last : _getNextSeqNoForType(selectedType);
    final seqNoCtl = TextEditingController(text: initialSeq);
    final locationCtl = TextEditingController(text: existing?.location ?? '');

    String currentGeneratedId = isEdit
        ? existing.tagId
        : _generateTagCode(
            plant: _selectedPlantId!,
            unit: _selectedUnitId!,
            coolerType: selectedType,
            seqNo: seqNoCtl.text,
          );

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            void updateTagIdAndSeq({bool updateSeq = false}) {
              if (!isEdit) {
                setDialogState(() {
                  if (updateSeq) {
                    seqNoCtl.text = _getNextSeqNoForType(selectedType);
                  }
                  currentGeneratedId = _generateTagCode(
                    plant: _selectedPlantId!,
                    unit: _selectedUnitId!,
                    coolerType: selectedType,
                    seqNo: seqNoCtl.text,
                  );
                });
              }
            }

            final elClass = _coolerCategoryClasses[selectedType] ?? 'Dual-Temp Dispenser (Heating & Cooling)';

            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(isEdit ? 'Edit Cooler: ${existing.tagId}' : 'Register Water Cooler & Dispenser'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Dispenser / Cooler Type',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: _coolerTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              selectedType = v;
                              updateTagIdAndSeq(updateSeq: true);
                            }
                          },
                        ),
                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.water_drop, color: Colors.blueAccent, size: 16),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Category: $elClass',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Optional Make & Capacity Dropdowns
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedMake,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Make / Brand (Optional)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: _makes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) {
                                  if (v != null) selectedMake = v;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedCapacity,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Capacity (Optional)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: _capacities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) {
                                  if (v != null) selectedCapacity = v;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

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
                                coolerType: selectedType,
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
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueAccent),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Auto-Generated Tag ID (Document Key)',
                                  style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
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
                            labelText: 'Location / Area Name',
                            hintText: 'e.g. Admin Building 1st Floor Pantry',
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
                        await _firestore.collection('water_coolers').doc(existing.id).update({
                          'coolerType': selectedType,
                          'make': selectedMake,
                          'capacityLiters': selectedCapacity,
                          'location': locationCtl.text.trim(),
                          'updatedAt': DateTime.now().toIso8601String(),
                        });
                      } else {
                        final newCooler = WaterCoolerModel(
                          id: currentGeneratedId,
                          plantId: _selectedPlantId!,
                          unitId: _selectedUnitId!,
                          tagId: currentGeneratedId,
                          coolerType: selectedType,
                          make: selectedMake,
                          capacityLiters: selectedCapacity,
                          owner: 'Vedanta',
                          department: 'Plant Utility',
                          location: locationCtl.text.trim(),
                          status: 'Never Tested',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        await _firestore.collection('water_coolers').doc(currentGeneratedId).set(newCooler.toMap());
                      }

                      await _fetchData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdit ? 'Updated Cooler: $currentGeneratedId' : 'Registered Cooler: $currentGeneratedId')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving cooler: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: Text(isEdit ? 'Update Cooler' : 'Save Cooler'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCooler(WaterCoolerModel cooler) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Water Cooler'),
        content: Text('Are you sure you want to delete "${cooler.tagId}"? Associated servicing records will remain for audit trail.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() => _isLoading = true);

              try {
                await _firestore.collection('water_coolers').doc(cooler.id).delete();
                await _fetchData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting cooler: $e')),
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
        String tempType = _filterCoolerType;
        String tempMake = _filterMake;
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
                      const Text('Filter Water Coolers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempType = 'All';
                            tempMake = 'All';
                            tempStatus = 'All';
                            tempQuarter = 'All';
                          });
                        },
                        child: const Text('Reset All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: tempType,
                    decoration: const InputDecoration(labelText: 'Dispenser Type', border: OutlineInputBorder(), isDense: true),
                    items: ['All', ..._coolerTypes].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setModalState(() => tempType = v!),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: tempMake,
                    decoration: const InputDecoration(labelText: 'Make / Brand', border: OutlineInputBorder(), isDense: true),
                    items: ['All', ..._makes].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setModalState(() => tempMake = v!),
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
                        _filterCoolerType = tempType;
                        _filterMake = tempMake;
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

  // --- SUBMIT QUARTERLY SERVICING & CERTIFICATION ---
  Future<void> _submitInspection() async {
    if (!_formKey.currentState!.validate() || _selectedCoolerForInspection == null) {
      if (_selectedCoolerForInspection == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a master cooler to perform checklist')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final cooler = _selectedCoolerForInspection!;
      final typeLower = cooler.coolerType.toLowerCase();
      final bool hasHotOption = typeLower.contains('hot & cold') || typeLower.contains('hot and cold') || typeLower.contains('dual');
      final bool hasColdOption = !typeLower.contains('ambient only');
      final bool hasTdsOption = typeLower.contains('ro') || typeLower.contains('uv') || typeLower.contains('purifi') || typeLower.contains('hot & cold') || typeLower.contains('dispenser') || typeLower.contains('storage') || typeLower.contains('cwc') || typeLower.contains('other');

      final double? tds = hasTdsOption ? double.tryParse(_tdsController.text.trim()) : null;
      final double? coldT = hasColdOption ? double.tryParse(_coldTempController.text.trim()) : null;
      final double? hotT = hasHotOption ? double.tryParse(_hotTempController.text.trim()) : null;

      bool isAllCheckpointsOk = !_checkpointStates.containsValue(false);
      bool isTdsSafe = tds == null || tds <= 500.0; // IS 10500 threshold
      bool isCertified = isAllCheckpointsOk && isTdsSafe;
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

      final fullRemarks = [
        if (itemizedRemarks.isNotEmpty) 'DEFECTS: ${itemizedRemarks.join(" | ")}',
        if (_remarksController.text.trim().isNotEmpty) _remarksController.text.trim(),
      ].join(' \n');

      final reportRef = _firestore.collection('water_cooler_reports').doc();
      final reportModel = WaterCoolerReportModel(
        id: reportRef.id,
        plantId: cooler.plantId,
        unitId: cooler.unitId,
        coolerId: cooler.id,
        tagId: cooler.tagId,
        coolerType: cooler.coolerType,
        owner: cooler.owner,
        department: cooler.department,
        location: cooler.location,
        checkType: 'Quarterly Servicing & Certification',
        testingDate: _testDate,
        nextDueDate: nextDue,
        quarter: qStr,
        status: statusStr,
        servicedBy: _testedByController.text.trim().isNotEmpty ? _testedByController.text.trim() : _currentUserName,
        vendorName: cooler.owner,
        measuredTds: tds,
        coldTemperature: coldT,
        hotTemperature: hotT,
        checkpoints: _checkpointStates,
        actionTaken: itemizedRemarks.isNotEmpty ? itemizedRemarks.join(" ; ") : 'Quarterly filter sanitization completed',
        remarks: fullRemarks,
      );

      await reportRef.set(reportModel.toMap());

      await _firestore.collection('water_coolers').doc(cooler.id).update({
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
                  ? 'Quarterly Servicing & Water Certification SUCCESS for: ${cooler.tagId}'
                  : 'UNSAFE / FAILED logged for: ${cooler.tagId}. Disconnect water & take into maintenance custody.',
            ),
            backgroundColor: isCertified ? Colors.green.shade700 : Colors.red.shade700,
          ),
        );

        setState(() {
          _selectedCoolerForInspection = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save quarterly checklist: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _startInspectionForCooler(WaterCoolerModel cooler) {
    setState(() {
      _selectedCoolerForInspection = cooler;
      _initializeCheckpointsForCoolerType(cooler.coolerType);
    });
  }

  // --- PDF EXPORTS ---
  Future<void> _exportPdfCertificate(WaterCoolerReportModel report) async {
    try {
      final pdf = pw.Document();
      final checkSheetTitle = 'WATER COOLER & HOT/COOL DISPENSER SERVICING CERTIFICATE';
      final categoryDesc = _coolerCategoryClasses[report.coolerType] ?? 'Dual-Temp Dispenser (Heating & Cooling)';

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
                          '$checkSheetTitle (IS 14724 / IS 10500:2012)',
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
                      _pdfCell('Cooler Tag ID / Set No.:', report.tagId, isBold: true),
                      _pdfCell('Category / Type:', '${report.coolerType} ($categoryDesc)'),
                    ]),
                    pw.TableRow(children: [
                      _pdfCell('Location / Area:', report.location),
                      _pdfCell('Servicing Date / Quarter:', '${report.testingDate.toString().split(' ')[0]} (${report.quarter})', isBold: true),
                    ]),
                    pw.TableRow(children: [
                      _pdfCell('Plant / Unit:', '${report.plantId} - ${report.unitId}'),
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
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue300, width: 0.8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      if (report.measuredTds != null)
                        pw.Text('Measured TDS: ${report.measuredTds!.toStringAsFixed(1)} ppm (Limit <= 500 ppm)',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      if (report.coldTemperature != null)
                        pw.Text('Cold Temp: ${report.coldTemperature!.toStringAsFixed(1)} C (Std: 10-15 C)',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      if (report.hotTemperature != null)
                        pw.Text('Hot Temp: ${report.hotTemperature!.toStringAsFixed(1)} C (Std: 80-90 C)',
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
                    'Equipment certified for potable drinking water usage as per IS 10500:2012 & IS 14724 safety standards.',
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
                        pw.Text('Serviced / Certified By: ${report.servicedBy}',
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

      final fileName = 'Water_Cooler_Cert_${report.tagId}_${report.quarter}.pdf';
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
                      pw.Text('Water Cooler, Hot & Cold Dispenser Quarterly Servicing Audit Summary',
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
                    decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                    children: [
                      _pdfHeaderCell('Tag ID'),
                      _pdfHeaderCell('Dispenser Type'),
                      _pdfHeaderCell('Make / Capacity'),
                      _pdfHeaderCell('Location'),
                      _pdfHeaderCell('Status'),
                      _pdfHeaderCell('Quarter'),
                      _pdfHeaderCell('Last Serviced'),
                      _pdfHeaderCell('Next Due Date'),
                      _pdfHeaderCell('Serviced By'),
                    ],
                  ),
                  ..._coolers.map((c) {
                    final matchingReport = _reports.firstWhere(
                      (r) => r.coolerId == c.id || r.tagId == c.tagId,
                      orElse: () => WaterCoolerReportModel(
                        id: '',
                        plantId: c.plantId,
                        unitId: c.unitId,
                        coolerId: c.id,
                        tagId: c.tagId,
                        coolerType: c.coolerType,
                        owner: c.owner,
                        department: c.department,
                        location: c.location,
                        checkType: '',
                        testingDate: c.lastServicingDate ?? DateTime.now(),
                        nextDueDate: c.nextDueDate ?? DateTime.now(),
                        quarter: c.currentQuarter,
                        status: c.status,
                        servicedBy: 'N/A',
                        vendorName: c.owner,
                        checkpoints: {},
                        remarks: '',
                      ),
                    );

                    final servDateStr = c.lastServicingDate != null ? c.lastServicingDate.toString().split(' ')[0] : 'Never';
                    final nextDueStr = c.nextDueDate != null ? c.nextDueDate.toString().split(' ')[0] : 'N/A';
                    final servicedByStr = matchingReport.servicedBy.isNotEmpty ? matchingReport.servicedBy : 'N/A';

                    return pw.TableRow(
                      children: [
                        _pdfBodyCell(c.tagId, isBold: true),
                        _pdfBodyCell(c.coolerType),
                        _pdfBodyCell('${c.make} (${c.capacityLiters})'),
                        _pdfBodyCell(c.location),
                        _pdfBodyCell(
                          c.status,
                          color: c.status == 'Certified'
                              ? PdfColors.green800
                              : (c.status == 'Expired' ? PdfColors.orange800 : PdfColors.red800),
                        ),
                        _pdfBodyCell(c.currentQuarter.isEmpty ? 'N/A' : c.currentQuarter),
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

      final fileName = 'Water_Coolers_Summary_${_selectedPlantId}_$_selectedUnitId.pdf';
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
      final List<Map<String, dynamic>> excelData = _coolers.map((c) {
        final matchingReport = _reports.firstWhere(
          (r) => r.coolerId == c.id || r.tagId == c.tagId,
          orElse: () => WaterCoolerReportModel(
            id: '',
            plantId: c.plantId,
            unitId: c.unitId,
            coolerId: c.id,
            tagId: c.tagId,
            coolerType: c.coolerType,
            owner: c.owner,
            department: c.department,
            location: c.location,
            checkType: '',
            testingDate: c.lastServicingDate ?? DateTime.now(),
            nextDueDate: c.nextDueDate ?? DateTime.now(),
            quarter: c.currentQuarter,
            status: c.status,
            servicedBy: 'N/A',
            vendorName: c.owner,
            checkpoints: {},
            remarks: '',
          ),
        );

        return {
          'Tag ID': c.tagId,
          'Cooler Type': c.coolerType,
          'Category': _coolerCategoryClasses[c.coolerType] ?? 'Dual-Temp Dispenser',
          'Make': c.make,
          'Capacity': c.capacityLiters,
          'Location': c.location,
          'Status': c.status,
          'Quarter': c.currentQuarter,
          'Servicing Date': c.lastServicingDate != null ? c.lastServicingDate.toString().split(' ')[0] : 'Never',
          'Next Due Date': c.nextDueDate != null ? c.nextDueDate.toString().split(' ')[0] : 'N/A',
          'Serviced By': matchingReport.servicedBy,
          'TDS (ppm)': matchingReport.measuredTds ?? 120.0,
          'Cold Temp (C)': matchingReport.coldTemperature ?? 12.0,
          'Hot Temp (C)': matchingReport.hotTemperature ?? 85.0,
          'Remarks': c.remarks,
        };
      }).toList();

      final fileName = 'Water_Coolers_Report_${_selectedPlantId}_$_selectedUnitId.xlsx';
      final bytes = ExcelService().generateExcel(
        excelData,
        'Water Coolers Registry',
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

  List<WaterCoolerModel> get _filteredCoolers {
    final query = _searchController.text.trim().toLowerCase();
    return _coolers.where((cooler) {
      final matchesSearch = query.isEmpty ||
          cooler.tagId.toLowerCase().contains(query) ||
          cooler.coolerType.toLowerCase().contains(query) ||
          cooler.location.toLowerCase().contains(query);

      final matchesChip = _selectedCoolerTypeChip == 'All Types' || cooler.coolerType == _selectedCoolerTypeChip;
      final matchesType = _filterCoolerType == 'All' || cooler.coolerType == _filterCoolerType;
      final matchesMake = _filterMake == 'All' || cooler.make == _filterMake;
      final matchesStatus = _filterStatus == 'All' || cooler.status == _filterStatus;
      final matchesQuarter = _filterQuarter == 'All' || cooler.currentQuarter == _filterQuarter;

      return matchesSearch && matchesChip && matchesType && matchesMake && matchesStatus && matchesQuarter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Water Cooler & Dispenser Checklist'),
        body: Center(child: PulseLoading()),
      );
    }

    return PopScope(
      canPop: _selectedCoolerForInspection == null && _historyCooler == null && !_isManagingDatabase && !_showHelp,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          if (_selectedCoolerForInspection != null) {
            _selectedCoolerForInspection = null;
          } else if (_historyCooler != null) {
            _historyCooler = null;
          } else if (_isManagingDatabase) {
            _isManagingDatabase = false;
          } else if (_showHelp) {
            _showHelp = false;
          }
        });
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Water Cooler & Dispenser Checklist'),
        body: _selectedCoolerForInspection != null
            ? _buildRecordingFormView()
            : _historyCooler != null
                ? _buildHistoryView()
                : _isManagingDatabase
                    ? _buildManageDatabaseView()
                    : _showHelp
                        ? _buildHelpView()
                        : _buildMainView(),
      ),
    );
  }

  // --- MAIN VIEW (Zero Layout Overflows, Spacious Responsive Cards) ---
  Widget _buildMainView() {
    final filtered = _filteredCoolers;
    final total = _coolers.length;
    final certified = _coolers.where((c) => c.status == 'Certified').length;
    final notCertified = _coolers.where((c) => c.status == 'Not Certified').length;
    final expired = _coolers.where((c) => c.status == 'Expired' || c.status == 'Never Tested').length;
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

          // 2. Metrics Compliance Overview Card (Responsive Zero Overflow Header)
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
                          'Drinking Water & Cooler Safety Compliance',
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
                      _buildStatItem('Total Units', '$total', Colors.white),
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
                    hintText: 'Search Tag ID, Cooler Type, Location...',
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
                tooltip: 'Filter Coolers',
                onPressed: _showFilterModal,
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.help_outline, color: Colors.white),
                tooltip: 'IS 10500 & Servicing Guide',
                onPressed: () => setState(() => _showHelp = true),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 4),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.settings, color: Colors.white),
                  tooltip: 'Manage Coolers Registry',
                  onPressed: () => setState(() => _isManagingDatabase = true),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Quick Filter Horizontal Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTypeChip('All Types'),
                ..._coolerTypes.map((type) => _buildTypeChip(type)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Header Row with Title & Excel / PDF Action Buttons (Wrapped to prevent overflow)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Water Coolers & Dispensers (${filtered.length})',
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

          // 5. Unit Cards with Clear Status & "Due in X Days" / "Overdue" Calculation
          filtered.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text('No matching water coolers or dispensers found for the selected scope.'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final cooler = filtered[index];
                    final now = DateTime.now();
                    final isNotCert = cooler.status == 'Not Certified';
                    final isCert = cooler.status == 'Certified';

                    int? daysRemaining;
                    int? overdueDays;
                    if (cooler.nextDueDate != null) {
                      daysRemaining = cooler.nextDueDate!.difference(now).inDays;
                      if (daysRemaining < 0) {
                        overdueDays = now.difference(cooler.nextDueDate!).inDays;
                      }
                    }

                    final bool isOverdue = (cooler.status == 'Expired') || (daysRemaining != null && daysRemaining < 0);

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
                      dueText = 'Status: FAILED / UNSAFE (Custody Lockout)';
                      dueTextColor = Colors.redAccent;
                    } else if (isOverdue) {
                      statusColor = Colors.orangeAccent;
                      pillBg = Colors.orange.withValues(alpha: 0.15);
                      statusIcon = Icons.hourglass_bottom;
                      statusBadgeText = 'OVERDUE';
                      dueText = overdueDays != null
                          ? 'Overdue by $overdueDays days (Due: ${cooler.nextDueDate.toString().split(' ')[0]})'
                          : 'Overdue for Quarterly Servicing';
                      dueTextColor = Colors.orangeAccent;
                    } else if (isCert) {
                      statusColor = Colors.greenAccent;
                      pillBg = Colors.green.withValues(alpha: 0.15);
                      statusIcon = Icons.check_circle;
                      statusBadgeText = 'CERTIFIED';
                      if (daysRemaining != null && daysRemaining > 0) {
                        dueText = 'Due in $daysRemaining days (${cooler.nextDueDate.toString().split(' ')[0]})';
                        dueTextColor = Colors.greenAccent;
                      } else if (daysRemaining == 0) {
                        dueText = 'Due Today (${cooler.nextDueDate.toString().split(' ')[0]})';
                        dueTextColor = Colors.amberAccent;
                      } else {
                        dueText = 'Next Due: ${cooler.nextDueDate.toString().split(' ')[0]}';
                        dueTextColor = Colors.greenAccent;
                      }
                    }

                    final elClass = _coolerCategoryClasses[cooler.coolerType] ?? 'Dual-Temp Dispenser (Heating & Cooling)';

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
                                        '${cooler.tagId} - ${cooler.coolerType}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Category: $elClass',
                                        style: const TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Make: ${cooler.make.isNotEmpty ? cooler.make : "Standard"} • Capacity: ${cooler.capacityLiters.isNotEmpty ? cooler.capacityLiters : "40 L/hr"}',
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                      ),
                                      if (cooler.location.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text('Location: ${cooler.location}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
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
                                    cooler.currentQuarter.isNotEmpty ? 'Q: ${cooler.currentQuarter}' : 'Q: N/A',
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
                                    cooler.lastServicingDate != null
                                        ? 'Last Serviced: ${cooler.lastServicingDate.toString().split(' ')[0]}'
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
                                      onPressed: () => setState(() => _historyCooler = cooler),
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
                                        isCert ? 'Reservice' : 'Service Unit',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      onPressed: () => _startInspectionForCooler(cooler),
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

  Widget _buildTypeChip(String label) {
    final isSelected = _selectedCoolerTypeChip == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        onSelected: (val) {
          setState(() {
            _selectedCoolerTypeChip = label;
          });
        },
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

  // --- HISTORY VIEW (_historyCooler != null) ---
  Widget _buildHistoryView() {
    final cooler = _historyCooler!;
    final coolerReports = _reports.where((r) => r.coolerId == cooler.id || r.tagId == cooler.tagId).toList();
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
                  onPressed: () => setState(() => _historyCooler = null),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Servicing History: ${cooler.tagId}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('${cooler.coolerType} • Make: ${cooler.make} • Location: ${cooler.location}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (coolerReports.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Text('No quarterly servicing records found for this unit.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: coolerReports.length,
                itemBuilder: (context, index) {
                  final r = coolerReports[index];
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
                                Text('Date: ${r.testingDate.toString().split(' ')[0]} | By: ${r.servicedBy} | TDS: ${r.measuredTds ?? 120.0} ppm',
                                    style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white70 : Colors.grey.shade700)),
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

  // --- RECORDING FORM VIEW (_selectedCoolerForInspection != null) ---
  Widget _buildRecordingFormView() {
    final cooler = _selectedCoolerForInspection!;
    final checkSheetTitle = '${cooler.coolerType.toUpperCase()} SERVICING CHECK SHEET';
    final elClass = _coolerCategoryClasses[cooler.coolerType] ?? 'Dual-Temp Dispenser (Heating & Cooling)';

    final typeLower = cooler.coolerType.toLowerCase();
    final bool hasHotOption = typeLower.contains('hot & cold') || typeLower.contains('hot and cold') || typeLower.contains('dual');
    final bool hasColdOption = !typeLower.contains('ambient only');
    final bool hasTdsOption = typeLower.contains('ro') || typeLower.contains('uv') || typeLower.contains('purifi') || typeLower.contains('hot & cold') || typeLower.contains('dispenser') || typeLower.contains('storage') || typeLower.contains('cwc') || typeLower.contains('other');

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
                        onPressed: () => setState(() => _selectedCoolerForInspection = null),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          checkSheetTitle,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.assignment, color: Colors.blueAccent, size: 15),
                            SizedBox(width: 6),
                            Text('WATER COOLER SERVICING DETAILS',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueAccent)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${cooler.coolerType} Tag ID: ${cooler.tagId}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Text('Category: $elClass',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                        Text('Make: ${cooler.make} (${cooler.capacityLiters}) | Location: ${cooler.location}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('Plant: $_selectedPlantId - $_selectedUnitId',
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
                          decoration: const InputDecoration(labelText: 'Servicing Date', border: OutlineInputBorder(), isDense: true),
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

                  // Applicable & Practical Measurement Inputs tailored to Cooler Type
                  Row(
                    children: [
                      if (hasTdsOption)
                        Expanded(
                          child: TextFormField(
                            controller: _tdsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Water TDS (ppm)',
                              hintText: '<= 500 ppm',
                              suffixText: 'ppm',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter TDS' : null,
                          ),
                        ),
                      if (hasTdsOption && (hasColdOption || hasHotOption)) const SizedBox(width: 8),
                      if (hasColdOption)
                        Expanded(
                          child: TextFormField(
                            controller: _coldTempController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cold Temp (10-15 °C)',
                              suffixText: '°C',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      if (hasHotOption) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _hotTempController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Hot Temp (80-90 °C)',
                              suffixText: '°C',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _testedByController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Servicing Done By / Certifier (Profile)',
                      prefixIcon: Icon(Icons.lock_person, color: Colors.blueAccent, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Divider(),
                  const SizedBox(height: 6),
                  Text('CHECK POINTS VERIFICATION (${_checkpointStates.length} POINTS)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
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
                                hintText: 'e.g. Filter choked, Hose leaking, Thermostat stuck, Tank scaled...',
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
                      'Water cooler will be certified for drinking use only after all electrical, hydraulic, and filtration points are found compliant as per IS 10500 / IS 14724.',
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
                      _isSubmitting ? 'Saving Servicing...' : 'SUBMIT QUARTERLY SERVICING REPORT',
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
                    'Manage Water Coolers Registry',
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
                    label: const Text('Add New Cooler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () => _showAddEditCoolerDialog(null),
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
                            collectionId: 'water_coolers',
                            title: 'Water Coolers Import',
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
            _coolers.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No water coolers found. Add one above!')))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _coolers.length,
                    itemBuilder: (context, idx) {
                      final cooler = _coolers[idx];
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
                                        Text(cooler.tagId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 3),
                                        Text('${cooler.coolerType} • Make: ${cooler.make} • Capacity: ${cooler.capacityLiters}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        if (cooler.location.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text('Location: ${cooler.location}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.amberAccent, size: 20),
                                        tooltip: 'Edit Cooler',
                                        onPressed: () => _showAddEditCoolerDialog(cooler),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                        tooltip: 'Delete Cooler',
                                        onPressed: () => _confirmDeleteCooler(cooler),
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
                    'Water Cooler & Dispenser Servicing Standards (IS 14724 / IS 10500)',
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
                        Icon(Icons.water_drop, color: Colors.amberAccent, size: 20),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '1. Statutory Servicing Clusters & Safety Limits',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildHelpItem(
                      'Cluster 1: Electrical & Power Supply Safety (CEA 2023)',
                      'ELECTRICAL INTEGRITY',
                      Colors.greenAccent,
                      '• RCCB Trip Test: 30mA residual current trip test at incoming socket to prevent electric shock in wet environments.\n'
                      '• Double Earthing: External metal body and internal refrigeration compressor must be solidly bonded to Protective Earth.\n'
                      '• Compressor Health: Sealed compressor wiring, start capacitor, and thermal overload cut-off verification.',
                    ),
                    const SizedBox(height: 10),

                    _buildHelpItem(
                      'Cluster 2: Hydraulic Lines, Valves & Leakage (IS 14724)',
                      'PLUMBING & VALVES',
                      Colors.cyanAccent,
                      '• Braided Hoses: Food-grade stainless steel braided hoses for both inlet and outlet filter lines with zero joint leakage.\n'
                      '• Floating Switch: High-level magnetic floating switch to automatically cut off incoming water flow and prevent storage tank overflow.\n'
                      '• Waste Drainage: SS drip tray drainage line sloped properly to prevent water stagnation and bacterial growth.',
                    ),
                    const SizedBox(height: 10),

                    _buildHelpItem(
                      'Cluster 3: Filtration, Purification & Sanitization (IS 10500:2012)',
                      'POTABLE WATER QUALITY',
                      Colors.purpleAccent,
                      '• SS-304 Tank Descaling: Food-grade sanitizing chemical flush (hydrogen peroxide / mild chlorine) to eliminate biofilm.\n'
                      '• Pre-Filter PP Candle: Replacement of 5-micron spun polypropylene sediment candle to trap suspended particulates.\n'
                      '• Activated Carbon Block: High-adsorption activated carbon block for de-chlorination and organic taste/odor removal.\n'
                      '• UV Radiation Lamp: Germicidal UV-C lamp glowing inside quartz sleeve for biological disinfection.\n'
                      '• TDS Limits: Total Dissolved Solids must be checked and maintained within acceptable drinking limits (<= 500 ppm).',
                    ),
                    const SizedBox(height: 10),

                    _buildHelpItem(
                      'Cluster 4: Thermal Calibration & Dispensing Taps',
                      'TEMPERATURE CONTROL',
                      Colors.blueAccent,
                      '• Cold Thermostat: Auto cut-off calibrated between 10 deg C to 15 deg C to prevent evaporator freeze-up.\n'
                      '• Hot Thermostat & Overheat Cut-out: High-limit thermal safety cut-off calibrated between 80 deg C to 90 deg C.\n'
                      '• Faucet Taps: Drip-free operation with safety child-lock on hot water taps to prevent accidental burns.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            GlassContainer(
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('2. Applicable Measurement Parameters By Equipment Type',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.amber)),
                    const SizedBox(height: 8),
                    const Text(
                      'To prevent redundant fields, only parameters physically applicable to each cooler setup are recorded:',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Table(
                      border: TableBorder.all(color: Colors.white24, width: 0.8),
                      columnWidths: const {
                        0: FlexColumnWidth(2.5),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.2),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15)),
                          children: const [
                            Padding(padding: EdgeInsets.all(6), child: Text('Equipment Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(6), child: Text('TDS (ppm)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purpleAccent))),
                            Padding(padding: EdgeInsets.all(6), child: Text('Cold Temp', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent))),
                            Padding(padding: EdgeInsets.all(6), child: Text('Hot Temp', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent))),
                          ],
                        ),
                        const TableRow(children: [
                          Padding(padding: EdgeInsets.all(6), child: Text('Hot & Cold Dispenser', style: TextStyle(fontSize: 10.5))),
                          Padding(padding: EdgeInsets.all(6), child: Text('<= 500 ppm', style: TextStyle(fontSize: 10, color: Colors.greenAccent))),
                          Padding(padding: EdgeInsets.all(6), child: Text('10 - 15 °C', style: TextStyle(fontSize: 10, color: Colors.greenAccent))),
                          Padding(padding: EdgeInsets.all(6), child: Text('80 - 90 °C', style: TextStyle(fontSize: 10, color: Colors.greenAccent))),
                        ]),
                        const TableRow(children: [
                          Padding(padding: EdgeInsets.all(6), child: Text('Storage Water Cooler (SS)', style: TextStyle(fontSize: 10.5))),
                          Padding(padding: EdgeInsets.all(6), child: Text('<= 500 ppm', style: TextStyle(fontSize: 10, color: Colors.greenAccent))),
                          Padding(padding: EdgeInsets.all(6), child: Text('10 - 15 °C', style: TextStyle(fontSize: 10, color: Colors.greenAccent))),
                          Padding(padding: EdgeInsets.all(6), child: Text('N/A', style: TextStyle(fontSize: 10, color: Colors.grey))),
                        ]),
                        const TableRow(children: [
                          Padding(padding: EdgeInsets.all(6), child: Text('RO + UV Water Cooler', style: TextStyle(fontSize: 10.5))),
                          Padding(padding: EdgeInsets.all(6), child: Text('<= 500 ppm', style: TextStyle(fontSize: 10, color: Colors.greenAccent))),
                          Padding(padding: EdgeInsets.all(6), child: Text('10 - 15 °C', style: TextStyle(fontSize: 10, color: Colors.greenAccent))),
                          Padding(padding: EdgeInsets.all(6), child: Text('N/A', style: TextStyle(fontSize: 10, color: Colors.grey))),
                        ]),
                        const TableRow(children: [
                          Padding(padding: EdgeInsets.all(6), child: Text('Wall Mounted Chiller', style: TextStyle(fontSize: 10.5))),
                          Padding(padding: EdgeInsets.all(6), child: Text('<= 500 ppm', style: TextStyle(fontSize: 10, color: Colors.greenAccent))),
                          Padding(padding: EdgeInsets.all(6), child: Text('10 - 15 °C', style: TextStyle(fontSize: 10, color: Colors.greenAccent))),
                          Padding(padding: EdgeInsets.all(6), child: Text('N/A', style: TextStyle(fontSize: 10, color: Colors.grey))),
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            GlassContainer(
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('3. Equipment Short Codes (Tag ID: PLANT-UNIT-CODE-SEQ)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.amber)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _coolerShortCodes.entries.map((e) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                          ),
                          child: Text('${e.value}: ${e.key}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            const Text('4. Statutory Servicing Checkpoints Directory (Tailored by Type)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _coolerTypes.length,
              itemBuilder: (context, idx) {
                final type = _coolerTypes[idx];
                final code = _coolerShortCodes[type] ?? 'WC';
                final questions = _getCheckpointsForCooler(type);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    title: Text(
                      '[$code] $type (${questions.length} Points)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    subtitle: Text('Servicing Cycle: Quarterly (Every 90 Days)', style: const TextStyle(fontSize: 10.5, color: Colors.tealAccent)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: questions.map((q) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 14, color: Colors.teal),
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
                          }).toList(),
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
